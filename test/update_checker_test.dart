import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocket_voice/shared/utils/update_checker.dart';

void main() {
  group('UpdateChecker.compareVersions', () {
    test('compares dotted numeric versions', () {
      expect(UpdateChecker.compareVersions('1.2.0', '1.2.0'), 0);
      expect(UpdateChecker.compareVersions('1.10.0', '1.9.2'), 1);
      expect(UpdateChecker.compareVersions('v1.2.0', '1.2.0'), 0);
      expect(UpdateChecker.compareVersions('1.2.0+3', '1.2.0'), 0);
      expect(UpdateChecker.compareVersions('1.2', '1.2.0'), 0);
      expect(UpdateChecker.compareVersions('1.2.1', '1.3.0'), -1);
    });
  });

  group('UpdateChecker.parseLatestRelease', () {
    test('parses the release tag and URL', () {
      final result = UpdateChecker.parseLatestRelease(
        '{"tag_name":"v1.3.0","html_url":"https://github.com/agamairi/pocket-voice/releases/tag/v1.3.0"}',
        currentVersion: '1.2.0',
      );

      expect(result.latestVersion, '1.3.0');
      expect(
        result.releaseUrl,
        'https://github.com/agamairi/pocket-voice/releases/tag/v1.3.0',
      );
      expect(result.isUpdateAvailable, isTrue);
    });

    test('reports no update when versions are equal', () {
      final result = UpdateChecker.parseLatestRelease(
        '{"tag_name":"v1.3.0"}',
        currentVersion: '1.3.0',
      );

      expect(result.isUpdateAvailable, isFalse);
    });

    test('throws when tag_name is missing', () {
      expect(
        () => UpdateChecker.parseLatestRelease(
          '{"html_url":"https://example.com/release"}',
          currentVersion: '1.2.0',
        ),
        throwsA(isA<UpdateCheckException>()),
      );
    });
  });

  group('UpdateChecker.check', () {
    test('returns the release and sends required headers', () async {
      late http.Request request;
      final client = MockClient((receivedRequest) async {
        request = receivedRequest;
        return http.Response(
          '{"tag_name":"v1.3.0","html_url":"https://example.com/release"}',
          200,
        );
      });

      final result = await UpdateChecker.check(
        currentVersion: '1.2.0',
        client: client,
      );

      expect(result.latestVersion, '1.3.0');
      expect(result.releaseUrl, 'https://example.com/release');
      expect(result.isUpdateAvailable, isTrue);
      expect(request.headers['user-agent'], 'pocket-voice-update-check');
      expect(request.headers['accept'], 'application/vnd.github+json');
    });

    test('throws on a non-200 response', () async {
      final client = MockClient(
        (_) async => http.Response('forbidden', 403),
      );

      await expectLater(
        UpdateChecker.check(currentVersion: '1.2.0', client: client),
        throwsA(
          isA<UpdateCheckException>().having(
            (exception) => exception.message,
            'message',
            contains('403'),
          ),
        ),
      );
    });

    test('wraps client errors', () async {
      final client = MockClient((_) async {
        throw http.ClientException('connection failed');
      });

      await expectLater(
        UpdateChecker.check(currentVersion: '1.2.0', client: client),
        throwsA(isA<UpdateCheckException>()),
      );
    });
  });
}
