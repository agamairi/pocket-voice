class VoiceProfile {
  final String id;
  final String name;
  final String referenceAudioPath;
  final String? optionalDescription;
  final String? optionalLicenseInfo;
  final bool isCustom;

  const VoiceProfile({
    required this.id,
    required this.name,
    required this.referenceAudioPath,
    this.optionalDescription,
    this.optionalLicenseInfo,
    this.isCustom = false,
  });

  VoiceProfile copyWith({
    String? id,
    String? name,
    String? referenceAudioPath,
    String? optionalDescription,
    String? optionalLicenseInfo,
    bool? isCustom,
  }) {
    return VoiceProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      referenceAudioPath: referenceAudioPath ?? this.referenceAudioPath,
      optionalDescription: optionalDescription ?? this.optionalDescription,
      optionalLicenseInfo: optionalLicenseInfo ?? this.optionalLicenseInfo,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'referenceAudioPath': referenceAudioPath,
      'optionalDescription': optionalDescription,
      'optionalLicenseInfo': optionalLicenseInfo,
      'isCustom': isCustom,
    };
  }

  factory VoiceProfile.fromJson(Map<String, dynamic> json) {
    return VoiceProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      referenceAudioPath: json['referenceAudioPath'] as String,
      optionalDescription: json['optionalDescription'] as String?,
      optionalLicenseInfo: json['optionalLicenseInfo'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
