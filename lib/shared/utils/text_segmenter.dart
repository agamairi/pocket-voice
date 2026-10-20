class TextChunk {
  final int index;
  final String text;
  final bool isEndOfParagraph;
  final String? tag;

  const TextChunk({
    required this.index,
    required this.text,
    required this.isEndOfParagraph,
    this.tag,
  });

  @override
  String toString() =>
      'TextChunk(index: $index, tag: $tag, isEndOfParagraph: $isEndOfParagraph, text: "$text")';
}

class ScriptSegment {
  final String? tag;
  final String text;

  const ScriptSegment({this.tag, required this.text});
}

class TextSegmenter {
  // Regex to match markup tags like [normal], [excited], [whisper], etc.
  static final RegExp tagRegex = RegExp(r'\[([a-zA-Z0-9_\-]+)\]');

  // Common abbreviations that should NOT end a sentence
  static final Set<String> _abbreviations = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'vs', 'etc',
    'eg', 'ie', 'inc', 'ltd', 'dept', 'approx', 'est',
    'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'sept', 'oct', 'nov', 'dec',
    'st', 'ave', 'rd', 'blvd', 'no', 'vol', 'p', 'pp', 'co', 'corp', 'u.s', 'u.k',
  };

  /// Strips all markup tags from text so they are never read aloud.
  static String stripMarkupTags(String input) {
    return input.replaceAll(tagRegex, '');
  }

  /// Parses script into tagged segments for future multi-voice/style mapping.
  static List<ScriptSegment> parseTaggedBlocks(String input) {
    final segments = <ScriptSegment>[];
    final matches = tagRegex.allMatches(input).toList();

    if (matches.isEmpty) {
      final trimmed = input.trim();
      if (trimmed.isNotEmpty) {
        segments.add(ScriptSegment(tag: null, text: trimmed));
      }
      return segments;
    }

    int currentIndex = 0;
    String? currentTag;

    for (final match in matches) {
      if (match.start > currentIndex) {
        final text = input.substring(currentIndex, match.start).trim();
        if (text.isNotEmpty) {
          segments.add(ScriptSegment(tag: currentTag, text: text));
        }
      }
      currentTag = match.group(1);
      currentIndex = match.end;
    }

    if (currentIndex < input.length) {
      final remaining = input.substring(currentIndex).trim();
      if (remaining.isNotEmpty) {
        segments.add(ScriptSegment(tag: currentTag, text: remaining));
      }
    }

    return segments;
  }

  /// Splits script into sequential chunks optimized for PocketTTS inference.
  static List<TextChunk> segmentText(String rawInput) {
    final chunks = <TextChunk>[];
    int chunkIndex = 0;

    // First split on blank lines and tags that begin their own line. Inline
    // tags remain in the same paragraph and are handled below.
    final paragraphs = <String>[];
    final paragraphLines = <String>[];

    void finishParagraph() {
      if (paragraphLines.isNotEmpty) {
        paragraphs.add(paragraphLines.join('\n'));
        paragraphLines.clear();
      }
    }

    for (final line in rawInput.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) {
        finishParagraph();
        continue;
      }

      final firstTag = tagRegex.firstMatch(line);
      final tagStartsLine = firstTag != null &&
          line.substring(0, firstTag.start).trim().isEmpty;
      if (tagStartsLine && paragraphLines.isNotEmpty) {
        finishParagraph();
      }
      paragraphLines.add(line);
    }
    finishParagraph();

    String? currentTag;
    for (final rawParagraph in paragraphs) {
      final paragraphStartTag = currentTag;
      final normalized = StringBuffer();
      final characterTags = <String?>[];
      var pendingSpace = false;
      var activeTag = currentTag;

      var position = 0;
      while (position < rawParagraph.length) {
        final tagMatch = tagRegex.matchAsPrefix(rawParagraph, position);
        if (tagMatch != null) {
          activeTag = tagMatch.group(1);
          position = tagMatch.end;
          continue;
        }

        final char = rawParagraph[position];
        position++;
        if (RegExp(r'\s').hasMatch(char)) {
          pendingSpace = normalized.length > 0;
          continue;
        }

        if (pendingSpace) {
          normalized.write(' ');
          characterTags.add(activeTag);
          pendingSpace = false;
        }
        normalized.write(char);
        characterTags.add(activeTag);
      }

      currentTag = activeTag;
      final paragraph = normalized.toString().trim();
      if (paragraph.isEmpty) continue;

      final sentences = _splitSentences(paragraph);
      var searchStart = 0;
      for (int sIdx = 0; sIdx < sentences.length; sIdx++) {
        final sentence = sentences[sIdx].trim();
        if (sentence.isEmpty) continue;

        final sentenceStart = paragraph.indexOf(sentence, searchStart);
        if (sentenceStart == -1) continue;
        final sentenceEnd = sentenceStart + sentence.length - 1;
        final sentenceTag = sentenceEnd < characterTags.length
            ? characterTags[sentenceEnd]
            : paragraphStartTag;

        chunks.add(TextChunk(
          index: chunkIndex++,
          text: sentence,
          isEndOfParagraph: sIdx == sentences.length - 1,
          tag: sentenceTag,
        ));
        searchStart = sentenceStart + sentence.length;
      }
    }

    return chunks;
  }

  /// Joins the sentence chunks of each paragraph into one chunk per paragraph.
  ///
  /// Used by paragraph mode so PocketTTS generates a whole paragraph in one pass
  /// (one voice run per paragraph instead of one per sentence). The merged chunk
  /// keeps the first sentence's tag and is always the end of its paragraph.
  static List<TextChunk> mergeParagraphs(List<TextChunk> sentenceChunks) {
    final merged = <TextChunk>[];
    final buffer = <String>[];
    String? paragraphTag;

    void flush() {
      if (buffer.isEmpty) return;
      merged.add(TextChunk(
        index: merged.length,
        text: buffer.join(' '),
        isEndOfParagraph: true,
        tag: paragraphTag,
      ));
      buffer.clear();
      paragraphTag = null;
    }

    for (final chunk in sentenceChunks) {
      if (buffer.isEmpty) paragraphTag = chunk.tag;
      buffer.add(chunk.text);
      if (chunk.isEndOfParagraph) flush();
    }
    flush();

    return merged;
  }

  /// Splits a paragraph into sentences, avoiding abbreviations, numbers, and quotes.
  static List<String> _splitSentences(String text) {
    if (text.trim().isEmpty) return [];

    final sentences = <String>[];
    int start = 0;
    final len = text.length;

    for (int i = 0; i < len; i++) {
      final char = text[i];
      if (char == '.' || char == '!' || char == '?') {
        // Handle ellipsis like "..." or "…."
        while (i + 1 < len && (text[i + 1] == '.' || text[i + 1] == '!' || text[i + 1] == '?')) {
          i++;
        }

        // Check for closing quotes or parentheses right after punctuation
        while (i + 1 < len && (text[i + 1] == '"' || text[i + 1] == "'" || text[i + 1] == '”' || text[i + 1] == '’' || text[i + 1] == ')')) {
          i++;
        }

        // Verify if this is an abbreviation
        final candidate = text.substring(start, i + 1).trim();
        if (_isAbbreviationEnding(candidate, text, i)) {
          continue;
        }

        // Check if next character is whitespace or end of string
        if (i + 1 >= len || RegExp(r'\s').hasMatch(text[i + 1])) {
          sentences.add(candidate);
          start = i + 1;
        }
      }
    }

    if (start < len) {
      final remaining = text.substring(start).trim();
      if (remaining.isNotEmpty) {
        sentences.add(remaining);
      }
    }

    return sentences;
  }

  static bool _isAbbreviationEnding(String candidate, String fullText, int punctuationIdx) {
    // Check for decimal numbers e.g. "3.14"
    if (punctuationIdx > 0 && punctuationIdx + 1 < fullText.length) {
      final prev = fullText[punctuationIdx - 1];
      final next = fullText[punctuationIdx + 1];
      if (RegExp(r'\d').hasMatch(prev) && RegExp(r'\d').hasMatch(next)) {
        return true;
      }
    }

    // Extract the last word preceding the punctuation
    final words = candidate.split(RegExp(r'\s+'));
    if (words.isEmpty) return false;
    final lastWord = words.last.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();

    return _abbreviations.contains(lastWord);
  }

  /// Counts the total number of words in the script excluding markup tags.
  static int countWords(String input) {
    final cleaned = stripMarkupTags(input).trim();
    if (cleaned.isEmpty) return 0;
    return cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Counts the total number of characters excluding markup tags.
  static int countCharacters(String input) {
    return stripMarkupTags(input).length;
  }

  /// Estimates narration duration in seconds based on words and pause lengths.
  static double estimateDuration(
    String input, {
    int sentencePauseMs = 180,
    int paragraphPauseMs = 400,
  }) {
    final chunks = segmentText(input);
    if (chunks.isEmpty) return 0.0;

    final wordCount = countWords(input);
    // Average speech rate is ~2.5 words per second (~150 wpm)
    final speechDuration = wordCount / 2.5;

    int sentencePauses = 0;
    int paragraphPauses = 0;

    for (int i = 0; i < chunks.length - 1; i++) {
      if (chunks[i].isEndOfParagraph) {
        paragraphPauses++;
      } else {
        sentencePauses++;
      }
    }

    final totalPauseSeconds =
        (sentencePauses * (sentencePauseMs / 1000.0)) +
        (paragraphPauses * (paragraphPauseMs / 1000.0));

    return speechDuration + totalPauseSeconds;
  }
}
