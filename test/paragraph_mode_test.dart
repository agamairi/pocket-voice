import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_voice/shared/models/tts_settings.dart';
import 'package:pocket_voice/shared/utils/text_segmenter.dart';

void main() {
  group('TextSegmenter.mergeParagraphs', () {
    test('joins the sentences of each paragraph into one chunk', () {
      final sentences = TextSegmenter.segmentText('One. Two.\n\nThree.');
      final merged = TextSegmenter.mergeParagraphs(sentences);

      expect(merged.length, equals(2));
      expect(merged[0].text, equals('One. Two.'));
      expect(merged[0].isEndOfParagraph, isTrue);
      expect(merged[1].text, equals('Three.'));
      expect(merged[1].isEndOfParagraph, isTrue);
    });

    test('keeps the first sentence tag and renumbers chunks', () {
      final sentences = TextSegmenter.segmentText('[excited]\nWow! Great.\n\n[whisper]\nShh.');
      final merged = TextSegmenter.mergeParagraphs(sentences);

      expect(merged.map((c) => c.index).toList(), equals([0, 1]));
      expect(merged[0].tag, equals('excited'));
      expect(merged[1].tag, equals('whisper'));
    });

    test('returns an empty list for no chunks', () {
      expect(TextSegmenter.mergeParagraphs(const []), isEmpty);
    });
  });

  group('TtsSettings persistence', () {
    test('round-trips through JSON, including booleans', () {
      const original = TtsSettings(
        sentencePauseMs: 0,
        paragraphPauseMs: 100,
        keepScreenAwake: false,
        paragraphMode: true,
      );

      final restored = TtsSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(original.toJson())) as Map),
      );

      expect(restored.sentencePauseMs, equals(0));
      expect(restored.paragraphPauseMs, equals(100));
      expect(restored.keepScreenAwake, isFalse);
      expect(restored.paragraphMode, isTrue);
    });

    test('paragraph mode defaults to off', () {
      expect(const TtsSettings().paragraphMode, isFalse);
      expect(TtsSettings.fromJson(const {}).paragraphMode, isFalse);
    });
  });
}
