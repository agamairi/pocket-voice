import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../shared/models/narration_item.dart';
import '../../shared/models/tts_settings.dart';
import '../../shared/models/voice_profile.dart';
import '../../shared/utils/duration_formatter.dart';
import '../../shared/utils/filename_generator.dart';
import '../library/library_service.dart';
import 'model_manager.dart';
import 'pocket_tts_service.dart';
import 'voice_manager.dart';

class TtsController extends ChangeNotifier {
  static const String _settingsKey = 'tts_settings_v2';
  static const String _legacySettingsKey = 'tts_settings_v1';

  final ModelManager modelManager;
  final VoiceManager voiceManager;
  final PocketTtsService ttsService;
  final LibraryService libraryService;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isInitialized = false;
  bool _isModelInstalled = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  bool _isGenerating = false;
  bool _isPreviewGenerating = false;
  GenerationProgress? _currentProgress;
  String? _errorMessage;

  TtsSettings _settings = const TtsSettings();
  List<VoiceProfile> _voices = [];
  VoiceProfile? _selectedVoice;

  NarrationItem? _currentNarration;
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  String? _currentlyPlayingPath;

  TtsController({
    required this.modelManager,
    required this.voiceManager,
    required this.ttsService,
    required this.libraryService,
  }) {
    _initAudioPlayerListeners();
  }

  bool get isInitialized => _isInitialized;
  bool get isModelInstalled => _isModelInstalled;
  bool get isDownloadingModel => _isDownloadingModel;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;

  bool get isGenerating => _isGenerating;
  bool get isPreviewGenerating => _isPreviewGenerating;
  GenerationProgress? get currentProgress => _currentProgress;
  String? get errorMessage => _errorMessage;

  TtsSettings get settings => _settings;
  List<VoiceProfile> get voices => _voices;
  VoiceProfile? get selectedVoice => _selectedVoice;

  NarrationItem? get currentNarration => _currentNarration;
  bool get isPlaying => _isPlaying;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;
  String? get currentlyPlayingPath => _currentlyPlayingPath;

