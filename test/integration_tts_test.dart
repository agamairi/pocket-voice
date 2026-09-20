import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

void main() {
  test('Integration Test: Synthesize offline PocketTTS narration', () async {
    const modelDir =
        '/Users/agamairi/.gemini/antigravity/brain/56f31ae1-4dc6-4484-b578-f1b172eba775/scratch/sherpa-onnx-pocket-tts-int8-2026-01-26';
    final modelDirectory = Directory(modelDir);

    // Skip if model files are not locally cached in this environment
    if (!await modelDirectory.exists()) {
      return;
    }

    String? nativeDylibDir;
    if (Platform.isMacOS) {
      final configFile = File('.dart_tool/package_config.json');
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        final match = RegExp(r'"rootUri":\s*"file://([^"]*sherpa_onnx_macos[^"]*)"')
            .firstMatch(content);
        if (match != null) {
          final rootUri = match.group(1)!;
          final candidate = '$rootUri/macos';
          if (Directory(candidate).existsSync()) {
            nativeDylibDir = candidate;
          }
        }
      }
    }

    await sherpa_onnx.initBindingsAsync(nativeDylibDir);

    final pocket = sherpa_onnx.OfflineTtsPocketModelConfig(
      lmFlow: '$modelDir/lm_flow.int8.onnx',
      lmMain: '$modelDir/lm_main.int8.onnx',
      encoder: '$modelDir/encoder.onnx',
      decoder: '$modelDir/decoder.int8.onnx',
      textConditioner: '$modelDir/text_conditioner.onnx',
      vocabJson: '$modelDir/vocab.json',
      tokenScoresJson: '$modelDir/token_scores.json',
      voiceEmbeddingCacheCapacity: 50,
    );

    final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
      pocket: pocket,
      numThreads: 2,
      debug: false,
    );

    final config = sherpa_onnx.OfflineTtsConfig(model: modelConfig);
    final tts = sherpa_onnx.OfflineTts(config);

    expect(tts.sampleRate, equals(24000));

    final wave = sherpa_onnx.readWave('$modelDir/test_wavs/bria.wav');
    expect(wave.samples.isNotEmpty, isTrue);
    expect(wave.sampleRate, equals(24000));

    final genConfig = sherpa_onnx.OfflineTtsGenerationConfig(
      sid: 0,
      speed: 1.0,
      referenceAudio: wave.samples,
      referenceSampleRate: wave.sampleRate,
      extra: {"max_reference_audio_len": 12},
    );

    const testPrompt =
        'Hello! This narration was generated completely on this device.';

    final audio = tts.generateWithConfig(
      text: testPrompt,
      config: genConfig,
    );

    expect(audio.samples.isNotEmpty, isTrue);
    expect(audio.sampleRate, equals(24000));

    // Save to temp file and verify
    final tempOutFile = '${Directory.systemTemp.path}/integration_pocket_test.wav';
    sherpa_onnx.writeWave(
      filename: tempOutFile,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );

    final outFile = File(tempOutFile);
    expect(await outFile.exists(), isTrue);
    expect(await outFile.length(), greaterThan(1000));

    // Cleanup
    await outFile.delete();
    tts.free();
  });
}
