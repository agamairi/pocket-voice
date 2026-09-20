import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_voice/shared/models/voice_profile.dart';

void main() {
  group('VoiceProfile Model & Serialization Tests', () {
    test('Serializes to and from JSON correctly', () {
      const profile = VoiceProfile(
        id: 'karen',
        name: 'Karen',
        referenceAudioPath: 'assets/voices/karen.wav',
        optionalDescription: 'Warm, expressive female studio narration',
        optionalLicenseInfo: 'CC-BY-4.0 (LibriTTS)',
        gender: 'female',
        isCustom: false,
      );

      final json = profile.toJson();
      final restored = VoiceProfile.fromJson(json);

      expect(restored.id, equals(profile.id));
      expect(restored.name, equals(profile.name));
      expect(restored.referenceAudioPath, equals(profile.referenceAudioPath));
      expect(restored.optionalDescription, equals(profile.optionalDescription));
      expect(restored.optionalLicenseInfo, equals(profile.optionalLicenseInfo));
      expect(restored.gender, equals('female'));
      expect(restored.isCustom, equals(profile.isCustom));
    });

    test('Custom voice profile handles null descriptions gracefully', () {
      const profile = VoiceProfile(
        id: 'custom_1234',
        name: 'My Custom Voice',
        referenceAudioPath: '/path/to/voice.wav',
        isCustom: true,
      );

      final json = profile.toJson();
      final restored = VoiceProfile.fromJson(json);

      expect(restored.id, equals('custom_1234'));
      expect(restored.name, equals('My Custom Voice'));
      expect(restored.optionalDescription, isNull);
      expect(restored.optionalLicenseInfo, isNull);
      expect(restored.isCustom, isTrue);
    });

    test('Equality and copyWith operate as expected', () {
      const profile1 = VoiceProfile(
        id: 'voice_1',
        name: 'Voice 1',
        referenceAudioPath: '/path/1.wav',
      );

      const profile2 = VoiceProfile(
        id: 'voice_1',
        name: 'Voice 1 Renamed',
        referenceAudioPath: '/path/1.wav',
      );

      // Equality based on ID
      expect(profile1, equals(profile2));

      final updated = profile1.copyWith(name: 'Updated Name');
      expect(updated.name, equals('Updated Name'));
      expect(updated.id, equals('voice_1'));
    });
  });
}
