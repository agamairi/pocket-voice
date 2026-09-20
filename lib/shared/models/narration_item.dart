class NarrationItem {
  final String id;
  final String title;
  final String filePath;
  final double durationSeconds;
  final int fileSizeBytes;
  final String voiceName;
  final DateTime createdAt;

  const NarrationItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.voiceName,
    required this.createdAt,
  });

  NarrationItem copyWith({
    String? id,
    String? title,
    String? filePath,
    double? durationSeconds,
    int? fileSizeBytes,
    String? voiceName,
    DateTime? createdAt,
  }) {
    return NarrationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      voiceName: voiceName ?? this.voiceName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'voiceName': voiceName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NarrationItem.fromJson(Map<String, dynamic> json) {
    return NarrationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      durationSeconds: (json['durationSeconds'] as num).toDouble(),
      fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
      voiceName: json['voiceName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
