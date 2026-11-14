import 'dart:io';

import 'package:test/test.dart';

Directory _resolveRepoRoot() {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    if (Directory('${dir.path}/.github/workflows').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  return Directory.current;
}

List<File> _workflowFiles() {
  final workflowsDir = Directory(
    '${_resolveRepoRoot().path}/.github/workflows',
  );
  if (!workflowsDir.existsSync()) {
    return <File>[];
  }
  return workflowsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Extracts all `run:` command blocks (single-line and multi-line) from YAML
/// lines without requiring an external YAML parser package.
List<String> _extractRunBlocks(String yamlContent) {
  final lines = yamlContent.split('\n');
  final blocks = <String>[];
  final runHeaderPattern = RegExp(r'^(\s*)(?:-\s*)?run:\s*(.*)$');

  var i = 0;
  while (i < lines.length) {
    final match = runHeaderPattern.firstMatch(lines[i]);
    if (match == null) {
      i++;
      continue;
    }

    final baseIndent = match.group(1)!.length;
    final inlineValue = match.group(2)!.trim();

    if (inlineValue == '|' ||
        inlineValue == '|-' ||
        inlineValue == '>' ||
        inlineValue == '>-') {
      final buffer = StringBuffer();
      i++;
      int? blockIndent;
      while (i < lines.length) {
        final line = lines[i];
        if (line.trim().isEmpty) {
          buffer.writeln();
          i++;
          continue;
        }
        final currentIndent = line.length - line.trimLeft().length;
        blockIndent ??= currentIndent;
        if (currentIndent <= baseIndent || currentIndent < blockIndent) {
          break;
        }
        buffer.writeln(line.substring(blockIndent));
        i++;
      }
      blocks.add(buffer.toString());
    } else {
      blocks.add(inlineValue);
      i++;
    }
  }
  return blocks;
}

void main() {
  group('GitHub Actions Workflow Security Hardening (Issue #420)', () {
    test('(Issue #420) every uses: entry in .github/workflows/*.yml is pinned '
        'to a 40-character lowercase hex commit SHA', () {
      final files = _workflowFiles();
      expect(
        files,
        isNotEmpty,
        reason: 'At least one workflow file must exist in .github/workflows/',
      );

      final usesPattern = RegExp(r'^\s*(?:-\s*)?uses:\s*([^\s#]+)');
      final shaPinPattern = RegExp(r'^[^@]+@[0-9a-f]{40}$');

      for (final file in files) {
        final lines = file.readAsLinesSync();
        var foundUses = false;
        for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          final line = lines[lineIndex];
          if (line.trimLeft().startsWith('#')) continue;
          final match = usesPattern.firstMatch(line);
          if (match == null) continue;
          foundUses = true;
          final target = match.group(1)!;
          expect(
            shaPinPattern.hasMatch(target),
            isTrue,
            reason:
                '${file.path}:${lineIndex + 1} uses "$target" which is not '
                'pinned to a 40-character lowercase hex commit SHA',
          );
        }
        expect(
          foundUses,
          isTrue,
          reason: '${file.path} should contain at least one uses: entry',
        );
      }
    });

    test('(Issue #420) ci.yml declares least-privilege permissions with '
        'contents: read', () {
      final ciFile = File(
        '${_resolveRepoRoot().path}/.github/workflows/ci.yml',
      );
      expect(ciFile.existsSync(), isTrue);
      final content = ciFile.readAsStringSync();

      expect(
        content,
        matches(
          RegExp(r'^permissions:\s*\n\s+contents:\s*read\b', multiLine: true),
        ),
        reason:
            'ci.yml must declare workflow-level permissions: contents: read',
      );
    });

    test(r'(Issue #420) no run: block contains ${{ interpolation and all '
        'git diff commands include --', () {
      final files = _workflowFiles();
      expect(files, isNotEmpty);

      final gitDiffLinePattern = RegExp(r'\bgit\s+diff\b.*');
      final gitDiffSeparatorPattern = RegExp(r'\bgit\s+diff\b.*\s--(?:\s|$)');

      for (final file in files) {
        final content = file.readAsStringSync();
        final runBlocks = _extractRunBlocks(content);
        expect(
          runBlocks,
          isNotEmpty,
          reason: '${file.path} should contain at least one run: block',
        );

        for (final block in runBlocks) {
          expect(
            block,
            isNot(contains(r'${{')),
            reason:
                '${file.path} contains unsafe \${{ interpolation inside a '
                'run: block:\n$block',
          );

          for (final diffMatch in gitDiffLinePattern.allMatches(block)) {
            final diffLine = diffMatch.group(0)!;
            expect(
              gitDiffSeparatorPattern.hasMatch(diffLine),
              isTrue,
              reason:
                  '${file.path} has a git diff command without "--" argument '
                  'separator: $diffLine',
            );
          }
        }
      }
    });

    test('(Issue #420) gemini-code-review.yml passes x-goog-api-key in headers '
        'and does not include ?key= in the URL', () {
      final reviewFile = File(
        '${_resolveRepoRoot().path}/.github/workflows/gemini-code-review.yml',
      );
      expect(reviewFile.existsSync(), isTrue);
      final content = reviewFile.readAsStringSync();

      expect(
        content,
        isNot(contains('?key=')),
        reason: 'API key must not be passed in the URL query string',
      );
      expect(
        content,
        contains("'x-goog-api-key': apiKey"),
        reason: 'API key must be passed via the x-goog-api-key request header',
      );
    });

    test(
      '(Issue #420) gemini-code-review.yml uses systemInstruction, untrusted '
      'boundary tags, and strips markdown/HTML image tags before posting',
      () {
        final reviewFile = File(
          '${_resolveRepoRoot().path}/.github/workflows/gemini-code-review.yml',
        );
        expect(reviewFile.existsSync(), isTrue);
        final content = reviewFile.readAsStringSync();

        expect(
          content,
          contains('systemInstruction'),
          reason: 'Static review instructions must use systemInstruction',
        );
        expect(
          content,
          contains('<untrusted_pr_title>'),
          reason: 'PR title must be wrapped in <untrusted_pr_title> tags',
        );
        expect(
          content,
          contains('<untrusted_pr_description>'),
          reason:
              'PR description must be wrapped in <untrusted_pr_description> '
              'tags',
        );
        expect(
          content,
          contains('<untrusted_pr_diff>'),
          reason: 'PR diff must be wrapped in <untrusted_pr_diff> tags',
        );
        expect(
          content,
          matches(RegExp(r'reviewText\s*=\s*reviewText\.replace\(')),
          reason:
              'reviewText must be sanitized to strip markdown/HTML image tags '
              'before posting',
        );
        expect(
          content,
          contains('<img'),
          reason: 'Sanitization must strip HTML <img> tags from reviewText',
        );
      },
    );
  });
}
