import 'dart:io';

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : 'coverage/lcov.info';
  final file = File(path);
  if (!file.existsSync()) {
    print('Coverage file not found at: $path');
    exit(1);
  }

  final lines = file.readAsLinesSync();
  var currentFile = '';
  var fileTotal = 0;
  var fileHit = 0;
  var totalLines = 0;
  var totalHit = 0;
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

  final overallPct = totalLines == 0 ? 100.0 : (totalHit / totalLines) * 100;
  print('=' * 50);
  print(
    'OVERALL COVERAGE: ${overallPct.toStringAsFixed(1)}% ($totalHit/$totalLines)',
  );
}
