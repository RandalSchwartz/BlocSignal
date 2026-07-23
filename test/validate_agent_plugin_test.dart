import 'dart:io';

import 'package:test/test.dart';

import '../tool/validate_agent_plugin.dart' as validator;

void main() {
  group('validation path filtering', () {
    test('recognizes generated directories with Windows separators', () {
      expect(
        validator.shouldSkipValidationPath(
          r'.git\objects\pack',
          separator: r'\',
        ),
        isTrue,
      );
      expect(
        validator.shouldSkipValidationPath(
          r'packages\app\.dart_tool\package_config.json',
          separator: r'\',
        ),
        isTrue,
      );
      expect(
        validator.shouldSkipValidationPath(
          r'packages\app\build\generated.md',
          separator: r'\',
        ),
        isTrue,
      );
      expect(
        validator.shouldSkipValidationPath(
          r'plugins\bloc-signals\skills\SKILL.md',
          separator: r'\',
        ),
        isFalse,
      );
    });

    test('prunes ignored directories before yielding files', () {
      final root = Directory.systemTemp.createTempSync(
        'blocsignal-validator-paths-',
      );
      addTearDown(() => root.deleteSync(recursive: true));

      File('${root.path}/README.md')
        ..createSync()
        ..writeAsStringSync('keep');
      for (final name in ['.git', '.dart_tool', 'build']) {
        final ignored = Directory('${root.path}/$name')..createSync();
        File('${ignored.path}/generated.md').writeAsStringSync('ignore');
      }

      final relativeFiles = validator
          .listValidationFiles(root)
          .map((file) => file.path.substring(root.path.length + 1))
          .toList();

      expect(relativeFiles, ['README.md']);
    });
  });

  group('UTF-8 validation reads', () {
    test('returns text for UTF-8 files', () {
      final root = Directory.systemTemp.createTempSync(
        'blocsignal-validator-text-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}/guide.md')
        ..writeAsStringSync('BlocSignal');

      expect(validator.readUtf8ValidationText(file), 'BlocSignal');
    });

    test('skips files with invalid UTF-8', () {
      final root = Directory.systemTemp.createTempSync(
        'blocsignal-validator-binary-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}/asset.bin')
        ..writeAsBytesSync([0xff, 0xfe, 0xfd]);

      expect(validator.readUtf8ValidationText(file), isNull);
    });

    test('does not hide file read failures', () {
      final root = Directory.systemTemp.createTempSync(
        'blocsignal-validator-missing-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final missing = File('${root.path}/missing.md');

      expect(
        () => validator.readUtf8ValidationText(missing),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
