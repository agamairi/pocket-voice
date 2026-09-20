class TtsSettings {
  final int sentencePauseMs;
  final int paragraphPauseMs;
  final int numThreads;
  final bool keepScreenAwake;
  final String defaultVoiceId;
  final int maxReferenceAudioLen;

  const TtsSettings({
    this.sentencePauseMs = 180,
    this.paragraphPauseMs = 400,
    this.numThreads = 2,
    this.keepScreenAwake = true,
    this.defaultVoiceId = 'bria',
    this.maxReferenceAudioLen = 12,
  });

  TtsSettings copyWith({
    int? sentencePauseMs,
    int? paragraphPauseMs,
    int? numThreads,
    bool? keepScreenAwake,
    String? defaultVoiceId,
    int? maxReferenceAudioLen,
  }) {
    return TtsSettings(
      sentencePauseMs: sentencePauseMs ?? this.sentencePauseMs,
      paragraphPauseMs: paragraphPauseMs ?? this.paragraphPauseMs,
      numThreads: numThreads ?? this.numThreads,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      defaultVoiceId: defaultVoiceId ?? this.defaultVoiceId,
      maxReferenceAudioLen: maxReferenceAudioLen ?? this.maxReferenceAudioLen,
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
    );
  }
}
