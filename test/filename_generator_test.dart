import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_voice/shared/utils/filename_generator.dart';

void main() {
  group('FilenameGenerator Tests', () {
    test('Generates default filename with narration_YYYY-MM-DD_HH-mm-ss.wav format', () {
      final fixedTime = DateTime(2026, 9, 20, 14, 30, 45);
      final filename = FilenameGenerator.generateDefaultFilename(fixedTime);

      expect(filename, equals('narration_2026-09-20_14-30-45.wav'));
    });

    test('Sanitizes illegal filename characters', () {
      const input = 'My/Awesome:Video*Narration?Test"File<1>|2.wav';
      final sanitized = FilenameGenerator.sanitizeFilename(input);

      expect(sanitized.contains('/'), isFalse);
      expect(sanitized.contains('\\'), isFalse);
      expect(sanitized.contains(':'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.contains('?'), isFalse);
      expect(sanitized.contains('"'), isFalse);
      expect(sanitized.contains('<'), isFalse);
      expect(sanitized.contains('>'), isFalse);
      expect(sanitized.contains('|'), isFalse);
      expect(sanitized.endsWith('.wav'), isTrue);
    });

    test('Appends .wav extension if missing', () {
      const input = 'youtube_intro_final';
      final sanitized = FilenameGenerator.sanitizeFilename(input);

      expect(sanitized, equals('youtube_intro_final.wav'));
    });

    test('Falls back to default format if input is blank', () {
      final sanitized = FilenameGenerator.sanitizeFilename('   ');

      expect(sanitized.startsWith('narration_'), isTrue);
      expect(sanitized.endsWith('.wav'), isTrue);
    });
  });
}
