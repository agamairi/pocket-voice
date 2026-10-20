class TtsSettings {
  final int sentencePauseMs;
  final int paragraphPauseMs;
  final int numThreads;
  final bool keepScreenAwake;
  final String defaultVoiceId;
  final int maxReferenceAudioLen;

  /// When true, each paragraph is generated in one pass so the voice stays steady
  /// within it. Sentence pauses then no longer apply; paragraph pauses still do.
  final bool paragraphMode;

  const TtsSettings({
    this.sentencePauseMs = 180,
    this.paragraphPauseMs = 400,
    this.numThreads = 2,
    this.keepScreenAwake = true,
    this.defaultVoiceId = 'bria',
    this.maxReferenceAudioLen = 12,
    this.paragraphMode = false,
  });

  TtsSettings copyWith({
    int? sentencePauseMs,
    int? paragraphPauseMs,
    int? numThreads,
    bool? keepScreenAwake,
    String? defaultVoiceId,
    int? maxReferenceAudioLen,
    bool? paragraphMode,
  }) {
    return TtsSettings(
      sentencePauseMs: sentencePauseMs ?? this.sentencePauseMs,
      paragraphPauseMs: paragraphPauseMs ?? this.paragraphPauseMs,
      numThreads: numThreads ?? this.numThreads,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      defaultVoiceId: defaultVoiceId ?? this.defaultVoiceId,
      maxReferenceAudioLen: maxReferenceAudioLen ?? this.maxReferenceAudioLen,
      paragraphMode: paragraphMode ?? this.paragraphMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sentencePauseMs': sentencePauseMs,
      'paragraphPauseMs': paragraphPauseMs,
      'numThreads': numThreads,
      'keepScreenAwake': keepScreenAwake,
      'defaultVoiceId': defaultVoiceId,
      'maxReferenceAudioLen': maxReferenceAudioLen,
      'paragraphMode': paragraphMode,
    };
  }

  factory TtsSettings.fromJson(Map<String, dynamic> json) {
    return TtsSettings(
      sentencePauseMs: json['sentencePauseMs'] as int? ?? 180,
      paragraphPauseMs: json['paragraphPauseMs'] as int? ?? 400,
      numThreads: json['numThreads'] as int? ?? 2,
      keepScreenAwake: json['keepScreenAwake'] as bool? ?? true,
      defaultVoiceId: json['defaultVoiceId'] as String? ?? 'bria',
      maxReferenceAudioLen: json['maxReferenceAudioLen'] as int? ?? 12,
      paragraphMode: json['paragraphMode'] as bool? ?? false,
    );
  }
}
