import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/raster_pdf_service.dart';
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

  bool _usedOcr = false;
  int _ocrProgress = 0;
  int _ocrTotal = 0;
  bool _isOcrRunning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      if (!mounted) return;
      ProcessingDialog.show(context, title: 'Membaca Dokumen', message: 'Mengekstrak lapisan teks dari PDF...');

      try {
        final pageCount = await PdfEngineService.getPageCount(file);
        final text = await PdfEngineService.extractText(file);
        if (!mounted) return;
        ProcessingDialog.hide(context);
        setState(() {
          _selectedFile = file;
          _extractedText = text;
          _usedOcr = false;
          _searchQuery = '';
          _searchController.clear();
        });

        // PDF hasil scan biasanya tidak punya lapisan teks -> jalankan OCR otomatis.
        final meaningful = text.replaceAll(RegExp(r'\s'), '').length;
        if (meaningful < 20 * pageCount) {
          await _runOcr();
        }
      } catch (e) {
        if (mounted) {
          ProcessingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengekstrak teks: ${PdfEngineService.friendlyError(e)}')),
          );
        }
      }
    }
  }

  /// OCR sungguhan: setiap halaman dirender menjadi gambar lalu dibaca oleh
  /// Google ML Kit Text Recognition (offline, berjalan di perangkat).
  Future<void> _runOcr() async {
    if (_selectedFile == null || _isOcrRunning) return;
    final total = await PdfEngineService.getPageCount(_selectedFile!);
    if (!mounted) return;
    setState(() {
      _isOcrRunning = true;
      _ocrProgress = 0;
      _ocrTotal = total;
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final buffer = StringBuffer();
    try {
      int page = 0;
      await for (final imagePath in RasterPdfService.renderPagesToTempPng(_selectedFile!)) {
        page++;
        final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
        if (page > 1) buffer.writeln();
        buffer.writeln('--- Halaman $page ---');
        buffer.writeln(result.text.trim());
        try {
          await File(imagePath).delete();
        } catch (_) {}
        if (!mounted) return;
        setState(() => _ocrProgress = page);
      }
      if (!mounted) return;
      final ocrText = buffer.toString().trim();
      setState(() {
        _extractedText = ocrText;
        _usedOcr = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ocrText.replaceAll(RegExp(r'---[^\n]*---|\s'), '').isEmpty
              ? 'OCR selesai, namun tidak ada teks yang terbaca. Pastikan hasil scan jelas.'
              : 'OCR selesai: teks dari $page halaman berhasil dikenali.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR gagal: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _isOcrRunning = false);
    }
  }

  int get _matchCount {
    if (_searchQuery.trim().isEmpty) return 0;
    final q = RegExp(RegExp.escape(_searchQuery.trim()), caseSensitive: false);
    return q.allMatches(_extractedText).length;
  }

  /// Menyorot semua kemunculan kata yang dicari.
  TextSpan _buildHighlightedText() {
    const base = TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary);
    final query = _searchQuery.trim();
    if (query.isEmpty) return TextSpan(text: _extractedText, style: base);
    final spans = <TextSpan>[];
    final regex = RegExp(RegExp.escape(query), caseSensitive: false);
    int last = 0;
    for (final m in regex.allMatches(_extractedText)) {
      if (m.start > last) spans.add(TextSpan(text: _extractedText.substring(last, m.start)));
      spans.add(TextSpan(
        text: _extractedText.substring(m.start, m.end),
        style: const TextStyle(backgroundColor: Color(0xFFFDE68A), fontWeight: FontWeight.bold),
      ));
      last = m.end;
    }
    if (last < _extractedText.length) spans.add(TextSpan(text: _extractedText.substring(last)));
    return TextSpan(style: base, children: spans);
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
          SnackBar(content: Text('Gagal menyimpan file: ${PdfEngineService.friendlyError(e)}')),
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
                if (_isOcrRunning)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Menjalankan OCR... halaman $_ocrProgress dari $_ocrTotal',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _ocrTotal == 0 ? null : _ocrProgress / _ocrTotal,
                          color: AppColors.optimizeGreen,
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        Icon(
                          _usedOcr ? Icons.document_scanner_rounded : Icons.text_fields_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _usedOcr ? 'Teks hasil OCR (ML Kit, offline)' : 'Teks dari lapisan teks PDF',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _runOcr,
                          icon: const Icon(Icons.document_scanner_outlined, size: 18),
                          label: Text(_usedOcr ? 'Ulangi OCR' : 'Jalankan OCR'),
                        ),
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
                      suffixText: _searchQuery.trim().isEmpty ? null : '$_matchCount ditemukan',
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
                            child: SelectableText.rich(_buildHighlightedText()),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
