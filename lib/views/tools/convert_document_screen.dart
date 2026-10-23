import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/document_convert_service.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class ConvertDocumentScreen extends StatefulWidget {
  final String mode; // 'to_word', 'to_excel', 'to_pdf'
  final String title;

  const ConvertDocumentScreen({
    super.key,
    required this.mode,
    required this.title,
  });

  @override
  State<ConvertDocumentScreen> createState() => _ConvertDocumentScreenState();
}

class _ConvertDocumentScreenState extends State<ConvertDocumentScreen> {
  File? _selectedFile;

  List<String> get _allowedExtensions {
    if (widget.mode == 'to_word' || widget.mode == 'to_excel') {
      return ['pdf'];
    } else {
      return widget.title.toLowerCase().contains('excel') ? ['xlsx', 'csv'] : ['docx', 'txt'];
    }
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );

    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        _selectedFile = File(files.first.path!);
      });
    }
  }

  Future<void> _convert() async {
    if (_selectedFile == null) return;

    ProcessingDialog.show(
      context,
      title: 'Mengonversi Dokumen',
      message: 'Sedang memproses konversi format dokumen...',
    );

    try {
      final String outputPath;
      final String toolName;
      final fileName = _selectedFile!.uri.pathSegments.last;
      final baseName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;

      if (widget.mode == 'to_word') {
        // PDF ke Word (.doc resmi yang didukung Microsoft Word dan WPS)
        final text = await PdfEngineService.extractText(_selectedFile!);
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

        final wordDocBuffer = StringBuffer();
        wordDocBuffer.writeln("<!DOCTYPE html>");
        wordDocBuffer.writeln("<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word'>");
        wordDocBuffer.writeln("<head><meta charset='utf-8'><title>$baseName</title>");
        wordDocBuffer.writeln("<style>");
        wordDocBuffer.writeln("body { font-family: 'Calibri', 'Segoe UI', Arial, sans-serif; font-size: 11pt; line-height: 1.6; margin: 1in; }");
        wordDocBuffer.writeln("h1 { font-size: 18pt; color: #1E3A8A; border-bottom: 2px solid #2563EB; padding-bottom: 6px; }");
        wordDocBuffer.writeln("p { margin-bottom: 10pt; text-align: justify; }");
        wordDocBuffer.writeln("</style></head><body>");
        wordDocBuffer.writeln("<h1>$baseName</h1>");
        for (final line in lines) {
          wordDocBuffer.writeln("<p>${line.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</p>");
        }
        wordDocBuffer.writeln("</body></html>");

        outputPath = await FileHelper.generateOutputPath('${baseName}_Word', '.doc');
        await File(outputPath).writeAsString(wordDocBuffer.toString());
        toolName = 'PDF ke Word';
      } else if (widget.mode == 'to_excel') {
        // PDF ke Excel (.csv berstruktur tabel)
        // layout: true mempertahankan jarak antarkolom sehingga tabel bisa dipecah
        final text = await PdfEngineService.extractText(_selectedFile!, layout: true);
        final lines = text.split('\n');
        // BOM UTF-8 agar Excel membaca karakter khusus dengan benar
        final csvContent = StringBuffer('\uFEFF');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            final cells = line.split(RegExp(r'\s{2,}|\t'));
            csvContent.writeln(cells.map((c) => '"${c.trim().replaceAll('"', '""')}"').join(','));
          }
        }
        outputPath = await FileHelper.generateOutputPath('${baseName}_Excel', '.csv');
        await File(outputPath).writeAsString(csvContent.toString());
        toolName = 'PDF ke Excel';
      } else {
        // Dokumen (DOCX/XLSX/CSV/TXT) ke PDF
        outputPath = await DocumentConvertService.convertToPdf(_selectedFile!);
        toolName = 'Konversi ke PDF';
      }

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: toolName,
      );

      await RecentFilesService.addFile(processedFile);

      if (mounted) {
        ProcessingDialog.hide(context);
        if (outputPath.endsWith('.pdf')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(filePath: outputPath, title: processedFile.name),
            ),
          );
        } else {
          await FileHelper.saveToLocalDevice(
            context,
            sourcePath: outputPath,
            preferredName: outputFile.uri.pathSegments.last,
          );
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengonversi dokumen: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _selectedFile == null ? _buildEmptyState() : _buildConfigView(),
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
              child: const Icon(Icons.transform_rounded, size: 64, color: AppColors.convertBlue),
            ),
            const SizedBox(height: 24),
            Text(
              'Pilih File untuk ${widget.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Format yang didukung: ${_allowedExtensions.map((e) => e.toUpperCase()).join(', ')}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pilih Berkas'),
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
              leading: const Icon(Icons.insert_drive_file_rounded, color: AppColors.convertBlue, size: 36),
              title: Text(
                _selectedFile!.uri.pathSegments.last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(FileHelper.formatBytes(_selectedFile!.lengthSync())),
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
                const Icon(Icons.check_circle_outline_rounded, color: AppColors.convertBlue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konversi Presisi ke ${_getOutputFormatName()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Menjaga format teks, paragraf, dan struktur dokumen agar tetap rapi saat dibuka.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              onPressed: _convert,
              icon: const Icon(Icons.sync_rounded),
              label: Text('Mulai Konversi ke ${_getOutputFormatName()}'),
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

  String _getOutputFormatName() {
    if (widget.mode == 'to_word') return 'Word (.doc)';
    if (widget.mode == 'to_excel') return 'Excel Spreadsheet (.csv)';
    return 'Dokumen PDF (.pdf)';
  }
}
