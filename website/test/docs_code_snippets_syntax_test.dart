import 'package:blocsignal_website/src/components/docs/docs_code_block.dart';
import 'package:blocsignal_website/src/models/docs_registry.dart';
import 'package:jaspr/jaspr.dart';
import 'package:test/test.dart';

void _collectCodeBlocks(Component component, List<DocsCodeBlock> blocks) {
  if (component is DocsCodeBlock) {
    blocks.add(component);
    return;
  }
  if (component is StatelessComponent) {
    final element = component.createElement();
    // ignore: invalid_use_of_protected_member
    final built = component.build(element);
    _collectCodeBlocks(built, blocks);
  } else if (component is DomComponent) {
    final children = component.children;
    if (children != null) {
      for (final child in children) {
        _collectCodeBlocks(child, blocks);
      }
    }
  }
}

void main() {
  group('Docs Code Snippets Syntax Verification', () {
    test('no documentation page contains invalid extends SuperClass(...) syntax in snippets', () {
      final blocks = <DocsCodeBlock>[];
      for (final category in DocsRegistry.categories) {
        for (final section in category.sections) {
          final pageComponent = section.builder();
          _collectCodeBlocks(pageComponent, blocks);
        }
      }

      expect(
        blocks,
        isNotEmpty,
        reason: 'Expected to find DocsCodeBlock instances across docs',
      );

      final invalidExtendsRegex = RegExp(
        r'extends\s+[A-Za-z0-9_]+(?:\s*<[^>]+>)?\s*\(',
      );

      final violations = <String>[];

      for (final block in blocks) {
        final title = block.displayTitle ?? 'Untitled';
        for (final (label, snippet) in [
          ('dart313Code', block.dart313Code),
          ('dart35Code', block.dart35Code),
          ('code', block.code),
        ]) {
          if (snippet == null) continue;
          final lines = snippet.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (invalidExtendsRegex.hasMatch(line)) {
              violations.add('$title [$label line ${i + 1}]: $line');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found invalid extends SuperClass(...) constructor invocation in docs snippets:\n'
            '${violations.join('\n')}',
      );
    });

    test('no documentation page contains invalid this() : super(...) syntax in snippets', () {
      final blocks = <DocsCodeBlock>[];
      for (final category in DocsRegistry.categories) {
        for (final section in category.sections) {
          final pageComponent = section.builder();
          _collectCodeBlocks(pageComponent, blocks);
        }
      }

      final invalidThisCtorRegex = RegExp(r'this\(\)\s*:');

      final violations = <String>[];

      for (final block in blocks) {
        final title = block.displayTitle ?? 'Untitled';
        for (final (label, snippet) in [
          ('dart313Code', block.dart313Code),
          ('dart35Code', block.dart35Code),
          ('code', block.code),
        ]) {
          if (snippet == null) continue;
          final lines = snippet.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (invalidThisCtorRegex.hasMatch(line)) {
              violations.add('$title [$label line ${i + 1}]: $line');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found invalid this() : super(...) syntax in docs snippets:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
