import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_effects.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #505) AvoidUnmanagedSignalEffects State mixins', () {
    test('flags unmanaged effect() in State mixin outside build() while '
        'ignoring build() and non-UI mixins', () async {
      const code = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';

mixin MyStateMixin<T extends StatefulWidget> on State<T> {
  void initMixin() {
    effect(() {});
  }

  @override
  Widget build(BuildContext context) {
    effect(() {});
    return Container();
  }
}

mixin PlainMixin {
  void initMixin() {
    effect(() {});
  }
}
''';
      final lints = await runLintRule(AvoidUnmanagedSignalEffects(), code);
      expect(lints, hasLength(1));
      expect(lints.first.lexeme, equals('effect'));
    });
  });
}
