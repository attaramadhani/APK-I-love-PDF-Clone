import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../models/processed_file.dart';
import '../viewer/pdf_viewer_screen.dart';

class RecentFilesScreen extends StatefulWidget {
  final VoidCallback? onGoToTools;

  const RecentFilesScreen({super.key, this.onGoToTools});

  @override
  RecentFilesScreenState createState() => RecentFilesScreenState();
}

class RecentFilesScreenState extends State<RecentFilesScreen> {
  List<ProcessedFile> _files = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'Semua'; // 'Semua', 'PDF', 'Gambar', 'Lainnya'

  @override
  void initState() {
    super.initState();
    loadFiles();
  }

  Future<void> loadFiles() async {
    setState(() => _isLoading = true);
    final files = await RecentFilesService.getRecentFiles();
    if (mounted) {
      setState(() {
        _files = files;
        _isLoading = false;
      });
    }
  }

  int get _totalBytes => _files.fold(0, (sum, f) => sum + f.sizeInBytes);

  List<ProcessedFile> get _filteredFiles {
    return _files.where((f) {
      final matchesSearch = _searchQuery.isEmpty ||
          f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.toolUsed.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      final isPdf = f.path.toLowerCase().endsWith('.pdf');
      final isImage = f.path.toLowerCase().endsWith('.png') ||
          f.path.toLowerCase().endsWith('.jpg') ||
          f.path.toLowerCase().endsWith('.jpeg');

      if (_selectedFilter == 'PDF') return isPdf;
      if (_selectedFilter == 'Gambar') return isImage;
      if (_selectedFilter == 'Lainnya') return !isPdf && !isImage;
      return true;
    }).toList();
  }

  void _openFile(ProcessedFile file) {
    if (file.path.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PdfViewerScreen(
            filePath: file.path,
            title: file.name,
          ),
        ),
      );
    } else {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Dokumen: ${file.name}',
        ),
      );
    }
  }

  Color _getBadgeColor(String toolUsed) {
    if (toolUsed.contains('Kompres')) return AppColors.optimizeGreen;
    if (toolUsed.contains('Gabung') || toolUsed.contains('Pisah') || toolUsed.contains('Atur')) {
      return AppColors.organizeOrange;
    }
    if (toolUsed.contains('Gambar') || toolUsed.contains('Word') || toolUsed.contains('Excel')) {
      return AppColors.convertBlue;
    }
    if (toolUsed.contains('Kunci') || toolUsed.contains('Proteksi') || toolUsed.contains('Banding')) {
      return AppColors.securityNavy;
    }
    return AppColors.primaryBlue;
  }

  IconData _getFileIcon(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description_rounded;
    if (lower.endsWith('.csv') || lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFiles;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const Text('File Terkini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            if (_files.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_files.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Riwayat',
            onPressed: loadFiles,
          ),
          if (_files.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Opsi Riwayat',
              onSelected: (val) async {
                if (val == 'clear') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Hapus Seluruh Riwayat?'),
                      content: const Text(
                        'Semua daftar file terkini akan dibersihkan dari aplikasi. File yang sudah tersimpan di memori HP tidak akan hilang.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          child: const Text('Bersihkan'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await RecentFilesService.clearAll();
                    loadFiles();
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Bersihkan Seluruh Riwayat', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadFiles,
        color: AppColors.primaryBlue,
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari nama dokumen atau alat...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ),

            // Horizontal Filter Chips
            if (_files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('Semua', _files.length),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'PDF',
                        _files.where((f) => f.path.toLowerCase().endsWith('.pdf')).length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Gambar',
                        _files.where((f) {
                          final lower = f.path.toLowerCase();
                          return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg');
                        }).length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Lainnya',
                        _files.where((f) {
                          final lower = f.path.toLowerCase();
                          return !lower.endsWith('.pdf') &&
                              !lower.endsWith('.png') &&
                              !lower.endsWith('.jpg') &&
                              !lower.endsWith('.jpeg');
                        }).length,
                      ),
                    ],
                  ),
                ),
              ),

            // File List or Empty State
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final file = filtered[index];
                            return _buildFileItemCard(file);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItemCard(ProcessedFile file) {
    final badgeColor = _getBadgeColor(file.toolUsed);
    final icon = _getFileIcon(file.path);
    final isPdf = file.path.toLowerCase().endsWith('.pdf');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openFile(file),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Type
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPdf
                      ? AppColors.primaryBlue.withValues(alpha: 0.1)
                      : AppColors.optimizeGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isPdf ? AppColors.primaryBlue : AppColors.optimizeGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Title and Meta Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.toolUsed,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          FileHelper.formatBytes(file.sizeInBytes),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            FileHelper.formatDate(file.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right Action Buttons (Rapi & Tidak Berantakan)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.file_download_rounded, size: 22, color: AppColors.primaryBlue),
                    tooltip: 'Simpan ke File Lokal',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      FileHelper.saveToLocalDevice(
                        context,
                        sourcePath: file.path,
                        preferredName: file.name,
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                    tooltip: 'Menu Dokumen',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (action) async {
                      if (action == 'open') {
                        _openFile(file);
                      } else if (action == 'download') {
                        FileHelper.saveToLocalDevice(
                          context,
                          sourcePath: file.path,
                          preferredName: file.name,
                        );
                      } else if (action == 'share') {
                        SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(file.path)],
                            text: 'Dokumen dari PDF Studio Pro: ${file.name}',
                          ),
                        );
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus berkas?'),
                            content: Text('"${file.name}" akan dihapus permanen dari aplikasi.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await RecentFilesService.removeFile(file.id);
                        if (File(file.path).existsSync()) {
                          try {
                            File(file.path).deleteSync();
                          } catch (_) {}
                        }
                        loadFiles();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 10),
                            Text('Buka Dokumen', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.file_download_outlined, size: 18, color: AppColors.primaryBlue),
                            SizedBox(width: 10),
                            Text('Simpan ke File Lokal', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 10),
                            Text('Bagikan', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Hapus', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    size: 60,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Belum Ada Dokumen Terkini',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dokumen yang Anda proses (Gabung, Kompres, Pisah, OCR, dll.) akan tersimpan otomatis dan tertata rapi di sini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                if (widget.onGoToTools != null)
                  ElevatedButton.icon(
                    onPressed: widget.onGoToTools,
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('Buka Menu Alat PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
