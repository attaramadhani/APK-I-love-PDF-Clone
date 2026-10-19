import 'package:flutter_test/flutter_test.dart';
import 'package:ilovepdf_mobile/core/services/ai_intelligence_service.dart';
import 'package:ilovepdf_mobile/core/utils/file_helper.dart';
import 'package:ilovepdf_mobile/main.dart';

void main() {
  testWidgets('PDF Studio Pro smoke test and tool listings', (WidgetTester tester) async {
    await tester.pumpWidget(const ILovePdfApp());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify brand title text and primary tools exist
    expect(find.text('Gabungkan PDF'), findsOneWidget);
    expect(find.text('Pisahkan PDF'), findsOneWidget);
  });

  test('FileHelper formatBytes formats byte sizes accurately', () {
    expect(FileHelper.formatBytes(0), '0 B');
    expect(FileHelper.formatBytes(1024), '1.00 KB');
    expect(FileHelper.formatBytes(1048576), '1.00 MB');
    expect(FileHelper.formatBytes(1073741824), '1.00 GB');
  });

  test('AiIntelligenceService generates offline summary and markdown cleanly', () {
    const sampleText = '''
BAB 1: PENDAHULUAN
Dokumen ini membahas tentang implementasi sistem manajemen berkas digital terdistribusi.
Tujuan dari penelitian ini adalah meningkatkan efisiensi dan keamanan berkas.
Sistem ini menggunakan algoritma enkripsi modern dan kompresi tanpa kehilangan data.

Kolom A  Kolom B  Kolom C
Data 1   Data 2   Data 3
Data 4   Data 5   Data 6
''';

    final summary = AiIntelligenceService.summarizeTextLocally(sampleText);
    expect(summary, contains('Ringkasan Dokumen (Mode Offline Pintar)'));
    expect(summary, contains('Total Kata'));

    final markdown = AiIntelligenceService.convertToMarkdownLocally(sampleText);
    expect(markdown, contains('Dokumen Terstruktur (Markdown)'));
    expect(markdown, contains('| Kolom A | Kolom B | Kolom C |'));
  });
}
