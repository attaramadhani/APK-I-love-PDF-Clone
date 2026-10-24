import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/file_helper.dart';

/// Pesan galat yang ramah pengguna untuk masalah membuka/memproses PDF.
class PdfOpenException implements Exception {
  final String message;
  const PdfOpenException(this.message);

  @override
  String toString() => message;
}

/// Mesin pemrosesan PDF.
///
/// Semua pekerjaan berat (parsing, menyusun ulang halaman, menyimpan) dijalankan
/// di background isolate melalui [Isolate.run] agar animasi loading tetap mulus
/// dan aplikasi tidak "Not Responding" (ANR) saat memproses berkas besar.
/// Fungsi yang dijalankan di isolate hanya menerima nilai sederhana
/// (String path, List<int>, dsb.) — jangan pernah mengoper BuildContext/State.
class PdfEngineService {
  // ---------------------------------------------------------------------------
  // Utilitas umum
  // ---------------------------------------------------------------------------

  /// Mengubah exception teknis menjadi pesan yang mudah dipahami pengguna.
  static String friendlyError(Object error) {
    if (error is PdfOpenException) return error.message;
    final msg = error.toString().toLowerCase();
    if (msg.contains('password') || msg.contains('encrypt')) {
      return 'Dokumen dilindungi kata sandi atau kata sandi salah. '
          'Gunakan alat "Buka Kunci PDF" terlebih dahulu.';
    }
    if (msg.contains('outofmemory') || msg.contains('out of memory')) {
      return 'Memori perangkat tidak cukup untuk memproses berkas sebesar ini.';
    }
    if (msg.contains('invalid') ||
        msg.contains('corrupt') ||
        msg.contains('format') ||
        msg.contains('xref') ||
        msg.contains('header')) {
      return 'Berkas PDF rusak atau formatnya tidak didukung.';
    }
    if (msg.contains('no such file') || msg.contains('pathnotfound')) {
      return 'Berkas tidak ditemukan. Coba pilih ulang berkasnya.';
    }
    return 'Terjadi kesalahan: $error';
  }

