import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/file_helper.dart';

class ImagePdfService {
  /// Mengonversi satu atau banyak gambar (JPG, PNG, WEBP) menjadi dokumen PDF
  static Future<String> imagesToPdf(
    List<File> imageFiles, {
    bool fitToPage = true,
    double margin = 20.0,
  }) async {
    final PdfDocument document = PdfDocument();

    try {
      // Set margin halaman
      document.pageSettings.margins.all = margin;

      for (final imageFile in imageFiles) {
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final PdfBitmap bitmap = PdfBitmap(imageBytes);

        final bool isLandscape = bitmap.width > bitmap.height;
        final PdfSection section = document.sections!.add();
        section.pageSettings.orientation =
            isLandscape ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;
        section.pageSettings.margins.all = margin;

        final PdfPage page = section.pages.add();
        final Size pageSize = page.getClientSize();

        // Kanvas putih solid murni
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
          bounds: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );

        if (fitToPage) {
          // Skalakan dengan mempertahankan aspek rasio
          double drawWidth = pageSize.width;
          double drawHeight = (bitmap.height / bitmap.width) * drawWidth;

          if (drawHeight > pageSize.height) {
            drawHeight = pageSize.height;
            drawWidth = (bitmap.width / bitmap.height) * drawHeight;
          }

          final double dx = (pageSize.width - drawWidth) / 2;
          final double dy = (pageSize.height - drawHeight) / 2;

          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(dx, dy, drawWidth, drawHeight),
          );
        } else {
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
          );
        }
      }

      final List<int> savedBytes = await document.save();
      final String outputPath = await FileHelper.generateOutputPath('Images_Converted');
      await File(outputPath).writeAsBytes(savedBytes);
      return outputPath;
    } finally {
      document.dispose();
    }
  }
}
