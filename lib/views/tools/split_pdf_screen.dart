import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../core/utils/page_range_parser.dart';
import '../../models/processed_file.dart';
import '../../widgets/processing_dialog.dart';
import '../viewer/pdf_viewer_screen.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  int _splitMode = 0; // 0: Pisah Setiap Halaman, 1: Rentang Kustom, 2: Ekstrak ke 1 Berkas
  final TextEditingController _customRangeController = TextEditingController();
  List<String> _splitResultFiles = [];

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
        _totalPages = count;
        _splitResultFiles = [];
        if (count >= 2) {
          final mid = (count / 2).ceil();
          _customRangeController.text = '1-$mid; ${mid + 1}-$count';
        } else {
          _customRangeController.text = '1';
        }
      });
    }
  }

  List<List<int>> _parseRanges(String input, int maxPages) =>
      PageRangeParser.parseGroups(input, maxPages);

  Future<void> _executeSplit() async {
    if (_selectedFile == null) return;

    List<List<int>> ranges = [];

    if (_splitMode == 0) {
      // 1 Halaman = 1 File Terpisah
      ranges = List.generate(_totalPages, (i) => [i]);
    } else if (_splitMode == 1) {
      // Rentang Kustom (dipisah tanda titik koma ;)
      ranges = _parseRanges(_customRangeController.text, _totalPages);
    } else {
      // Ekstrak ke 1 Berkas Gabungan
      final singleRange = _parseRanges(_customRangeController.text.replaceAll(';', ','), _totalPages);
      final merged = <int>{};
      for (final r in singleRange) {
        merged.addAll(r);
      }
      if (merged.isNotEmpty) {
        ranges = [merged.toList()..sort()];
      }
    }

    if (ranges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rentang halaman tidak valid.')),
      );
      return;
    }

    ProcessingDialog.show(
      context,
      title: 'Memisahkan Dokumen PDF',
      message: 'Menghasilkan ${ranges.length} berkas PDF terpisah...',
    );

    try {
      final outputPaths = await PdfEngineService.splitPdfToMultipleFiles(_selectedFile!, ranges);

      // Catat seluruh file ke riwayat lokal
      for (final path in outputPaths) {
        final f = File(path);
        final size = await f.length();
        final processedFile = ProcessedFile(
          id: const Uuid().v4(),
          name: f.uri.pathSegments.last,
          path: path,
          sizeInBytes: size,
          createdAt: DateTime.now(),
          toolUsed: 'Pisahkan PDF',
        );
        await RecentFilesService.addFile(processedFile);
      }

      if (mounted) {
        ProcessingDialog.hide(context);
        if (outputPaths.length == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                filePath: outputPaths.first,
                title: File(outputPaths.first).uri.pathSegments.last,
              ),
            ),
          );
        } else {
          setState(() {
            _splitResultFiles = outputPaths;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memisahkan PDF: ${PdfEngineService.friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pisahkan PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _selectedFile == null
          ? _buildFilePickerEmptyState()
          : (_splitResultFiles.isNotEmpty ? _buildResultsView() : _buildConfigurationView()),
    );
  }

  Widget _buildFilePickerEmptyState() {
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
              child: const Icon(Icons.call_split_rounded, size: 64, color: AppColors.organizeOrange),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilih File PDF untuk Dipisahkan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pisahkan dokumen PDF menjadi beberapa file terpisah per halaman atau berdasarkan rentang kustom.',
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

  Widget _buildConfigurationView() {
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
              subtitle: Text(
                'Total: $_totalPages Halaman (${FileHelper.formatBytes(_selectedFile!.lengthSync())})',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.change_circle_outlined),
                tooltip: 'Ganti File',
                onPressed: _pickFile,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Metode Pemisahan Berkas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildModeOption(
            0,
            'Pisah Setiap Halaman (Banyak Berkas)',
            'Setiap 1 lembar halaman akan diekstrak menjadi 1 file PDF mandiri (menghasilkan $_totalPages file).',
            Icons.filter_none_rounded,
          ),
          const SizedBox(height: 10),
          _buildModeOption(
            1,
            'Pisah Berdasarkan Rentang Kustom (Multi-Berkas)',
            'Tentukan beberapa rentang. Setiap rentang akan disimpan menjadi berkas PDF terpisah.',
            Icons.view_week_rounded,
          ),
          const SizedBox(height: 10),
          _buildModeOption(
            2,
            'Ekstrak Halaman Pilihan ke 1 Berkas',
            'Ambil halaman tertentu dan simpan ke dalam 1 berkas PDF baru.',
            Icons.content_cut_rounded,
          ),
          if (_splitMode != 0) ...[
            const SizedBox(height: 24),
            Text(
              _splitMode == 1 ? 'Tentukan Rentang Tiap Berkas (Pisahkan dengan tanda ; )' : 'Tentukan Halaman yang Diekstrak',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _splitMode == 1
                  ? 'Contoh: 1-2; 3-4; 5-8 (menghasilkan 3 berkas PDF terpisah)'
                  : 'Contoh: 1-3, 5, 8 (disatukan menjadi 1 berkas)',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customRangeController,
              decoration: InputDecoration(
                hintText: 'Misal: 1-2; 3-$_totalPages',
                prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
          ],
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _executeSplit,
              icon: const Icon(Icons.call_split_rounded),
              label: Text(
                _splitMode == 0
                    ? 'Pisahkan Menjadi $_totalPages Berkas PDF'
                    : (_splitMode == 1 ? 'Pisahkan Menjadi Beberapa Berkas PDF' : 'Ekstrak Halaman ke 1 PDF'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.organizeOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(int mode, String title, String subtitle, IconData icon) {
    final isSelected = _splitMode == mode;
    return InkWell(
      onTap: () => setState(() => _splitMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.organizeOrange.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.organizeOrange : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.organizeOrange : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.organizeOrange.withValues(alpha: 0.1),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.organizeOrange, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Berhasil Dipisahkan: ${_splitResultFiles.length} Berkas PDF!',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Text(
                          'Setiap bagian telah disimpan menjadi berkas dokumen independen.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    FileHelper.saveMultipleToLocalDevice(context, filePaths: _splitResultFiles);
                  },
                  icon: const Icon(Icons.file_download_rounded),
                  label: Text('Simpan Semua ${_splitResultFiles.length} Berkas ke File Lokal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.organizeOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daftar Berkas Hasil Pemisahan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _splitResultFiles = [];
                  });
                },
                child: const Text('Ulangi / Atur Kembali'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _splitResultFiles.length,
            itemBuilder: (context, index) {
              final path = _splitResultFiles[index];
              final file = File(path);
              final name = file.uri.pathSegments.last;
              final size = file.existsSync() ? FileHelper.formatBytes(file.lengthSync()) : '';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.organizeOrange.withValues(alpha: 0.15),
                    child: Text('${index + 1}', style: const TextStyle(color: AppColors.organizeOrange, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(size, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.file_download_rounded, color: AppColors.primaryBlue),
                        tooltip: 'Simpan ke File Lokal',
                        onPressed: () {
                          FileHelper.saveToLocalDevice(context, sourcePath: path, preferredName: name);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_rounded, color: AppColors.textSecondary),
                        tooltip: 'Buka PDF',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfViewerScreen(filePath: path, title: name),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: AppColors.textSecondary),
                        tooltip: 'Bagikan',
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(files: [XFile(path)], text: 'Dokumen terpisah: $name'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
