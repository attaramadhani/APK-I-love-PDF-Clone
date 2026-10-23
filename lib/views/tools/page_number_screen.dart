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

class PageNumberScreen extends StatefulWidget {
  const PageNumberScreen({super.key});

  @override
  State<PageNumberScreen> createState() => _PageNumberScreenState();
}

class _PageNumberScreenState extends State<PageNumberScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  String _selectedFormat = 'Halaman {page} dari {total}';
  bool _atBottom = true;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      int count = 0;
      try {
        count = await PdfEngineService.getPageCount(file);
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
        _totalPages = count;
      });
    }
  }

  Future<void> _applyPageNumbers() async {
    if (_selectedFile == null) return;

    ProcessingDialog.show(
      context,
      title: 'Menambahkan Nomor Halaman',
      message: 'Menerapkan penomoran ke seluruh halaman...',
    );

    try {
      final outputPath = await PdfEngineService.addPageNumbers(
        _selectedFile!,
        format: _selectedFormat,
        atBottom: _atBottom,
      );

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Nomor Halaman',
      );

      await RecentFilesService.addFile(processedFile);

      if (mounted) {
        ProcessingDialog.hide(context);
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
          SnackBar(content: Text('Gagal menambahkan nomor halaman: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nomor Halaman', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        color: AppColors.editPurple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.format_list_numbered_rounded, size: 64, color: AppColors.editPurple),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF untuk Diberi Nomor',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sisipkan penomoran halaman otomatis dengan format dan posisi yang rapi.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Pilih Berkas PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.editPurple),
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
                        'Total: $_totalPages Halaman (${FileHelper.formatBytes(_selectedFile!.lengthSync())})',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(icon: const Icon(Icons.change_circle_outlined), onPressed: _pickFile),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Pilih Format Nomor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildFormatOption('Halaman {page} dari {total}', 'Halaman 1 dari $_totalPages'),
                  const SizedBox(height: 8),
                  _buildFormatOption('Halaman {page}', 'Halaman 1'),
                  const SizedBox(height: 8),
                  _buildFormatOption('{page} / {total}', '1 / $_totalPages'),
                  const SizedBox(height: 24),
                  const Text('Posisi Penomoran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Bawah (Footer)')),
                          selected: _atBottom,
                          selectedColor: AppColors.editPurple,
                          labelStyle: TextStyle(color: _atBottom ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold),
                          onSelected: (val) => setState(() => _atBottom = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Atas (Header)')),
                          selected: !_atBottom,
                          selectedColor: AppColors.editPurple,
                          labelStyle: TextStyle(color: !_atBottom ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold),
                          onSelected: (val) => setState(() => _atBottom = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _applyPageNumbers,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Terapkan Nomor Halaman'),
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

  Widget _buildFormatOption(String value, String preview) {
    final isSelected = _selectedFormat == value;
    return InkWell(
      onTap: () => setState(() => _selectedFormat = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.editPurple.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.editPurple : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppColors.editPurple : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(preview, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
