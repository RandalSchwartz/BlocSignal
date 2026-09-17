import 'dart:io';

/// Calculates coverage from lcov.info files and optionally enforces a minimum threshold.
void main(List<String> args) {
  double? minThreshold;
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
    // Auto-discover coverage/lcov.info across known workspace packages
    final candidateDirs = [
      '.',
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

    for (final dir in candidateDirs) {
      final lcovFile = File(
        dir == '.' ? 'coverage/lcov.info' : '$dir/coverage/lcov.info',
      );
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

  for (final file in files) {
    print('\n📄 Coverage report: ${file.path}');
    final lines = file.readAsLinesSync();
    var currentFile = '';
    var fileTotal = 0;
    var fileHit = 0;
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
        totalLines++;
        if (hits > 0) {
          fileHit++;
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
  }

  final overallPct = totalLines == 0 ? 100.0 : (totalHit / totalLines) * 100;
  print('=' * 50);
  print(
    'OVERALL COVERAGE: ${overallPct.toStringAsFixed(1)}% ($totalHit/$totalLines)',
  );

  if (minThreshold != null) {
    if (overallPct < minThreshold) {
      print(
        '❌ Coverage threshold check failed: ${overallPct.toStringAsFixed(1)}% '
        'is below minimum required ${minThreshold.toStringAsFixed(1)}%.',
      );
      exit(1);
    } else {
      print(
        '✅ Coverage threshold check passed: ${overallPct.toStringAsFixed(1)}% '
        'meets required minimum ${minThreshold.toStringAsFixed(1)}%.',
      );
    }
  }
}
