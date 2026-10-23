import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../core/utils/text_diff.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class ComparePdfScreen extends StatefulWidget {
  const ComparePdfScreen({super.key});

  @override
  State<ComparePdfScreen> createState() => _ComparePdfScreenState();
}

class _ComparePdfScreenState extends State<ComparePdfScreen> {
  File? _fileA;
  File? _fileB;
  String _analysisSummary = '';
  int _pagesA = 0;
  int _pagesB = 0;
  int _wordsA = 0;
  int _wordsB = 0;
  DiffResult? _diff;

  Future<void> _pickFile(bool isFileA) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        if (isFileA) {
          _fileA = File(files.first.path!);
        } else {
          _fileB = File(files.first.path!);
        }
        _analysisSummary = '';
      });
    }
  }

  Future<void> _compare() async {
    if (_fileA == null || _fileB == null) return;

    ProcessingDialog.show(
      context,
      title: 'Menganalisis Perbandingan Dokumen',
      message: 'Membaca struktur dan membandingkan isi...',
    );

    try {
      _pagesA = await PdfEngineService.getPageCount(_fileA!);
      _pagesB = await PdfEngineService.getPageCount(_fileB!);

      final textA = await PdfEngineService.extractText(_fileA!);
      final textB = await PdfEngineService.extractText(_fileB!);

      _wordsA = textA.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      _wordsB = textB.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

      final textDiff = await TextDiff.compareInBackground(textA, textB);
      _diff = textDiff;

      final diff = _wordsB - _wordsA;

      final buffer = StringBuffer();
      buffer.writeln('HASIL ANALISIS PERBANDINGAN:');
      buffer.writeln('----------------------------------------');
      buffer.writeln('Dokumen A: ${_fileA!.uri.pathSegments.last}');
      buffer.writeln('• Ukuran: ${FileHelper.formatBytes(_fileA!.lengthSync())}');
      buffer.writeln('• Jumlah Halaman: $_pagesA');
      buffer.writeln('• Estimasi Kata: $_wordsA kata\n');

      buffer.writeln('Dokumen B: ${_fileB!.uri.pathSegments.last}');
      buffer.writeln('• Ukuran: ${FileHelper.formatBytes(_fileB!.lengthSync())}');
      buffer.writeln('• Jumlah Halaman: $_pagesB');
      buffer.writeln('• Estimasi Kata: $_wordsB kata\n');

      buffer.writeln('KESIMPULAN PERBEDAAN:');
      if (_pagesA != _pagesB) {
        buffer.writeln('• Perubahan Halaman: Dokumen B memiliki selisih ${_pagesB - _pagesA} halaman dibanding Dokumen A.');
      } else {
        buffer.writeln('• Jumlah Halaman: Sama persis ($_pagesA halaman).');
      }

      if (diff > 0) {
        buffer.writeln('• Penambahan Konten: Dokumen B memiliki sekitar +$diff kata lebih banyak.');
      } else if (diff < 0) {
        buffer.writeln('• Pengurangan Konten: Dokumen B memiliki sekitar ${diff.abs()} kata lebih sedikit.');
      } else {
        buffer.writeln('• Konten Kata: Jumlah kata relatif identik.');
      }

      buffer.writeln('• Kemiripan isi: ${textDiff.similarityPercent}%');
      buffer.writeln('• Baris ditambahkan di B: ${textDiff.added}');
      buffer.writeln('• Baris dihapus dari A: ${textDiff.removed}');
      if (textDiff.truncated) {
        buffer.writeln('• Catatan: hanya ${TextDiff.maxLines} baris pertama yang dibandingkan.');
      }
      if (textDiff.added + textDiff.removed > 0) {
        buffer.writeln('\nDETAIL PERUBAHAN:');
        var shown = 0;
        for (final line in textDiff.lines) {
          if (line.type == DiffType.same) continue;
          buffer.writeln('${line.type == DiffType.added ? '+ ' : '- '}${line.text}');
          if (++shown >= 200) {
            buffer.writeln('... (perubahan lainnya dipotong)');
            break;
          }
        }
      }

      if (mounted) {
        ProcessingDialog.hide(context);
        setState(() {
          _analysisSummary = buffer.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membandingkan berkas: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  Future<void> _generatePdfReport() async {
    if (_analysisSummary.isEmpty || _fileA == null || _fileB == null) return;

    ProcessingDialog.show(
      context,
      title: 'Membuat Laporan PDF',
      message: 'Menyusun dokumen laporan perbandingan...',
    );

    try {
      final doc = PdfDocument();
      final page = doc.pages.add();

      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );

      // Header Laporan
      final fontTitle = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
      final fontBody = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final fontHeader = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);

      page.graphics.drawString(
        'LAPORAN PERBANDINGAN DOKUMEN PDF',
        fontTitle,
        brush: PdfSolidBrush(PdfColor(15, 23, 42)),
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 25),
      );

      page.graphics.drawString(
        'Dihasilkan secara otomatis oleh PDF Studio Pro pada ${FileHelper.formatDate(DateTime.now())}',
        fontBody,
        brush: PdfSolidBrush(PdfColor(100, 116, 139)),
        bounds: Rect.fromLTWH(0, 25, page.getClientSize().width, 20),
      );

      // Grid Tabel Perbandingan
      final grid = PdfGrid();
      grid.columns.add(count: 3);
      grid.headers.add(1);

      final headerRow = grid.headers[0];
      headerRow.cells[0].value = 'Parameter Analisis';
      headerRow.cells[1].value = 'Dokumen A (Asli)';
      headerRow.cells[2].value = 'Dokumen B (Revisi)';
      headerRow.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(37, 99, 235)),
        textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
        font: fontHeader,
      );

      void addRow(String param, String valA, String valB) {
        final row = grid.rows.add();
        row.cells[0].value = param;
        row.cells[1].value = valA;
        row.cells[2].value = valB;
      }

      addRow('Nama Berkas', _fileA!.uri.pathSegments.last, _fileB!.uri.pathSegments.last);
      addRow('Ukuran File', FileHelper.formatBytes(_fileA!.lengthSync()), FileHelper.formatBytes(_fileB!.lengthSync()));
      addRow('Jumlah Halaman', '$_pagesA Halaman', '$_pagesB Halaman');
      addRow('Estimasi Kata', '$_wordsA kata', '$_wordsB kata');

      final diffPages = _pagesB - _pagesA;
      final diffWords = _wordsB - _wordsA;
      addRow('Selisih Halaman', '-', diffPages == 0 ? 'Sama' : '$diffPages Halaman');
      if (_diff != null) {
        addRow('Kemiripan Isi', '-', '${_diff!.similarityPercent}%');
        addRow('Baris Ditambah / Dihapus', '-', '+${_diff!.added} / -${_diff!.removed}');
      }
      addRow('Selisih Kata', '-', diffWords == 0 ? 'Identik' : '${diffWords > 0 ? "+$diffWords" : "$diffWords"} kata');

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 8, right: 8, top: 6, bottom: 6),
        font: fontBody,
      );

      final layoutResult = grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, 60, page.getClientSize().width, page.getClientSize().height - 70),
      );

      // Rangkuman Tekstual
      if (layoutResult != null) {
        final summaryTop = layoutResult.bounds.bottom + 20;
        page.graphics.drawString(
          'Catatan & Ringkasan Perbedaan:',
          fontHeader,
          brush: PdfSolidBrush(PdfColor(15, 23, 42)),
          bounds: Rect.fromLTWH(0, summaryTop, page.getClientSize().width, 20),
        );

        final textElement = PdfTextElement(
          text: _analysisSummary,
          font: fontBody,
        );
        textElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, summaryTop + 20, page.getClientSize().width, page.getClientSize().height - summaryTop - 30),
        );
      }

      final bytes = await doc.save();
      doc.dispose();

      final outputPath = await FileHelper.generateOutputPath('Laporan_Bandingkan_PDF');
      await File(outputPath).writeAsBytes(bytes);

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Bandingkan PDF',
      );

      await RecentFilesService.addFile(processedFile);

      if (mounted) {
        ProcessingDialog.hide(context);
        Navigator.push(
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
          SnackBar(content: Text('Gagal membuat dokumen laporan: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandingkan PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Dua Dokumen PDF untuk Dibandingkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Sistem membandingkan isi teks baris demi baris: bagian yang ditambah, dihapus, serta jumlah halaman dan kata.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            // File A Card
            _buildFileCard('Dokumen Asli (A)', _fileA, () => _pickFile(true)),
            const SizedBox(height: 12),

            // File B Card
            _buildFileCard('Dokumen Revisi (B)', _fileB, () => _pickFile(false)),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_fileA != null && _fileB != null) ? _compare : null,
                icon: const Icon(Icons.compare_rounded),
                label: const Text('Bandingkan Kedua Dokumen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.securityNavy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            if (_analysisSummary.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ringkasan Analisis:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _generatePdfReport,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Buat Dokumen PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: SelectableText.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, height: 1.6, fontFamily: 'monospace', color: AppColors.textPrimary),
                    children: _analysisSummary.split('\n').map((line) {
                      Color? bg;
                      if (line.startsWith('+ ')) bg = const Color(0xFFDCFCE7);
                      if (line.startsWith('- ')) bg = const Color(0xFFFEE2E2);
                      return TextSpan(text: '$line\n', style: TextStyle(backgroundColor: bg));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _generatePdfReport,
                  icon: const Icon(Icons.file_download_rounded, color: AppColors.primaryBlue),
                  label: const Text('Simpan Hasil Analisis ke Dokumen PDF Lokal'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primaryBlue),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(String label, File? file, VoidCallback onPick) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.securityNavy.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.securityNavy),
        ),
        title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        subtitle: Text(
          file != null ? file.uri.pathSegments.last : 'Belum ada file dipilih',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, color: file != null ? AppColors.textPrimary : AppColors.textMuted),
        ),
        trailing: ElevatedButton(
          onPressed: onPick,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.securityNavy,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(file != null ? 'Ganti' : 'Pilih'),
        ),
      ),
    );
  }
}
