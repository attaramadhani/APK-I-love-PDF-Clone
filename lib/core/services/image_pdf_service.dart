import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/file_helper.dart';
import 'pdf_engine_service.dart';

class ImagePdfService {
  /// Sisi terpanjang maksimum gambar (px). ~2000px cukup tajam untuk A4 @ 200 DPI.
  static const int maxImageSide = 2200;

  /// Mengonversi satu atau banyak gambar (JPG, PNG, WEBP, HEIC yang didukung decoder)
  /// menjadi dokumen PDF. Orientasi EXIF dari kamera diterapkan sehingga foto
  /// tidak lagi tampil miring, dan gambar diperkecil agar PDF tidak membengkak.
  static Future<String> imagesToPdf(
    List<File> imageFiles, {
    bool fitToPage = true,
    double margin = 20.0,
  }) async {
    if (imageFiles.isEmpty) {
      throw const PdfOpenException('Pilih minimal 1 gambar.');
    }
    final paths = imageFiles.map((f) => f.path).toList();
    final outputPath = await FileHelper.generateOutputPath('Images_Converted');
    await Isolate.run(() => _buildSync(paths, fitToPage, margin, outputPath));
    return outputPath;
  }

  /// Menormalkan gambar: terapkan orientasi EXIF, perkecil, dan ubah ke JPEG.
  /// Mengembalikan null bila format tidak dikenali (akan dicoba langsung).
  static ({Uint8List bytes, int width, int height})? _normalize(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    var image = img.bakeOrientation(decoded);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxImageSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxImageSide)
          : img.copyResize(image, height: maxImageSide);
    }
    // Ratakan transparansi (PNG) di atas latar putih agar tidak menjadi hitam.
    if (image.hasAlpha) {
      final bg = img.Image(width: image.width, height: image.height);
      img.fill(bg, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(bg, image);
      image = bg;
    }
    return (bytes: img.encodeJpg(image, quality: 88), width: image.width, height: image.height);
  }

  static Future<void> _buildSync(
    List<String> paths,
    bool fitToPage,
    double margin,
    String outputPath,
  ) async {
    final PdfDocument document = PdfDocument();
    try {
      document.pageSettings.margins.all = margin;
      int added = 0;

      for (final path in paths) {
        final Uint8List raw = File(path).readAsBytesSync();
        final normalized = _normalize(raw);
        PdfBitmap? bitmap;
        try {
          bitmap = PdfBitmap(normalized?.bytes ?? raw);
        } catch (_) {
          bitmap = null;
        }
        if (bitmap == null) continue; // format tidak didukung, lewati gambar ini
        final int bw = normalized?.width ?? bitmap.width;
        final int bh = normalized?.height ?? bitmap.height;

        final bool isLandscape = bw > bh;
        final PdfSection section = document.sections!.add();
        section.pageSettings.orientation =
            isLandscape ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;
        section.pageSettings.margins.all = margin;

        final PdfPage page = section.pages.add();
        final Size pageSize = page.getClientSize();

        if (fitToPage) {
          double drawWidth = pageSize.width;
          double drawHeight = (bh / bw) * drawWidth;
          if (drawHeight > pageSize.height) {
            drawHeight = pageSize.height;
            drawWidth = (bw / bh) * drawHeight;
          }
          final double dx = (pageSize.width - drawWidth) / 2;
          final double dy = (pageSize.height - drawHeight) / 2;
          page.graphics.drawImage(bitmap, Rect.fromLTWH(dx, dy, drawWidth, drawHeight));
        } else {
          page.graphics.drawImage(bitmap, Rect.fromLTWH(0, 0, pageSize.width, pageSize.height));
        }
        added++;
      }

      if (added == 0) {
        throw const PdfOpenException('Tidak ada gambar yang bisa dibaca. Gunakan format JPG atau PNG.');
      }

      final List<int> savedBytes = await document.save();
      File(outputPath).writeAsBytesSync(savedBytes);
    } finally {
      document.dispose();
    }
  }
}
