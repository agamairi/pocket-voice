import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/voice_profile.dart';
import 'model_manager.dart';

class VoiceManager {
  static const String _customVoicesKey = 'custom_voice_profiles_v1';
  static const String _defaultVoiceIdKey = 'default_voice_id_v1';

  final ModelManager modelManager;

  VoiceManager({required this.modelManager});

  /// Returns bundled voices from the downloaded model directory.
  Future<List<VoiceProfile>> getBundledVoices() async {
    final modelDir = await modelManager.getModelDirectory();
    final briaPath = '${modelDir.path}/test_wavs/bria.wav';
    final loonaPath = '${modelDir.path}/test_wavs/loona.wav';

    final voices = <VoiceProfile>[];

    if (await File(briaPath).exists()) {
      voices.add(VoiceProfile(
        id: 'bria',
        name: 'Bria',
        referenceAudioPath: briaPath,
        optionalDescription: 'Clear, balanced narration voice',
        optionalLicenseInfo: 'Creative Commons (Official PocketTTS model sample)',
        isCustom: false,
      ));
    }

    if (await File(loonaPath).exists()) {
      voices.add(VoiceProfile(
        id: 'loona',
        name: 'Loona',
        referenceAudioPath: loonaPath,
        optionalDescription: 'Expressive narration voice',
        optionalLicenseInfo: 'Creative Commons (Official PocketTTS model sample)',
        isCustom: false,
      ));
    }

    return voices;
  }

  /// Returns all custom voices imported by the user.
  Future<List<VoiceProfile>> getCustomVoices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_customVoicesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final voices = <VoiceProfile>[];
      for (final item in list) {
        final profile = VoiceProfile.fromJson(item as Map<String, dynamic>);
        // Ensure the audio file still exists on disk
        if (await File(profile.referenceAudioPath).exists()) {
          voices.add(profile);
        }
      }
      return voices;
    } catch (_) {
      return [];
    }
  }

  /// Returns all voices (bundled + custom).
  Future<List<VoiceProfile>> getAllVoices() async {
    final bundled = await getBundledVoices();
    final custom = await getCustomVoices();
    return [...bundled, ...custom];
  }

  /// Imports a user-selected WAV file as a custom voice profile.
  Future<VoiceProfile> importCustomVoice({
    required String sourceFilePath,
    required String name,
    String? description,
  }) async {
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw Exception('Selected audio file does not exist: $sourceFilePath');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final customVoicesDir = Directory('${docsDir.path}/voices');
    await customVoicesDir.create(recursive: true);

    final id = 'custom_${const Uuid().v4().substring(0, 8)}';
    final targetPath = '${customVoicesDir.path}/$id.wav';

    // Copy to app-private storage
    await sourceFile.copy(targetPath);

    final profile = VoiceProfile(
      id: id,
      name: name.trim().isEmpty ? 'Custom Voice' : name.trim(),
      referenceAudioPath: targetPath,
      optionalDescription: description?.trim().isEmpty == true ? null : description?.trim(),
      optionalLicenseInfo: 'User-provided on-device audio sample',
      isCustom: true,
    );

    final existing = await getCustomVoices();
    existing.add(profile);
    await _saveCustomVoices(existing);

    return profile;
  }

  /// Renames an existing custom voice.
  Future<void> renameCustomVoice(String id, String newName) async {
    final voices = await getCustomVoices();
    final index = voices.indexWhere((v) => v.id == id);
    if (index != -1) {
      voices[index] = voices[index].copyWith(name: newName.trim());
      await _saveCustomVoices(voices);
    }
  }

  /// Deletes a custom voice profile and its audio file from device storage.
  Future<void> deleteCustomVoice(String id) async {
    final voices = await getCustomVoices();
    final index = voices.indexWhere((v) => v.id == id);
    if (index != -1) {
      final profile = voices[index];
      try {
        final file = File(profile.referenceAudioPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      voices.removeAt(index);
      await _saveCustomVoices(voices);

      // If default voice was deleted, reset default
      final defaultId = await getDefaultVoiceId();
      if (defaultId == id) {
        await setDefaultVoiceId('bria');
      }
    }
  }

  /// Gets the ID of the user's default voice.
  Future<String> getDefaultVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultVoiceIdKey) ?? 'bria';
  }

  /// Sets the default voice ID.
  Future<void> setDefaultVoiceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultVoiceIdKey, id);
  }

  Future<void> _saveCustomVoices(List<VoiceProfile> voices) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = voices.map((v) => v.toJson()).toList();
    await prefs.setString(_customVoicesKey, jsonEncode(jsonList));
  }
}
