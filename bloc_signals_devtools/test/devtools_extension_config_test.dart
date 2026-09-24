import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('DevTools Extension Configuration & Packaging', () {
    test('extension/devtools/config.yaml exists and contains valid metadata',
        () {
      final configFile = File('extension/devtools/config.yaml');
      expect(
        configFile.existsSync(),
        isTrue,
        reason:
            'extension/devtools/config.yaml must exist for DevTools discovery',
      );

      final content = configFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;

      expect(yaml['name'], equals('bloc_signals_devtools'));
      expect(
        yaml['issueTracker'],
        equals('https://github.com/RandalSchwartz/BlocSignal/issues'),
      );
      expect(yaml['version'], isNotEmpty);
      expect(yaml['materialIconCodePoint'], isNotEmpty);
      expect(yaml['requiresConnection'], isTrue);
    });

    test('extension/devtools/.pubignore preserves build assets', () {
      final pubignoreFile = File('extension/devtools/.pubignore');
      expect(
        pubignoreFile.existsSync(),
        isTrue,
        reason:
            'extension/devtools/.pubignore must exist to override gitignore',
      );

      final content = pubignoreFile.readAsStringSync();
      expect(content, contains('!build'));
    });

    test('extension/devtools/build directory exists and contains index.html',
        () {
      final buildDir = Directory('extension/devtools/build');
      expect(
        buildDir.existsSync(),
        isTrue,
        reason:
            'extension/devtools/build must exist for DevTools iframe loading',
      );

      final indexFile = File('extension/devtools/build/index.html');
      expect(
        indexFile.existsSync(),
        isTrue,
        reason: 'extension/devtools/build/index.html must exist',
      );
    });
  });
}
