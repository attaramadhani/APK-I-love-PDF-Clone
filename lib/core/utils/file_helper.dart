import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileHelper {
  static String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double size = bytes / (1 << (i * 10));
    return "${size.toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  static Future<String> getAppOutputDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(dir.path, 'PDF_Studio_Files'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir.path;
  }

  static Future<String> generateOutputPath(String prefix, [String ext = '.pdf']) async {
    final dirPath = await getAppOutputDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return p.join(dirPath, '${prefix}_$timestamp$ext');
  }

  /// MIME type berdasarkan ekstensi berkas.
  static String mimeTypeFor(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.txt':
        return 'text/plain';
      case '.md':
        return 'text/markdown';
      case '.csv':
        return 'text/csv';
      case '.doc':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  /// Menyalin berkas ke folder Download publik dengan nama unik (tidak menimpa).
  static Future<String?> _copyToPublicDownload(File file, String fileName) async {
    if (!Platform.isAndroid) return null;
    try {
      final downloadDir = Directory('/storage/emulated/0/Download/PDF Studio Pro');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      final base = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);
      var dest = File(p.join(downloadDir.path, fileName));
      var n = 1;
      while (await dest.exists()) {
        dest = File(p.join(downloadDir.path, '$base ($n)$ext'));
        n++;
      }
      await file.copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  /// Tombol & aksi resmi: Simpan Berkas ke Penyimpanan Lokal (Download / Storage HP)
  static Future<bool> saveToLocalDevice(
    BuildContext context, {
    required String sourcePath,
    String? preferredName,
  }) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berkas sumber tidak ditemukan.')),
          );
        }
        return false;
      }

      final fileName = preferredName ?? file.uri.pathSegments.last;
      final Uint8List bytes = await file.readAsBytes();

      // Simpan via Storage Access Framework (SAF): pengguna memilih folder tujuan.
      // Bila pengguna membatalkan dialog, JANGAN menyalin diam-diam ke tempat lain.
      Uri? uri;
      String? publicDownloadPath;
      try {
        uri = await FilePicker.saveFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: mimeTypeFor(fileName),
          dialogTitle: 'Simpan ke File Lokal',
        );
      } catch (_) {
        // Fallback hanya bila dialog SAF tidak tersedia di perangkat.
        publicDownloadPath = await _copyToPublicDownload(file, fileName);
      }

      final isSuccess = uri != null || publicDownloadPath != null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSuccess
                        ? (publicDownloadPath != null
                            ? 'Berkas disimpan ke Download/PDF Studio Pro'
                            : 'Berkas berhasil disimpan ke penyimpanan lokal!')
                        : 'Penyimpanan berkas dibatalkan.',
                  ),
                ),
              ],
            ),
            backgroundColor: isSuccess ? Colors.green.shade700 : Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return isSuccess;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan ke penyimpanan lokal: $e')),
        );
      }
      return false;
    }
  }

  /// Menyimpan beberapa berkas sekaligus ke penyimpanan Download perangkat
  static Future<int> saveMultipleToLocalDevice(
    BuildContext context, {
    required List<String> filePaths,
  }) async {
    int savedCount = 0;
    try {
      for (final path in filePaths) {
        final file = File(path);
        if (!await file.exists()) continue;
        final fileName = file.uri.pathSegments.last;
        // Coba salin langsung ke Download/PDF Studio Pro (Android 10+ tidak perlu izin).
        var saved = await _copyToPublicDownload(file, fileName) != null;
        if (!saved) {
          // Fallback: dialog simpan per berkas.
          final uri = await FilePicker.saveFile(
            fileName: fileName,
            bytes: await file.readAsBytes(),
            mimeType: mimeTypeFor(fileName),
            dialogTitle: 'Simpan $fileName',
          );
          saved = uri != null;
        }
        if (saved) savedCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$savedCount dari ${filePaths.length} berkas tersimpan (Download/PDF Studio Pro)',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan beberapa berkas: $e')),
        );
      }
    }
    return savedCount;
  }
}
