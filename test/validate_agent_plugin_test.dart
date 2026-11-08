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
    test('retains backfilled entries for #316, #317, and #318 above their '
        'prior release headers across Unreleased and future releases', () {
      final flutterChangelog = File('bloc_signals_flutter/CHANGELOG.md')
          .readAsStringSync();
      expect(
        flutterChangelog.trimLeft(),
        matches(
          RegExp(
            r'^#\s+Changelog\s+##\s+(Unreleased|\d+\.\d+\.\d+)|^##\s+(Unreleased|\d+\.\d+\.\d+)',
          ),
        ),
      );
      expect(
        flutterChangelog,
        contains('BlocSignalListenableExtension.toValueListenable()'),
      );
      expect(flutterChangelog, contains('(#316)'));
      expect(
        flutterChangelog.indexOf('(#316)'),
        lessThan(flutterChangelog.indexOf('## 1.3.3')),
      );

      final replayChangelog = File('bloc_signals_replay/CHANGELOG.md')
          .readAsStringSync();
      expect(
        replayChangelog.trimLeft(),
        matches(
          RegExp(
            r'^#\s+Changelog\s+##\s+(Unreleased|\d+\.\d+\.\d+)|^##\s+(Unreleased|\d+\.\d+\.\d+)',
          ),
        ),
      );
      expect(replayChangelog, contains('ReplayBlocMixin'));
      expect(replayChangelog, contains('(#317)'));
      expect(
        replayChangelog.indexOf('(#317)'),
        lessThan(replayChangelog.indexOf('## 1.1.2')),
      );

      final hydrateChangelog = File('bloc_signals_hydrate/CHANGELOG.md')
          .readAsStringSync();
      expect(
        hydrateChangelog.trimLeft(),
        matches(
          RegExp(
            r'^#\s+Changelog\s+##\s+(Unreleased|\d+\.\d+\.\d+)|^##\s+(Unreleased|\d+\.\d+\.\d+)',
          ),
        ),
      );
      expect(hydrateChangelog, contains('HydratedMixin.fromJson'));
      expect(hydrateChangelog, contains('(#318)'));
      expect(
        hydrateChangelog.indexOf('(#318)'),
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

  group('(Issue #206: Phase 6) bloc_signals_genui_jaspr 1.0.0 and 14-package '
      'ecosystem catalog invariants', () {
    test('#PubspecAndChangelogReady: validates bloc_signals_genui_jaspr '
        '1.0.0 and bloc_signals_genui_flutter 1.1.0 metadata and example', () {
      final jasprPubspec = File('bloc_signals_genui_jaspr/pubspec.yaml')
          .readAsStringSync();
      expect(jasprPubspec, contains('version: 1.0.0'));
      expect(jasprPubspec, contains('sdk: ^3.5.0'));

      final topicsMatch = RegExp(r'topics:\n((?:\s+-\s+\S+\n)+)')
          .firstMatch(jasprPubspec);
      expect(topicsMatch, isNotNull);
      final topics = RegExp(r'-\s+(\S+)')
          .allMatches(topicsMatch!.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
      expect(topics.length, lessThanOrEqualTo(5));
      expect(topics, ['bloc', 'signals', 'genui', 'a2ui', 'jaspr']);

      final jasprChangelog = File('bloc_signals_genui_jaspr/CHANGELOG.md')
          .readAsStringSync();
      final topJasprHeading = RegExp(
        r'^##\s+(.+)$',
        multiLine: true,
      ).firstMatch(jasprChangelog)?.group(1)?.trim();
      expect(topJasprHeading, '1.0.0');

      final jasprExample = File(
        'bloc_signals_genui_jaspr/example/example.dart',
      );
      expect(jasprExample.existsSync(), isTrue);
      expect(jasprExample.readAsStringSync().trim(), isNotEmpty);

      final flutterPubspec = File('bloc_signals_genui_flutter/pubspec.yaml')
          .readAsStringSync();
      expect(flutterPubspec, contains('version: 1.1.0'));

      final flutterChangelog = File('bloc_signals_genui_flutter/CHANGELOG.md')
          .readAsStringSync();
      final topFlutterHeading = RegExp(
        r'^##\s+(.+)$',
        multiLine: true,
      ).firstMatch(flutterChangelog)?.group(1)?.trim();
      expect(topFlutterHeading, '1.1.0');
    });

    test('#EcosystemCatalogsSynchronized: verifies 14-package catalog '
        'synchronization across READMEs, docs, website, and skills', () {
      final rootReadme = File('README.md').readAsStringSync();
      expect(rootReadme, contains('14 published packages'));
      expect(rootReadme, contains('bloc_signals_genui_jaspr'));

      const packageDirs = [
        'bloc_signals',
        'bloc_signals_flutter',
        'bloc_signals_bloc',
        'bloc_signals_riverpod',
        'bloc_signals_jaspr',
        'bloc_signals_hydrate',
        'bloc_signals_replay',
        'bloc_signals_otel',
        'bloc_signals_devtools',
        'bloc_signals_test',
        'bloc_signals_lint',
        'bloc_signals_genui',
        'bloc_signals_genui_flutter',
        'bloc_signals_genui_jaspr',
      ];
      for (final pkg in packageDirs) {
        final readme = File('$pkg/README.md').readAsStringSync();
        expect(
          readme,
          contains('14 modular packages'),
          reason: '$pkg/README.md must mention 14 modular packages',
        );
        expect(
          readme,
          contains('bloc_signals_genui_jaspr'),
          reason: '$pkg/README.md must list bloc_signals_genui_jaspr',
        );
      }

      final publishingDoc = File('doc/internals/publishing_and_scoring.md')
          .readAsStringSync();
      expect(publishingDoc, contains('14 published packages'));
      expect(publishingDoc, contains('14. `bloc_signals_genui_jaspr`'));

      final catalogText = File(
        'website/lib/src/components/package_catalog.dart',
      ).readAsStringSync();
      expect(catalogText, contains("name: 'bloc_signals_genui_jaspr'"));
      expect(
        catalogText,
        contains("name: 'bloc_signals_genui_jaspr',\n    version: '1.0.0',"),
      );
      expect(
        catalogText,
        contains("name: 'bloc_signals_genui_flutter',\n    version: '1.1.0',"),
      );

      final installDoc = File(
        'website/lib/src/components/docs/pages/docs_installation.dart',
      ).readAsStringSync();
      expect(installDoc, contains('bloc_signals_genui_jaspr'));

      final genuiSkill = File(
        'plugins/bloc-signals/skills/bloc-signals/genui.md',
      ).readAsStringSync();
      final h1Line = genuiSkill.split('\n').first;
      expect(h1Line, contains('bloc_signals_genui_jaspr'));
      expect(
        genuiSkill,
        contains('https://img.shields.io/pub/v/bloc_signals_genui_jaspr.svg'),
      );
      expect(
        genuiSkill,
        contains('https://img.shields.io/pub/points/bloc_signals_genui_jaspr'),
      );
    });
  });
}
