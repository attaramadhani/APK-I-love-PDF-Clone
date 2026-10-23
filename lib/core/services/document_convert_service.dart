import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import '../utils/file_helper.dart';
import 'pdf_engine_service.dart';

/// Konversi dokumen kantor (DOCX, XLSX, CSV, TXT) menjadi PDF secara offline.
///
/// * DOCX: paragraf & tabel dibaca dari `word/document.xml` di dalam arsip ZIP.
/// * XLSX: sheet pertama dibaca dari `xl/worksheets/*.xml` + `sharedStrings.xml`
///   lalu digambar sebagai tabel (PdfGrid) yang otomatis berlanjut ke halaman baru.
/// * CSV/TXT: dibaca sebagai teks UTF-8.
class DocumentConvertService {
  static const supportedExtensions = ['docx', 'xlsx', 'csv', 'txt'];

  static Future<String> convertToPdf(File file) async {
    final ext = p.extension(file.path).toLowerCase().replaceFirst('.', '');
    if (ext == 'doc' || ext == 'xls') {
      throw const PdfOpenException(
        'Format lama .doc/.xls belum didukung. Buka berkas di Word/Excel/WPS lalu '
        'simpan ulang sebagai .docx/.xlsx, kemudian coba lagi.',
      );
    }
    if (!supportedExtensions.contains(ext)) {
      throw const PdfOpenException('Format berkas tidak didukung untuk dikonversi ke PDF.');
    }
    var title = p.basenameWithoutExtension(file.path);
    final safeBase = title.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final outputPath = await FileHelper.generateOutputPath(
      '${safeBase.length > 20 ? safeBase.substring(0, 20) : safeBase}_Converted',
    );
    final path = file.path;
    await Isolate.run(() => _convertSync(path, ext, title, outputPath));
    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static Archive _unzip(List<int> bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const PdfOpenException('Berkas rusak atau bukan dokumen Office yang valid.');
    }
  }

  static String _readEntry(Archive archive, String name) {
    final entry = archive.findFile(name);
    if (entry == null) return '';
    return utf8.decode(entry.content, allowMalformed: true);
  }

  /// Mengembalikan blok-blok DOCX: String = paragraf, List<List<String>> = tabel.
  static List<Object> _parseDocx(List<int> bytes) {
    final archive = _unzip(bytes);
    final xmlText = _readEntry(archive, 'word/document.xml');
    if (xmlText.isEmpty) {
      throw const PdfOpenException('Isi dokumen Word tidak ditemukan.');
    }
    final doc = XmlDocument.parse(xmlText);
    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return const [];

    String paragraphText(XmlElement para) {
      final sb = StringBuffer();
      for (final node in para.descendants.whereType<XmlElement>()) {
        switch (node.name.qualified) {
          case 'w:t':
            sb.write(node.innerText);
            break;
          case 'w:tab':
            sb.write('    ');
            break;
          case 'w:br':
          case 'w:cr':
            sb.write('\n');
            break;
        }
      }
      return sb.toString();
    }

    final blocks = <Object>[];
    for (final child in body.childElements) {
      final name = child.name.qualified;
      if (name == 'w:p') {
        blocks.add(paragraphText(child));
      } else if (name == 'w:tbl') {
        final rows = <List<String>>[];
        for (final tr in child.findAllElements('w:tr')) {
          rows.add(tr
              .findElements('w:tc')
              .map((tc) => tc.findAllElements('w:p').map(paragraphText).join('\n').trim())
              .toList());
        }
        if (rows.isNotEmpty) blocks.add(rows);
      }
    }
    return blocks;
  }

  static int _columnIndex(String cellRef) {
    var col = 0;
    for (final code in cellRef.codeUnits) {
      if (code >= 65 && code <= 90) {
        col = col * 26 + (code - 64);
      } else if (code >= 97 && code <= 122) {
        col = col * 26 + (code - 96);
      } else {
        break;
      }
    }
    return col - 1;
  }

  static List<List<String>> _parseXlsx(List<int> bytes) {
    final archive = _unzip(bytes);

    final shared = <String>[];
    final sharedXml = _readEntry(archive, 'xl/sharedStrings.xml');
    if (sharedXml.isNotEmpty) {
      for (final si in XmlDocument.parse(sharedXml).findAllElements('si')) {
        shared.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    }

    String sheetName = 'xl/worksheets/sheet1.xml';
    if (archive.findFile(sheetName) == null) {
      final candidates = archive.files
          .map((f) => f.name)
          .where((n) => n.startsWith('xl/worksheets/') && n.endsWith('.xml'))
          .toList()
        ..sort();
      if (candidates.isEmpty) {
        throw const PdfOpenException('Lembar kerja Excel tidak ditemukan.');
      }
      sheetName = candidates.first;
    }

    final sheet = XmlDocument.parse(_readEntry(archive, sheetName));
    final rows = <List<String>>[];
    for (final row in sheet.findAllElements('row')) {
      final cells = <int, String>{};
      var nextCol = 0;
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r');
        final col = ref != null ? _columnIndex(ref) : nextCol;
        nextCol = col + 1;
        final type = c.getAttribute('t');
        String value;
        if (type == 'inlineStr') {
          value = c.findAllElements('t').map((t) => t.innerText).join();
        } else {
          final v = c.findElements('v').firstOrNull?.innerText ?? '';
          if (type == 's') {
            final idx = int.tryParse(v);
            value = (idx != null && idx < shared.length) ? shared[idx] : v;
          } else if (type == 'b') {
            value = v == '1' ? 'TRUE' : 'FALSE';
          } else {
            value = v;
          }
        }
        if (col >= 0) cells[col] = value;
      }
      if (cells.isEmpty) continue;
      final maxCol = cells.keys.reduce((a, b) => a > b ? a : b);
      rows.add(List<String>.generate(maxCol + 1, (i) => cells[i] ?? ''));
    }
    return rows;
  }

