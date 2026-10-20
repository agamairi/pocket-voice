import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The result of checking the latest GitHub release against the app version.
class UpdateCheckResult {
  /// The version passed to the update check.
  final String currentVersion;

  /// The latest release version without a leading `v`.
  final String latestVersion;

  /// The release page URL, or the repository releases page when unavailable.
  final String releaseUrl;

  /// Creates an update check result.
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
  });

  /// Whether the latest release is strictly newer than the current version.
  bool get isUpdateAvailable {
    return UpdateChecker.compareVersions(latestVersion, currentVersion) > 0;
  }
}

/// An error encountered while checking for an app update.
class UpdateCheckException implements Exception {
  /// A user-facing description of the error.
  final String message;

  /// Creates an update check exception.
  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}

/// Checks GitHub for the latest Pocket Voice release.
class UpdateChecker {
  /// The GitHub repository owner.
  static const String repoOwner = 'agamairi';

  /// The GitHub repository name.
  static const String repoName = 'pocket-voice';

  /// The repository releases page.
  static const String releasesPage =
      'https://github.com/agamairi/pocket-voice/releases';

  /// The GitHub API endpoint for the latest release.
  static const String latestReleaseApi =
      'https://api.github.com/repos/agamairi/pocket-voice/releases/latest';

  /// Returns -1, 0 or 1 comparing dotted numeric versions.
  ///
  /// A leading `v`, build metadata after `+`, missing components, and
  /// non-numeric components are ignored or treated as zero as appropriate.
  static int compareVersions(String a, String b) {
    final left = _versionComponents(a);
    final right = _versionComponents(b);
    final length = left.length > right.length ? left.length : right.length;

    for (var i = 0; i < length; i++) {
      final leftComponent = i < left.length ? left[i] : 0;
      final rightComponent = i < right.length ? right[i] : 0;
      if (leftComponent > rightComponent) return 1;
      if (leftComponent < rightComponent) return -1;
    }
    return 0;
  }

  /// Parses the JSON body returned by the latest release endpoint.
  static UpdateCheckResult parseLatestRelease(
    String body, {
    required String currentVersion,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateCheckException(
        'GitHub returned an unexpected response.',
      );
    }

    final tagName = decoded['tag_name'];
    if (tagName is! String) {
      throw const UpdateCheckException(
        'GitHub returned a release without a version tag.',
      );
    }

    final latestVersion = _stripVersionPrefix(tagName);
    final htmlUrl = decoded['html_url'];
    return UpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseUrl: htmlUrl is String && htmlUrl.isNotEmpty
          ? htmlUrl
          : releasesPage,
    );
  }

  /// Fetches and compares the latest GitHub release with [currentVersion].
  static Future<UpdateCheckResult> check({
    required String currentVersion,
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient
          .get(
            Uri.parse(latestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'pocket-voice-update-check',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw UpdateCheckException(
          'GitHub returned an unexpected response (HTTP ${response.statusCode}).',
        );
      }

      try {
        return parseLatestRelease(
          response.body,
          currentVersion: currentVersion,
        );
      } on FormatException {
        throw const UpdateCheckException(
          'GitHub returned an invalid response. Please try again.',
        );
      }
    } on UpdateCheckException {
      rethrow;
    } on TimeoutException {
      throw const UpdateCheckException(
        'The update check timed out. Please try again.',
      );
    } on http.ClientException {
      throw const UpdateCheckException(
        'Could not reach GitHub. Check your connection and try again.',
      );
    } on FormatException {
      throw const UpdateCheckException(
        'GitHub returned an invalid response. Please try again.',
      );
    } catch (_) {
      throw const UpdateCheckException(
        'Could not reach GitHub. Check your connection and try again.',
      );
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  static List<int> _versionComponents(String version) {
    final normalized = _stripVersionPrefix(version).split('+').first;
    return normalized
        .split('.')
        .map((component) => int.tryParse(component) ?? 0)
        .toList();
  }

  static String _stripVersionPrefix(String version) {
    final trimmed = version.trim();
    return trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
  }
}
