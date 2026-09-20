import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import '../../shared/models/tts_settings.dart';
import '../../shared/models/voice_profile.dart';
import '../../shared/utils/text_segmenter.dart';
import '../../shared/utils/wav_concatenator.dart';
import 'model_manager.dart';

class GenerationCancelledException implements Exception {
  final String message;
  GenerationCancelledException([this.message = 'Narration generation was cancelled.']);
  @override
  String toString() => message;
}

class GenerationProgress {
  final double progress; // 0.0 to 1.0
  final int currentChunk;
  final int totalChunks;
  final int currentParagraph;
  final int totalParagraphs;
  final double generatedSeconds;
  final String statusText;

  const GenerationProgress({
    required this.progress,
    required this.currentChunk,
    required this.totalChunks,
    required this.currentParagraph,
    required this.totalParagraphs,
    required this.generatedSeconds,
    required this.statusText,
  });
}

class GenerationResult {
  final String outputPath;
  final double durationSeconds;
  final int fileSizeBytes;
  final int sampleCount;
  final int sampleRate;

  const GenerationResult({
    required this.outputPath,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.sampleCount,
    required this.sampleRate,
  });
}

class _IsolateJobConfig {
  final SendPort mainSendPort;
  final String modelDirPath;
  final String referenceAudioPath;
  final List<TextChunk> chunks;
  final int sentencePauseMs;
  final int paragraphPauseMs;
  final int numThreads;
  final int maxReferenceAudioLen;
  final String outputPath;
  final bool isPreviewOnly;

  _IsolateJobConfig({
    required this.mainSendPort,
    required this.modelDirPath,
    required this.referenceAudioPath,
    required this.chunks,
    required this.sentencePauseMs,
    required this.paragraphPauseMs,
    required this.numThreads,
    required this.maxReferenceAudioLen,
    required this.outputPath,
    this.isPreviewOnly = false,
  });
}

class PocketTtsService {
  final ModelManager modelManager;
  Isolate? _activeIsolate;
  ReceivePort? _activeReceivePort;
  SendPort? _isolateCommandPort;
  String? _activeOutputPath;
  bool _isGenerating = false;

  PocketTtsService({required this.modelManager});

  bool get isGenerating => _isGenerating;

  /// Initializes the service.
  Future<void> initialize() async {
    // Bindings will be initialized in foreground and background isolates
    try {
      await sherpa_onnx.initBindingsAsync();
    } catch (_) {}
  }

  /// Synthesizes the provided text into a complete 24 kHz WAV file.
  Future<GenerationResult> generate({
    required String text,
    required VoiceProfile voice,
    required TtsSettings settings,
    required String outputPath,
    void Function(GenerationProgress)? onProgress,
  }) async {
    if (_isGenerating) {
      throw Exception('Another generation request is already active.');
    }

    final modelDir = await modelManager.getModelDirectory();
    if (!await modelManager.isModelInstalled()) {
      throw Exception('PocketTTS model is not installed. Please download the model first.');
    }

    if (!await File(voice.referenceAudioPath).exists()) {
      throw Exception('Voice reference audio file not found: ${voice.referenceAudioPath}');
    }

    // Segment text into manageable chunks
    final chunks = TextSegmenter.segmentText(text);
    if (chunks.isEmpty) {
      throw Exception('No narratable text provided.');
    }

    _isGenerating = true;
    _activeOutputPath = outputPath;
    final completer = Completer<GenerationResult>();

    _activeReceivePort = ReceivePort();
    final receivePort = _activeReceivePort!;

    try {
      final job = _IsolateJobConfig(
        mainSendPort: receivePort.sendPort,
        modelDirPath: modelDir.path,
        referenceAudioPath: voice.referenceAudioPath,
        chunks: chunks,
        sentencePauseMs: settings.sentencePauseMs,
        paragraphPauseMs: settings.paragraphPauseMs,
        numThreads: settings.numThreads,
        maxReferenceAudioLen: settings.maxReferenceAudioLen,
        outputPath: outputPath,
        isPreviewOnly: false,
      );

      _activeIsolate = await Isolate.spawn(
        _ttsWorkerIsolate,
        job,
        errorsAreFatal: true,
      );

      receivePort.listen((message) {
        if (message is SendPort) {
          _isolateCommandPort = message;
        } else if (message is Map) {
          final type = message['type'];
          if (type == 'progress') {
            final progress = GenerationProgress(
              progress: (message['overallProgress'] as num).toDouble(),
              currentChunk: message['currentChunk'] as int,
              totalChunks: message['totalChunks'] as int,
              currentParagraph: message['currentParagraph'] as int,
              totalParagraphs: message['totalParagraphs'] as int,
              generatedSeconds: (message['generatedSeconds'] as num).toDouble(),
              statusText: message['statusText'] as String,
            );
            onProgress?.call(progress);
          } else if (type == 'done') {
            final result = GenerationResult(
              outputPath: message['outputPath'] as String,
              durationSeconds: (message['durationSeconds'] as num).toDouble(),
              fileSizeBytes: message['fileSizeBytes'] as int,
              sampleCount: message['sampleCount'] as int,
              sampleRate: message['sampleRate'] as int,
            );
            if (!completer.isCompleted) completer.complete(result);
          } else if (type == 'cancelled') {
            _cleanupOutputFile(outputPath);
            if (!completer.isCompleted) {
              completer.completeError(GenerationCancelledException());
            }
          } else if (type == 'error') {
            _cleanupOutputFile(outputPath);
            if (!completer.isCompleted) {
              completer.completeError(Exception(message['error']));
            }
          }
        }
      });

      return await completer.future;
    } catch (e) {
      _cleanupOutputFile(outputPath);
      rethrow;
    } finally {
      _cleanupIsolate();
    }
  }

