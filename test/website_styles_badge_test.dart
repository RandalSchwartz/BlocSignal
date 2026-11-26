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

String _stripCssComments(String css) =>
    css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

String? _extractRuleBlock(String css, String selector) {
  final escaped = RegExp.escape(selector);
  final match = RegExp('(?:^|[\\s}])$escaped\\s*\\{([^}]*)\\}').firstMatch(css);
  return match?.group(1);
}

void main() {
  group('Docs Badge Styles (Issue #507)', () {
    late String strippedCss;
    late String docsPkgLintSource;

    setUpAll(() {
      final cssFile = _resolveRepoFile('website/web/styles.css');
      expect(
        cssFile.existsSync(),
        isTrue,
        reason: 'website/web/styles.css must exist',
      );
      strippedCss = _stripCssComments(cssFile.readAsStringSync());

      final docsFile = _resolveRepoFile(
        'website/lib/src/components/docs/pages/docs_pkg_lint.dart',
      );
      expect(
        docsFile.existsSync(),
        isTrue,
        reason: 'docs_pkg_lint.dart must exist',
      );
      docsPkgLintSource = docsFile.readAsStringSync();
    });

    test('(Issue #507) defines base .badge pill rule', () {
      final block = _extractRuleBlock(strippedCss, '.badge');
      expect(block, isNotNull, reason: '.badge rule must exist in styles.css');

      expect(
        RegExp(r'(?:^|[;\s])display:\s*inline-flex\b').hasMatch(block!),
        isTrue,
        reason: '.badge must set display: inline-flex',
      );
      expect(
        RegExp(r'(?:^|[;\s])align-items:\s*center\b').hasMatch(block),
        isTrue,
        reason: '.badge must set align-items: center',
      );
      expect(
        RegExp(r'(?:^|[;\s])border-radius:\s*9999px\b').hasMatch(block),
        isTrue,
        reason: '.badge must set border-radius: 9999px',
      );
      expect(
        RegExp(r'(?:^|[;\s])white-space:\s*nowrap\b').hasMatch(block),
        isTrue,
        reason: '.badge must set white-space: nowrap',
      );
    });

    test('(Issue #507) defines .badge-warning with semantic amber styling', () {
      final block = _extractRuleBlock(strippedCss, '.badge-warning');
      expect(
        block,
        isNotNull,
        reason: '.badge-warning rule must exist in styles.css',
      );

      expect(
        RegExp(r'(?:^|[;\s])background:\s*rgba\(245,\s*158,\s*11,\s*0\.15\)')
            .hasMatch(block!),
        isTrue,
        reason: '.badge-warning must set amber background',
      );
      expect(
        RegExp(r'(?:^|[;\s{])color:\s*#fbbf24\b').hasMatch(block),
        isTrue,
        reason: '.badge-warning must set color: #fbbf24',
      );
      expect(
        RegExp(
          r'(?:^|[;\s])border:\s*1px\s+solid\s+rgba\(245,\s*158,\s*11,\s*0\.3\)',
        ).hasMatch(block),
        isTrue,
        reason: '.badge-warning must set amber border',
      );
    });

    test('(Issue #507) defines .badge-error with semantic red styling', () {
      final block = _extractRuleBlock(strippedCss, '.badge-error');
      expect(
        block,
        isNotNull,
        reason: '.badge-error rule must exist in styles.css',
      );

      expect(
        RegExp(r'(?:^|[;\s])background:\s*rgba\(239,\s*68,\s*68,\s*0\.15\)')
            .hasMatch(block!),
        isTrue,
        reason: '.badge-error must set red background',
      );
      expect(
        RegExp(r'(?:^|[;\s{])color:\s*#f87171\b').hasMatch(block),
        isTrue,
        reason: '.badge-error must set color: #f87171',
      );
      expect(
        RegExp(
          r'(?:^|[;\s])border:\s*1px\s+solid\s+rgba\(239,\s*68,\s*68,\s*0\.3\)',
        ).hasMatch(block),
        isTrue,
        reason: '.badge-error must set red border',
      );
    });

    test('(Issue #507) docs_pkg_lint badge classes exist in styles.css', () {
      final classStrings = RegExp(r"classes:\s*'([^']*)'")
          .allMatches(docsPkgLintSource)
          .map((m) => m.group(1)!)
          .toList();

      final badgeTokens = <String>{};
      for (final classList in classStrings) {
        final tokens = classList
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty);
        if (tokens.contains('badge') ||
            tokens.any((t) => t.startsWith('badge-'))) {
          badgeTokens.addAll(tokens);
        }
      }

      expect(
        badgeTokens,
        containsAll(<String>['badge', 'badge-warning', 'badge-error']),
      );

      for (final token in badgeTokens) {
        final rule = _extractRuleBlock(strippedCss, '.$token');
        expect(
          rule,
          isNotNull,
          reason:
              'Class .$token referenced in docs_pkg_lint.dart must exist in website/web/styles.css',
        );
      }
    });
  });
}