  /// Parser CSV sederhana yang mendukung tanda kutip dan pemisah , atau ;
  static List<List<String>> parseCsv(String text) {
    final firstLine = text.split('\n').first;
    final sep = ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length ? ';' : ',';
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == sep) {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    }
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Render PDF
  // ---------------------------------------------------------------------------

  static Future<void> _convertSync(String path, String ext, String title, String outputPath) async {
    final bytes = File(path).readAsBytesSync();
    final List<Object> blocks;
    switch (ext) {
      case 'docx':
        blocks = _parseDocx(bytes);
        break;
      case 'xlsx':
        blocks = [_parseXlsx(bytes)];
        break;
      case 'csv':
        blocks = [parseCsv(utf8.decode(bytes, allowMalformed: true))];
        break;
      default:
        blocks = utf8.decode(bytes, allowMalformed: true).split(RegExp(r'\r?\n'));
    }

    final hasContent = blocks.any((b) =>
        (b is String && b.trim().isNotEmpty) || (b is List && b.isNotEmpty));
    if (!hasContent) {
      throw const PdfOpenException('Dokumen kosong, tidak ada isi yang bisa dikonversi.');
    }

    final doc = PdfDocument();
    try {
      doc.pageSettings.margins.all = 40;
      final fontTitle = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
      final fontBody = PdfStandardFont(PdfFontFamily.helvetica, 11);
      final fontCell = PdfStandardFont(PdfFontFamily.helvetica, 9);
      final fontHeader = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
      final format = PdfLayoutFormat(layoutType: PdfLayoutType.paginate);

      PdfPage page = doc.pages.add();
      final width = page.getClientSize().width;

      page.graphics.drawString(
        title,
        fontTitle,
        brush: PdfSolidBrush(PdfColor(37, 99, 235)),
        bounds: Rect.fromLTWH(0, 0, width, 24),
      );
      page.graphics.drawLine(
        PdfPen(PdfColor(226, 232, 240), width: 1),
        const Offset(0, 28),
        Offset(width, 28),
      );
      double y = 38;

      // Gabungkan paragraf berturut-turut menjadi satu elemen teks agar
      // pagination ditangani otomatis oleh Syncfusion.
      final paragraphBuffer = StringBuffer();

      void flushParagraphs() {
        final text = paragraphBuffer.toString().trimRight();
        paragraphBuffer.clear();
        if (text.isEmpty) return;
        final result = PdfTextElement(text: text, font: fontBody).draw(
          page: page,
          bounds: Rect.fromLTWH(0, y, width, 0),
          format: format,
        );
        if (result != null) {
          page = result.page;
          y = result.bounds.bottom + 10;
        }
      }

      for (final block in blocks) {
        if (block is String) {
          paragraphBuffer.writeln(block);
        } else if (block is List<List<String>>) {
          flushParagraphs();
          if (block.isEmpty) continue;
          final cols = block.map((r) => r.length).reduce((a, b) => a > b ? a : b);
          if (cols == 0) continue;
          final grid = PdfGrid();
          grid.columns.add(count: cols);
          grid.style = PdfGridStyle(
            font: fontCell,
            cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
          );
          grid.headers.add(1);
          final header = grid.headers[0];
          for (int c = 0; c < cols; c++) {
            header.cells[c].value = c < block.first.length ? block.first[c] : '';
          }
          header.style = PdfGridRowStyle(
            backgroundBrush: PdfSolidBrush(PdfColor(239, 246, 255)),
            font: fontHeader,
          );
          for (final r in block.skip(1)) {
            final row = grid.rows.add();
            for (int c = 0; c < cols; c++) {
              row.cells[c].value = c < r.length ? r[c] : '';
            }
          }
          final result = grid.draw(
            page: page,
            bounds: Rect.fromLTWH(0, y, width, 0),
            format: format,
          );
          if (result != null) {
            page = result.page;
            y = result.bounds.bottom + 14;
          }
        }
      }
      flushParagraphs();

      final List<int> saved = await doc.save();
      File(outputPath).writeAsBytesSync(saved);
    } finally {
      doc.dispose();
    }
  }
}
