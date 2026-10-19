import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart' show Color;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/file_helper.dart';

class PdfEngineService {
  /// 1. Gabungkan banyak file PDF menjadi satu file
  static Future<String> mergePdfs(List<File> files) async {
    final PdfDocument outputDoc = PdfDocument();

    try {
      for (final file in files) {
        final Uint8List bytes = await file.readAsBytes();
        final PdfDocument sourceDoc = PdfDocument(inputBytes: bytes);
        for (int i = 0; i < sourceDoc.pages.count; i++) {
          final PdfPage sourcePage = sourceDoc.pages[i];
          final PdfSection section = outputDoc.sections!.add();
          section.pageSettings.size = sourcePage.size;
          section.pageSettings.margins.all = 0;
          final PdfPage newPage = section.pages.add();
          newPage.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(255, 255, 255)),
            bounds: Rect.fromLTWH(0, 0, sourcePage.size.width, sourcePage.size.height),
          );
          final PdfTemplate template = sourcePage.createTemplate();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0), sourcePage.size);
        }
        sourceDoc.dispose();
      }

      final List<int> savedBytes = await outputDoc.save();
      final String outputPath = await FileHelper.generateOutputPath('Merged');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      outputDoc.dispose();
    }
  }

  /// 2. Pisahkan PDF Menjadi Banyak Berkas (Multi-File Split)
  /// Setiap entri dalam [ranges] menghasilkan 1 file PDF independen
  static Future<List<String>> splitPdfToMultipleFiles(
    File file,
    List<List<int>> ranges,
  ) async {
    final Uint8List bytes = await file.readAsBytes();
    final PdfDocument sourceDoc = PdfDocument(inputBytes: bytes);
    final List<String> outputPaths = [];
    final rawBase = file.uri.pathSegments.last.replaceAll('.pdf', '');
    final baseName = rawBase.length > 15 ? rawBase.substring(0, 15) : rawBase;

    try {
      for (int i = 0; i < ranges.length; i++) {
        final List<int> pageIndices = ranges[i];
        if (pageIndices.isEmpty) continue;

        final PdfDocument splitDoc = PdfDocument();
        for (int index in pageIndices) {
          if (index >= 0 && index < sourceDoc.pages.count) {
            final PdfPage sourcePage = sourceDoc.pages[index];
            final PdfSection section = splitDoc.sections!.add();
            section.pageSettings.size = sourcePage.size;
            section.pageSettings.margins.all = 0;
            final PdfPage newPage = section.pages.add();
            newPage.graphics.drawRectangle(
              brush: PdfSolidBrush(PdfColor(255, 255, 255)),
              bounds: Rect.fromLTWH(0, 0, sourcePage.size.width, sourcePage.size.height),
            );
            final PdfTemplate template = sourcePage.createTemplate();
            newPage.graphics.drawPdfTemplate(template, const Offset(0, 0), sourcePage.size);
          }
        }

        final List<int> savedBytes = await splitDoc.save();
        splitDoc.dispose();

        final String partLabel = pageIndices.length == 1
            ? 'Hal_${pageIndices.first + 1}'
            : 'Bagian_${i + 1}_Hal_${pageIndices.first + 1}-${pageIndices.last + 1}';

        final String outputPath = await FileHelper.generateOutputPath('${baseName}_$partLabel');
        await File(outputPath).writeAsBytes(savedBytes);
        outputPaths.add(outputPath);
      }

      return outputPaths;
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Kompatibilitas mundur untuk split single-range
  static Future<List<String>> splitPdf(File file, List<int> pageIndices) async {
    return splitPdfToMultipleFiles(file, [pageIndices]);
  }

  /// 3. Putar Halaman PDF (90, 180, 270 derajat)
  static Future<String> rotatePdf(File file, int rotationDegrees) async {
    final Uint8List bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      PdfPageRotateAngle angle;
      switch (rotationDegrees % 360) {
        case 90:
          angle = PdfPageRotateAngle.rotateAngle90;
          break;
        case 180:
          angle = PdfPageRotateAngle.rotateAngle180;
          break;
        case 270:
          angle = PdfPageRotateAngle.rotateAngle270;
          break;
        default:
          angle = PdfPageRotateAngle.rotateAngle0;
      }

      for (int i = 0; i < document.pages.count; i++) {
        document.pages[i].rotation = angle;
      }

      final List<int> savedBytes = await document.save();
      final String outputPath = await FileHelper.generateOutputPath('Rotated');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      document.dispose();
    }
  }

  /// 4. Hapus halaman tertentu dari PDF
  static Future<String> removePages(File file, List<int> pagesToRemove) async {
    final Uint8List bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      // Urutkan dari belakang agar indeks tidak bergeser saat dihapus
      pagesToRemove.sort((a, b) => b.compareTo(a));
      for (int pageIndex in pagesToRemove) {
        if (pageIndex >= 0 && pageIndex < document.pages.count) {
          document.pages.removeAt(pageIndex);
        }
      }

      final List<int> savedBytes = await document.save();
      final String outputPath = await FileHelper.generateOutputPath('RemovedPages');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      document.dispose();
    }
  }

  /// 5. Tambahkan Tanda Air (Watermark Teks)
  static Future<String> addWatermark(
    File file, {
    required String text,
    double opacity = 0.3,
    double fontSize = 40,
    double angle = 45,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, fontSize, style: PdfFontStyle.bold);
      final PdfBrush brush = PdfSolidBrush(PdfColor(128, 128, 128));

      for (int i = 0; i < document.pages.count; i++) {
        final PdfPage page = document.pages[i];
        final Size size = page.size;

        page.graphics.save();
        page.graphics.setTransparency(opacity);
        page.graphics.translateTransform(size.width / 2, size.height / 2);
        page.graphics.rotateTransform(angle);

        final Size textSize = font.measureString(text);
        page.graphics.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
        );
        page.graphics.restore();
      }

      final List<int> savedBytes = await document.save();
      final String outputPath = await FileHelper.generateOutputPath('Watermarked');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      document.dispose();
    }
  }

  /// 6. Tambahkan Nomor Halaman
  static Future<String> addPageNumbers(
    File file, {
    String format = 'Halaman {page} dari {total}',
    bool atBottom = true,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final PdfBrush brush = PdfSolidBrush(PdfColor(80, 80, 80));
      final int total = document.pages.count;

      for (int i = 0; i < total; i++) {
        final PdfPage page = document.pages[i];
        final String text = format
            .replaceAll('{page}', '${i + 1}')
            .replaceAll('{total}', '$total');

        final Size textSize = font.measureString(text);
        final double x = (page.size.width - textSize.width) / 2;
        final double y = atBottom ? (page.size.height - 30) : 20;

        page.graphics.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(x, y, textSize.width, textSize.height),
        );
      }

      final List<int> savedBytes = await document.save();
      final String outputPath = await FileHelper.generateOutputPath('Numbered');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      document.dispose();
    }
  }

  /// 7. Proteksi PDF dengan Kata Sandi
  static Future<String> protectPdf(
    File file, {
    required String password,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      final PdfSecurity security = document.security;
      security.userPassword = password;
      security.ownerPassword = password;
      security.encryptionOptions = PdfEncryptionOptions.encryptAllContents;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      final List<int> savedBytes = await document.save();
      final String outputPath = await FileHelper.generateOutputPath('Protected');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      document.dispose();
    }
  }

  /// 8. Buka Kunci PDF (Unlock password yang diketahui)
  static Future<String> unlockPdf(File file, String password) async {
    final Uint8List bytes = await file.readAsBytes();
    // Buka dengan password yang diberikan
    final PdfDocument document = PdfDocument(inputBytes: bytes, password: password);

    try {
      // Bersihkan keamanan
      document.security.userPassword = '';
      document.security.ownerPassword = '';

      final List<int> savedBytes = await document.save();
      final String outputPath = await FileHelper.generateOutputPath('Unlocked');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      document.dispose();
    }
  }

  /// 9. Ekstrak Teks untuk fitur AI / Markdown
  static Future<String> extractText(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      return text;
    } finally {
      document.dispose();
    }
  }
}
