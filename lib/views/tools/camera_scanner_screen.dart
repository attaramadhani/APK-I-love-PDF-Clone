import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/image_pdf_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final List<File> _scannedPages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Buka kamera secara otomatis saat pertama kali dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePage();
    });
  }

  Future<void> _capturePage() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );

    if (photo != null) {
      setState(() {
        _scannedPages.add(File(photo.path));
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final images = await _picker.pickMultiImage(
      imageQuality: 92,
    );

    if (images.isNotEmpty) {
      setState(() {
        _scannedPages.addAll(images.map((img) => File(img.path)));
      });
    }
  }

  Future<void> _generateScannedPdf() async {
    if (_scannedPages.isEmpty) return;

    ProcessingDialog.show(
      context,
      title: 'Menyimpan Dokumen Pindaian',
      message: 'Mengonversi ${_scannedPages.length} halaman pindaian ke format PDF...',
    );

    try {
      final outputPath = await ImagePdfService.imagesToPdf(_scannedPages);
      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Pindai ke PDF',
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
          SnackBar(content: Text('Gagal menyimpan hasil pindai: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai ke PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_scannedPages.isNotEmpty) ...[
            IconButton(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_rounded),
              tooltip: 'Impor dari Galeri',
            ),
            TextButton.icon(
              onPressed: _capturePage,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text('Kamera'),
            ),
          ],
        ],
      ),
      body: _scannedPages.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 72, color: AppColors.organizeOrange),
                    const SizedBox(height: 16),
                    const Text(
                      'Pindai Dokumen ke PDF',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ambil foto dokumen fisik dengan kamera atau pilih pindaian yang tersimpan di galeri.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _capturePage,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Buka Kamera Pemindai'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.organizeOrange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded, color: AppColors.organizeOrange),
                        label: const Text('Pilih dari Galeri Foto'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.organizeOrange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${_scannedPages.length} Halaman Pindaian',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt_rounded, color: AppColors.organizeOrange),
                        tooltip: 'Foto Halaman Tambahan',
                        onPressed: _capturePage,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _scannedPages.length,
                    itemBuilder: (context, index) {
                      final file = _scannedPages[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(file, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _scannedPages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Hal ${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateScannedPdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: Text('Simpan ${_scannedPages.length} Halaman ke PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.organizeOrange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
