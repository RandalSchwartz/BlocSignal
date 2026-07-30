import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Workspace Test Discovery (#79)', () {
    test(
        'dart_test.yaml exists in bloc_signals_test and restricts discovery to test/',
        () {
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

    test('tool/run_workspace_tests.dart exists and targets workspace packages',
        () {
      final scriptFile = File('tool/run_workspace_tests.dart');
      expect(scriptFile.existsSync(), isTrue);

      final content = scriptFile.readAsStringSync();
      expect(content, contains('bloc_signals'));
      expect(content, contains('bloc_signals_test'));
      expect(content, contains('bloc_signals_flutter'));
    });
  });
}
