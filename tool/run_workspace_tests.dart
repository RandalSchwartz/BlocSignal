import 'dart:io';

/// Runs tests across all workspace packages in isolation to prevent
/// path resolution and symbol compilation collisions.
void main(List<String> args) {
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
    'website',
  ];

  print('🧪 Running workspace tests across ${packages.length} targets...\n');

  var failed = false;

  for (final pkg in packages) {
    final isWebsite = pkg == 'website';
    final executable = 'flutter';
    final commandArgs = isWebsite
        ? ['pub', 'run', 'test', '-p', 'chrome', ...args]
        : ['test', ...args];

    print('➡️ Running tests in $pkg ($executable test ${args.join(' ')})');

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

  if (failed) {
    print('💥 One or more package test suites failed.');
    exit(1);
  } else {
    print('🎉 All workspace package tests passed successfully!');
  }
}
