import 'package:intl/intl.dart';

class FilenameGenerator {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');

  /// Generates the default filename narration_YYYY-MM-DD_HH-mm-ss.wav
  static String generateDefaultFilename([DateTime? time]) {
    final t = time ?? DateTime.now();
    return 'narration_${_dateFormat.format(t)}.wav';
  }

  /// Sanitizes a user-provided filename by removing illegal filesystem characters
  /// and ensuring it ends with `.wav`.
  static String sanitizeFilename(String input) {
    var cleaned = input.trim();
    if (cleaned.isEmpty) {
      return generateDefaultFilename();
    }

    // Replace invalid characters / \ : * ? " < > |
    cleaned = cleaned.replaceAll(RegExp(r'[\/\\:\*\?"<>\|\x00-\x1F]'), '_');

    // Remove trailing spaces or dots
    cleaned = cleaned.replaceAll(RegExp(r'[\s\.]+$'), '');

    if (cleaned.isEmpty) {
      return generateDefaultFilename();
    }

    if (!cleaned.toLowerCase().endsWith('.wav')) {
      cleaned = '$cleaned.wav';
    }

    return cleaned;
  }
}
