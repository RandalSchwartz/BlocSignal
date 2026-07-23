import 'package:flutter_test/flutter_test.dart';

import '../bin/run_benchmarks.dart' as runner;

void main() {
  test('Run cross-framework performance benchmarks', () {
    runner.main();
  });
}