  /// Synthesizes a brief preview (e.g. first chunk or selected sentence).
  Future<GenerationResult> generatePreview({
    required String text,
    required VoiceProfile voice,
    required TtsSettings settings,
    required String tempPreviewPath,
    void Function(GenerationProgress)? onProgress,
  }) async {
    final chunks = TextSegmenter.segmentText(text);
    final previewChunks = chunks.isEmpty ? <TextChunk>[] : [chunks.first];

    if (previewChunks.isEmpty) {
      throw Exception('No previewable text provided.');
    }

    return generate(
      text: previewChunks.first.text,
      voice: voice,
      settings: settings,
      outputPath: tempPreviewPath,
      onProgress: onProgress,
    );
  }

  /// Cancels in-progress generation and cleans up partial files.
  void cancel() {
    if (!_isGenerating) return;

    try {
      _isolateCommandPort?.send({'command': 'cancel'});
    } catch (_) {}

    // Give isolate 200ms to clean itself up, otherwise kill it
    Timer(const Duration(milliseconds: 200), () {
      _cleanupIsolate();
      if (_activeOutputPath != null) {
        _cleanupOutputFile(_activeOutputPath!);
      }
    });
  }

  void _cleanupOutputFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  void _cleanupIsolate() {
    _isGenerating = false;
    _activeOutputPath = null;
    _isolateCommandPort = null;
    _activeReceivePort?.close();
    _activeReceivePort = null;
    _activeIsolate?.kill(priority: Isolate.immediate);
    _activeIsolate = null;
  }

  /// Disposes of any resources.
  void dispose() {
    cancel();
  }
}

