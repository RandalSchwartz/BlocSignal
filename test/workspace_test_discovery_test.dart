import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Workspace Test Discovery (#79)', () {
    test('dart_test.yaml exists in bloc_signals_test and restricts discovery to test/', () {
      final configFile = File('bloc_signals_test/dart_test.yaml');
      expect(configFile.existsSync(), isTrue);

      final content = configFile.readAsStringSync();
      expect(content, contains('paths:'));
      expect(content, contains('test/'));
    });

    test('root dart_test.yaml exists and restricts test paths', () {
      final configFile = File('dart_test.yaml');
      expect(configFile.existsSync(), isTrue);

      final content = configFile.readAsStringSync();
      expect(content, contains('paths:'));
      expect(content, contains('test/'));
    });

    test(
      'tool/run_workspace_tests.dart exists and targets workspace packages',
      () {
        final scriptFile = File('tool/run_workspace_tests.dart');
        expect(scriptFile.existsSync(), isTrue);

        final content = scriptFile.readAsStringSync();
        expect(content, contains('bloc_signals'));
        expect(content, contains('bloc_signals_test'));
        expect(content, contains('bloc_signals_flutter'));
      },
    );

    test(
      'all docs source files referenced in docs_content.dart exist on disk',
      () {
        final docsContentFile = File(
          'website/lib/src/components/docs/docs_content.dart',
        );
        expect(docsContentFile.existsSync(), isTrue);

        final content = docsContentFile.readAsStringSync();
        final pathRegex = RegExp(
          r"'website/lib/src/components/docs/pages/[^']+\.dart'",
        );
        final matches = pathRegex.allMatches(content);
        expect(matches, isNotEmpty);

        for (final match in matches) {
          final matchedPath = match.group(0)!.replaceAll("'", '');
          final file = File(matchedPath);
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Docs source file does not exist on disk: $matchedPath',
          );
        }
      },
    );
  });
}
