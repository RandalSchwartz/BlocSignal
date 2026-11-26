import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;
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

Directory _resolveRepoDirectory(String relativePath) {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final candidate = Directory(p.join(dir.path, relativePath));
    if (candidate.existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  return Directory(relativePath);
}

final class _TargetBlankViolation {
  const new({required this.path, required this.line, required this.relValue});

  final String path;
  final int line;
  final String? relValue;

  @override
  String toString() =>
      '$path:$line: blank target link missing rel="noopener noreferrer" '
      '(found rel=${relValue == null ? "<missing>" : '"$relValue"'})';
}

final class _TargetBlankAstVisitor extends RecursiveAstVisitor<void> {
  new({required this.path, required this.lineInfo});

  final String path;
  final LineInfo lineInfo;
  final List<_TargetBlankViolation> violations = <_TargetBlankViolation>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    final ctorName = node.constructorName.name?.name;
    if (typeName == 'a' && (ctorName == null || ctorName == 'new')) {
      _inspectAnchorCall(node.argumentList, node.offset);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final isAnchorCall =
        methodName == 'a' ||
        (methodName == 'new' && _isAnchorTarget(node.realTarget));
    if (isAnchorCall) {
      _inspectAnchorCall(node.argumentList, node.offset);
    }
    super.visitMethodInvocation(node);
  }

  static bool _isAnchorTarget(Expression? target) => switch (target) {
    SimpleIdentifier(:final name) => name == 'a',
    PrefixedIdentifier(:final identifier) => identifier.name == 'a',
    PropertyAccess(:final propertyName) => propertyName.name == 'a',
    _ => false,
  };

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final fn = node.function;
    final isAnchorCall = switch (fn) {
      SimpleIdentifier(:final name) => name == 'a',
      PrefixedIdentifier(:final identifier) => identifier.name == 'a',
      PropertyAccess(:final propertyName) => propertyName.name == 'a',
      _ => false,
    };
    if (isAnchorCall) {
      _inspectAnchorCall(node.argumentList, node.offset);
    }
    super.visitFunctionExpressionInvocation(node);
  }

  static bool _containsBlankTarget(Expression expr) => switch (expr) {
    ParenthesizedExpression(:final expression) => _containsBlankTarget(
      expression,
    ),
    ConditionalExpression(:final thenExpression, :final elseExpression) =>
      _containsBlankTarget(thenExpression) ||
          _containsBlankTarget(elseExpression),
    BinaryExpression(
      operator: final op,
      :final leftOperand,
      :final rightOperand,
    )
        when op.type == TokenType.QUESTION_QUESTION =>
      _containsBlankTarget(leftOperand) || _containsBlankTarget(rightOperand),
    _ => _isBlankTargetLeaf(expr),
  };

  static bool _isBlankTargetLeaf(Expression expr) {
    final src = expr.toSource();
    return src == 'Target.blank' ||
        src == '.blank' ||
        src.endsWith('.Target.blank');
  }

  static bool _containsBlankTargetString(Expression expr) => switch (expr) {
    ParenthesizedExpression(:final expression) => _containsBlankTargetString(
      expression,
    ),
    ConditionalExpression(:final thenExpression, :final elseExpression) =>
      _containsBlankTargetString(thenExpression) ||
          _containsBlankTargetString(elseExpression),
    BinaryExpression(
      operator: final op,
      :final leftOperand,
      :final rightOperand,
    )
        when op.type == TokenType.QUESTION_QUESTION =>
      _containsBlankTargetString(leftOperand) ||
          _containsBlankTargetString(rightOperand),
    StringLiteral(:final stringValue) =>
      stringValue?.trim().toLowerCase() == '_blank',
    _ => false,
  };

  static bool _mapContainsBlankTarget(CollectionElement element) =>
      switch (element) {
        MapLiteralEntry(:final key, :final value) =>
          key is StringLiteral &&
              key.stringValue?.toLowerCase() == 'target' &&
              _containsBlankTargetString(value),
        IfElement(:final thenElement, :final elseElement) =>
          _mapContainsBlankTarget(thenElement) ||
              (elseElement != null && _mapContainsBlankTarget(elseElement)),
        _ => false,
      };

  void _inspectAnchorCall(ArgumentList argumentList, int offset) {
    var hasBlankTarget = false;
    SetOrMapLiteral? attributesMap;

    for (final arg in argumentList.arguments) {
      if (arg is! NamedArgument) continue;
      final label = arg.name.lexeme;
      final expression = arg.argumentExpression;
      if (label == 'target') {
        if (_containsBlankTarget(expression)) {
          hasBlankTarget = true;
        }
      } else if (label == 'attributes' && expression is SetOrMapLiteral) {
        attributesMap = expression;
      }
    }

    String? relValue;
    if (attributesMap != null) {
      for (final element in attributesMap.elements) {
        if (_mapContainsBlankTarget(element)) {
          hasBlankTarget = true;
        }
        if (element is! MapLiteralEntry) continue;
        final key = element.key;
        final value = element.value;
        final keyStr = key is StringLiteral ? key.stringValue : null;
        if (keyStr != null && keyStr.toLowerCase() == 'rel') {
          relValue = value is StringLiteral ? value.stringValue : null;
        }
      }
    }

    if (!hasBlankTarget) return;

    final tokens = relValue == null
        ? const <String>{}
        : relValue.trim().toLowerCase().split(RegExp(r'\s+')).toSet();
    if (!tokens.contains('noopener') || !tokens.contains('noreferrer')) {
      final location = lineInfo.getLocation(offset);
      violations.add(
        _TargetBlankViolation(
          path: path,
          line: location.lineNumber,
          relValue: relValue,
        ),
      );
    }
  }
}

