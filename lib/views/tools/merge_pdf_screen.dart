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

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<File> _selectedFiles = [];

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty) {
      setState(() {
        for (final item in files) {
          if (item.path != null) {
            final file = File(item.path!);
            if (!_selectedFiles.any((f) => f.path == file.path)) {
              _selectedFiles.add(file);
            }
          }
        }
      });
    }
  }

  Future<void> _mergePdfs() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 2 file PDF untuk digabungkan')),
      );
      return;
    }

    ProcessingDialog.show(context, title: 'Menggabungkan PDF', message: 'Sedang memproses ${_selectedFiles.length} file...');

    try {
      final outputPath = await PdfEngineService.mergePdfs(_selectedFiles);
      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Gabungkan PDF',
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
          SnackBar(content: Text('Gagal menggabungkan: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gabungkan PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _selectedFiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.organizeOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_merge_rounded, size: 64, color: AppColors.organizeOrange),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF untuk Digabung',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pilih 2 atau lebih file PDF. Anda dapat mengatur urutan halaman dengan mudah.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Pilih File PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.organizeOrange),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedFiles.length} file dipilih (geser untuk atur urutan)',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedFiles.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _selectedFiles.removeAt(oldIndex);
                        _selectedFiles.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      final name = file.uri.pathSegments.last;
                      final size = FileHelper.formatBytes(file.lengthSync());

                      return Card(
                        key: ValueKey(file.path),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryRed),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(size, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.removeAt(index);
                                  });
                                },
                              ),
                              const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                            ],
                          ),
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
                        onPressed: _selectedFiles.length >= 2 ? _mergePdfs : null,
                        icon: const Icon(Icons.call_merge_rounded),
                        label: Text('Gabungkan ${_selectedFiles.length} PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
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
