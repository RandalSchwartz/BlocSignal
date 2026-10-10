import 'dart:io';

/// Calculates coverage from lcov.info files and optionally enforces minimum thresholds.
void main(List<String> args) {
  double? minThreshold;
  double? perPackageMinThreshold;
  final paths = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--min=')) {
      final raw = arg.substring(6);
      minThreshold = double.tryParse(raw);
      if (minThreshold == null) {
        stderr.writeln('Invalid --min threshold value: $raw');
        exit(1);
      }
    } else if (arg == '--min' && i + 1 < args.length) {
      final raw = args[++i];
      minThreshold = double.tryParse(raw);
      if (minThreshold == null) {
        stderr.writeln('Invalid --min threshold value: $raw');
        exit(1);
      }
    } else if (arg.startsWith('--per-package-min=')) {
      final raw = arg.substring('--per-package-min='.length);
      perPackageMinThreshold = double.tryParse(raw);
      if (perPackageMinThreshold == null) {
        stderr.writeln('Invalid --per-package-min threshold value: $raw');
        exit(1);
      }
    } else if (arg == '--per-package-min' && i + 1 < args.length) {
      final raw = args[++i];
      perPackageMinThreshold = double.tryParse(raw);
      if (perPackageMinThreshold == null) {
        stderr.writeln('Invalid --per-package-min threshold value: $raw');
        exit(1);
      }
    } else if (!arg.startsWith('-')) {
      paths.add(arg);
    }
  }

  final files = <File>[];
  if (paths.isNotEmpty) {
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) {
        files.add(f);
      } else {
        print('Coverage file not found at: $p');
        exit(1);
      }
    }
  } else {
    // Auto-discover coverage/lcov.info across workspace packages with a lib/ directory
    final candidateDirs = [
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
    ];

    final exampleDirs = Directory('examples').existsSync()
        ? (Directory('examples')
              .listSync()
              .whereType<Directory>()
              .where(
                (dir) =>
                    File('${dir.path}/pubspec.yaml').existsSync() &&
                    Directory('${dir.path}/coverage').existsSync(),
              )
              .map(
                (dir) =>
                    'examples/'
                    '${dir.uri.pathSegments.where((s) => s.isNotEmpty).last}',
              )
              .toList()
            ..sort())
        : <String>[];

    candidateDirs.addAll(exampleDirs);

    for (final dir in candidateDirs) {
      final lcovFile = File('$dir/coverage/lcov.info');
      if (lcovFile.existsSync()) {
        files.add(lcovFile);
      }
    }
  }

  if (files.isEmpty) {
    print('No coverage files found.');
    exit(1);
  }

  var totalLines = 0;
  var totalHit = 0;
  final packageStats = <({String name, int hit, int total, double pct})>[];

  for (final file in files) {
    print('\n📄 Coverage report: ${file.path}');
    final lines = file.readAsLinesSync();
    var currentFile = '';
    var fileTotal = 0;
    var fileHit = 0;
    var pkgTotal = 0;
    var pkgHit = 0;
    final uncovered = <int>[];

    for (final l in lines) {
      if (l.startsWith('SF:')) {
        currentFile = l.substring(3);
        fileTotal = 0;
        fileHit = 0;
        uncovered.clear();
      } else if (l.startsWith('DA:')) {
        final parts = l.substring(3).split(',');
        final lineNum = int.parse(parts[0]);
        final hits = int.parse(parts[1]);
        fileTotal++;
        pkgTotal++;
        totalLines++;
        if (hits > 0) {
          fileHit++;
          pkgHit++;
          totalHit++;
        } else {
          uncovered.add(lineNum);
        }
      } else if (l == 'end_of_record') {
        final pct = fileTotal == 0 ? 100.0 : (fileHit / fileTotal) * 100;
        print(
          '${pct.toStringAsFixed(1).padLeft(5)}% ($fileHit/$fileTotal) - $currentFile',
        );
        if (uncovered.isNotEmpty) {
          print('       Uncovered lines: $uncovered');
        }
      }
    }

    final pkgPct = pkgTotal == 0 ? 100.0 : (pkgHit / pkgTotal) * 100;
    packageStats.add((
      name: _derivePackageName(file.path),
      hit: pkgHit,
      total: pkgTotal,
      pct: pkgPct,
    ));
  }

  print('\n${'=' * 50}');
  print('PACKAGE COVERAGE SUMMARY:');
  for (final stat in packageStats) {
    print(
      '  ${stat.pct.toStringAsFixed(1).padLeft(5)}% (${stat.hit}/${stat.total}) - ${stat.name}',
    );
  }

  final overallPct = totalLines == 0 ? 100.0 : (totalHit / totalLines) * 100;
  print('=' * 50);
  print(
    'OVERALL COVERAGE: ${overallPct.toStringAsFixed(1)}% ($totalHit/$totalLines)',
  );

  var failed = false;

  if (perPackageMinThreshold != null) {
    final failingPackages = packageStats
        .where((s) => s.pct < perPackageMinThreshold!)
        .toList();
    if (failingPackages.isNotEmpty) {
      final summary = failingPackages
          .map((s) => '${s.name} (${s.pct.toStringAsFixed(1)}%)')
          .join(', ');
      print(
        '❌ Per-package coverage threshold check failed: $summary '
        'below minimum required ${perPackageMinThreshold.toStringAsFixed(1)}%.',
      );
      failed = true;
    } else {
      print(
        '✅ Per-package coverage threshold check passed: all ${packageStats.length} '
        'packages meet required minimum ${perPackageMinThreshold.toStringAsFixed(1)}%.',
      );
    }
  }

  if (minThreshold != null) {
    if (overallPct < minThreshold) {
      print(
        '❌ Coverage threshold check failed: ${overallPct.toStringAsFixed(1)}% '
        'is below minimum required ${minThreshold.toStringAsFixed(1)}%.',
      );
      failed = true;
    } else {
      print(
        '✅ Coverage threshold check passed: ${overallPct.toStringAsFixed(1)}% '
        'meets required minimum ${minThreshold.toStringAsFixed(1)}%.',
      );
    }
  }

  if (failed) {
    exit(1);
  }
}

String _derivePackageName(String filePath) {
  final normalized = filePath.replaceAll(r'\', '/');
  final segments = normalized
      .split('/')
      .where((s) => s.isNotEmpty && s != '.')
      .toList();
  final covIndex = segments.lastIndexOf('coverage');
  if (covIndex > 0) {
    if (covIndex >= 2 && segments[covIndex - 2] == 'examples') {
      return 'examples/${segments[covIndex - 1]}';
    }
    return segments[covIndex - 1];
  }
  return segments.isNotEmpty ? segments.last : filePath;
}