List<_TargetBlankViolation> _findTargetBlankViolations(
  String source, {
  required String path,
}) {
  final result = parseString(content: source, path: path);
  final visitor = _TargetBlankAstVisitor(path: path, lineInfo: result.lineInfo);
  result.unit.accept(visitor);
  return visitor.violations;
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
        contains("script-src 'self' https://www.googletagmanager.com"),
      );
      final scriptSrcMatch = RegExp('script-src[^;]+').firstMatch(csp);
      expect(scriptSrcMatch, isNotNull);
      final scriptSrc = scriptSrcMatch!.group(0)!;
      expect(scriptSrc, isNot(contains("'unsafe-inline'")));
      expect(scriptSrc, isNot(contains("'unsafe-eval'")));
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

    test(
      '(Issue #478) website/web/index.html has no inline scripts, '
      'gtag-init.js exists, and build_static.dart compiles with --csp -O2',
      () {
        final indexHtml = _resolveRepoFile('website/web/index.html');
        expect(indexHtml.existsSync(), isTrue);
        final html = indexHtml.readAsStringSync();

        final scriptMatches = RegExp(
          r'<script\b([^>]*)>([\s\S]*?)</script>',
          caseSensitive: false,
        ).allMatches(html);
        expect(scriptMatches, isNotEmpty);
        for (final match in scriptMatches) {
          final attrs = match.group(1) ?? '';
          final body = (match.group(2) ?? '').trim();
          expect(
            attrs,
            contains('src='),
            reason: 'All <script> tags in index.html must load external src',
          );
          expect(
            body,
            isEmpty,
            reason: 'Inline <script> bodies violate strict CSP',
          );
        }

        final gtagInit = _resolveRepoFile('website/web/gtag-init.js');
        expect(gtagInit.existsSync(), isTrue);

        final buildStatic = _resolveRepoFile('website/tool/build_static.dart');
        expect(buildStatic.existsSync(), isTrue);
        final buildSource = buildStatic.readAsStringSync();
        expect(buildSource, contains("'--csp'"));
        expect(buildSource, contains("'-O2'"));
      },
    );

    test('(Issue #426: F03) external Target.blank links across modified files '
        'include rel="noopener noreferrer"', () {
      const modifiedFiles = [
        'website/lib/src/components/navbar.dart',
        'website/lib/src/components/hero.dart',
        'website/lib/src/components/package_catalog.dart',
        'website/lib/src/pages/publications_page.dart',
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

  group('Website Target.blank AST Audit (Issue #442)', () {
    test('(Issue #442: F01) all blank-target links across website/lib/ '
        'include rel="noopener noreferrer"', () {
      final websiteLibDir = _resolveRepoDirectory('website/lib');
      expect(
        websiteLibDir.existsSync(),
        isTrue,
        reason: 'website/lib directory must exist',
      );

      final dartFiles =
          websiteLibDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      expect(dartFiles, isNotEmpty);

      final allViolations = <_TargetBlankViolation>[];
      for (final file in dartFiles) {
        final relativePath = p.relative(
          file.path,
          from: websiteLibDir.parent.parent.path,
        );
        allViolations.addAll(
          _findTargetBlankViolations(
            file.readAsStringSync(),
            path: relativePath,
          ),
        );
      }

      expect(
        allViolations,
        isEmpty,
        reason:
            'Every blank-target <a> call in website/lib/ must include '
            'rel="noopener noreferrer":\n${allViolations.join('\n')}',
      );
    });

    test('(Issue #442: F02) AST scanner detects non-compliant blank-target '
        'snippets and ignores compliant or non-code occurrences', () {
      const nonCompliantSnippets = <String, String>{
        'missing attributes': '''
void f() {
  a(href: 'https://example.com', target: Target.blank, []);
}
''',
        'attributes without rel': '''
void f() {
  a(
    href: 'https://example.com',
    target: Target.blank,
    attributes: <String, String>{'class': 'btn'},
    [],
  );
}
''',
        'rel missing noreferrer': '''
void f() {
  a(
    href: 'https://example.com',
    target: Target.blank,
    attributes: const {'rel': 'noopener'},
    [],
  );
}
''',
        'rel missing noopener': '''
void f() {
  a(
    href: 'https://example.com',
    target: Target.blank,
    attributes: const {'rel': 'noreferrer'},
    [],
  );
}
''',
        'dot shorthand target without rel': '''
void f() {
  a(href: 'https://example.com', target: .blank, []);
}
''',
        'dom.a without rel': '''
void f() {
  dom.a(href: 'https://example.com', target: Target.blank, []);
}
''',
        'attributes target _blank without rel': '''
void f() {
  a(
    href: 'https://example.com',
    attributes: const <String, String>{'target': '_blank'},
    [],
  );
}
''',
        'const a without rel': '''
void f() {
  const a(href: 'https://example.com', target: Target.blank, []);
}
''',
        'const dom.a without rel': '''
void f() {
  const dom.a(href: 'https://example.com', target: Target.blank, []);
}
''',
        'a.new without rel': '''
void f() {
  a.new(href: 'https://example.com', target: Target.blank, []);
}
''',
        'dom.a.new without rel': '''
void f() {
  dom.a.new(href: 'https://example.com', target: Target.blank, []);
}
''',
        'conditional Target.blank without rel': '''
void f(bool isExternal) {
  a(
    href: 'https://example.com',
    target: isExternal ? Target.blank : Target.self,
    [],
  );
}
''',
        'conditional dot shorthand .blank without rel': '''
void f(bool isExternal) {
  a(
    href: 'https://example.com',
    target: isExternal ? .blank : null,
    [],
  );
}
''',
        'null-coalescing Target.blank without rel': '''
void f(Target? maybeTarget) {
  a(
    href: 'https://example.com',
    target: maybeTarget ?? Target.blank,
    [],
  );
}
''',
        'parenthesized Target.blank without rel': '''
void f() {
  a(
    href: 'https://example.com',
    target: (Target.blank),
    [],
  );
}
''',
        'conditional if-element target _blank without rel': '''
void f(bool isExternal) {
  a(
    href: 'https://example.com',
    attributes: {if (isExternal) 'target': '_blank'},
    [],
  );
}
''',
        'case-insensitive TARGET _BLANK without rel': '''
void f() {
  a(
    href: 'https://example.com',
    attributes: const {'TARGET': '_BLANK'},
    [],
  );
}
''',
      };

      for (final entry in nonCompliantSnippets.entries) {
        final violations = _findTargetBlankViolations(
          entry.value,
          path: 'fixture_${entry.key}.dart',
        );
        expect(
          violations,
          hasLength(1),
          reason: 'Expected 1 violation for "${entry.key}"',
        );
      }

      const compliantSource = r'''
void f(bool flag, bool isExternal) {
  // Commented out: a(href: 'https://example.com', target: Target.blank, []);
  final msg = "See ${flag ? "a(target: Target.blank)" : "none"}";
  a(
    href: 'https://example.com',
    target: Target.blank,
    attributes: const <String, String>{'rel': 'noopener noreferrer'},
    [],
  );
  a(
    href: 'https://example.com',
    target: .blank,
    attributes: const {'rel': 'noreferrer noopener'},
    [],
  );
  dom.a(
    href: 'https://example.com',
    target: Target.blank,
    attributes: {'class': 'ext', 'rel': 'noopener noreferrer'},
    [],
  );
  a(
    href: 'https://example.com',
    attributes: const <String, String>{
      'target': '_blank',
      'rel': 'noopener noreferrer',
    },
    [],
  );
  const a(
    href: 'https://example.com',
    target: Target.blank,
    attributes: {'rel': 'noopener noreferrer'},
    [],
  );
  a.new(
    href: 'https://example.com',
    target: Target.blank,
    attributes: {'REL': 'noopener noreferrer'},
    [],
  );
  a(
    href: 'https://example.com',
    target: isExternal ? Target.blank : null,
    attributes: const {'rel': 'noopener noreferrer'},
    [],
  );
}
''';

      final compliantViolations = _findTargetBlankViolations(
        compliantSource,
        path: 'fixture_compliant.dart',
      );
      expect(
        compliantViolations,
        isEmpty,
        reason:
            'Compliant links, comments, and interpolated strings should not '
            'produce violations',
      );
    });
  });
}