  /// Membuka dokumen dari bytes dengan pesan galat yang jelas.
  static PdfDocument _open(List<int> bytes, {String? password}) {
    try {
      return password == null
          ? PdfDocument(inputBytes: bytes)
          : PdfDocument(inputBytes: bytes, password: password);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('password') || msg.contains('encrypt')) {
        throw PdfOpenException(password == null
            ? 'Dokumen dilindungi kata sandi. Buka kuncinya dulu dengan alat "Buka Kunci PDF".'
            : 'Kata sandi yang Anda masukkan salah.');
      }
      throw const PdfOpenException('Berkas PDF rusak atau formatnya tidak didukung.');
    }
  }

  /// Menghitung jumlah halaman (dipakai saat memilih berkas).
  static Future<int> getPageCount(File file) {
    final path = file.path;
    return Isolate.run(() {
      final doc = _open(File(path).readAsBytesSync());
      try {
        return doc.pages.count;
      } finally {
        doc.dispose();
      }
    });
  }

  /// Ukuran tiap halaman dalam satuan point (1/72 inci).
  static Future<List<Size>> getPageSizes(File file) {
    final path = file.path;
    return Isolate.run(() {
      final doc = _open(File(path).readAsBytesSync());
      try {
        return List<Size>.generate(doc.pages.count, (i) => doc.pages[i].size);
      } finally {
        doc.dispose();
      }
    });
  }

  /// Menyiapkan section baru dengan ukuran & rotasi yang benar.
  ///
  /// PENTING (perilaku Syncfusion):
  /// * `pageSettings.size` selalu dipaksa potret kecuali `orientation` diatur
  ///   ke landscape lebih dulu — tanpa ini halaman landscape menjadi potret
  ///   dan isinya terpotong.
  /// * `PdfPage.rotation` diabaikan untuk halaman baru; rotasi harus diatur
  ///   lewat `pageSettings.rotate` SEBELUM halaman ditambahkan.
  @visibleForTesting
  static PdfPage addPage(
    PdfDocument target,
    Size size, {
    PdfPageRotateAngle rotation = PdfPageRotateAngle.rotateAngle0,
  }) {
    final PdfSection section = target.sections!.add();
    section.pageSettings.orientation =
        size.width > size.height ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;
    section.pageSettings.size = size;
    section.pageSettings.margins.all = 0;
    if (rotation != PdfPageRotateAngle.rotateAngle0) {
      section.pageSettings.rotate = rotation;
    }
    return section.pages.add();
  }

  /// Menyalin satu halaman sumber ke dokumen tujuan sebagai template vektor
  /// dengan kanvas putih (mencegah latar hitam pada halaman transparan).
  /// Rotasi asli dipertahankan, ditambah [extraRotation] derajat bila ada.
  @visibleForTesting
  static void copyPage(PdfDocument target, PdfPage sourcePage, {int extraRotation = 0}) {
    final Size size = sourcePage.size;
    final PdfPage newPage = addPage(
      target,
      size,
      rotation: _degreesToAngle(_angleToDegrees(sourcePage.rotation) + extraRotation),
    );
    newPage.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(0, 0, size.width, size.height),
    );
    final PdfTemplate template = sourcePage.createTemplate();
    newPage.graphics.drawPdfTemplate(template, Offset.zero, size);
  }

  /// Melepas seluruh enkripsi dokumen. Syncfusion baru benar-benar menghapus
  /// enkripsi bila kedua sandi kosong DAN daftar izin dikosongkan; tanpa
  /// `permissions.clear()` hasil "buka kunci" ternyata tetap terenkripsi.
  @visibleForTesting
  static void removeSecurity(PdfDocument doc) {
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    doc.security.permissions.clear();
  }

  static String _baseName(File file) {
    var name = file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    name = name.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return name.length > 20 ? name.substring(0, 20) : name;
  }

  // ---------------------------------------------------------------------------
  // 1. Gabungkan PDF
  // ---------------------------------------------------------------------------
  static Future<String> mergePdfs(List<File> files) async {
    if (files.length < 2) {
      throw const PdfOpenException('Pilih minimal 2 berkas PDF untuk digabungkan.');
    }
    final paths = files.map((f) => f.path).toList();
    final outputPath = await FileHelper.generateOutputPath('Merged');
    await Isolate.run(() => _mergeSync(paths, outputPath));
    return outputPath;
  }

  static Future<void> _mergeSync(List<String> paths, String outputPath) async {
    final PdfDocument outputDoc = PdfDocument();
    final List<PdfDocument> sources = [];
    try {
      for (final path in paths) {
        final sourceDoc = _open(File(path).readAsBytesSync());
        sources.add(sourceDoc);
        for (int i = 0; i < sourceDoc.pages.count; i++) {
          copyPage(outputDoc, sourceDoc.pages[i]);
        }
      }
      // Dokumen sumber baru di-dispose SETELAH disimpan, karena template
      // halaman masih mereferensikan data dari dokumen sumber.
      final List<int> savedBytes = await outputDoc.save();
      File(outputPath).writeAsBytesSync(savedBytes);
    } finally {
      outputDoc.dispose();
      for (final d in sources) {
        d.dispose();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Pisahkan PDF menjadi banyak berkas
  // ---------------------------------------------------------------------------
  static Future<List<String>> splitPdfToMultipleFiles(
    File file,
    List<List<int>> ranges,
  ) async {
    final validRanges = ranges.where((r) => r.isNotEmpty).toList();
    if (validRanges.isEmpty) {
      throw const PdfOpenException('Rentang halaman tidak valid.');
    }
    final baseName = _baseName(file);
    final List<String> outputPaths = [];
    for (int i = 0; i < validRanges.length; i++) {
      final r = validRanges[i];
      final label = r.length == 1
          ? 'Hal_${r.first + 1}'
          : 'Bagian_${i + 1}_Hal_${r.first + 1}-${r.last + 1}';
      outputPaths.add(await FileHelper.generateOutputPath('${baseName}_$label'));
    }
    final path = file.path;
    await Isolate.run(() => _splitSync(path, validRanges, outputPaths));
    return outputPaths;
  }

  static Future<void> _splitSync(
    String path,
    List<List<int>> ranges,
    List<String> outputPaths,
  ) async {
    final PdfDocument sourceDoc = _open(File(path).readAsBytesSync());
    try {
      for (int i = 0; i < ranges.length; i++) {
        final PdfDocument splitDoc = PdfDocument();
        try {
          for (final index in ranges[i]) {
            if (index >= 0 && index < sourceDoc.pages.count) {
              copyPage(splitDoc, sourceDoc.pages[index]);
            }
          }
          if (splitDoc.pages.count == 0) {
            throw const PdfOpenException('Rentang halaman di luar jumlah halaman dokumen.');
          }
          final List<int> savedBytes = await splitDoc.save();
          File(outputPaths[i]).writeAsBytesSync(savedBytes);
        } finally {
          splitDoc.dispose();
        }
      }
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Kompatibilitas mundur untuk split single-range
  static Future<List<String>> splitPdf(File file, List<int> pageIndices) async {
    return splitPdfToMultipleFiles(file, [pageIndices]);
  }

  // ---------------------------------------------------------------------------
  // 3. Putar halaman (relatif terhadap rotasi yang sudah ada)
  // ---------------------------------------------------------------------------
  static int _angleToDegrees(PdfPageRotateAngle angle) {
    switch (angle) {
      case PdfPageRotateAngle.rotateAngle90:
        return 90;
      case PdfPageRotateAngle.rotateAngle180:
        return 180;
      case PdfPageRotateAngle.rotateAngle270:
        return 270;
      default:
        return 0;
    }
  }

  static PdfPageRotateAngle _degreesToAngle(int degrees) {
    switch (((degrees % 360) + 360) % 360) {
      case 90:
        return PdfPageRotateAngle.rotateAngle90;
      case 180:
        return PdfPageRotateAngle.rotateAngle180;
      case 270:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  /// [pageIndices] null = semua halaman.
  static Future<String> rotatePdf(
    File file,
    int rotationDegrees, {
    List<int>? pageIndices,
  }) async {
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Rotated');
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync());
      try {
        for (int i = 0; i < doc.pages.count; i++) {
          if (pageIndices != null && !pageIndices.contains(i)) continue;
          final page = doc.pages[i];
          page.rotation = _degreesToAngle(_angleToDegrees(page.rotation) + rotationDegrees);
        }
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 4. Hapus halaman
  // ---------------------------------------------------------------------------
  static Future<String> removePages(File file, List<int> pagesToRemove) async {
    final path = file.path;
    final toRemove = pagesToRemove.toSet().toList()..sort((a, b) => b.compareTo(a));
    final outputPath = await FileHelper.generateOutputPath('RemovedPages');
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync());
      try {
        final valid = toRemove.where((i) => i >= 0 && i < doc.pages.count).toList();
        if (valid.isEmpty) {
          throw const PdfOpenException('Tidak ada halaman valid yang dipilih untuk dihapus.');
        }
        if (valid.length >= doc.pages.count) {
          throw const PdfOpenException('Tidak bisa menghapus semua halaman. Sisakan minimal 1 halaman.');
        }
        for (final pageIndex in valid) {
          doc.pages.removeAt(pageIndex);
        }
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 5. Watermark teks
  // ---------------------------------------------------------------------------
  static Future<String> addWatermark(
    File file, {
    required String text,
    double opacity = 0.3,
    double fontSize = 40,
    double angle = 45,
  }) async {
    if (text.trim().isEmpty) {
      throw const PdfOpenException('Teks watermark tidak boleh kosong.');
    }
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Watermarked');
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync());
      try {
        final PdfBrush brush = PdfSolidBrush(PdfColor(128, 128, 128));
        for (int i = 0; i < doc.pages.count; i++) {
          final PdfPage page = doc.pages[i];
          final Size size = page.getClientSize();

          // Kecilkan font otomatis bila teks terlalu panjang untuk halaman
          double fs = fontSize;
          PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, fs, style: PdfFontStyle.bold);
          final double maxWidth = (size.width < size.height ? size.width : size.height) * 1.1;
          while (font.measureString(text).width > maxWidth && fs > 10) {
            fs -= 2;
            font = PdfStandardFont(PdfFontFamily.helvetica, fs, style: PdfFontStyle.bold);
          }

          page.graphics.save();
          page.graphics.setTransparency(opacity.clamp(0.05, 1.0));
          page.graphics.translateTransform(size.width / 2, size.height / 2);
          page.graphics.rotateTransform(-angle);
          final Size textSize = font.measureString(text);
          page.graphics.drawString(
            text,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
          );
          page.graphics.restore();
        }
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 6. Nomor halaman
  // ---------------------------------------------------------------------------
  static Future<String> addPageNumbers(
    File file, {
    String format = 'Halaman {page} dari {total}',
    bool atBottom = true,
  }) async {
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Numbered');
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync());
      try {
        final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 10);
        final PdfBrush brush = PdfSolidBrush(PdfColor(80, 80, 80));
        final int total = doc.pages.count;
        for (int i = 0; i < total; i++) {
          final PdfPage page = doc.pages[i];
          final Size size = page.getClientSize();
          final String text = format
              .replaceAll('{page}', '${i + 1}')
              .replaceAll('{total}', '$total');
          final Size textSize = font.measureString(text);
          final double x = (size.width - textSize.width) / 2;
          final double y = atBottom ? (size.height - textSize.height - 18) : 18;
          page.graphics.drawString(
            text,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(x, y, textSize.width + 2, textSize.height + 2),
          );
        }
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 7. Proteksi kata sandi (AES-256)
  // ---------------------------------------------------------------------------
  static Future<String> protectPdf(
    File file, {
    required String password,
  }) async {
    if (password.length < 4) {
      throw const PdfOpenException('Kata sandi minimal 4 karakter.');
    }
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Protected');
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync());
      try {
        final PdfSecurity security = doc.security;
        security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
        security.encryptionOptions = PdfEncryptionOptions.encryptAllContents;
        security.userPassword = password;
        security.ownerPassword = password;
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 8. Buka kunci (kata sandi harus diketahui)
  // ---------------------------------------------------------------------------
  static Future<String> unlockPdf(File file, String password) async {
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Unlocked');
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync(), password: password);
      try {
        removeSecurity(doc);
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 9. Ekstrak teks
  // ---------------------------------------------------------------------------
  /// [layout] = true mempertahankan tata letak kolom (berguna untuk tabel/Excel).
  static Future<String> extractText(File file, {bool layout = false}) {
    final path = file.path;
    return Isolate.run(() {
      final doc = _open(File(path).readAsBytesSync());
      try {
        return PdfTextExtractor(doc).extractText(layoutText: layout);
      } finally {
        doc.dispose();
      }
    });
  }

  /// Teks per halaman (indeks 0 = halaman 1).
  static Future<List<String>> extractTextPerPage(File file) {
    final path = file.path;
    return Isolate.run(() {
      final doc = _open(File(path).readAsBytesSync());
      try {
        final extractor = PdfTextExtractor(doc);
        return List<String>.generate(
          doc.pages.count,
          (i) => extractor.extractText(startPageIndex: i, endPageIndex: i),
        );
      } finally {
        doc.dispose();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 10. Optimasi/kompresi lossless (struktur & stream)
  // ---------------------------------------------------------------------------
  static Future<String> optimizePdf(File file, {String prefix = 'Compressed'}) async {
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath(prefix);
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync());
      try {
        doc.compressionLevel = PdfCompressionLevel.best;
        doc.fileStructure.incrementalUpdate = false;
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 11. Membuat PDF dari gambar JPEG per halaman (dipakai rasterisasi)
  // ---------------------------------------------------------------------------
  static Future<void> buildPdfFromJpegPages(
    List<Uint8List> jpegPages,
    List<Size> pageSizes,
    String outputPath,
  ) {
    return Isolate.run(() async {
      final doc = PdfDocument();
      try {
        doc.compressionLevel = PdfCompressionLevel.best;
        for (int i = 0; i < jpegPages.length; i++) {
          final size = pageSizes[i];
          final page = addPage(doc, size);
          page.graphics.drawImage(
            PdfBitmap(jpegPages[i]),
            Rect.fromLTWH(0, 0, size.width, size.height),
          );
        }
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 12. Potong margin (crop) — nilai dalam point
  // ---------------------------------------------------------------------------
  static Future<String> cropPdf(
    File file, {
    required double top,
    required double bottom,
    required double left,
    required double right,
  }) async {
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Cropped');
    await Isolate.run(() async {
      final source = _open(File(path).readAsBytesSync());
      final output = PdfDocument();
      try {
        for (int i = 0; i < source.pages.count; i++) {
          final sourcePage = source.pages[i];
          final orig = sourcePage.size;
          final w = (orig.width - left - right).clamp(50.0, orig.width);
          final h = (orig.height - top - bottom).clamp(50.0, orig.height);
          final newPage = addPage(output, Size(w, h), rotation: sourcePage.rotation);
          newPage.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(255, 255, 255)),
            bounds: Rect.fromLTWH(0, 0, w, h),
          );
          newPage.graphics.drawPdfTemplate(sourcePage.createTemplate(), Offset(-left, -top), orig);
        }
        final List<int> savedBytes = await output.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        output.dispose();
        source.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 13. Susun ulang halaman: [order] = indeks halaman asli sesuai urutan baru,
  //     [extraRotations] = rotasi tambahan (derajat) untuk tiap entri order.
  // ---------------------------------------------------------------------------
  static Future<String> organizePdf(
    File file,
    List<int> order,
    List<int> extraRotations,
  ) async {
    if (order.isEmpty) {
      throw const PdfOpenException('Dokumen harus memiliki minimal 1 halaman.');
    }
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Organized');
    await Isolate.run(() async {
      final source = _open(File(path).readAsBytesSync());
      final output = PdfDocument();
      try {
        for (int i = 0; i < order.length; i++) {
          final idx = order[i];
          if (idx < 0 || idx >= source.pages.count) continue;
          copyPage(output, source.pages[idx], extraRotation: extraRotations[i]);
        }
        final List<int> savedBytes = await output.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        output.dispose();
        source.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 14. Bubuhkan gambar (tanda tangan) ke halaman
  //     [pageMode]: 'last' | 'first' | 'all'
  //     [position]: 'bottom_right' | 'bottom_left' | 'bottom_center'
  // ---------------------------------------------------------------------------
  static Future<String> stampImage(
    File file,
    Uint8List pngBytes, {
    required double imageAspect, // lebar / tinggi
    String pageMode = 'last',
    String position = 'bottom_right',
    double widthPt = 160,
  }) async {
    final path = file.path;
    final outputPath = await FileHelper.generateOutputPath('Signed');
    await Isolate.run(() async {
      final doc = _open(File(path).readAsBytesSync());
      try {
        final count = doc.pages.count;
        final List<int> targets = pageMode == 'all'
            ? List<int>.generate(count, (i) => i)
            : [pageMode == 'first' ? 0 : count - 1];
        final bitmap = PdfBitmap(pngBytes);
        for (final i in targets) {
          final page = doc.pages[i];
          final size = page.getClientSize();
          final w = widthPt.clamp(60.0, size.width * 0.6);
          final h = w / (imageAspect <= 0 ? 2 : imageAspect);
          const margin = 36.0;
          double x;
          switch (position) {
            case 'bottom_left':
              x = margin;
              break;
            case 'bottom_center':
              x = (size.width - w) / 2;
              break;
            default:
              x = size.width - w - margin;
          }
          final y = size.height - h - margin;
          page.graphics.drawImage(bitmap, Rect.fromLTWH(x, y, w, h));
        }
        final List<int> savedBytes = await doc.save();
        File(outputPath).writeAsBytesSync(savedBytes);
      } finally {
        doc.dispose();
      }
    });
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // 15. Cari posisi kata/frasa (untuk redaksi berdasarkan kata kunci)
  //     Hasil: indeks halaman -> daftar kotak (point, origin kiri-atas).
  // ---------------------------------------------------------------------------
  static Future<Map<int, List<Rect>>> findTextBounds(File file, List<String> terms) {
    final path = file.path;
    final cleanTerms = terms.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (cleanTerms.isEmpty) return Future.value(<int, List<Rect>>{});
    return Isolate.run(() {
      final doc = _open(File(path).readAsBytesSync());
      try {
        final result = <int, List<Rect>>{};
        final matches = PdfTextExtractor(doc).findText(cleanTerms);
        for (final m in matches) {
          result.putIfAbsent(m.pageIndex, () => <Rect>[]).add(m.bounds.inflate(1.5));
        }
        return result;
      } finally {
        doc.dispose();
      }
    });
  }
}
