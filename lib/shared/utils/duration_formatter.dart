class DurationFormatter {
  static String formatSeconds(double totalSeconds) {
    if (totalSeconds.isNaN || totalSeconds.isInfinite || totalSeconds < 0) {
      return '00:00';
    }

    final int seconds = totalSeconds.round();
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  static String formatDuration(Duration duration) {
    return formatSeconds(duration.inMilliseconds / 1000.0);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
