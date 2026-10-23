import 'dart:io';
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

class RepairPdfScreen extends StatefulWidget {
  const RepairPdfScreen({super.key});

  @override
  State<RepairPdfScreen> createState() => _RepairPdfScreenState();
}

class _RepairPdfScreenState extends State<RepairPdfScreen> {
  File? _selectedFile;

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

  Future<void> _repairPdf() async {
    if (_selectedFile == null) return;

    ProcessingDialog.show(
      context,
      title: 'Memperbaiki PDF',
      message: 'Menganalisis tabel xref, merekonstruksi stream dan font rusak...',
    );

    try {
      // Parser Syncfusion membaca ulang seluruh objek lalu menulis struktur
      // xref & stream yang baru (bukan pembaruan inkremental).
      final outputPath = await PdfEngineService.optimizePdf(_selectedFile!, prefix: 'Repaired');

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Perbaiki PDF',
      );

      await RecentFilesService.addFile(processedFile);

      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struktur berkas PDF berhasil dipulihkan!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(filePath: outputPath, title: processedFile.name),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbaiki berkas: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perbaiki PDF', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      child: const Icon(Icons.build_circle_rounded, size: 64, color: AppColors.optimizeGreen),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF yang Rusak atau Korup',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sistem akan memulihkan format dan membangun kembali struktur xref table yang rusak agar bisa dibuka normal.',
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
                        FileHelper.formatBytes(_selectedFile!.lengthSync()),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(icon: const Icon(Icons.change_circle_outlined), onPressed: _pickFile),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.optimizeGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.optimizeGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.optimizeGreen),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Proses perbaikan akan merekonstruksi objek grafis, menyusun ulang tabel xref, dan membersihkan aliran data stream yang rusak.',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _repairPdf,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Mulai Perbaiki Dokumen'),
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
}
