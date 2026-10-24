import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
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
  Size _canvasSize = const Size(400, 220);
  bool _isDrawing = false;
  String _pageMode = 'last'; // last | first | all
  String _position = 'bottom_right'; // bottom_right | bottom_left | bottom_center

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (!mounted) return;

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      try {
        await PdfEngineService.getPageCount(file);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(PdfEngineService.friendlyError(e))),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Offset _clampToCanvas(Offset p) => Offset(
        p.dx.clamp(0.0, _canvasSize.width),
        p.dy.clamp(0.0, _canvasSize.height),
      );

  /// Mengekspor coretan sebagai PNG transparan beresolusi tinggi yang dipotong
  /// rapat mengikuti area tanda tangan (tanpa ruang kosong berlebih).
  /// Mengembalikan (bytes PNG, rasio lebar/tinggi).
  Future<(Uint8List, double)> _exportSignatureAsImage() async {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final line in _lines) {
      for (final p in line) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    const pad = 8.0;
    minX -= pad;
    minY -= pad;
    maxX += pad;
    maxY += pad;
    final w = (maxX - minX).clamp(20.0, 4000.0);
    final h = (maxY - minY).clamp(20.0, 4000.0);
    const scale = 3.0; // tajam saat dicetak

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.translate(-minX, -minY);

    final paint = Paint()
      ..color = _selectedColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final dotPaint = Paint()..color = _selectedColor;

    for (final line in _lines) {
      if (line.length == 1) {
        canvas.drawCircle(line.first, 1.75, dotPaint);
        continue;
      }
      final path = Path()..moveTo(line.first.dx, line.first.dy);
      for (int i = 1; i < line.length; i++) {
        path.lineTo(line[i].dx, line[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage((w * scale).round(), (h * scale).round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return (byteData!.buffer.asUint8List(), w / h);
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
      message: 'Menerapkan tanda tangan ke halaman dokumen...',
    );

    try {
      final (sigBytes, aspect) = await _exportSignatureAsImage();
      final outputPath = await PdfEngineService.stampImage(
        _selectedFile!,
        sigBytes,
        imageAspect: aspect,
        pageMode: _pageMode,
        position: _position,
      );

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
          SnackBar(content: Text('Gagal menandatangani PDF: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  Widget _buildChoiceChips(String label, Map<String, String> options, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries
              .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: value == e.key,
                    selectedColor: AppColors.editPurple.withValues(alpha: 0.18),
                    onSelected: (_) => onChanged(e.key),
                  ))
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangani PDF (e-Sign)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        // Kunci scroll saat jari menyentuh kanvas agar coretan vertikal tidak
        // berubah menjadi gerakan menggulir halaman.
        physics: _isDrawing ? const NeverScrollableScrollPhysics() : null,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        setState(() {
                          _isDrawing = true;
                          _lines.add([_clampToCanvas(event.localPosition)]);
                        });
                      },
                      onPointerMove: (event) {
                        if (_lines.isEmpty) return;
                        setState(() {
                          _lines.last.add(_clampToCanvas(event.localPosition));
                        });
                      },
                      onPointerUp: (_) => setState(() => _isDrawing = false),
                      onPointerCancel: (_) => setState(() => _isDrawing = false),
                      child: CustomPaint(
                        painter: _SignaturePainter(lines: _lines, color: _selectedColor),
                        size: Size.infinite,
                        child: _lines.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tanda tangan di sini',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
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
            const SizedBox(height: 20),
            _buildChoiceChips(
              'Halaman:',
              const {'last': 'Halaman terakhir', 'first': 'Halaman pertama', 'all': 'Semua halaman'},
              _pageMode,
              (v) => setState(() => _pageMode = v),
            ),
            const SizedBox(height: 16),
            _buildChoiceChips(
              'Posisi:',
              const {'bottom_right': 'Kanan bawah', 'bottom_center': 'Tengah bawah', 'bottom_left': 'Kiri bawah'},
              _position,
              (v) => setState(() => _position = v),
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
      if (line.length == 1) {
        canvas.drawCircle(line.first, 1.75, Paint()..color = color);
        continue;
      }
      for (int i = 0; i < line.length - 1; i++) {
        canvas.drawLine(line[i], line[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
