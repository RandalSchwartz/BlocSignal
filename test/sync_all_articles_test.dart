import 'dart:io';

import 'package:test/test.dart';

import '../tool/sync_all_articles.dart' as sync_tool;

void main() {
  group('sync_all_articles slug sanitization and containment (Issue #418)', () {
    test('preserves valid slugs', () {
      expect(
        sync_tool.sanitizeSlug('my-article_01', id: 1),
        equals('my-article_01'),
      );
      expect(
        sync_tool.sanitizeSlug('BlocSignal_Release-2026', id: 2),
        equals('BlocSignal_Release-2026'),
      );
    });

    test(
      'falls back to article-<id> for null, empty, or punctuation slugs',
      () {
        expect(sync_tool.sanitizeSlug(null, id: 101), equals('article-101'));
        expect(sync_tool.sanitizeSlug('', id: 102), equals('article-102'));
        expect(
          sync_tool.sanitizeSlug('   \t\n ', id: 103),
          equals('article-103'),
        );
        expect(
          sync_tool.sanitizeSlug('...---___', id: 104),
          equals('article-104'),
        );
        expect(
          sync_tool.sanitizeSlug(r'!@#$%^&*()', id: 105),
          equals('article-105'),
        );
      },
    );

    test(
      'neutralizes path traversal and separator payloads in sanitizeSlug',
      () {
        final payloads = <String, String>{
          '../../etc/passwd': 'etc-passwd',
          '../foo/bar': 'foo-bar',
          'sub/dir': 'sub-dir',
          r'..\evil': 'evil',
          'foo\x00bar': 'foo-bar',
        };

        for (final entry in payloads.entries) {
          expect(
            sync_tool.sanitizeSlug(entry.key, id: 42),
            equals(entry.value),
            reason: 'Expected ${entry.key} to sanitize to ${entry.value}',
          );
        }

        expect(sync_tool.sanitizeSlug('..', id: 42), equals('article-42'));
      },
    );

    test('neutralizes or rejects malicious id in fallback', () {
      final result = sync_tool.sanitizeSlug(null, id: '../evil');
      expect(result, equals('article-evil'));
      expect(RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(result), isTrue);

      expect(
        () => sync_tool.sanitizeSlug('', id: '../..'),
        throwsArgumentError,
      );
      expect(() => sync_tool.sanitizeSlug('', id: ''), throwsArgumentError);
    });

    test('throws ArgumentError when slug is empty or null and id is null', () {
      expect(() => sync_tool.sanitizeSlug(null, id: null), throwsArgumentError);
      expect(() => sync_tool.sanitizeSlug('', id: null), throwsArgumentError);
      expect(
        () => sync_tool.sanitizeSlug('...', id: null),
        throwsArgumentError,
      );
    });

    test('rejects traversal payloads in resolveContainedArticleFile', () {
      final tempRoot = Directory.systemTemp.createTempSync(
        'sync_articles_dir_',
      );
      addTearDown(() => tempRoot.deleteSync(recursive: true));

      final articlesDir = Directory('${tempRoot.path}/articles')..createSync();
      const payloads = [
        '../../etc/passwd',
        '../foo/bar',
        'sub/dir',
        r'..\evil',
        'foo\x00bar',
        '..',
        '.',
        '',
      ];

      for (final payload in payloads) {
        expect(
          () => sync_tool.resolveContainedArticleFile(articlesDir, payload),
          throwsArgumentError,
          reason: 'Expected payload "$payload" to throw ArgumentError',
        );
      }
    });

    test('rejects symlink escape targeting a file outside articlesDir', () {
      final tempRoot = Directory.systemTemp.createTempSync(
        'sync_articles_sym_',
      );
      addTearDown(() => tempRoot.deleteSync(recursive: true));

      final articlesDir = Directory('${tempRoot.path}/articles')..createSync();
      final outsideDir = Directory('${tempRoot.path}/outside')..createSync();
      final outsideFile = File('${outsideDir.path}/secret.md')
        ..writeAsStringSync('sensitive');

      Link('${articlesDir.path}/escaped-slug.md').createSync(outsideFile.path);

      expect(
        () =>
            sync_tool.resolveContainedArticleFile(articlesDir, 'escaped-slug'),
        throwsArgumentError,
      );
    });

    test('resolves valid contained file strictly inside articlesDir', () {
      final tempRoot = Directory.systemTemp.createTempSync('sync_articles_ok_');
      addTearDown(() => tempRoot.deleteSync(recursive: true));

      final articlesDir = Directory('${tempRoot.path}/articles')..createSync();
      final resolved = sync_tool.resolveContainedArticleFile(
        articlesDir,
        'my-article_01',
      );

      final canonicalDir = articlesDir.resolveSymbolicLinksSync();
      expect(
        resolved.path,
        equals('$canonicalDir${Platform.pathSeparator}my-article_01.md'),
      );
      expect(resolved.parent.path, equals(canonicalDir));
    });
  });

  group('sync_all_articles HTTP 429 rate-limit retry and backoff', () {
    test('parseRetryAfter parses integer seconds and clamps to maxDelay', () {
      expect(
        sync_tool.parseRetryAfter('5', fallback: const Duration(seconds: 2)),
        equals(const Duration(seconds: 5)),
      );
      expect(
        sync_tool.parseRetryAfter(' 0 ', fallback: const Duration(seconds: 2)),
        equals(Duration.zero),
      );
      expect(
        sync_tool.parseRetryAfter(
          '120',
          fallback: const Duration(seconds: 2),
          maxDelay: const Duration(seconds: 30),
        ),
        equals(const Duration(seconds: 30)),
      );
    });

    test('parseRetryAfter parses HTTP-date relative to now and clamps', () {
      final now = DateTime.utc(2026, 11, 21, 12);
      expect(
        sync_tool.parseRetryAfter(
          HttpDate.format(now.add(const Duration(seconds: 12))),
          fallback: const Duration(seconds: 2),
          now: now,
        ),
        equals(const Duration(seconds: 12)),
      );
      expect(
        sync_tool.parseRetryAfter(
          HttpDate.format(now.subtract(const Duration(seconds: 5))),
          fallback: const Duration(seconds: 2),
          now: now,
        ),
        equals(Duration.zero),
      );
      expect(
        sync_tool.parseRetryAfter(
          HttpDate.format(now.add(const Duration(minutes: 5))),
          fallback: const Duration(seconds: 2),
          now: now,
          maxDelay: const Duration(seconds: 45),
        ),
        equals(const Duration(seconds: 45)),
      );
    });

    test(
      'parseRetryAfter falls back cleanly on null, negative, or invalid',
      () {
        expect(
          sync_tool.parseRetryAfter(null, fallback: const Duration(seconds: 4)),
          equals(const Duration(seconds: 4)),
        );
        expect(
          sync_tool.parseRetryAfter(
            '   ',
            fallback: const Duration(seconds: 4),
          ),
          equals(const Duration(seconds: 4)),
        );
        expect(
          sync_tool.parseRetryAfter('-3', fallback: const Duration(seconds: 4)),
          equals(const Duration(seconds: 4)),
        );
        expect(
          sync_tool.parseRetryAfter(
            'not-a-date',
            fallback: const Duration(seconds: 90),
          ),
          equals(const Duration(seconds: 60)),
        );
      },
    );

    test(
      'fetchWithRateLimitRetry returns immediately on 200 or non-429',
      () async {
        final sleeps = <Duration>[];
        var calls = 0;

        final ok = await sync_tool.fetchWithRateLimitRetry(() async {
          calls++;
          return (statusCode: 200, body: 'ok', retryAfter: null);
        }, sleep: (d) async => sleeps.add(d));
        expect(ok.statusCode, equals(200));
        expect(ok.body, equals('ok'));
        expect(calls, equals(1));
        expect(sleeps, isEmpty);

        calls = 0;
        final notFound = await sync_tool.fetchWithRateLimitRetry(() async {
          calls++;
          return (statusCode: 404, body: 'missing', retryAfter: '10');
        }, sleep: (d) async => sleeps.add(d));
        expect(notFound.statusCode, equals(404));
        expect(calls, equals(1));
        expect(sleeps, isEmpty);
      },
    );

    test(
      'fetchWithRateLimitRetry retries 429 using Retry-After and backoff',
      () async {
        final sleeps = <Duration>[];
        final retries = <(int attempt, Duration delay)>[];
        var attempt = 0;
        final responses = [
          (statusCode: 429, body: 'slow down', retryAfter: '3'),
          (statusCode: 429, body: 'still busy', retryAfter: null),
          (statusCode: 429, body: 'busy again', retryAfter: null),
          (statusCode: 200, body: '{"ok":true}', retryAfter: null),
        ];

        final result = await sync_tool.fetchWithRateLimitRetry(
          () async => responses[attempt++],
          sleep: (d) async => sleeps.add(d),
          onRetry: (retryAttempt, delay) => retries.add((retryAttempt, delay)),
        );

        expect(result.statusCode, equals(200));
        expect(result.body, equals('{"ok":true}'));
        expect(attempt, equals(4));
        expect(
          sleeps,
          equals([
            const Duration(seconds: 3), // Retry-After header from attempt 0
            const Duration(seconds: 4), // 2s << 1 on attempt 1
            const Duration(seconds: 8), // 2s << 2 on attempt 2
          ]),
        );
        expect(
          retries,
          equals([
            (1, const Duration(seconds: 3)),
            (2, const Duration(seconds: 4)),
            (3, const Duration(seconds: 8)),
          ]),
        );
      },
    );

    test(
      'fetchWithRateLimitRetry returns final 429 when maxRetries exhausted',
      () async {
        final sleeps = <Duration>[];
        var calls = 0;

        final result = await sync_tool.fetchWithRateLimitRetry(
          () async {
            calls++;
            return (statusCode: 429, body: 'rate limited', retryAfter: null);
          },
          maxRetries: 2,
          initialBackoff: const Duration(seconds: 1),
          sleep: (d) async => sleeps.add(d),
        );

        expect(result.statusCode, equals(429));
        expect(result.body, equals('rate limited'));
        expect(calls, equals(3));
        expect(
          sleeps,
          equals([const Duration(seconds: 1), const Duration(seconds: 2)]),
        );
      },
    );
  });
}
