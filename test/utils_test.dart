import 'package:flutter_test/flutter_test.dart';
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
}
