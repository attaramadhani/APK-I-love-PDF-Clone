import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:ilovepdf_mobile/core/services/document_convert_service.dart';
import 'package:ilovepdf_mobile/core/services/pdf_engine_service.dart';
import 'package:ilovepdf_mobile/core/utils/page_range_parser.dart';
import 'package:ilovepdf_mobile/core/utils/text_diff.dart';

void main() {
  group('PageRangeParser', () {
    test('mengurai rentang & halaman tunggal', () {
      expect(PageRangeParser.parseGroup('1-3, 5', 10), [0, 1, 2, 4]);
    });
    test('rentang terbalik, terbuka, dan en-dash', () {
      expect(PageRangeParser.parseGroup('4-2', 10), [1, 2, 3]);
      expect(PageRangeParser.parseGroup('8-', 10), [7, 8, 9]);
      expect(PageRangeParser.parseGroup('-2', 10), [0, 1]);
      expect(PageRangeParser.parseGroup('2–3', 10), [1, 2]);
    });
    test('mengabaikan halaman di luar batas & input sampah', () {
      expect(PageRangeParser.parseGroup('0, 11, abc, 3', 10), [2]);
    });
    test('banyak kelompok dipisah titik koma', () {
      expect(PageRangeParser.parseGroups('1-2; 3; ;99', 5), [
        [0, 1],
        [2],
      ]);
    });
  });

  group('TextDiff', () {
    test('mendeteksi baris tambah & hapus', () {
      final r = TextDiff.compare('a\nb\nc', 'a\nc\nd');
      expect(r.removed, 1);
      expect(r.added, 1);
      expect(r.unchanged, 2);
      expect(r.lines.where((l) => l.type == DiffType.removed).single.text, 'b');
      expect(r.lines.where((l) => l.type == DiffType.added).single.text, 'd');
    });
    test('dokumen identik = 100% mirip', () {
      final r = TextDiff.compare('x  y\nz', 'x y\n\nz');
      expect(r.similarityPercent, 100);
    });
  });

  group('DocumentConvertService.parseCsv', () {
    test('kutip, koma di dalam kutip, dan pemisah titik koma', () {
      expect(DocumentConvertService.parseCsv('a,"b,c",d\n1,2,3\n'), [
        ['a', 'b,c', 'd'],
        ['1', '2', '3'],
      ]);
      expect(DocumentConvertService.parseCsv('x;y\r\n"he said ""hi""";2'), [
        ['x', 'y'],
        ['he said "hi"', '2'],
      ]);
    });
  });

  test('PdfEngineService.friendlyError menerjemahkan galat umum', () {
    expect(PdfEngineService.friendlyError(Exception('Invalid password')), contains('kata sandi'));
    expect(PdfEngineService.friendlyError(const PdfOpenException('Pesan khusus')), 'Pesan khusus');
  });

  group('PdfEngineService (perilaku Syncfusion)', () {
    PdfDocument reload(PdfDocument doc, {String? password}) {
      final bytes = doc.saveSync();
      doc.dispose();
      return password == null
          ? PdfDocument(inputBytes: bytes)
          : PdfDocument(inputBytes: bytes, password: password);
    }

    test('halaman landscape tetap landscape setelah disalin', () {
      final out = PdfDocument();
      PdfEngineService.addPage(out, const Size(842, 595));
      final loaded = reload(out);
      expect(loaded.pages[0].size.width, closeTo(842, 0.5));
      expect(loaded.pages[0].size.height, closeTo(595, 0.5));
      loaded.dispose();
    });

    test('rotasi asli + rotasi tambahan diterapkan pada halaman baru', () {
      final src = PdfDocument();
      src.pageSettings.rotate = PdfPageRotateAngle.rotateAngle90;
      src.pages.add();
      final source = reload(src);
      expect(source.pages[0].rotation, PdfPageRotateAngle.rotateAngle90);

      final out = PdfDocument();
      PdfEngineService.copyPage(out, source.pages[0], extraRotation: 90);
      final result = reload(out);
      expect(result.pages[0].rotation, PdfPageRotateAngle.rotateAngle180);
      result.dispose();
      source.dispose();
    });

    test('buka kunci benar-benar menghapus enkripsi', () {
      final doc = PdfDocument();
      doc.pages.add();
      doc.security.userPassword = 'rahasia';
      doc.security.ownerPassword = 'rahasia';
      final locked = reload(doc, password: 'rahasia');
      PdfEngineService.removeSecurity(locked);
      final bytes = locked.saveSync();
      locked.dispose();
      // Harus bisa dibuka TANPA kata sandi
      final unlocked = PdfDocument(inputBytes: bytes);
      expect(unlocked.pages.count, 1);
      unlocked.dispose();
      expect(String.fromCharCodes(bytes).contains('/Encrypt'), isFalse);
    });
  });
}
