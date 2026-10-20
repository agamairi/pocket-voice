import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class WavConcatenator {
  /// Concatenates audio chunks with silence pauses between them.
  /// Applies a tiny fade-in/fade-out (0.5ms) at chunk boundaries to prevent audio clicks.
  static Float32List concatenateChunks({
    required List<Float32List> chunks,
    required List<int> pausesMs,
    int sampleRate = 24000,
  }) {
    if (chunks.isEmpty) {
      return Float32List(0);
    }
    if (chunks.length == 1) {
      return chunks.first;
    }

    // Calculate total sample count
    int totalSamples = 0;
    for (int i = 0; i < chunks.length; i++) {
      totalSamples += chunks[i].length;
      if (i < pausesMs.length) {
        final pauseSamples = (pausesMs[i] * sampleRate) ~/ 1000;
        totalSamples += pauseSamples;
      }
    }

    final combined = Float32List(totalSamples);
    int offset = 0;
    const edgeFadeSeconds = 0.0005; // 0.5ms fade at each chunk edge
    final fadeLength = (sampleRate * edgeFadeSeconds).round();

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final chunkLen = chunk.length;

      // Copy chunk with gentle boundary fading
      for (int s = 0; s < chunkLen; s++) {
        double factor = 1.0;
        if (s < fadeLength && fadeLength > 0) {
          factor = s / fadeLength;
        } else if (s >= chunkLen - fadeLength && fadeLength > 0) {
          factor = (chunkLen - 1 - s) / fadeLength;
        }
        combined[offset + s] = chunk[s] * factor;
      }
      offset += chunkLen;

      // Insert pause (silence: zeros are already default in Float32List)
      if (i < pausesMs.length) {
        final pauseSamples = (pausesMs[i] * sampleRate) ~/ 1000;
        offset += pauseSamples;
      }
    }

    return combined;
  }

  /// Normalizes a chunk to a target RMS level without mutating its input.
  static Float32List normalizeLoudness(
    Float32List samples, {
    double targetRms = 0.1,
    double maxGain = 4.0,
    double peakCeiling = 0.98,
  }) {
    final normalized = Float32List.fromList(samples);
    if (samples.isEmpty) return normalized;

    double sumSquares = 0.0;
    double peak = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
      if (sample.abs() > peak) peak = sample.abs();
    }

    final rms = sqrt(sumSquares / samples.length);
    if (rms < 1e-6) return normalized;

    var gain = targetRms / rms;
    if (gain > maxGain) gain = maxGain;
    if (peak * gain > peakCeiling) {
      gain = peakCeiling / peak;
    }

    for (int i = 0; i < normalized.length; i++) {
      normalized[i] = samples[i] * gain;
    }
    return normalized;
  }

  /// Creates a standard 44-byte RIFF/WAVE header + 16-bit PCM payload.
  static Uint8List createWavBytes(Float32List samples, {int sampleRate = 24000}) {
    final numSamples = samples.length;
    final numChannels = 1; // Mono
    final bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final subChunk2Size = numSamples * (bitsPerSample ~/ 8);
    final chunkSize = 36 + subChunk2Size;

    final byteData = ByteData(44 + subChunk2Size);

    // RIFF chunk descriptor
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, chunkSize, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6d); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // "data" sub-chunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, subChunk2Size, Endian.little);

    // Write 16-bit PCM samples with clamping
    int byteOffset = 44;
    for (int i = 0; i < numSamples; i++) {
      double sample = samples[i];
      // Clamp between -1.0 and 1.0
      if (sample > 1.0) sample = 1.0;
      if (sample < -1.0) sample = -1.0;

      // Scale to 16-bit signed int [-32768, 32767]
      final pcm16 = (sample * 32767.0).round();
      byteData.setInt16(byteOffset, pcm16, Endian.little);
      byteOffset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  /// Writes the 24 kHz WAV file to disk.
  static Future<File> writeWavFile({
    required String filePath,
    required Float32List samples,
    int sampleRate = 24000,
  }) async {
    final bytes = createWavBytes(samples, sampleRate: sampleRate);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
  }
}
