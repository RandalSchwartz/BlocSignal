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

  group(
    '(Issue #336: R1) SCAR-TEST-23 semantic lint test harness invariants',
    () {
      test('codifies SCAR-TEST-23 across AGENTS.md, scars.md, and lint.md', () {
        final agentsText = File('AGENTS.md').readAsStringSync();
        expect(agentsText, contains('SCAR-TEST-23'));
        expect(agentsText, contains('runLintRule'));
        expect(agentsText, contains('disposeLintTestHarness'));
        expect(agentsText, contains('AnalysisContextCollection'));

        final scarsText = File(
          'plugins/bloc-signals/skills/bloc-signals/scars.md',
        ).readAsStringSync();
        expect(scarsText, contains('SCAR-TEST-23'));
        expect(scarsText, contains('runLintRule'));
        expect(scarsText, contains('disposeLintTestHarness'));
        expect(scarsText, contains('AnalysisContextCollection'));

        final lintText = File(
          'plugins/bloc-signals/skills/bloc-signals/lint.md',
        ).readAsStringSync();
        expect(lintText, contains('SCAR-TEST-23'));
        expect(lintText, contains('runLintRule'));
        expect(lintText, contains('disposeLintTestHarness'));
        expect(lintText, contains('AnalysisContextCollection'));
      });
    },
  );

  group('(Issue #343: SCAR-DOC-18) per-PR Unreleased changelog and pubspec '
      'hygiene invariants', () {
    test('backfills ## Unreleased entries for #316, #317, and #318 before '
        'latest version headers', () {
      final flutterChangelog = File('bloc_signals_flutter/CHANGELOG.md')
          .readAsStringSync();
      expect(flutterChangelog.trimLeft(), startsWith('## Unreleased'));
      expect(
        flutterChangelog,
        contains('BlocSignalListenableExtension.toValueListenable()'),
      );
      expect(flutterChangelog, contains('(#316)'));
      expect(
        flutterChangelog.indexOf('## Unreleased'),
        lessThan(flutterChangelog.indexOf('## 1.3.3')),
      );

      final replayChangelog = File('bloc_signals_replay/CHANGELOG.md')
          .readAsStringSync();
      expect(replayChangelog.trimLeft(), startsWith('## Unreleased'));
      expect(replayChangelog, contains('ReplayBlocMixin'));
      expect(replayChangelog, contains('(#317)'));
      expect(
        replayChangelog.indexOf('## Unreleased'),
        lessThan(replayChangelog.indexOf('## 1.1.2')),
      );

      final hydrateChangelog = File('bloc_signals_hydrate/CHANGELOG.md')
          .readAsStringSync();
      expect(hydrateChangelog.trimLeft(), startsWith('## Unreleased'));
      expect(hydrateChangelog, contains('HydratedMixin.fromJson'));
      expect(hydrateChangelog, contains('(#318)'));
      expect(
        hydrateChangelog.indexOf('## Unreleased'),
        lessThan(hydrateChangelog.indexOf('## 1.0.3')),
      );
    });

    test('codifies SCAR-DOC-18 across AGENTS.md, publishing_and_scoring.md, '
        'and scars.md', () {
      final agentsText = File('AGENTS.md').readAsStringSync();
      expect(agentsText, contains('SCAR-DOC-18'));
      expect(agentsText, contains('## Unreleased'));

      final publishingText = File('doc/internals/publishing_and_scoring.md')
          .readAsStringSync();
      expect(publishingText, contains('SCAR-DOC-18'));
      expect(publishingText, contains('## Unreleased'));

      final scarsText = File(
        'plugins/bloc-signals/skills/bloc-signals/scars.md',
      ).readAsStringSync();
      expect(scarsText, contains('SCAR-DOC-18'));
      expect(scarsText, contains('## Unreleased'));
    });
  });
}
