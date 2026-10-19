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

      // 1. Simpan via Storage Access Framework (SAF) - pengguna bisa memilih folder tujuan
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: fileName.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream',
        dialogTitle: 'Simpan ke File Lokal',
      );

      // 2. Jika di Android, salin juga ke folder Download publik perangkat jika tersedia
      String? publicDownloadPath;
      if (Platform.isAndroid) {
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final destFile = File(p.join(downloadDir.path, fileName));
            await file.copy(destFile.path);
            publicDownloadPath = destFile.path;
          }
        } catch (_) {}
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
                            ? 'Berkas berhasil disimpan ke folder Download & lokal!'
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
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        for (final path in filePaths) {
          final file = File(path);
          if (await file.exists()) {
            final fileName = file.uri.pathSegments.last;
            final destPath = p.join(downloadDir.path, fileName);
            await file.copy(destPath);
            savedCount++;
          }
        }
      } else {
        for (final path in filePaths) {
          final file = File(path);
          if (await file.exists()) {
            final fileName = file.uri.pathSegments.last;
            final bytes = await file.readAsBytes();
            await FilePicker.saveFile(
              fileName: fileName,
              bytes: bytes,
              dialogTitle: 'Simpan $fileName',
            );
            savedCount++;
          }
        }
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
                    '$savedCount berkas berhasil disimpan ke folder Download perangkat!',
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
