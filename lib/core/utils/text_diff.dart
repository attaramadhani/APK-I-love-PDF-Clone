import 'dart:isolate';

/// Jenis baris pada hasil perbandingan.
enum DiffType { same, added, removed }

class DiffLine {
  final DiffType type;
  final String text;
  const DiffLine(this.type, this.text);
}

class DiffResult {
  final List<DiffLine> lines;
  final int added;
  final int removed;
  final int unchanged;
  final bool truncated;

  const DiffResult(this.lines, this.added, this.removed, this.unchanged, this.truncated);

  /// Persentase kemiripan (0–100) berdasarkan baris yang sama.
  int get similarityPercent {
    final total = unchanged * 2 + added + removed;
    if (total == 0) return 100;
    return ((unchanged * 2) * 100 / total).round();
  }
}

/// Perbandingan teks baris-per-baris berbasis Longest Common Subsequence.
/// Murni Dart, tanpa dependensi — mudah diuji dengan unit test.
class TextDiff {
  /// Batas baris per dokumen agar memori tetap aman di HP (LCS = O(n*m)).
  static const int maxLines = 1500;

  static List<String> _normalize(String text) => text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
      .where((l) => l.isNotEmpty)
      .toList();

  /// Menjalankan [compare] di background isolate.
  static Future<DiffResult> compareInBackground(String textA, String textB) =>
      Isolate.run(() => compare(textA, textB));

  static DiffResult compare(String textA, String textB) {
    var a = _normalize(textA);
    var b = _normalize(textB);
    final truncated = a.length > maxLines || b.length > maxLines;
    if (a.length > maxLines) a = a.sublist(0, maxLines);
    if (b.length > maxLines) b = b.sublist(0, maxLines);

    final n = a.length, m = b.length;
    final width = m + 1;
    // Tabel LCS satu dimensi (n+1)*(m+1)
    final table = List<int>.filled((n + 1) * width, 0);
    for (int i = n - 1; i >= 0; i--) {
      for (int j = m - 1; j >= 0; j--) {
        table[i * width + j] = a[i] == b[j]
            ? table[(i + 1) * width + j + 1] + 1
            : (table[(i + 1) * width + j] >= table[i * width + j + 1]
                ? table[(i + 1) * width + j]
                : table[i * width + j + 1]);
      }
    }

    final lines = <DiffLine>[];
    int i = 0, j = 0, added = 0, removed = 0, same = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        lines.add(DiffLine(DiffType.same, a[i]));
        same++;
        i++;
        j++;
      } else if (table[(i + 1) * width + j] >= table[i * width + j + 1]) {
        lines.add(DiffLine(DiffType.removed, a[i]));
        removed++;
        i++;
      } else {
        lines.add(DiffLine(DiffType.added, b[j]));
        added++;
        j++;
      }
    }
    while (i < n) {
      lines.add(DiffLine(DiffType.removed, a[i++]));
      removed++;
    }
    while (j < m) {
      lines.add(DiffLine(DiffType.added, b[j++]));
      added++;
    }
    return DiffResult(lines, added, removed, same, truncated);
  }
}
