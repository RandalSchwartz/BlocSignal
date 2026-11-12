import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

File _resolveRepoFile(String relativePath) {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final candidate = File('${dir.path}/$relativePath');
    if (candidate.existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  return File(relativePath);
}

void main() {
  group('Website Security Headers & External Link Hardening (Issue #426)', () {
    test('(Issue #426: F01) firebase.json defines comprehensive HTTP security '
        'headers', () {
      final firebaseJsonFile = _resolveRepoFile('firebase.json');
      expect(
        firebaseJsonFile.existsSync(),
        isTrue,
        reason: 'firebase.json must exist at repo root',
      );

      final jsonMap = jsonDecode(
        firebaseJsonFile.readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        jsonMap,
        contains('hosting'),
        reason: 'firebase.json must have a "hosting" section',
      );

      final hosting = jsonMap['hosting'] as Map<String, dynamic>;
      expect(
        hosting,
        contains('headers'),
        reason: 'hosting section must define "headers"',
      );

      final headersList = hosting['headers'] as List<dynamic>;
      expect(
        headersList,
        isNotEmpty,
        reason: 'headers list must contain at least one header rule',
      );

      final globalRule = headersList.firstWhere(
        (h) => h is Map<String, dynamic> && h['source'] == '**',
        orElse: () => null,
      ) as Map<String, dynamic>?;

      expect(
        globalRule,
        isNotNull,
        reason: 'Must define a global header rule with source "**"',
      );

      final rawHeaders = globalRule!['headers'] as List<dynamic>;
      final headerMap = <String, String>{};
      for (final item in rawHeaders) {
        if (item is Map<String, dynamic>) {
          headerMap[item['key'] as String] = item['value'] as String;
        }
      }

      // Verify Content-Security-Policy
      expect(headerMap, contains('Content-Security-Policy'));
      final csp = headerMap['Content-Security-Policy']!;
      expect(csp, contains("default-src 'self'"));
      expect(
        csp,
        contains(
          "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.googletagmanager.com",
        ),
      );
      expect(
        csp,
        contains(
          "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
        ),
      );
      expect(csp, contains("font-src 'self' https://fonts.gstatic.com data:"));
      expect(csp, contains("img-src 'self' data: https:"));
      expect(
        csp,
        contains(
          "connect-src 'self' https://www.google-analytics.com https://*.google-analytics.com https://analytics.google.com https://*.analytics.google.com https://www.googletagmanager.com",
        ),
      );
      expect(
        csp,
        contains(
          "frame-src 'self' https://www.youtube-nocookie.com https://www.youtube.com",
        ),
      );
      expect(csp, contains("frame-ancestors 'none'"));
      expect(csp, contains("object-src 'none'"));
      expect(csp, contains("base-uri 'self'"));

      // Verify X-Content-Type-Options
      expect(headerMap, contains('X-Content-Type-Options'));
      expect(headerMap['X-Content-Type-Options'], equals('nosniff'));

      // Verify X-Frame-Options
      expect(headerMap, contains('X-Frame-Options'));
      expect(headerMap['X-Frame-Options'], equals('DENY'));

      // Verify Referrer-Policy
      expect(headerMap, contains('Referrer-Policy'));
      expect(
        headerMap['Referrer-Policy'],
        equals('strict-origin-when-cross-origin'),
      );

      // Verify Strict-Transport-Security
      expect(headerMap, contains('Strict-Transport-Security'));
      expect(
        headerMap['Strict-Transport-Security'],
        equals('max-age=31536000; includeSubDomains; preload'),
      );

      // Verify Permissions-Policy
      expect(headerMap, contains('Permissions-Policy'));
      expect(
        headerMap['Permissions-Policy'],
        equals('camera=(), microphone=(), geolocation=()'),
      );
    });

    test('(Issue #426: F03) external Target.blank links across modified files '
        'include rel="noopener noreferrer"', () {
      const modifiedFiles = [
        'website/lib/src/components/navbar.dart',
        'website/lib/src/components/hero.dart',
        'website/lib/src/components/package_catalog.dart',
        'website/lib/src/pages/publications_page.dart',
        'website/tool/update_publications.dart',
      ];

      for (final relativePath in modifiedFiles) {
        final file = _resolveRepoFile(relativePath);
        expect(
          file.existsSync(),
          isTrue,
          reason: '$relativePath must exist on disk',
        );

        final content = file.readAsStringSync();

        // Find all occurrences of Target.blank
        final targetBlankMatches = RegExp(r'target:\s*Target\.blank')
            .allMatches(content);
        expect(
          targetBlankMatches,
          isNotEmpty,
          reason: '$relativePath should contain Target.blank usages',
        );

        for (final match in targetBlankMatches) {
          final start = (match.start - 300).clamp(0, content.length);
          final end = (match.end + 300).clamp(0, content.length);
          final snippet = content.substring(start, end);

          expect(
            snippet,
            contains("'rel': 'noopener noreferrer'"),
            reason:
                'Target.blank at offset ${match.start} in $relativePath '
                'must specify rel="noopener noreferrer". Snippet: $snippet',
          );
        }
      }
    });
  });
}
