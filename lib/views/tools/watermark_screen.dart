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

class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({super.key});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  File? _selectedFile;
  final TextEditingController _textController = TextEditingController(text: 'RAHASIA');
  double _opacity = 0.3;
  double _angle = 45;

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

  Future<void> _applyWatermark() async {
    if (_selectedFile == null) return;
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan teks tanda air terlebih dahulu')),
      );
      return;
    }

    ProcessingDialog.show(
      context,
      title: 'Menambahkan Tanda Air',
      message: 'Menerapkan watermark pada seluruh halaman...',
    );

    try {
      final outputPath = await PdfEngineService.addWatermark(
        _selectedFile!,
        text: _textController.text.trim(),
        opacity: _opacity,
        angle: _angle,
      );

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Tanda Air',
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
          SnackBar(content: Text('Gagal menambahkan tanda air: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Air / Watermark', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      child: const Icon(Icons.branding_watermark_rounded, size: 64, color: AppColors.editPurple),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih File PDF untuk Diberi Watermark',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tambahkan stempel teks atau tanda hak cipta di seluruh halaman PDF.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Pilih File PDF'),
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
                  const Text('Teks Tanda Air', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Misal: DOKUMEN RAHASIA',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      prefixIcon: const Icon(Icons.text_fields_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Transparansi (${(_opacity * 100).toInt()}%)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 0.9,
                    divisions: 8,
                    activeColor: AppColors.editPurple,
                    onChanged: (val) => setState(() => _opacity = val),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kemiringan Sudut (${_angle.toInt()}°)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [0.0, 45.0, 90.0].map((deg) {
                      final isSelected = _angle == deg;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text('${deg.toInt()}°'),
                            selected: isSelected,
                            selectedColor: AppColors.editPurple,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                            onSelected: (val) => setState(() => _angle = deg),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _applyWatermark,
                      icon: const Icon(Icons.branding_watermark_rounded),
                      label: const Text('Terapkan Tanda Air'),
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
}
