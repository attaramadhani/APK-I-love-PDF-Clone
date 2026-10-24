import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/raster_pdf_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  File? _selectedFile;
  int _compressionLevel = 1; // 0: Ringan, 1: Rekomendasi, 2: Ekstrem

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (!mounted) return;

    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        _selectedFile = File(files.first.path!);
      });
    }
  }

  Future<void> _compressPdf() async {
    if (_selectedFile == null) return;

    ProcessingDialog.show(
      context,
      title: 'Mengompres PDF',
      message: 'Mengoptimalkan stream data dan memperkecil ukuran berkas...',
    );

    try {
      final originalSize = _selectedFile!.lengthSync();

      // Tahap 1: optimasi lossless (teks tetap bisa dipilih/dicari).
      String bestPath = await PdfEngineService.optimizePdf(_selectedFile!);
      int bestSize = File(bestPath).lengthSync();

      // Tahap 2 (Rekomendasi/Maksimal): render ulang halaman menjadi JPEG
      // beresolusi lebih rendah. Sangat efektif untuk hasil scan & foto.
      // Hasil terkecil yang dipakai, sehingga file tidak pernah membesar.
      if (_compressionLevel > 0) {
        final double dpi = _compressionLevel == 2 ? 96 : 144;
        final int quality = _compressionLevel == 2 ? 50 : 72;
        try {
          final rasterPath = await RasterPdfService.rasterizePdf(
            _selectedFile!,
            prefix: 'Compressed',
            dpi: dpi,
            jpegQuality: quality,
            onProgress: (done, total) => ProcessingDialog.updateProgress('Halaman $done dari $total'),
          );
          final rasterSize = File(rasterPath).lengthSync();
          // Untuk Rekomendasi, hanya ganti ke versi gambar bila hematnya signifikan
          // (>30%), agar dokumen teks biasa tetap bisa dicari/disalin.
          final threshold = _compressionLevel == 2 ? 1.0 : 0.7;
          if (rasterSize < bestSize * threshold) {
            await File(bestPath).delete();
            bestPath = rasterPath;
            bestSize = rasterSize;
          } else {
            await File(rasterPath).delete();
          }
        } catch (_) {
          // Bila render gagal, tetap gunakan hasil optimasi lossless.
        }
      }

      // Jangan pernah memberikan hasil yang lebih besar dari aslinya.
      if (bestSize >= originalSize) {
        await File(bestPath).writeAsBytes(await _selectedFile!.readAsBytes());
        bestSize = originalSize;
      }

      final outputPath = bestPath;
      final outputFile = File(outputPath);
      final newSize = bestSize;

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: newSize,
        createdAt: DateTime.now(),
        toolUsed: 'Kompres PDF',
      );

      await RecentFilesService.addFile(processedFile);

      if (mounted) {
        ProcessingDialog.hide(context);
        _showSuccessDialog(originalSize, newSize, outputPath, processedFile.name);
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengompres PDF: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  void _showSuccessDialog(int oldSize, int newSize, String path, String title) {
    final reduction = oldSize > 0 ? (((oldSize - newSize) / oldSize) * 100).clamp(0, 99).toInt() : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.optimizeGreen),
            SizedBox(width: 8),
            Text('Kompresi Selesai!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.optimizeGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sebelum:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(FileHelper.formatBytes(oldSize), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.optimizeGreen),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Sesudah:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(FileHelper.formatBytes(newSize), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.optimizeGreen)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              reduction > 0
                  ? 'Ukuran berhasil dihemat sebesar $reduction%. Berkas siap digunakan!'
                  : 'Dokumen ini sudah optimal, ukurannya tidak bisa diperkecil lagi tanpa merusak isi. Coba tingkat "Maksimal" bila belum.',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              FileHelper.saveToLocalDevice(context, sourcePath: path, preferredName: title);
            },
            icon: const Icon(Icons.file_download_rounded, size: 18),
            label: const Text('Simpan ke File Lokal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(filePath: path, title: title),
                ),
              );
            },
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: const Text('Buka PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.optimizeGreen),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kompres PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _selectedFile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.optimizeGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.compress_rounded, size: 64, color: AppColors.optimizeGreen),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF untuk Dikompres',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Perkecil ukuran dokumen PDF tanpa mengurangi keterbacaan teks dan ketajaman gambar.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Pilih Berkas PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.optimizeGreen),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
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
                      subtitle: Text(
                        'Ukuran saat ini: ${FileHelper.formatBytes(_selectedFile!.lengthSync())}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.change_circle_outlined),
                        onPressed: _pickFile,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Pilih Tingkat Kompresi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildLevelTile(0, 'Kompresi Ringan', 'Optimasi struktur tanpa mengubah isi. Teks tetap bisa dipilih & dicari.'),
                  const SizedBox(height: 10),
                  _buildLevelTile(1, 'Kompresi Rekomendasi (Terbaik)', 'Gambar halaman dikompres 144 DPI. Sangat efektif untuk hasil scan/foto; otomatis memilih hasil terkecil.'),
                  const SizedBox(height: 10),
                  _buildLevelTile(2, 'Kompresi Maksimal', 'Ukuran sekecil mungkin (96 DPI) untuk syarat upload ketat. Teks hasil bisa menjadi gambar.'),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _compressPdf,
                      icon: const Icon(Icons.compress_rounded),
                      label: const Text('Mulai Kompres Dokumen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.optimizeGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLevelTile(int level, String title, String subtitle) {
    final isSelected = _compressionLevel == level;
    return InkWell(
      onTap: () => setState(() => _compressionLevel = level),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.optimizeGreen.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.optimizeGreen : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.optimizeGreen : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
