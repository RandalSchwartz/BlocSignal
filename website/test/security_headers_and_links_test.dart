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

/// Helper model for testing PublicationItem.isHttps logic directly in unit tests
class const TestPublicationItem({required final String url}) {
  bool get isHttps => url.startsWith('https://');
}

void main() {
  group('Security Headers & External Link Hardening (Issue #426)', () {
    test('(Issue #426: F01) firebase.json defines comprehensive HTTP security headers', () {
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

      // Verify remaining security headers
      expect(headerMap['X-Content-Type-Options'], equals('nosniff'));
      expect(headerMap['X-Frame-Options'], equals('DENY'));
      expect(
        headerMap['Referrer-Policy'],
        equals('strict-origin-when-cross-origin'),
      );
      expect(
        headerMap['Strict-Transport-Security'],
        equals('max-age=31536000; includeSubDomains; preload'),
      );
      expect(
        headerMap['Permissions-Policy'],
        equals('camera=(), microphone=(), geolocation=()'),
      );
    });

    test('(Issue #426: F02) PublicationsPage enforces https:// schemes on all PublicationItem entries', () {
      final pubPageFile = _resolveRepoFile(
        'website/lib/src/pages/publications_page.dart',
      );
      expect(
        pubPageFile.existsSync(),
        isTrue,
        reason: 'publications_page.dart must exist',
      );

      final content = pubPageFile.readAsStringSync();

      // 1. Verify PublicationItem has isHttps getter
      expect(
        content,
        contains("bool get isHttps => url.startsWith('https://');"),
        reason: 'PublicationItem must define isHttps getter',
      );

      // 2. Verify PublicationsPage exposes static const allPublications = _publications;
      expect(
        content,
        contains('static const allPublications = _publications;'),
        reason: 'PublicationsPage must expose static const allPublications = _publications;',
      );

      // 3. Verify filteredPublications applies isHttps validation filter
      expect(
        RegExp(
          r'filteredPublications\s*\.\s*where\s*\(\s*\(\s*pub\s*\)\s*=>\s*pub\.isHttps\s*\)',
        ).hasMatch(content),
        isTrue,
        reason: 'PublicationsPage must filter publications through pub.isHttps',
      );

      // 4. Extract all URL entries in PublicationItem declarations and verify they start with https://
      final urlMatches = RegExp(r"url:\s*'([^']+)'").allMatches(content);
      expect(
        urlMatches,
        isNotEmpty,
        reason: 'Must find publication URLs in publications_page.dart',
      );

      for (final match in urlMatches) {
        final url = match.group(1)!;
        expect(
          url.startsWith('https://'),
          isTrue,
          reason:
              'URL "$url" in publications_page.dart must start with https://',
        );
      }

      // 5. Unit test TestPublicationItem / isHttps semantics
      const securePub = TestPublicationItem(url: 'https://dev.to/example');
      expect(securePub.isHttps, isTrue);

      const insecurePub = TestPublicationItem(url: 'http://dev.to/example');
      expect(insecurePub.isHttps, isFalse);

      const nonHttpPub = TestPublicationItem(url: 'ftp://dev.to/example');
      expect(nonHttpPub.isHttps, isFalse);
    });

    test('(Issue #426: F03) external Target.blank links across modified files include rel="noopener noreferrer"', () {
      final targetFiles = [
        'website/lib/src/components/navbar.dart',
        'website/lib/src/components/hero.dart',
        'website/lib/src/components/package_catalog.dart',
        'website/lib/src/pages/publications_page.dart',
        'website/tool/update_publications.dart',
      ];

      for (final filePath in targetFiles) {
        final file = _resolveRepoFile(filePath);
        expect(
          file.existsSync(),
          isTrue,
          reason: '$filePath must exist in repository',
        );

        final content = file.readAsStringSync();
        final blankMatches = RegExp(r'Target\.blank').allMatches(content);
        expect(
          blankMatches,
          isNotEmpty,
          reason: '$filePath must contain at least one Target.blank link',
        );

        // For each occurrence of Target.blank, inspect enclosing block to ensure
        // rel="noopener noreferrer" is set.
        for (final match in blankMatches) {
          final startIdx = match.start;
          final windowStart = (startIdx - 300) < 0 ? 0 : startIdx - 300;
          final windowEnd = (startIdx + 300) > content.length
              ? content.length
              : startIdx + 300;
          final surroundingCode = content.substring(windowStart, windowEnd);

          final hasRelNoopener =
              surroundingCode.contains("'rel': 'noopener noreferrer'") ||
              surroundingCode.contains('"rel": "noopener noreferrer"') ||
              surroundingCode.contains("'rel': \"noopener noreferrer\"");

          expect(
            hasRelNoopener,
            isTrue,
            reason:
                'Target.blank at offset $startIdx in $filePath must specify rel="noopener noreferrer". '
                'Surrounding code:\n$surroundingCode',
          );
        }
      }
    });
  });
}
