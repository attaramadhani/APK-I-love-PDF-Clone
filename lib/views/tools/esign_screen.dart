import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class EsignScreen extends StatefulWidget {
  const EsignScreen({super.key});

  @override
  State<EsignScreen> createState() => _EsignScreenState();
}

class _EsignScreenState extends State<EsignScreen> {
  File? _selectedFile;
  final List<List<Offset>> _lines = [];
  Color _selectedColor = Colors.black;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        _selectedFile = File(files.first.path!);
      });
    }
  }

  Future<File> _exportSignatureAsImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 200));

    final paint = Paint()
      ..color = _selectedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (final line in _lines) {
      for (int i = 0; i < line.length - 1; i++) {
        canvas.drawLine(line[i], line[i + 1], paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(400, 200);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final sigFile = File('${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
    await sigFile.writeAsBytes(buffer);
    return sigFile;
  }

  Future<void> _applySignatureToPdf() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dokumen PDF yang ingin ditandatangani')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gambar tanda tangan Anda pada kanvas terlebih dahulu')),
      );
      return;
    }

    ProcessingDialog.show(
      context,
      title: 'Membubuhkan Tanda Tangan',
      message: 'Menerapkan stempel tanda tangan ke halaman dokumen...',
    );

    try {
      final sigImageFile = await _exportSignatureAsImage();
      final sigBytes = await sigImageFile.readAsBytes();
      final pdfBytes = await _selectedFile!.readAsBytes();

      final document = PdfDocument(inputBytes: pdfBytes);
      final bitmap = PdfBitmap(sigBytes);

      // Bubuhkan tanda tangan di halaman terakhir pada pojok kanan bawah
      if (document.pages.count > 0) {
        final lastPage = document.pages[document.pages.count - 1];
        final pageSize = lastPage.getClientSize();
        const sigWidth = 150.0;
        const sigHeight = 75.0;

        lastPage.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(
            pageSize.width - sigWidth - 30,
            pageSize.height - sigHeight - 40,
            sigWidth,
            sigHeight,
          ),
        );
      }

      final savedBytes = await document.save();
      document.dispose();

      final outputPath = await FileHelper.generateOutputPath('Signed');
      await File(outputPath).writeAsBytes(savedBytes);

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Tanda Tangani PDF',
      );

      await RecentFilesService.addFile(processedFile);

      if (mounted) {
        ProcessingDialog.hide(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (ctx) => PdfViewerScreen(
              filePath: outputPath,
              title: processedFile.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menandatangani PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangani PDF (e-Sign)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedFile == null)
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.upload_file_rounded, size: 48, color: AppColors.editPurple),
                      SizedBox(height: 12),
                      Text('Pilih Dokumen PDF untuk Ditandatangani', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Ketuk di sini untuk memilih file dari memori perangkat', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryRed, size: 36),
                  title: Text(
                    _selectedFile!.uri.pathSegments.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(FileHelper.formatBytes(_selectedFile!.lengthSync()), style: const TextStyle(color: AppColors.textSecondary)),
                  trailing: IconButton(icon: const Icon(Icons.change_circle_outlined), onPressed: _pickFile),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kanvas Tanda Tangan Digital', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => setState(() => _lines.clear()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Hapus Coretan'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 1.5),
              ),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _lines.add([details.localPosition]);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    if (_lines.isNotEmpty) {
                      _lines.last.add(details.localPosition);
                    }
                  });
                },
                child: CustomPaint(
                  painter: _SignaturePainter(lines: _lines, color: _selectedColor),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Warna Tinta:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 12),
                _buildColorDot(Colors.black),
                _buildColorDot(const Color(0xFF0D47A1)),
                _buildColorDot(const Color(0xFFB71C1C)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _applySignatureToPdf,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Bubuhkan Tanda Tangan ke PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.editPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> lines;
  final Color color;

  _SignaturePainter({required this.lines, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (final line in lines) {
      for (int i = 0; i < line.length - 1; i++) {
        canvas.drawLine(line[i], line[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
