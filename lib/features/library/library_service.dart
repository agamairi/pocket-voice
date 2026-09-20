import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/narration_item.dart';

class LibraryService {
  static const String _libraryPrefsKey = 'saved_narrations_v1';

  /// Returns the app-managed Narrations directory.
  Future<Directory> getNarrationsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/Narrations');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all saved narration items, pruning any whose files have been deleted from disk.
  Future<List<NarrationItem>> getSavedNarrations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_libraryPrefsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final items = <NarrationItem>[];
      for (final item in list) {
        final narration = NarrationItem.fromJson(item as Map<String, dynamic>);
        if (await File(narration.filePath).exists()) {
          items.add(narration);
        }
      }
      // Sort newest first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  /// Adds a newly generated narration to the library.
  Future<void> addNarration(NarrationItem item) async {
    final items = await getSavedNarrations();
    items.insert(0, item);
    await _saveNarrations(items);
  }

  /// Renames a narration file and updates its metadata.
  Future<NarrationItem> renameNarration(String id, String newFileName) async {
    final items = await getSavedNarrations();
    final index = items.indexWhere((i) => i.id == id);
    if (index == -1) {
      throw Exception('Narration not found');
    }

    final oldItem = items[index];
    final oldFile = File(oldItem.filePath);
    final narrationsDir = await getNarrationsDirectory();
    final newPath = '${narrationsDir.path}/$newFileName';

    if (await oldFile.exists()) {
      await oldFile.rename(newPath);
    }

    final newItem = oldItem.copyWith(
      title: newFileName,
      filePath: newPath,
    );
    items[index] = newItem;
    await _saveNarrations(items);
    return newItem;
  }

  /// Deletes a narration file and its metadata.
  Future<void> deleteNarration(String id) async {
    final items = await getSavedNarrations();
    final index = items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = items[index];
      try {
        final file = File(item.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      items.removeAt(index);
      await _saveNarrations(items);
    }
  }

  Future<void> _saveNarrations(List<NarrationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = items.map((i) => i.toJson()).toList();
    await prefs.setString(_libraryPrefsKey, jsonEncode(jsonList));
  }
}