/// The worker isolate function that performs PocketTTS inference without blocking the UI isolate.
void _ttsWorkerIsolate(_IsolateJobConfig job) async {
  final commandPort = ReceivePort();
  job.mainSendPort.send(commandPort.sendPort);

  bool isCancelled = false;
  commandPort.listen((message) {
    if (message is Map && message['command'] == 'cancel') {
      isCancelled = true;
    }
  });

  sherpa_onnx.OfflineTts? tts;

  try {
    await sherpa_onnx.initBindingsAsync();

    final pocket = sherpa_onnx.OfflineTtsPocketModelConfig(
      lmFlow: '${job.modelDirPath}/lm_flow.int8.onnx',
      lmMain: '${job.modelDirPath}/lm_main.int8.onnx',
      encoder: '${job.modelDirPath}/encoder.onnx',
      decoder: '${job.modelDirPath}/decoder.int8.onnx',
      textConditioner: '${job.modelDirPath}/text_conditioner.onnx',
      vocabJson: '${job.modelDirPath}/vocab.json',
      tokenScoresJson: '${job.modelDirPath}/token_scores.json',
      voiceEmbeddingCacheCapacity: 50,
    );

    final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
      pocket: pocket,
      numThreads: job.numThreads,
      debug: false,
    );

    final config = sherpa_onnx.OfflineTtsConfig(model: modelConfig);
    tts = sherpa_onnx.OfflineTts(config);

    final wave = sherpa_onnx.readWave(job.referenceAudioPath);
    if (wave.samples.isEmpty || wave.sampleRate == 0) {
      throw Exception('Failed to read reference audio: ${job.referenceAudioPath}');
    }

    final genConfig = sherpa_onnx.OfflineTtsGenerationConfig(
      sid: 0,
      speed: 1.0,
      referenceAudio: wave.samples,
      referenceSampleRate: wave.sampleRate,
      extra: {"max_reference_audio_len": job.maxReferenceAudioLen},
    );

    final totalChunks = job.chunks.length;
    // Count paragraphs
    int totalParagraphs = 0;
    for (final c in job.chunks) {
      if (c.isEndOfParagraph) totalParagraphs++;
    }
    if (totalParagraphs == 0) totalParagraphs = 1;

    final audioChunks = <Float32List>[];
    final pausesMs = <int>[];
    int currentParagraph = 1;
    int totalSamplesGenerated = 0;

    for (int i = 0; i < totalChunks; i++) {
      if (isCancelled) {
        job.mainSendPort.send({'type': 'cancelled'});
        return;
      }

      final chunk = job.chunks[i];
      final chunkIndex = i + 1;

      // Real generation with progress callback
      final audio = tts.generateWithConfig(
        text: chunk.text,
        config: genConfig,
        onProgress: (samples, chunkProgress) {
          if (isCancelled) return 0; // Returning 0 stops generation immediately

          final baseProgress = i / totalChunks;
          final chunkWeight = 1.0 / totalChunks;
          final overallProgress = (baseProgress + (chunkProgress * chunkWeight)).clamp(0.0, 1.0);

          final currentSeconds = (totalSamplesGenerated + samples.length) / tts!.sampleRate;

          job.mainSendPort.send({
            'type': 'progress',
            'overallProgress': overallProgress,
            'currentChunk': chunkIndex,
            'totalChunks': totalChunks,
            'currentParagraph': currentParagraph,
            'totalParagraphs': totalParagraphs,
            'generatedSeconds': currentSeconds,
            'statusText': 'Generating paragraph $currentParagraph / $totalParagraphs...',
          });

          return 1; // 1 to continue
        },
      );

      if (isCancelled) {
        job.mainSendPort.send({'type': 'cancelled'});
        return;
      }

      audioChunks.add(audio.samples);
      totalSamplesGenerated += audio.samples.length;

      // Add pause if not the last chunk
      if (i < totalChunks - 1) {
        if (chunk.isEndOfParagraph) {
          pausesMs.add(job.paragraphPauseMs);
          final pauseSamples = (job.paragraphPauseMs * tts.sampleRate) ~/ 1000;
          totalSamplesGenerated += pauseSamples;
          currentParagraph++;
        } else {
          pausesMs.add(job.sentencePauseMs);
          final pauseSamples = (job.sentencePauseMs * tts.sampleRate) ~/ 1000;
          totalSamplesGenerated += pauseSamples;
        }
      }
    }

    // Concatenate chunks and write final WAV
    final finalSamples = WavConcatenator.concatenateChunks(
      chunks: audioChunks,
      pausesMs: pausesMs,
      sampleRate: tts.sampleRate,
    );

    await WavConcatenator.writeWavFile(
      filePath: job.outputPath,
      samples: finalSamples,
      sampleRate: tts.sampleRate,
    );

    final outputFile = File(job.outputPath);
    final fileSizeBytes = await outputFile.length();
    final durationSeconds = finalSamples.length / tts.sampleRate;

    job.mainSendPort.send({
      'type': 'done',
      'outputPath': job.outputPath,
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'sampleCount': finalSamples.length,
      'sampleRate': tts.sampleRate,
    });
  } catch (e) {
    job.mainSendPort.send({'type': 'error', 'error': e.toString()});
  } finally {
    commandPort.close();
    tts?.free();
  }
}
