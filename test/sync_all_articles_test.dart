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
}
