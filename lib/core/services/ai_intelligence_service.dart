import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiIntelligenceService {
  static const String _apiKeyPref = 'gemini_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, apiKey.trim());
  }

  /// Panggilan ke Gemini API (Mencoba model Flash terkini dengan fallback)
  static Future<String> generateAiResponse(String prompt) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Kunci API Gemini belum diatur. Masukkan Google Gemini API Key di Pengaturan, atau gunakan Mode Offline (Lokal).',
      );
    }

    final models = ['gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-2.5-flash'];
    String lastError = '';

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null && text.toString().trim().isNotEmpty) {
            return text.toString().trim();
          }
        } else {
          lastError = '(${response.statusCode}) ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw Exception('Gagal menghubungi Google Gemini AI: $lastError');
  }

  /// Ringkasan AI (Online via Gemini)
  static Future<String> summarizeText(String pdfText) async {
    final prompt = '''
Anda adalah asisten AI dari PDF Studio Pro. Tolong buatkan ringkasan yang sangat jelas, terstruktur, dan komprehensif dari teks dokumen berikut dalam Bahasa Indonesia. 
Sajikan dengan format:
1. Ringkasan Eksekutif (1-2 paragraf)
2. Poin-Poin Kunci (Bullet points terstruktur)
3. Kesimpulan Akhir

Teks Dokumen:
$pdfText
''';
    return await generateAiResponse(prompt);
  }

  /// Terjemahkan Dokumen (Online via Gemini)
  static Future<String> translateText(String pdfText, String targetLanguage) async {
    final prompt = '''
Terjemahkan teks dokumen berikut secara akurat ke bahasa: $targetLanguage.
Pertahankan struktur judul, paragraf, daftar isi, dan istilah teknis dengan tepat.

Teks Dokumen:
$pdfText
''';
    return await generateAiResponse(prompt);
  }

  /// Ubah PDF ke Markdown Terstruktur (Online via Gemini)
  static Future<String> convertToMarkdown(String pdfText) async {
    final prompt = '''
Konversikan teks dokumen mentah berikut menjadi dokumen format Markdown (.md) yang rapi dan terstruktur dengan heading (#, ##, ###), tabel jika ada, dan formatting yang bersih.

Teks Dokumen:
$pdfText
''';
    return await generateAiResponse(prompt);
  }

  /// Ringkasan Cerdas Offline (Tanpa API Key / Internet)
  static String summarizeTextLocally(String pdfText) {
    final lines = pdfText.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return 'Dokumen tidak memiliki teks yang cukup untuk diringkas.';

    final words = pdfText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final totalWords = words.length;
    final totalChars = pdfText.length;
    final paragraphs = lines.where((l) => l.length > 40).toList();

    final buffer = StringBuffer();
    buffer.writeln('# 📄 Ringkasan Dokumen (Mode Offline Pintar)\n');
    buffer.writeln('> 💡 *Dihasilkan secara lokal di perangkat tanpa koneksi internet. Tambahkan Google Gemini API Key di Pengaturan untuk ringkasan generatif AI mendalam.*\n');
    buffer.writeln('### 📊 Statistik Dokumen');
    buffer.writeln('- **Total Kata:** $totalWords kata');
    buffer.writeln('- **Total Karakter:** $totalChars karakter');
    buffer.writeln('- **Jumlah Paragraf Utama:** ${paragraphs.length} paragraf\n');

    buffer.writeln('### 📌 Ringkasan Eksekutif');
    if (paragraphs.isNotEmpty) {
      buffer.writeln(paragraphs.take(2).join('\n\n'));
    } else {
      buffer.writeln(lines.take(3).join('\n\n'));
    }

    buffer.writeln('\n\n### 🎯 Poin-Poin Kunci');
    final keyPoints = lines.where((l) => l.length > 30 && l.length < 150).take(6).toList();
    if (keyPoints.isNotEmpty) {
      for (final pt in keyPoints) {
        buffer.writeln('- $pt');
      }
    } else {
      for (int i = 0; i < lines.length && i < 5; i++) {
        buffer.writeln('- ${lines[i]}');
      }
    }

    buffer.writeln('\n### 📝 Kesimpulan');
    if (paragraphs.length > 2) {
      buffer.writeln(paragraphs.last);
    } else {
      buffer.writeln('Dokumen telah berhasil dianalisis dan dirangkum secara lokal.');
    }

    return buffer.toString();
  }

  /// Ubah PDF ke Markdown Secara Lokal (Tanpa API Key / Internet)
  static String convertToMarkdownLocally(String pdfText) {
    final lines = pdfText.split(RegExp(r'\r?\n'));
    final buffer = StringBuffer();
    buffer.writeln('# Dokumen Terstruktur (Markdown)\n');
    buffer.writeln('> 💡 *Dikonversi ke format Markdown (.md) terstruktur secara lokal di perangkat.*\n');

    bool inTable = false;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (inTable) inTable = false;
        buffer.writeln();
        continue;
      }

      // Deteksi baris tabel (terdapat tab atau 2+ spasi pemisah kolom)
      final parts = trimmed.split(RegExp(r'\s{2,}|\t'));
      if (parts.length >= 2) {
        if (!inTable) {
          buffer.writeln('| ${parts.map((p) => p.trim()).join(' | ')} |');
          buffer.writeln('| ${parts.map((_) => '---').join(' | ')} |');
          inTable = true;
        } else {
          buffer.writeln('| ${parts.map((p) => p.trim()).join(' | ')} |');
        }
      } else {
        inTable = false;
        if (trimmed.length < 45 && !trimmed.endsWith('.')) {
          buffer.writeln('\n## $trimmed\n');
        } else if (trimmed.startsWith('-') || trimmed.startsWith('•') || trimmed.startsWith('*')) {
          buffer.writeln('* ${trimmed.substring(1).trim()}');
        } else {
          buffer.writeln('$trimmed\n');
        }
      }
    }
    return buffer.toString();
  }
}
