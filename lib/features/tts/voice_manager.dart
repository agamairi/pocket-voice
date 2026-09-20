import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/voice_profile.dart';
import 'model_manager.dart';

class _BundledVoiceInfo {
  final String id;
  final String name;
  final String assetFileName;
  final String gender;
  final String description;

  const _BundledVoiceInfo({
    required this.id,
    required this.name,
    required this.assetFileName,
    required this.gender,
    required this.description,
  });
}

class VoiceManager {
  static const String _customVoicesKey = 'custom_voice_profiles_v1';
  static const String _defaultVoiceIdKey = 'default_voice_id_v1';

  static const List<_BundledVoiceInfo> _predefinedVoices = [
    // 8 Female Voices
    _BundledVoiceInfo(
      id: 'female_karen',
      name: 'Karen',
      assetFileName: 'female_karen.wav',
      gender: 'female',
      description: 'Clear, articulate studio narrator (Neutral/British)',
    ),
    _BundledVoiceInfo(
      id: 'female_judy',
      name: 'Judy',
      assetFileName: 'female_judy.wav',
      gender: 'female',
      description: 'Warm, expressive, documentary style',
    ),
    _BundledVoiceInfo(
      id: 'female_lizzie',
      name: 'Lizzie',
      assetFileName: 'female_lizzie.wav',
      gender: 'female',
      description: 'Bright, lively storytelling voice',
    ),
    _BundledVoiceInfo(
      id: 'female_linda',
      name: 'Linda',
      assetFileName: 'female_linda.wav',
      gender: 'female',
      description: 'Calm, steady, professional narrative tone',
    ),
    _BundledVoiceInfo(
      id: 'female_kathy',
      name: 'Kathy',
      assetFileName: 'female_kathy.wav',
      gender: 'female',
      description: 'Energetic, articulate explainer voice',
    ),
    _BundledVoiceInfo(
      id: 'female_missie',
      name: 'Missie',
      assetFileName: 'female_missie.wav',
      gender: 'female',
      description: 'Friendly, conversational YouTube creator tone',
    ),
    _BundledVoiceInfo(
      id: 'female_laurie',
      name: 'Laurie',
      assetFileName: 'female_laurie.wav',
      gender: 'female',
      description: 'Deep, resonant, dramatic female voice',
    ),
    _BundledVoiceInfo(
      id: 'female_dawn',
      name: 'Dawn',
      assetFileName: 'female_dawn.wav',
      gender: 'female',
      description: 'Crisp, modern, upbeat educational voice',
    ),

    // 8 Male Voices
    _BundledVoiceInfo(
      id: 'male_eric',
      name: 'Eric',
      assetFileName: 'male_eric.wav',
      gender: 'male',
      description: 'Deep, confident commercial trailer & documentary narrator',
    ),
    _BundledVoiceInfo(
      id: 'male_brooks',
      name: 'Brooks',
      assetFileName: 'male_brooks.wav',
      gender: 'male',
      description: 'Warm, thoughtful podcast storytelling voice',
    ),
    _BundledVoiceInfo(
      id: 'male_tim',
      name: 'Tim',
      assetFileName: 'male_tim.wav',
      gender: 'male',
      description: 'Smooth, authoritative audiobook narrator',
    ),
    _BundledVoiceInfo(
      id: 'male_kevin',
      name: 'Kevin',
      assetFileName: 'male_kevin.wav',
      gender: 'male',
      description: 'Dynamic, punchy YouTube tech review voice',
    ),
    _BundledVoiceInfo(
      id: 'male_john',
      name: 'John',
      assetFileName: 'male_john.wav',
      gender: 'male',
      description: 'Rich, baritone cinematic narrator',
    ),
    _BundledVoiceInfo(
      id: 'male_sam',
      name: 'Sam',
      assetFileName: 'male_sam.wav',
      gender: 'male',
      description: 'Friendly, casual conversational explainer',
    ),
    _BundledVoiceInfo(
      id: 'male_james',
      name: 'James',
      assetFileName: 'male_james.wav',
      gender: 'male',
      description: 'Clear, engaging documentary voice',
    ),
    _BundledVoiceInfo(
      id: 'male_justin',
      name: 'Justin',
      assetFileName: 'male_justin.wav',
      gender: 'male',
      description: 'Resonant, classical theater voice',
    ),
  ];

  final ModelManager modelManager;

  VoiceManager({required this.modelManager});

  /// Extracts and returns all bundled voices (8 female, 8 male, plus model samples).
  Future<List<VoiceProfile>> getBundledVoices() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final bundledDir = Directory('${docsDir.path}/bundled_voices');
    await bundledDir.create(recursive: true);

    final voices = <VoiceProfile>[];

    // 1. Load the 16 studio reference voices
    for (final info in _predefinedVoices) {
      final targetFile = File('${bundledDir.path}/${info.assetFileName}');
      if (!await targetFile.exists() || await targetFile.length() == 0) {
        try {
          final data = await rootBundle.load('assets/voices/${info.assetFileName}');
          await targetFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
        } catch (_) {
          // In test environment where rootBundle may not contain assets, check fallback
          final localAsset = File('assets/voices/${info.assetFileName}');
          if (await localAsset.exists()) {
            await localAsset.copy(targetFile.path);
          }
        }
      }

      if (await targetFile.exists()) {
        voices.add(VoiceProfile(
          id: info.id,
          name: info.name,
          referenceAudioPath: targetFile.path,
          optionalDescription: info.description,
          optionalLicenseInfo: 'Creative Commons Attribution (LibriTTS corpus)',
          isCustom: false,
          gender: info.gender,
        ));
      }
    }

    // 2. Also check original model test wavs
    final modelDir = await modelManager.getModelDirectory();
    final briaPath = '${modelDir.path}/test_wavs/bria.wav';
    final loonaPath = '${modelDir.path}/test_wavs/loona.wav';

    if (await File(briaPath).exists()) {
      voices.add(VoiceProfile(
        id: 'bria',
        name: 'Bria',
        referenceAudioPath: briaPath,
        optionalDescription: 'Clear, balanced narration voice',
        optionalLicenseInfo: 'Creative Commons (Official PocketTTS sample)',
        isCustom: false,
        gender: 'female',
      ));
    }

    if (await File(loonaPath).exists()) {
      voices.add(VoiceProfile(
        id: 'loona',
        name: 'Loona',
        referenceAudioPath: loonaPath,
        optionalDescription: 'Expressive narration voice',
        optionalLicenseInfo: 'Creative Commons (Official PocketTTS sample)',
        isCustom: false,
        gender: 'female',
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
    String? gender,
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
      gender: gender,
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

      final defaultId = await getDefaultVoiceId();
      if (defaultId == id) {
        await setDefaultVoiceId('female_karen');
      }
    }
  }

  /// Gets the ID of the user's default voice.
  Future<String> getDefaultVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultVoiceIdKey) ?? 'female_karen';
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
