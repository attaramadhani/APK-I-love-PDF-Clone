import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  /// Kata sandi untuk membuka PDF terenkripsi (mis. hasil alat Proteksi PDF).
  final String? password;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.password,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';
  PDFViewController? _pdfViewController;

  void _showJumpToPageDialog() {
    if (_totalPages <= 1) return;
    final controller = TextEditingController(text: '${_currentPage + 1}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.find_in_page_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Lompat ke Halaman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan nomor halaman antara 1 sampai $_totalPages:',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Misal: 15',
                prefixIcon: const Icon(Icons.numbers_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pdfViewController?.setPage(0);
                  },
                  icon: const Icon(Icons.first_page_rounded, size: 18),
                  label: const Text('Halaman 1'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pdfViewController?.setPage(_totalPages - 1);
                  },
                  icon: const Icon(Icons.last_page_rounded, size: 18),
                  label: Text('Hal $_totalPages'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.pop(ctx);
                _pdfViewController?.setPage(page - 1);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nomor halaman harus antara 1 dan $_totalPages')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('Lompat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);
    final fileSize = file.existsSync() ? FileHelper.formatBytes(file.lengthSync()) : '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (fileSize.isNotEmpty)
              Text(
                fileSize,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          if (_isReady && _totalPages > 1)
            IconButton(
              icon: const Icon(Icons.find_in_page_rounded),
              tooltip: 'Lompat / Cari Halaman',
              onPressed: _showJumpToPageDialog,
            ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded, color: AppColors.primaryBlue),
            tooltip: 'Simpan ke File Lokal',
            onPressed: () {
              FileHelper.saveToLocalDevice(
                context,
                sourcePath: widget.filePath,
                preferredName: widget.title,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Bagikan',
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  files: [XFile(widget.filePath)],
                  text: 'Dokumen dari PDF Studio Pro: ${widget.title}',
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            PDFView(
              filePath: widget.filePath,
              password: widget.password,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              fitPolicy: FitPolicy.BOTH,
              preventLinkNavigation: false,
              nightMode: false,
              backgroundColor: Colors.white,
              onRender: (pages) {
              if (!mounted) return;
              setState(() {
                _totalPages = pages ?? 0;
                _isReady = true;
              });
            },
            onError: (error) {
              if (!mounted) return;
              setState(() {
                _errorMessage = error.toString();
              });
            },
            onPageError: (page, error) {
              if (!mounted) return;
              setState(() {
                _errorMessage = '$page: ${error.toString()}';
              });
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _pdfViewController = pdfViewController;
            },
            onPageChanged: (int? page, int? total) {
              if (!mounted) return;
              setState(() {
                _currentPage = page ?? 0;
              });
            },
          ),
          if (!_isReady && _errorMessage.isEmpty)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            ),
          if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Gagal memuat dokumen:\n$_errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),

          // Floating Fast Page Scrubber Slider (Navigasi Halaman Cepat)
          if (_isReady && _totalPages > 1)
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _showJumpToPageDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currentPage + 1} / $_totalPages',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          activeTrackColor: AppColors.primaryBlue,
                          thumbColor: AppColors.primaryBlue,
                          inactiveTrackColor: AppColors.cardBorder,
                        ),
                        child: Slider(
                          value: (_currentPage + 1).toDouble().clamp(1.0, _totalPages.toDouble()),
                          min: 1.0,
                          max: _totalPages.toDouble(),
                          onChanged: (val) {
                            final target = val.toInt();
                            _pdfViewController?.setPage(target - 1);
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.find_in_page_rounded, size: 20, color: AppColors.primaryBlue),
                      tooltip: 'Cari / Lompat Halaman',
                      onPressed: _showJumpToPageDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    FileHelper.saveToLocalDevice(
                      context,
                      sourcePath: widget.filePath,
                      preferredName: widget.title,
                    );
                  },
                  icon: const Icon(Icons.file_download_rounded, size: 20),
                  label: const Text('Simpan ke File Lokal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(widget.filePath)],
                        text: 'Dokumen dari PDF Studio Pro: ${widget.title}',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Bagikan'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
