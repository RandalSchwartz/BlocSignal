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
      'all docs source files referenced in docs_registry.dart exist on disk',
      () {
        final docsRegistryFile = File(
          'website/lib/src/models/docs_registry.dart',
        );
        final docsContentFile = File(
          'website/lib/src/components/docs/docs_content.dart',
        );
        expect(docsRegistryFile.existsSync(), isTrue);
        expect(docsContentFile.existsSync(), isTrue);

        final registryText = docsRegistryFile.readAsStringSync();
        final contentText = docsContentFile.readAsStringSync();
        final content = '$registryText\n$contentText';
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

  group('(Issue #334: R20) Workspace Pubspec, Runner, '
      'and Per-Package Coverage Hygiene', () {
    test('every member bloc_signals* package declaring a bloc_signals '
        'dependency specifies ^1.5.0 or ^1.6.0 and hydrate pubspec has '
        'no consecutive blank lines', () {
      final rootDir = Directory.current;
      final memberDirs = rootDir
          .listSync()
          .whereType<Directory>()
          .where(
            (d) => d.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('bloc_signals_'),
          )
          .toList();

      expect(memberDirs, isNotEmpty);

      final depPattern = RegExp(
        r'^\s+bloc_signals:\s*\^(\d+\.\d+\.\d+)\s*$',
        multiLine: true,
      );

      for (final dir in memberDirs) {
        final pubspecFile = File('${dir.path}/pubspec.yaml');
        if (!pubspecFile.existsSync()) continue;
        final content = pubspecFile.readAsStringSync();
        final match = depPattern.firstMatch(content);
        if (match != null) {
          final constraint = match.group(1)!;
          expect(
            constraint,
            anyOf(equals('1.5.0'), equals('1.6.0')),
            reason:
                '${pubspecFile.path} must depend on bloc_signals '
                '^1.5.0 or ^1.6.0, found ^$constraint',
          );
        }
      }

      final hydratePubspec = File('bloc_signals_hydrate/pubspec.yaml')
          .readAsStringSync();
      expect(
        hydratePubspec,
        isNot(contains('\n\n\n')),
        reason:
            'bloc_signals_hydrate/pubspec.yaml must not contain '
            'consecutive blank lines',
      );
    });

    test('tool/run_workspace_tests.dart discovers and includes all examples/* '
        'directories that have both pubspec.yaml and a test subdirectory', () {
      final examplesDir = Directory('examples');
      expect(examplesDir.existsSync(), isTrue);

      final expectedExamples =
          examplesDir
              .listSync()
              .whereType<Directory>()
              .where(
                (d) =>
                    File('${d.path}/pubspec.yaml').existsSync() &&
                    Directory('${d.path}/test').existsSync(),
              )
              .map(
                (d) =>
                    'examples/'
                    '${d.uri.pathSegments.where((s) => s.isNotEmpty).last}',
              )
              .toList()
            ..sort();

      expect(expectedExamples.length, greaterThanOrEqualTo(30));

      final runnerContent = File('tool/run_workspace_tests.dart')
          .readAsStringSync();

      expect(runnerContent, contains("Directory('examples')"));
      expect(runnerContent, contains('/pubspec.yaml'));
      expect(runnerContent, contains('/test'));
    });

    test('tool/calculate_coverage.dart prints Package Coverage Summary, '
        'derives examples/<name> names, auto-discovers examples/, and '
        'enforces --per-package-min and --min thresholds', () {
      final coverageScriptContent = File('tool/calculate_coverage.dart')
          .readAsStringSync();
      expect(coverageScriptContent, contains("Directory('examples')"));
      expect(coverageScriptContent, contains('/pubspec.yaml'));
      expect(coverageScriptContent, contains('/coverage'));

      final tempDir = Directory.systemTemp.createTempSync(
        'bloc_signals_r20_cov_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final pkgADir = Directory('${tempDir.path}/pkg_a/coverage')
        ..createSync(recursive: true);
      final pkgBDir = Directory('${tempDir.path}/examples/demo_app/coverage')
        ..createSync(recursive: true);

      final pkgALcov = File('${pkgADir.path}/lcov.info')
        ..writeAsStringSync(
          'SF:lib/a.dart\n'
          'DA:1,1\n'
          'DA:2,1\n'
          'DA:3,1\n'
          'DA:4,1\n'
          'end_of_record\n',
        ); // 100% (4/4)

      final pkgBLcov = File('${pkgBDir.path}/lcov.info')
        ..writeAsStringSync(
          'SF:lib/b.dart\n'
          'DA:1,1\n'
          'DA:2,0\n'
          'DA:3,0\n'
          'DA:4,0\n'
          'end_of_record\n',
        ); // 25% (1/4), overall = 5/8 = 62.5%

      // 1. Both packages meet --per-package-min=20 and --min=60
      final passResult = Process.runSync('dart', [
        'run',
        'tool/calculate_coverage.dart',
        '--min=60',
        '--per-package-min=20',
        pkgALcov.path,
        pkgBLcov.path,
      ]);
      expect(
        passResult.exitCode,
        equals(0),
        reason:
            'Expected exit code 0 when thresholds are met, '
            'stdout: ${passResult.stdout}\nstderr: ${passResult.stderr}',
      );
      expect(
        passResult.stdout.toString().toUpperCase(),
        contains('PACKAGE COVERAGE SUMMARY'),
      );
      expect(passResult.stdout.toString(), contains('pkg_a'));
      expect(passResult.stdout.toString(), contains('examples/demo_app'));

      // 2. Overall meets --min=60 (62.5%), but examples/demo_app (25%) fails
      // --per-package-min=50.
      final failPerPkgResult = Process.runSync('dart', [
        'run',
        'tool/calculate_coverage.dart',
        '--min=60',
        '--per-package-min=50',
        pkgALcov.path,
        pkgBLcov.path,
      ]);
      expect(
        failPerPkgResult.exitCode,
        isNot(equals(0)),
        reason:
            'Expected non-zero exit code when examples/demo_app is below '
            '--per-package-min=50',
      );
      expect(failPerPkgResult.stdout.toString(), contains('examples/demo_app'));
    });
  });
}
