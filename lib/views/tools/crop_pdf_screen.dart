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

class CropPdfScreen extends StatefulWidget {
  const CropPdfScreen({super.key});

  @override
  State<CropPdfScreen> createState() => _CropPdfScreenState();
}

class _CropPdfScreenState extends State<CropPdfScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  int _presetIndex = 0; // 0: Margin Putih (20pt), 1: Header/Footer (45pt), 2: Kustom

  double _cropTop = 20;
  double _cropBottom = 20;
  double _cropLeft = 20;
  double _cropRight = 20;

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

  void _applyPreset(int index) {
    setState(() {
      _presetIndex = index;
      if (index == 0) {
        // Potong margin putih keliling
        _cropTop = 25;
        _cropBottom = 25;
        _cropLeft = 25;
        _cropRight = 25;
      } else if (index == 1) {
        // Potong header dan footer
        _cropTop = 50;
        _cropBottom = 50;
        _cropLeft = 10;
        _cropRight = 10;
      }
    });
  }

  Future<void> _executeCrop() async {
    if (_selectedFile == null) return;

    ProcessingDialog.show(
      context,
      title: 'Memotong Halaman Dokumen',
      message: 'Menghapus margin dan menyusun ulang $_totalPages halaman...',
    );

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final sourceDoc = PdfDocument(inputBytes: bytes);
      final outputDoc = PdfDocument();

      for (int i = 0; i < sourceDoc.pages.count; i++) {
        final sourcePage = sourceDoc.pages[i];
        final origSize = sourcePage.size;

        final newWidth = (origSize.width - _cropLeft - _cropRight).clamp(50.0, origSize.width);
        final newHeight = (origSize.height - _cropTop - _cropBottom).clamp(50.0, origSize.height);
        final newSize = Size(newWidth, newHeight);

        final section = outputDoc.sections!.add();
        section.pageSettings.size = newSize;
        section.pageSettings.margins.all = 0;

        final newPage = section.pages.add();
        newPage.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
          bounds: Rect.fromLTWH(0, 0, newSize.width, newSize.height),
        );
        final template = sourcePage.createTemplate();
        // Geser konten ke kiri dan atas sebesar margin yang dipotong
        newPage.graphics.drawPdfTemplate(template, Offset(-_cropLeft, -_cropTop), origSize);
      }

      final savedBytes = await outputDoc.save();
      outputDoc.dispose();
      sourceDoc.dispose();

      final outputPath = await FileHelper.generateOutputPath('Cropped');
      await File(outputPath).writeAsBytes(savedBytes);

      final outputFile = File(outputPath);
      final fileSize = await outputFile.length();

      final processedFile = ProcessedFile(
        id: const Uuid().v4(),
        name: outputFile.uri.pathSegments.last,
        path: outputPath,
        sizeInBytes: fileSize,
        createdAt: DateTime.now(),
        toolUsed: 'Potong PDF',
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
          SnackBar(content: Text('Gagal memotong dokumen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Potong PDF (Crop Margin)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                color: AppColors.editPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.crop_rounded, size: 64, color: AppColors.editPurple),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilih File PDF untuk Dipotong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Potong margin putih berlebih, bersihkan kop/footer, atau sesuaikan ukuran batas halaman dokumen.',
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
    );
  }

  Widget _buildConfigView() {
    return SingleChildScrollView(
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
              subtitle: Text('Total: $_totalPages Halaman (${FileHelper.formatBytes(_selectedFile!.lengthSync())})'),
              trailing: IconButton(
                icon: const Icon(Icons.change_circle_outlined),
                tooltip: 'Ganti File',
                onPressed: _pickFile,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Pilihan Pemotongan Margin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPresetChip(0, 'Margin Putih\n(25 pt)'),
              const SizedBox(width: 8),
              _buildPresetChip(1, 'Kop & Catatan\n(50 pt)'),
              const SizedBox(width: 8),
              _buildPresetChip(2, 'Atur Kustom\n(Manual)'),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Sesuaikan Batas Pemotongan (Point):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSliderRow('Atas (Top):', _cropTop, (v) => setState(() => _cropTop = v)),
          _buildSliderRow('Bawah (Bottom):', _cropBottom, (v) => setState(() => _cropBottom = v)),
          _buildSliderRow('Kiri (Left):', _cropLeft, (v) => setState(() => _cropLeft = v)),
          _buildSliderRow('Kanan (Right):', _cropRight, (v) => setState(() => _cropRight = v)),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _executeCrop,
              icon: const Icon(Icons.crop_rounded),
              label: const Text('Terapkan Pemotongan Dokumen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.editPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(int index, String label) {
    final isSelected = _presetIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _applyPreset(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.editPurple.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.editPurple : AppColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
              color: isSelected ? AppColors.editPurple : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${value.toInt()} pt',
              activeColor: AppColors.editPurple,
              onChanged: (v) {
                setState(() => _presetIndex = 2);
                onChanged(v);
              },
            ),
          ),
          SizedBox(
            width: 45,
            child: Text('${value.toInt()} pt', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
