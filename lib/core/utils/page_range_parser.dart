/// Parser rentang halaman yang dipakai alat Pisahkan & Hapus Halaman.
///
/// Contoh input (nomor halaman dimulai dari 1):
/// * `1-3, 5`       -> [0, 1, 2, 4]
/// * `7-4`          -> [3, 4, 5, 6]   (rentang terbalik otomatis dibalik)
/// * `8-`           -> 8 sampai halaman terakhir
/// * `-3`           -> halaman 1 sampai 3
/// Mendukung tanda hubung biasa (-), en-dash (–) dan em-dash (—).
class PageRangeParser {
  /// Mengurai satu kelompok (dipisah koma) menjadi indeks 0-based unik & terurut.
  static List<int> parseGroup(String input, int maxPages) {
    final Set<int> indices = {};
    final normalized = input.replaceAll(RegExp('[–—]'), '-');
    for (var sub in normalized.split(',')) {
      sub = sub.replaceAll(' ', '');
      if (sub.isEmpty) continue;
      if (sub.contains('-')) {
        final parts = sub.split('-');
        if (parts.length != 2) continue;
        int? start = parts[0].isEmpty ? 1 : int.tryParse(parts[0]);
        int? end = parts[1].isEmpty ? maxPages : int.tryParse(parts[1]);
        if (start == null || end == null) continue;
        if (start > end) {
          final tmp = start;
          start = end;
          end = tmp;
        }
        for (int i = start; i <= end; i++) {
          if (i >= 1 && i <= maxPages) indices.add(i - 1);
        }
      } else {
        final page = int.tryParse(sub);
        if (page != null && page >= 1 && page <= maxPages) indices.add(page - 1);
      }
    }
    return indices.toList()..sort();
  }

  /// Mengurai banyak kelompok yang dipisah titik koma (;). Setiap kelompok = 1 berkas.
  static List<List<int>> parseGroups(String input, int maxPages) {
    return input
        .split(';')
        .map((g) => parseGroup(g, maxPages))
        .where((g) => g.isNotEmpty)
        .toList();
  }
}