  void _initAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = (state == PlayerState.playing);
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      _playbackPosition = pos;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((dur) {
      _playbackDuration = dur;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) async {
      _isPlaying = false;
      _playbackPosition = Duration.zero;
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      notifyListeners();
    });
  }

  /// Initial load of preferences, model status, and voices.
  Future<void> initialize() async {
    await ttsService.initialize();
    await _loadSettings();
    _isModelInstalled = await modelManager.isModelInstalled();

    if (_isModelInstalled) {
      await refreshVoices();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Loads settings from JSON storage, falling back to the legacy query-string
  /// format. The legacy format stored booleans as text, so they must be converted
  /// back before TtsSettings.fromJson reads them; otherwise the whole load fails
  /// and every setting silently reverts to its default.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonStr = prefs.getString(_settingsKey);
    if (jsonStr != null) {
      try {
        _settings = TtsSettings.fromJson(Map<String, dynamic>.from(jsonDecode(jsonStr) as Map));
        return;
      } catch (_) {}
    }

    final legacyStr = prefs.getString(_legacySettingsKey);
    if (legacyStr != null) {
      try {
        final legacy = Uri.splitQueryString(legacyStr).map((k, v) {
          if (v == 'true') return MapEntry(k, true);
          if (v == 'false') return MapEntry(k, false);
          return MapEntry(k, int.tryParse(v) ?? v);
        });
        _settings = TtsSettings.fromJson(Map<String, dynamic>.from(legacy));
      } catch (_) {}
    }
  }

  Future<void> updateSettings(TtsSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(newSettings.toJson()));
  }

  Future<void> refreshVoices() async {
    _voices = await voiceManager.getAllVoices();
    final defaultId = await voiceManager.getDefaultVoiceId();

    if (_voices.isNotEmpty) {
      _selectedVoice = _voices.firstWhere(
        (v) => v.id == defaultId,
        orElse: () => _voices.first,
      );
    } else {
      _selectedVoice = null;
    }
    notifyListeners();
  }

  void selectVoice(VoiceProfile voice) {
    _selectedVoice = voice;
    notifyListeners();
  }

  Future<void> setDefaultVoice(VoiceProfile voice) async {
    await voiceManager.setDefaultVoiceId(voice.id);
    _selectedVoice = voice;
    notifyListeners();
  }

  /// Downloads and unpacks the PocketTTS model archive.
  Future<void> downloadModel() async {
    _isDownloadingModel = true;
    _downloadProgress = 0.0;
    _downloadStatus = 'Starting download...';
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await modelManager.downloadAndInstall(
        onProgress: (received, total, progress) {
          _downloadProgress = progress;
          final mbRec = DurationFormatter.formatFileSize(received);
          final mbTot = DurationFormatter.formatFileSize(total);
          _downloadStatus = 'Downloading: $mbRec / $mbTot (${(progress * 100).toStringAsFixed(0)}%)';
          notifyListeners();
        },
        onStatus: (status) {
          _downloadStatus = status;
          notifyListeners();
        },
      );

      _isModelInstalled = success;
      if (success) {
        await refreshVoices();
      }
    } catch (e) {
      _errorMessage = 'Download failed: $e';
    } finally {
      _isDownloadingModel = false;
      notifyListeners();
    }
  }

  void cancelModelDownload() {
    modelManager.cancelDownload();
    _isDownloadingModel = false;
    _downloadStatus = 'Download cancelled';
    notifyListeners();
  }

  Future<void> deleteModel() async {
    await modelManager.deleteModel();
    _isModelInstalled = false;
    _voices = [];
    _selectedVoice = null;
    notifyListeners();
  }

  /// Imports a custom reference WAV file.
  Future<VoiceProfile?> importCustomVoice({
    required String filePath,
    required String name,
    String? description,
    String? gender,
  }) async {
    try {
      final profile = await voiceManager.importCustomVoice(
        sourceFilePath: filePath,
        name: name,
        description: description,
        gender: gender,
      );
      await refreshVoices();
      _selectedVoice = profile;
      notifyListeners();
      return profile;
    } catch (e) {
      _errorMessage = 'Failed to import voice: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteCustomVoice(String id) async {
    await voiceManager.deleteCustomVoice(id);
    await refreshVoices();
  }

  Future<void> renameCustomVoice(String id, String newName) async {
    await voiceManager.renameCustomVoice(id, newName);
    await refreshVoices();
  }

  /// Generates a preview chunk (selected sentence or first chunk of script).
  Future<void> generatePreview(String scriptText, {String? selectedSentence}) async {
    if (_selectedVoice == null) {
      _errorMessage = 'Please select a voice first.';
      notifyListeners();
      return;
    }

    final textToSynthesize = (selectedSentence != null && selectedSentence.trim().isNotEmpty)
        ? selectedSentence.trim()
        : scriptText.trim();

    if (textToSynthesize.isEmpty) {
      _errorMessage = 'Please enter some text in the script editor.';
      notifyListeners();
      return;
    }

    _isPreviewGenerating = true;
    _errorMessage = null;
    notifyListeners();

    final docsDir = await getApplicationDocumentsDirectory();
    final tempPath = '${docsDir.path}/preview_temp.wav';

    try {
      if (_settings.keepScreenAwake) {
        await WakelockPlus.enable();
      }

      final result = await ttsService.generatePreview(
        text: textToSynthesize,
        voice: _selectedVoice!,
        settings: _settings,
        tempPreviewPath: tempPath,
        onProgress: (p) {
          _currentProgress = p;
          notifyListeners();
        },
      );

      // Play preview audio immediately
      await playAudio(result.outputPath);
    } catch (e) {
      if (e is! GenerationCancelledException) {
        _errorMessage = 'Preview generation failed: $e';
      }
    } finally {
      _isPreviewGenerating = false;
      _currentProgress = null;
      if (_settings.keepScreenAwake) {
        await WakelockPlus.disable();
      }
      notifyListeners();
    }
  }

  /// Generates complete narration WAV for the full script.
  Future<NarrationItem?> generateNarration(String scriptText, {String? customFilename}) async {
    if (_selectedVoice == null) {
      _errorMessage = 'Please select a voice profile.';
      notifyListeners();
      return null;
    }

    final text = scriptText.trim();
    if (text.isEmpty) {
      _errorMessage = 'Please enter a script to generate narration.';
      notifyListeners();
      return null;
    }

    _isGenerating = true;
    _currentProgress = null;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_settings.keepScreenAwake) {
        await WakelockPlus.enable();
      }

      final narrationsDir = await libraryService.getNarrationsDirectory();
      final filename = customFilename != null && customFilename.trim().isNotEmpty
          ? FilenameGenerator.sanitizeFilename(customFilename)
          : FilenameGenerator.generateDefaultFilename();
      final targetFilePath = '${narrationsDir.path}/$filename';

      final result = await ttsService.generate(
        text: text,
        voice: _selectedVoice!,
        settings: _settings,
        outputPath: targetFilePath,
        onProgress: (p) {
          _currentProgress = p;
          notifyListeners();
        },
      );

      final narrationItem = NarrationItem(
        id: const Uuid().v4(),
        title: filename,
        filePath: result.outputPath,
        durationSeconds: result.durationSeconds,
        fileSizeBytes: result.fileSizeBytes,
        voiceName: _selectedVoice!.name,
        createdAt: DateTime.now(),
      );

      await libraryService.addNarration(narrationItem);
      _currentNarration = narrationItem;

      // Auto-load audio player for newly generated item
      await playAudio(narrationItem.filePath);

      return narrationItem;
    } catch (e) {
      if (e is! GenerationCancelledException) {
        _errorMessage = 'Narration generation failed: $e';
      }
      return null;
    } finally {
      _isGenerating = false;
      _currentProgress = null;
      if (_settings.keepScreenAwake) {
        await WakelockPlus.disable();
      }
      notifyListeners();
    }
  }

  void cancelGeneration() {
    ttsService.cancel();
    _isGenerating = false;
    _isPreviewGenerating = false;
    _currentProgress = null;
    notifyListeners();
  }

  /// Plays a WAV audio file.
  Future<void> playAudio(String filePath) async {
    try {
      if (_currentlyPlayingPath != filePath) {
        await _audioPlayer.stop();
        _currentlyPlayingPath = filePath;
        _playbackPosition = Duration.zero;
        await _audioPlayer.play(DeviceFileSource(filePath));
      } else {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          // If the track is at the start (e.g. completed or stopped) or at/past the duration,
          // replay from scratch since resume() on Android won't work on completed MediaPlayer.
          if (_playbackPosition == Duration.zero ||
              (_playbackDuration > Duration.zero && _playbackPosition >= _playbackDuration)) {
            await _audioPlayer.stop();
            await _audioPlayer.play(DeviceFileSource(filePath));
          } else {
            try {
              await _audioPlayer.resume();
            } catch (_) {
              await _audioPlayer.stop();
              await _audioPlayer.play(
                DeviceFileSource(filePath),
                position: _playbackPosition,
              );
            }
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Playback error: $e';
      notifyListeners();
    }
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
  }

  Future<void> seekAudio(Duration position) async {
    _playbackPosition = position;
    try {
      await _audioPlayer.seek(position);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _currentlyPlayingPath = null;
    _playbackPosition = Duration.zero;
    notifyListeners();
  }

  /// Opens the Android native share sheet for the generated audio file.
  Future<void> shareNarration(NarrationItem item) async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(item.filePath, mimeType: 'audio/wav', name: item.title)],
            subject: item.title,
          ),
        );
      } else {
        _errorMessage = 'Audio file does not exist on disk: ${item.filePath}';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Share failed: $e';
      notifyListeners();
    }
  }

  /// Renames a narration in the library.
  Future<void> renameNarration(NarrationItem item, String newName) async {
    try {
      final sanitized = FilenameGenerator.sanitizeFilename(newName);
      final updated = await libraryService.renameNarration(item.id, sanitized);
      if (_currentNarration?.id == item.id) {
        _currentNarration = updated;
        if (_currentlyPlayingPath == item.filePath) {
          _currentlyPlayingPath = updated.filePath;
        }
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Rename failed: $e';
      notifyListeners();
    }
  }

  /// Deletes a narration from the library.
  Future<void> deleteNarration(NarrationItem item) async {
    if (_currentlyPlayingPath == item.filePath) {
      await stopAudio();
    }
    await libraryService.deleteNarration(item.id);
    if (_currentNarration?.id == item.id) {
      _currentNarration = null;
    }
    notifyListeners();
  }

  void setCurrentNarration(NarrationItem? item) {
    _currentNarration = item;
    notifyListeners();
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    ttsService.dispose();
    super.dispose();
  }
}
