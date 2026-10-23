import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class PageItemModel {
  final int originalIndex;
  int rotation; // 0, 90, 180, 270

  PageItemModel({required this.originalIndex, this.rotation = 0});
}

class OrganizePagesScreen extends StatefulWidget {
  const OrganizePagesScreen({super.key});

  @override
  State<OrganizePagesScreen> createState() => _OrganizePagesScreenState();
}

class _OrganizePagesScreenState extends State<OrganizePagesScreen> {
  File? _selectedFile;
  List<PageItemModel> _pages = [];

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
        _pages = List.generate(count, (i) => PageItemModel(originalIndex: i));
      });
    }
  }

  void _movePage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  void _rotatePage(int index) {
    setState(() {
      _pages[index].rotation = (_pages[index].rotation + 90) % 360;
    });
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumen harus menyisakan minimal 1 halaman.')),
      );
      return;
    }
    setState(() {
      _pages.removeAt(index);
    });
  }

  Future<void> _executeOrganize() async {
    if (_selectedFile == null || _pages.isEmpty) return;

    ProcessingDialog.show(
      context,
      title: 'Menyusun Halaman Dokumen',
      message: 'Menerapkan urutan dan rotasi baru...',
    );

    try {
      final outputPath = await PdfEngineService.organizePdf(
        _selectedFile!,
        _pages.map((p) => p.originalIndex).toList(),
        _pages.map((p) => p.rotation).toList(),
      );

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Atur Halaman',
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
          SnackBar(content: Text('Gagal menyusun halaman: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur Halaman PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _selectedFile == null ? _buildEmptyState() : _buildEditorView(),
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
                color: AppColors.organizeOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_motion_rounded, size: 64, color: AppColors.organizeOrange),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilih File PDF untuk Diatur Halamannya',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ubah susunan urutan halaman, putar halaman tertentu, atau hapus lembaran yang tidak diinginkan.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pilih Berkas PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.organizeOrange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${_pages.length} Halaman Aktif',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.change_circle_outlined, size: 18),
                label: const Text('Ganti File'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.organizeOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.organizeOrange),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halaman Asli: #${page.originalIndex + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (page.rotation != 0)
                              Text(
                                'Rotasi: ${page.rotation}°',
                                style: const TextStyle(fontSize: 11, color: AppColors.organizeOrange, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_right_rounded, size: 22),
                        tooltip: 'Putar 90°',
                        onPressed: () => _rotatePage(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                        tooltip: 'Geser ke Atas',
                        onPressed: index > 0 ? () => _movePage(index, index - 1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                        tooltip: 'Geser ke Bawah',
                        onPressed: index < _pages.length - 1 ? () => _movePage(index, index + 1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                        tooltip: 'Hapus Halaman',
                        onPressed: () => _deletePage(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _executeOrganize,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Simpan Susunan Dokumen Baru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.organizeOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
