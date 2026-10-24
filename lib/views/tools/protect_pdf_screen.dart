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

class ProtectPdfScreen extends StatefulWidget {
  final bool isUnlockMode;

  const ProtectPdfScreen({super.key, this.isUnlockMode = false});

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  File? _selectedFile;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (!mounted) return;

    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        _selectedFile = File(files.first.path!);
      });
    }
  }

  Future<void> _execute() async {
    if (_selectedFile == null) return;
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kata sandi terlebih dahulu')),
      );
      return;
    }

    ProcessingDialog.show(
      context,
      title: widget.isUnlockMode ? 'Membuka Kunci PDF' : 'Mengenkripsi Dokumen',
      message: 'Sedang menerapkan enkripsi keamanan AES...',
    );

    try {
      final String outputPath;
      if (widget.isUnlockMode) {
        outputPath = await PdfEngineService.unlockPdf(_selectedFile!, password);
      } else {
        outputPath = await PdfEngineService.protectPdf(_selectedFile!, password: password);
      }

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: widget.isUnlockMode ? 'Buka Kunci PDF' : 'Proteksi PDF',
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
              // PDF hasil proteksi terenkripsi: penampil perlu sandinya.
              password: widget.isUnlockMode ? null : password,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses PDF: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isUnlockMode ? 'Buka Kunci PDF' : 'Proteksi PDF';
    final actionText = widget.isUnlockMode ? 'Buka Kata Sandi' : 'Enkripsi Dokumen';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      child: Icon(
                        widget.isUnlockMode ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 64,
                        color: AppColors.securityNavy,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Pilih File PDF untuk $title',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isUnlockMode
                          ? 'Hapus kata sandi dokumen PDF agar dapat diakses secara bebas.'
                          : 'Enkripsi file PDF Anda dengan kata sandi AES 256-bit standar industri.',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Pilih File PDF'),
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
                        FileHelper.formatBytes(_selectedFile!.lengthSync()),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.change_circle_outlined),
                        onPressed: _pickFile,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Kata Sandi (Password)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Masukkan kata sandi...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _execute,
                      icon: Icon(widget.isUnlockMode ? Icons.lock_open_rounded : Icons.lock_rounded),
                      label: Text(actionText),
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
}
