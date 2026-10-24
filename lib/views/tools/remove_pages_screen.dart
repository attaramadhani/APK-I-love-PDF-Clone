import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../core/utils/page_range_parser.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class RemovePagesScreen extends StatefulWidget {
  const RemovePagesScreen({super.key});

  @override
  State<RemovePagesScreen> createState() => _RemovePagesScreenState();
}

class _RemovePagesScreenState extends State<RemovePagesScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  final TextEditingController _pagesController = TextEditingController();

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (!mounted) return;

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

  List<int> _parsePagesToRemove(String input, int maxPages) =>
      PageRangeParser.parseGroup(input.replaceAll(';', ','), maxPages);

  Future<void> _executeRemovePages() async {
    if (_selectedFile == null) return;
    final pagesToRemove = _parsePagesToRemove(_pagesController.text, _totalPages);

    if (pagesToRemove.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor halaman yang ingin dihapus')),
      );
      return;
    }

    if (pagesToRemove.length >= _totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat menghapus seluruh halaman dokumen')),
      );
      return;
    }

    ProcessingDialog.show(
      context,
      title: 'Menghapus Halaman',
      message: 'Membuang ${pagesToRemove.length} halaman dari berkas...',
    );

    try {
      final outputPath = await PdfEngineService.removePages(_selectedFile!, pagesToRemove);
      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Hapus Halaman',
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
          SnackBar(content: Text('Gagal menghapus halaman: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Halaman PDF', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        color: AppColors.organizeOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_sweep_rounded, size: 64, color: AppColors.organizeOrange),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF untuk Dihapus Halamannya',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buang halaman yang tidak diperlukan secara cepat dari berkas dokumen Anda.',
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
                      trailing: IconButton(
                        icon: const Icon(Icons.change_circle_outlined),
                        onPressed: _pickFile,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Nomor Halaman yang Ingin Dibuang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Masukkan nomor halaman yang akan dihapus, pisahkan dengan koma atau tanda hubung.\nContoh: 2, 4 atau 2-4',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pagesController,
                    decoration: InputDecoration(
                      hintText: 'Misal: 2, 4-5',
                      prefixIcon: const Icon(Icons.delete_outline_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _executeRemovePages,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Hapus Halaman yang Dipilih'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
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
