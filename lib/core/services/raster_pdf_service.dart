import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import '../utils/file_helper.dart';
import 'pdf_engine_service.dart';

/// Kotak area (satuan point PDF, origin kiri-atas halaman) yang akan disensor.
typedef RedactionBuilder = List<Rect> Function(int pageIndex, Size pageSize);

/// Layanan yang merender halaman PDF menjadi gambar lalu menyusunnya kembali.
///
/// Dipakai untuk:
/// * Kompresi kuat (menurunkan resolusi + kualitas JPEG).
/// * Redaksi PERMANEN: area hitam dibakar ke dalam gambar sehingga teks di
///   bawahnya benar-benar hilang (tidak bisa disalin/diekstrak lagi).
/// * OCR: menghasilkan gambar halaman untuk dibaca ML Kit.
class RasterPdfService {
  /// Mengubah piksel RGBA hasil render menjadi JPEG berlatar putih.
  static Uint8List _encodeJpeg(
    Uint8List rgba,
    int width,
    int height,
    int quality,
    List<List<int>> blackBoxes,
  ) {
    final src = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
    );
    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, src);
    for (final b in blackBoxes) {
      img.fillRect(
        canvas,
        x1: b[0],
        y1: b[1],
        x2: b[2],
        y2: b[3],
        color: img.ColorRgb8(0, 0, 0),
      );
    }
    return img.encodeJpg(canvas, quality: quality);
  }

  static Future<Uint8List> _encodeInBackground(
    Uint8List rgba,
    int width,
    int height,
    int quality,
    List<List<int>> boxes,
  ) =>
      Isolate.run(() => _encodeJpeg(rgba, width, height, quality, boxes));

  /// Merender ulang seluruh halaman menjadi JPEG dan menyimpannya sebagai PDF baru.
  ///
  /// [onProgress] dipanggil dengan (halamanSelesai, totalHalaman).
  static Future<String> rasterizePdf(
    File file, {
    required String prefix,
    double dpi = 150,
    int jpegQuality = 75,
    RedactionBuilder? redactions,
    void Function(int done, int total)? onProgress,
  }) async {
    final Uint8List pdfBytes = await file.readAsBytes();
    final List<Size> pageSizes = await PdfEngineService.getPageSizes(file);
    final int total = pageSizes.length;
    final List<Uint8List> jpegs = [];
    final List<Size> outSizes = [];

    int index = 0;
    await for (final raster in Printing.raster(pdfBytes, dpi: dpi)) {
      final int w = raster.width;
      final int h = raster.height;
      // Ukuran halaman (pt) dihitung dari ukuran render agar orientasi/rotasi
      // halaman selalu sesuai dengan yang terlihat.
      final Size pageSize = Size(w * 72.0 / dpi, h * 72.0 / dpi);
      final double scale = dpi / 72.0;

      final List<List<int>> boxes = [];
      if (redactions != null) {
        for (final r in redactions(index, pageSize)) {
          boxes.add([
            (r.left * scale).floor().clamp(0, w - 1),
            (r.top * scale).floor().clamp(0, h - 1),
            (r.right * scale).ceil().clamp(0, w - 1),
            (r.bottom * scale).ceil().clamp(0, h - 1),
          ]);
        }
      }

      final Uint8List pixels = Uint8List.fromList(raster.pixels);
      final int q = jpegQuality;
      final Uint8List jpeg = await _encodeInBackground(pixels, w, h, q, boxes);
      jpegs.add(jpeg);
      outSizes.add(pageSize);

      index++;
      onProgress?.call(index, total);
    }

    if (jpegs.isEmpty) {
      throw const PdfOpenException('Gagal merender halaman PDF.');
    }

    final outputPath = await FileHelper.generateOutputPath(prefix);
    await PdfEngineService.buildPdfFromJpegPages(jpegs, outSizes, outputPath);
    return outputPath;
  }

  /// Merender setiap halaman ke berkas PNG sementara (untuk OCR).
  /// Mengembalikan daftar path gambar sesuai urutan halaman.
  static Stream<String> renderPagesToTempPng(File file, {double dpi = 200}) async* {
    final Uint8List pdfBytes = await file.readAsBytes();
    final tempDir = await Directory.systemTemp.createTemp('ocr_');
    int index = 0;
    await for (final raster in Printing.raster(pdfBytes, dpi: dpi)) {
      final pixels = Uint8List.fromList(raster.pixels);
      final w = raster.width;
      final h = raster.height;
      final Uint8List jpeg = await _encodeInBackground(pixels, w, h, 92, const []);
      final path = '${tempDir.path}/page_${index + 1}.jpg';
      await File(path).writeAsBytes(jpeg);
      index++;
      yield path;
    }
  }
}
