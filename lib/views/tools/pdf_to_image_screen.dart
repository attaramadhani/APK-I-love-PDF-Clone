import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  List<String> _generatedImagePaths = [];
  bool _isProcessing = false;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();

      setState(() {
        _selectedFile = file;
        _totalPages = count;
        _generatedImagePaths = [];
      });
    }
  }

  /// Merender halaman dengan latar belakang putih solid (mencegah background hitam)
  Future<Uint8List> _renderPageWithWhiteBackground(PdfRaster raster) async {
    final ui.Image srcImage = await raster.toImage();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Gambar latar belakang putih solid 100% opaque
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, raster.width.toDouble(), raster.height.toDouble()),
      whitePaint,
    );

    // 2. Gambar isi dokumen PDF di atas kertas putih
    canvas.drawImage(srcImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(raster.width, raster.height);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _extractImages() async {
    if (_selectedFile == null) return;

    ProcessingDialog.show(
      context,
      title: 'Mengekstrak Gambar Halaman',
      message: 'Merender $_totalPages halaman menjadi gambar berlatar putih jernih...',
    );

    setState(() => _isProcessing = true);

    try {
      final pdfBytes = await _selectedFile!.readAsBytes();
      final List<String> imagePaths = [];
      final baseName = _selectedFile!.uri.pathSegments.last.replaceAll('.pdf', '');

      int pageIndex = 1;
      await for (final page in Printing.raster(pdfBytes, dpi: 150)) {
        // Render dengan latar belakang putih solid
        final Uint8List pngBytes = await _renderPageWithWhiteBackground(page);
        final String imagePath = await FileHelper.generateOutputPath('${baseName}_Hal_$pageIndex', '.png');
        await File(imagePath).writeAsBytes(pngBytes);
        imagePaths.add(imagePath);

        final processedFile = ProcessedFile(
          id: const Uuid().v4(),
          name: '${baseName}_Hal_$pageIndex.png',
          path: imagePath,
          sizeInBytes: pngBytes.length,
          createdAt: DateTime.now(),
          toolUsed: 'PDF ke Gambar',
        );
        await RecentFilesService.addFile(processedFile);

        pageIndex++;
      }

      if (mounted) {
        ProcessingDialog.hide(context);
        setState(() {
          _generatedImagePaths = imagePaths;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekstrak gambar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF ke Gambar (JPG/PNG)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _selectedFile == null
          ? _buildEmptyState()
          : (_generatedImagePaths.isNotEmpty ? _buildResultsGrid() : _buildConfigView()),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.convertBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_rounded, size: 64, color: AppColors.convertBlue),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilih File PDF untuk Diubah ke Gambar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ekstrak setiap halaman dokumen PDF Anda menjadi berkas gambar beresolusi tinggi dengan latar belakang putih jernih.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pilih Berkas PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.convertBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryRed, size: 36),
              title: Text(
                _selectedFile!.uri.pathSegments.last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Total: $_totalPages Halaman (${FileHelper.formatBytes(_selectedFile!.lengthSync())})'),
              trailing: IconButton(
                icon: const Icon(Icons.change_circle_outlined),
                tooltip: 'Ganti File',
                onPressed: _pickFile,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.convertBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.convertBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.image_outlined, color: AppColors.convertBlue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konversi Putih Solid (150 DPI)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Akan menghasilkan $_totalPages file gambar terpisah dengan latar belakang putih kertas yang jernih dan bebas warna hitam.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _extractImages,
              icon: const Icon(Icons.photo_library_rounded),
              label: Text('Ekstrak $_totalPages Halaman Menjadi Gambar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.convertBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.convertBlue.withValues(alpha: 0.1),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.convertBlue, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Berhasil Diekstrak: ${_generatedImagePaths.length} Gambar!',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Text(
                          'Semua halaman telah dikonversi dengan latar belakang putih jernih.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    FileHelper.saveMultipleToLocalDevice(context, filePaths: _generatedImagePaths);
                  },
                  icon: const Icon(Icons.file_download_rounded),
                  label: Text('Simpan Semua ${_generatedImagePaths.length} Gambar ke File Lokal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.convertBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pratinjau Gambar Hasil:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton(
                onPressed: () => setState(() => _generatedImagePaths = []),
                child: const Text('Pilih Berkas Lain'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: _generatedImagePaths.length,
            itemBuilder: (context, index) {
              final path = _generatedImagePaths[index];
              final file = File(path);
              final name = file.uri.pathSegments.last;

              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: Image.file(
                            file,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Hal ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.file_download_rounded, size: 18, color: AppColors.primaryBlue),
                                  tooltip: 'Simpan ke File Lokal',
                                  onPressed: () {
                                    FileHelper.saveToLocalDevice(context, sourcePath: path, preferredName: name);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.textSecondary),
                                  tooltip: 'Bagikan',
                                  onPressed: () {
                                    SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Gambar: $name'));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
