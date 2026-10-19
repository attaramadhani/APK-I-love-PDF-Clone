import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class RedactPdfScreen extends StatefulWidget {
  const RedactPdfScreen({super.key});

  @override
  State<RedactPdfScreen> createState() => _RedactPdfScreenState();
}

class _RedactPdfScreenState extends State<RedactPdfScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  int _redactOption = 0; // 0: Bagian Atas (Header/Kop), 1: Bagian Bawah (Footer), 2: Kotak Sensor Tengah

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();

      setState(() {
        _selectedFile = file;
        _totalPages = count;
      });
    }
  }

  Future<void> _applyRedaction() async {
    if (_selectedFile == null) return;

    ProcessingDialog.show(
      context,
      title: 'Menyamarkan PDF',
      message: 'Menerapkan blok sensor permanen pada dokumen...',
    );

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final brush = PdfSolidBrush(PdfColor(0, 0, 0));

      for (int i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];
        final size = page.getClientSize();

        if (_redactOption == 0) {
          // Sensor Bagian Atas (Header)
          page.graphics.drawRectangle(brush: brush, bounds: Rect.fromLTWH(20, 20, size.width - 40, 50));
        } else if (_redactOption == 1) {
          // Sensor Bagian Bawah (Footer)
          page.graphics.drawRectangle(brush: brush, bounds: Rect.fromLTWH(20, size.height - 60, size.width - 40, 40));
        } else {
          // Sensor Area Tengah
          page.graphics.drawRectangle(brush: brush, bounds: Rect.fromLTWH(40, size.height / 2 - 30, size.width - 80, 60));
        }
      }

      final savedBytes = await doc.save();
      doc.dispose();

      final outputPath = await FileHelper.generateOutputPath('Redacted');
      await File(outputPath).writeAsBytes(savedBytes);

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Samarkan PDF',
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
          SnackBar(content: Text('Gagal menyamarkan dokumen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Samarkan PDF (Redact)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        color: AppColors.securityNavy.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.visibility_off_rounded, size: 64, color: AppColors.securityNavy),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF untuk Disamarkan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tutup dan sensor permanen informasi pribadi atau data rahasia dengan blok warna hitam.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Pilih Berkas PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.securityNavy),
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
                  const Text('Pilih Area Sensor Dokumen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildOption(0, 'Sensor Header (Bagian Atas Halaman)', 'Menutup kop surat, identitas pengirim, atau nomor surat di bagian atas.'),
                  const SizedBox(height: 10),
                  _buildOption(1, 'Sensor Footer (Bagian Bawah Halaman)', 'Menutup catatan kaki, metadata, atau penomoran rahasia di bagian bawah.'),
                  const SizedBox(height: 10),
                  _buildOption(2, 'Sensor Blok Tengah Dokumen', 'Menutup paragraf isi di area tengah seluruh halaman.'),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _applyRedaction,
                      icon: const Icon(Icons.visibility_off_rounded),
                      label: const Text('Terapkan Sensor Permanen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.securityNavy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOption(int option, String title, String subtitle) {
    final isSelected = _redactOption == option;
    return InkWell(
      onTap: () => setState(() => _redactOption = option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.securityNavy.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.securityNavy : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppColors.securityNavy : AppColors.textSecondary),
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
