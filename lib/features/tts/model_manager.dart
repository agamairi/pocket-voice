import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum ModelStatus {
  notInstalled,
  downloading,
  extracting,
  ready,
  error,
}

class ModelManager {
  static const String modelArchiveUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-pocket-tts-int8-2026-01-26.tar.bz2';

  static const String modelDirName = 'sherpa-onnx-pocket-tts-int8-2026-01-26';

  static const List<String> requiredFiles = [
    'lm_flow.int8.onnx',
    'lm_main.int8.onnx',
    'encoder.onnx',
    'decoder.int8.onnx',
    'text_conditioner.onnx',
    'vocab.json',
    'token_scores.json',
  ];

  static const int estimatedArchiveSize = 98336520; // ~94 MB

  http.Client? _activeClient;
  bool _isCancelled = false;

  /// Returns the base directory for model storage in app-private storage.
  Future<Directory> getModelDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/models/$modelDirName');
    return modelDir;
  }

  /// Checks if all required PocketTTS model files are present and valid.
  Future<bool> isModelInstalled() async {
    try {
      final modelDir = await getModelDirectory();
      if (!await modelDir.exists()) {
        return false;
      }

      for (final fileName in requiredFiles) {
        final file = File('${modelDir.path}/$fileName');
        if (!await file.exists() || await file.length() == 0) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies the presence and minimum sizes of all model files.
  Future<bool> verifyModelFiles() async {
    return isModelInstalled();
  }

  /// Computes the total on-disk size of the installed model files.
  Future<int> getInstalledModelSizeBytes() async {
    final modelDir = await getModelDirectory();
    if (!await modelDir.exists()) return 0;

    int totalBytes = 0;
    try {
      await for (final entity in modelDir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (_) {}
    return totalBytes;
  }

  /// Cancels any in-progress download.
  void cancelDownload() {
    _isCancelled = true;
    _activeClient?.close();
    _activeClient = null;
  }

  /// Downloads and unpacks the official PocketTTS archive.
  Future<bool> downloadAndInstall({
    required void Function(int received, int total, double progress) onProgress,
    required void Function(String message) onStatus,
  }) async {
    _isCancelled = false;
    final docsDir = await getApplicationDocumentsDirectory();
    final tempArchiveFile = File('${docsDir.path}/models/pocket_tts_temp.tar.bz2');
    final targetModelDir = await getModelDirectory();

    try {
      await tempArchiveFile.parent.create(recursive: true);
      if (await tempArchiveFile.exists()) {
        await tempArchiveFile.delete();
      }

      onStatus('Connecting to model repository...');
      _activeClient = http.Client();
      final request = http.Request('GET', Uri.parse(modelArchiveUrl));
      final response = await _activeClient!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with server status ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? estimatedArchiveSize;
      int receivedBytes = 0;
      final sink = tempArchiveFile.openWrite();

      onStatus('Downloading PocketTTS INT8 model...');

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          if (await tempArchiveFile.exists()) {
            await tempArchiveFile.delete();
          }
          throw Exception('Download cancelled by user.');
        }

        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = (totalBytes > 0) ? (receivedBytes / totalBytes) : 0.0;
        onProgress(receivedBytes, totalBytes, progress);
      }

      await sink.flush();
      await sink.close();
      _activeClient = null;

      if (_isCancelled) {
        throw Exception('Download cancelled by user.');
      }

      onStatus('Decompressing and installing model files...');
      onProgress(receivedBytes, totalBytes, 1.0);

      // Run archive decompression in background isolate to keep UI completely smooth
      final archiveBytes = await tempArchiveFile.readAsBytes();
      final targetPath = targetModelDir.path;

      await Isolate.run(() {
        final bz2 = BZip2Decoder().decodeBytes(archiveBytes);
        final tar = TarDecoder().decodeBytes(bz2);

        for (final entry in tar) {
          if (!entry.isFile) continue;
          // Archive contains prefix e.g. "sherpa-onnx-pocket-tts-int8-2026-01-26/filename"
          final parts = entry.name.split('/');
          final relativeName = parts.skip(1).join('/');
          if (relativeName.isEmpty) continue;

          final destFile = File('$targetPath/$relativeName');
          destFile.parent.createSync(recursive: true);
          destFile.writeAsBytesSync(entry.content as List<int>);
        }
      });

      // Remove temp archive file
      if (await tempArchiveFile.exists()) {
        await tempArchiveFile.delete();
      }

      onStatus('Verifying installed model files...');
      final verified = await verifyModelFiles();
      if (!verified) {
        throw Exception('Model verification failed: Missing required model components.');
      }

      onStatus('Model ready for offline use!');
      return true;
    } catch (e) {
      if (await tempArchiveFile.exists()) {
        try {
          await tempArchiveFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      _activeClient = null;
    }
  }

  /// Deletes the installed model files to free storage.
  Future<void> deleteModel() async {
    final modelDir = await getModelDirectory();
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
  }
}
