import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';

class OcrPdfScreen extends StatefulWidget {
  const OcrPdfScreen({super.key});

  @override
  State<OcrPdfScreen> createState() => _OcrPdfScreenState();
}

class _OcrPdfScreenState extends State<OcrPdfScreen> {
  File? _selectedFile;
  String _extractedText = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      ProcessingDialog.show(context, title: 'OCR & Ekstraksi Teks', message: 'Membaca dan memindai teks dari dokumen...');

      try {
        final text = await PdfEngineService.extractText(file);
        if (mounted) {
          ProcessingDialog.hide(context);
          setState(() {
            _selectedFile = file;
            _extractedText = text;
          });
        }
      } catch (e) {
        if (mounted) {
          ProcessingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengekstrak teks: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportToTextFile() async {
    if (_extractedText.isEmpty) return;

    ProcessingDialog.show(context, title: 'Menyimpan Berkas Teks', message: 'Membuat file .txt...');

    try {
      final outputPath = await FileHelper.generateOutputPath('OCR_Text', '.txt');
      await File(outputPath).writeAsString(_extractedText);

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'OCR PDF (Teks)',
      );

      await RecentFilesService.addFile(processedFile);

      if (mounted) {
        ProcessingDialog.hide(context);
        await FileHelper.saveToLocalDevice(
          context,
          sourcePath: outputPath,
          preferredName: outputFile.uri.pathSegments.last,
        );
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR & Ekstrak Teks', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_extractedText.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Salin Seluruh Teks',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _extractedText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seluruh teks berhasil disalin ke clipboard!')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Ekspor ke File .TXT',
              onPressed: _exportToTextFile,
            ),
          ],
        ],
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
                      child: const Icon(Icons.text_snippet_rounded, size: 64, color: AppColors.optimizeGreen),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF untuk OCR',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pindai dan ekstrak teks dari dokumen PDF agar dapat dicari, disalin, dan diekspor ke teks.',
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
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.uri.pathSegments.last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${FileHelper.formatBytes(_selectedFile!.lengthSync())} • ${_extractedText.length} karakter ditemukan',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(onPressed: _pickFile, child: const Text('Ganti')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari kata dalam teks OCR...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: _extractedText.trim().isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada teks yang dapat diekstrak dari dokumen ini.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : SingleChildScrollView(
                            child: SelectableText(
                              _extractedText,
                              style: const TextStyle(fontSize: 14, height: 1.6),
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
