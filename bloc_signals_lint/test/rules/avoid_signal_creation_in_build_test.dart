import 'package:bloc_signals_lint/src/rules/avoid_signal_creation_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_effects.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #482) AvoidSignalCreationInBuild', () {
    test('flags direct signal(), computed(), and effect() in build() '
        'while ignoring nested closures and non-build methods', () async {
      const code = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = signal(0);
    final c = computed(() => 1);
    final e = effect(() {});
    return Button(
      onPressed: () {
        final okInCallback = signal(1);
      },
    );
  }
}

class MyState extends State<StatefulWidget> {
  @override
  void initState() {
    final ok = signal(0);
    final okComputed = computed(() => 1);
    final stop = effect(() {});
  }

  @override
  Widget build(BuildContext context) => Container();
}
''';
      final lints = await runLintRule(AvoidSignalCreationInBuild(), code);
      expect(lints, hasLength(3));
      expect(
        lints.map((l) => l.lexeme),
        containsAll(['signal', 'computed', 'effect']),
      );

      // Ensure AvoidUnmanagedSignalEffects does not duplicate build()
      // diagnostics.
      final unmanagedLints = await runLintRule(
        AvoidUnmanagedSignalEffects(),
        code,
      );
      expect(unmanagedLints, isEmpty);
    });

    test('flags signal/computed/effect in Jaspr build()', () async {
      const jasprCode = '''
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';

class MyComponent extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    final s = signal(0);
    return Component();
  }
}
''';
      final lints = await runLintRule(AvoidSignalCreationInBuild(), jasprCode);
      expect(lints, hasLength(1));
    });

    test('(Issue #482: BLOCKER-6) flags aliased bs.signal() and ignores local '
        'user-defined helpers in build()', () async {
      const code = '''
import 'package:bloc_signals/bloc_signals.dart' as bs;
import 'package:flutter/widgets.dart';

int signal(int x) => x;
int computed(int Function() fn) => fn();
void effect(void Function() fn) {}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final flagged = bs.signal(0);
    final flaggedComputed = bs.computed(() => 1);
    final localSignal = signal(0);
    final localComputed = computed(() => 1);
    effect(() {});
    return Container();
  }
}
''';
      final lints = await runLintRule(AvoidSignalCreationInBuild(), code);
      expect(lints, hasLength(2));
      expect(lints.map((l) => l.lexeme), containsAll(['signal', 'computed']));
    });

    test('(Issue #482: Round 2 BLOCKER-11) ignores helper.signal / computed / '
        'effect on custom non-prefix receiver in build()', () async {
      const code = '''
class Helper {
  int signal(int x) => x;
  int computed(int Function() fn) => fn();
  void effect(void Function() fn) {}
}

class MyWidget extends StatelessWidget {
  final Helper helper = Helper();

  @override
  Widget build(BuildContext context) {
    final a = helper.signal(0);
    final b = helper.computed(() => 1);
    helper.effect(() {});
    return Container();
  }
}
''';
      final lints = await runLintRule(AvoidSignalCreationInBuild(), code);
      expect(lints, isEmpty);
    });
  });
}
