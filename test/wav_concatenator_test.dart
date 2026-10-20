import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_voice/shared/utils/wav_concatenator.dart';

void main() {
  group('WavConcatenator Tests', () {
    test('Concatenates audio chunks with pause samples', () {
      final chunk1 = Float32List.fromList([0.1, 0.2, 0.3, 0.4]);
      final chunk2 = Float32List.fromList([0.5, 0.6, 0.7, 0.8]);

      // 1000 ms pause at 24000 Hz = 24000 silent samples
      const pauseMs = 100; // 100 ms = 2400 samples
      final combined = WavConcatenator.concatenateChunks(
        chunks: [chunk1, chunk2],
        pausesMs: [pauseMs],
        sampleRate: 24000,
      );

      final expectedSamples = 4 + 2400 + 4;
      expect(combined.length, equals(expectedSamples));

      // First chunk starts smoothly
      expect(combined[0], closeTo(0.0, 0.05)); // Due to fade-in
      // Middle is silence (zeros)
      expect(combined[100], equals(0.0));
      expect(combined[1000], equals(0.0));
    });

    test('Creates valid standard 44-byte RIFF/WAVE header', () {
      // 1 second of 24000 Hz mono audio
      final samples = Float32List(24000);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.5;
      }

      final bytes = WavConcatenator.createWavBytes(samples, sampleRate: 24000);

      expect(bytes.length, equals(44 + 24000 * 2)); // 44 header + 48000 payload

      // Verify RIFF header
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      // Verify WAVE
      expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      // Verify "fmt "
      expect(String.fromCharCodes(bytes.sublist(12, 16)), equals('fmt '));

      final byteData = ByteData.sublistView(bytes);

      // Audio format == 1 (PCM)
      expect(byteData.getUint16(20, Endian.little), equals(1));
      // Num channels == 1 (Mono)
      expect(byteData.getUint16(22, Endian.little), equals(1));
      // Sample rate == 24000
      expect(byteData.getUint32(24, Endian.little), equals(24000));
      // Byte rate == 24000 * 2 = 48000
      expect(byteData.getUint32(28, Endian.little), equals(48000));
      // Block align == 2
      expect(byteData.getUint16(32, Endian.little), equals(2));
      // Bits per sample == 16
      expect(byteData.getUint16(34, Endian.little), equals(16));

      // Verify "data"
      expect(String.fromCharCodes(bytes.sublist(36, 40)), equals('data'));
      // Data size == 48000
      expect(byteData.getUint32(40, Endian.little), equals(48000));
    });

    test('Clamps extreme float values to 16-bit signed PCM range', () {
      final samples = Float32List.fromList([-2.5, 2.5, 0.0]);
      final bytes = WavConcatenator.createWavBytes(samples, sampleRate: 24000);
      final byteData = ByteData.sublistView(bytes);

      // Index 0: clamped to -1.0 -> -32767 / -32768
      final pcm0 = byteData.getInt16(44, Endian.little);
      expect(pcm0, equals(-32767));

      // Index 1: clamped to 1.0 -> 32767
      final pcm1 = byteData.getInt16(46, Endian.little);
      expect(pcm1, equals(32767));

      // Index 2: 0.0 -> 0
      final pcm2 = byteData.getInt16(48, Endian.little);
      expect(pcm2, equals(0));
    });

    test('normalizeLoudness raises a quiet chunk to target RMS', () {
      final samples = Float32List(2400);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.05 * sin(2 * pi * 200 * i / 24000);
      }

      final normalized = WavConcatenator.normalizeLoudness(samples);
      final rms = sqrt(
        normalized.fold<double>(0.0, (sum, sample) => sum + sample * sample) /
            normalized.length,
      );

      expect(rms, closeTo(0.1, 0.01));
    });

    test('normalizeLoudness lowers a loud chunk to target RMS', () {
      final samples = Float32List(2400);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.2 * sin(2 * pi * 200 * i / 24000);
      }

      final normalized = WavConcatenator.normalizeLoudness(samples);
      final rms = sqrt(
        normalized.fold<double>(0.0, (sum, sample) => sum + sample * sample) /
            normalized.length,
      );

      expect(rms, closeTo(0.1, 0.01));
    });

    test('normalizeLoudness keeps peaks under the ceiling', () {
      final samples = Float32List.fromList(List<double>.filled(2400, 0.01));
      samples[1200] = 0.5;

      final normalized = WavConcatenator.normalizeLoudness(samples);
      final maxAbsolute = normalized
          .map((sample) => sample.abs())
          .reduce((a, b) => a > b ? a : b);

      expect(maxAbsolute, lessThanOrEqualTo(0.98 + 1e-6));
    });

    test('normalizeLoudness leaves silence and does not mutate input', () {
      final silence = Float32List(8);
      final normalizedSilence = WavConcatenator.normalizeLoudness(silence);

      expect(normalizedSilence.length, equals(silence.length));
      expect(normalizedSilence.every((sample) => sample == 0.0), isTrue);
      expect(identical(normalizedSilence, silence), isFalse);

      final input = Float32List.fromList([0.1, -0.2, 0.3]);
      final original = Float32List.fromList(input);
      WavConcatenator.normalizeLoudness(input);

      expect(input, orderedEquals(original));
    });
  });
}
