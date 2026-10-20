import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_voice/shared/utils/text_segmenter.dart';

void main() {
  group('TextSegmenter Tests', () {
    test('Strips markup tags cleanly from script', () {
      const input =
          '[normal]\nThis is normal narration.\n[excited]\nThat damage is ridiculous!\n[whisper]\nKeep quiet.';
      final cleaned = TextSegmenter.stripMarkupTags(input);

      expect(cleaned.contains('[normal]'), isFalse);
      expect(cleaned.contains('[excited]'), isFalse);
      expect(cleaned.contains('[whisper]'), isFalse);
      expect(cleaned.contains('This is normal narration.'), isTrue);
      expect(cleaned.contains('That damage is ridiculous!'), isTrue);
      expect(cleaned.contains('Keep quiet.'), isTrue);
    });

    test('Parses tagged blocks preserving tags and contents', () {
      const input =
          '[normal]\nThis is the normal narration.\n[excited]\nThat damage is ridiculous!';
      final blocks = TextSegmenter.parseTaggedBlocks(input);

      expect(blocks.length, equals(2));
      expect(blocks[0].tag, equals('normal'));
      expect(blocks[0].text, equals('This is the normal narration.'));
      expect(blocks[1].tag, equals('excited'));
      expect(blocks[1].text, equals('That damage is ridiculous!'));
    });

    test('Handles untagged script gracefully in parseTaggedBlocks', () {
      const input = 'Simple untagged script here.';
      final blocks = TextSegmenter.parseTaggedBlocks(input);

      expect(blocks.length, equals(1));
      expect(blocks[0].tag, isNull);
      expect(blocks[0].text, equals('Simple untagged script here.'));
    });

    test('Segments paragraphs and sentences correctly', () {
      const input =
          'First sentence here. Second sentence in first paragraph!\n\n'
          'Third sentence begins the second paragraph. Fourth sentence follows? Yes it does.';

      final chunks = TextSegmenter.segmentText(input);

      expect(chunks.length, equals(5));

      // Paragraph 1
      expect(chunks[0].text, equals('First sentence here.'));
      expect(chunks[0].isEndOfParagraph, isFalse);

      expect(chunks[1].text, equals('Second sentence in first paragraph!'));
      expect(chunks[1].isEndOfParagraph, isTrue);

      // Paragraph 2
      expect(chunks[2].text, equals('Third sentence begins the second paragraph.'));
      expect(chunks[2].isEndOfParagraph, isFalse);

      expect(chunks[3].text, equals('Fourth sentence follows?'));
      expect(chunks[3].isEndOfParagraph, isFalse);

      expect(chunks[4].text, equals('Yes it does.'));
      expect(chunks[4].isEndOfParagraph, isTrue);
    });

    test('Avoids splitting sentences on abbreviations and decimal numbers', () {
      const input =
          'Dr. Smith and Mr. Jones met at 3.14 PM vs. yesterday. It was great!';

      final chunks = TextSegmenter.segmentText(input);

      expect(chunks.length, equals(2));
      expect(chunks[0].text, equals('Dr. Smith and Mr. Jones met at 3.14 PM vs. yesterday.'));
      expect(chunks[1].text, equals('It was great!'));
    });

    test('Preserves quotation marks with sentences', () {
      const input = 'The narrator said, "PocketTTS is fast!" And it really was.';

      final chunks = TextSegmenter.segmentText(input);

      expect(chunks.length, equals(2));
      expect(chunks[0].text, equals('The narrator said, "PocketTTS is fast!"'));
      expect(chunks[1].text, equals('And it really was.'));
    });

    test('Counts words accurately excluding tags', () {
      const input = '[intro] Hello YouTube world! [pause] Welcome to the channel.';
      final count = TextSegmenter.countWords(input);

      // "Hello", "YouTube", "world!", "Welcome", "to", "the", "channel." -> 7 words
      expect(count, equals(7));
    });

    test('Counts characters accurately excluding tags', () {
      const input = '[tag]Hello world';
      final count = TextSegmenter.countCharacters(input);

      expect(count, equals('Hello world'.length));
    });

    test('Calculates estimated duration factoring words and pause settings', () {
      const input = 'Sentence one here. Sentence two here.\n\nParagraph two starts.';

      final duration = TextSegmenter.estimateDuration(
        input,
        sentencePauseMs: 200,
        paragraphPauseMs: 500,
      );

      // 9 words / 2.5 words/sec = 3.6 sec + (1 sentence pause: 0.2s) + (1 paragraph pause: 0.5s) = 4.3s
      expect(duration, closeTo(4.3, 0.1));
    });

    test('Keeps inline tags inside one sentence', () {
      const input = 'We did it [excited] finally! Next one.';

      final chunks = TextSegmenter.segmentText(input);

      expect(chunks.length, equals(2));
      expect(chunks[0].text, equals('We did it finally!'));
      expect(chunks[0].tag, equals('excited'));
      expect(chunks[0].isEndOfParagraph, isFalse);
      expect(chunks[1].text, equals('Next one.'));
      expect(chunks[1].tag, equals('excited'));
      expect(chunks[1].isEndOfParagraph, isTrue);
    });

    test('Tag on its own line starts a new paragraph', () {
      const input = '[normal]\nFirst line here.\n[excited]\nSecond line here.';

      final chunks = TextSegmenter.segmentText(input);

      expect(chunks.length, equals(2));
      expect(chunks[0].tag, equals('normal'));
      expect(chunks[0].isEndOfParagraph, isTrue);
      expect(chunks[1].tag, equals('excited'));
      expect(chunks[1].isEndOfParagraph, isTrue);
    });

    test('Inline tag does not break paragraph', () {
      const input = 'Hello [whisper] there\n\nNew paragraph.';

      final chunks = TextSegmenter.segmentText(input);

      expect(chunks.length, equals(2));
      expect(chunks[0].text, equals('Hello there'));
      expect(chunks[0].tag, equals('whisper'));
      expect(chunks[0].isEndOfParagraph, isTrue);
      expect(chunks[1].text, equals('New paragraph.'));
      expect(chunks[1].tag, equals('whisper'));
      expect(chunks[1].isEndOfParagraph, isTrue);
    });
  });
}
