import 'dart:io';

/// Runs tests across all workspace packages in isolation to prevent
/// path resolution and symbol compilation collisions.
void main(List<String> args) {
  final examplePackages =
      Directory('examples')
          .listSync()
          .whereType<Directory>()
          .where(
            (dir) =>
                File('${dir.path}/pubspec.yaml').existsSync() &&
                Directory('${dir.path}/test').existsSync(),
          )
          .map(
            (dir) =>
                'examples/'
                '${dir.uri.pathSegments.where((s) => s.isNotEmpty).last}',
          )
          .toList()
        ..sort();

  final packages = [
    '.', // Root workspace tests
    'bloc_signals',
    'bloc_signals_flutter',
    'bloc_signals_bloc',
    'bloc_signals_jaspr',
    'bloc_signals_replay',
    'bloc_signals_otel',
    'bloc_signals_test',
    'bloc_signals_lint',
    'bloc_signals_riverpod',
    'bloc_signals_hydrate',
    'bloc_signals_devtools',
    'bloc_signals_genui',
    'bloc_signals_genui_flutter',
    ...examplePackages,
    'website',
  ];

  print('🧪 Running workspace tests across ${packages.length} targets...\n');

  var failed = false;

  for (final pkg in packages) {
    final isWebsite = pkg == 'website';
    final isRoot = pkg == '.';
    final isExample = pkg.startsWith('examples/');
    final executable = isWebsite ? 'dart' : 'flutter';
    final filteredArgs = (isWebsite || isRoot || isExample)
        ? args.where((a) => !a.startsWith('--coverage')).toList()
        : args;
    final commandArgs = isWebsite
        ? ['test', '-p', 'chrome', ...filteredArgs]
        : ['test', ...filteredArgs];

    print('➡️ Running tests in $pkg ($executable ${commandArgs.join(' ')})');

    final process = Process.runSync(
      executable,
      commandArgs,
      workingDirectory: Directory(pkg).absolute.path,
    );

    if (process.stdout.toString().isNotEmpty) {
      stdout.write(process.stdout);
    }
    if (process.stderr.toString().isNotEmpty) {
      stderr.write(process.stderr);
    }

    if (process.exitCode != 0) {
      print('❌ Test failure in package $pkg');
      failed = true;
    } else {
      print('✅ Passed package $pkg\n');
    }
  }

  print(
    '🔍 Validating DevTools extension packaging in bloc_signals_devtools...',
  );
  final devtoolsValidation = Process.runSync('dart', [
    'run',
    'devtools_extensions',
    'validate',
    '--package=bloc_signals_devtools',
  ]);
  if (devtoolsValidation.stdout.toString().isNotEmpty) {
    stdout.write(devtoolsValidation.stdout);
  }
  if (devtoolsValidation.stderr.toString().isNotEmpty) {
    stderr.write(devtoolsValidation.stderr);
  }
  if (devtoolsValidation.exitCode != 0) {
    print('❌ DevTools extension validation failed.');
    failed = true;
  } else {
    print('✅ DevTools extension validation passed.\n');
  }

  if (failed) {
    print('💥 One or more package test suites failed.');
    exit(1);
  } else {
    print('🎉 All workspace package tests passed successfully!');
  }
}
