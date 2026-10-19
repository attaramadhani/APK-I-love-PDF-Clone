import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/processed_file.dart';

class RecentFilesService {
  static const String _key = 'recent_processed_files';

  static Future<List<ProcessedFile>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    List<ProcessedFile> files = [];

    for (var str in jsonList) {
      try {
        final item = ProcessedFile.fromJson(jsonDecode(str));
        // Only keep files that still exist on device storage
        if (File(item.path).existsSync()) {
          files.add(item);
        }
      } catch (_) {}
    }
    // Sort newest first
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }

  static Future<void> addFile(ProcessedFile file) async {
    final prefs = await SharedPreferences.getInstance();
    List<ProcessedFile> current = await getRecentFiles();
    // Remove if duplicate path exists
    current.removeWhere((item) => item.path == file.path);
    current.insert(0, file);

    final strList = current.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_key, strList);
  }

  static Future<void> removeFile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<ProcessedFile> current = await getRecentFiles();
    current.removeWhere((item) => item.id == id);
    final strList = current.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_key, strList);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
