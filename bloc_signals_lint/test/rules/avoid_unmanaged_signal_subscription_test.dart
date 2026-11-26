import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_subscription.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #482) AvoidUnmanagedSignalSubscription', () {
    test(
      'flags discarded ReadonlySignal.subscribe(...) expression statements',
      () async {
        const badCode = '''
void bad(ReadonlySignal<int> count) {
  count.subscribe((v) {});
  final s = signal(0);
  s.subscribe((v) {});
}
''';
        final lints = await runLintRule(
          AvoidUnmanagedSignalSubscription(),
          badCode,
        );
        expect(lints, hasLength(2));
        expect(lints.every((l) => l.lexeme == 'subscribe'), isTrue);
      },
    );

    test('allows assigned, stored, or returned subscribe() cleanup closures '
        'and non-ReadonlySignal subscribe()', () async {
      const goodCode = '''
class CustomPubSub {
  void subscribe(void Function(int) cb) {}
}

void Function() good(ReadonlySignal<int> count, CustomPubSub pubSub) {
  final unsub = count.subscribe((v) {});
  final List<void Function()> subs = [];
  subs.add(count.subscribe((v) {}));
  pubSub.subscribe((v) {});
  return count.subscribe((v) {});
}
''';
      final lints = await runLintRule(
        AvoidUnmanagedSignalSubscription(),
        goodCode,
      );
      expect(lints, isEmpty);
    });

    test(
      '(Issue #482: BLOCKER-1) flags ReadonlySignal from preact_signals',
      () async {
        const preactCode = '''
import 'package:preact_signals/preact_signals.dart';

void bad(ReadonlySignal<int> count) {
  count.subscribe((v) {});
}
''';
        final lints = await runLintRule(
          AvoidUnmanagedSignalSubscription(),
          preactCode,
        );
        expect(lints, hasLength(1));
        expect(lints.single.lexeme, equals('subscribe'));
      },
    );

    test('(Issue #482: Round 2 BLOCKER-13) ignores dynamic receiver '
        'subscribe()', () async {
      const dynamicCode = '''
void ok(dynamic d) {
  d.subscribe((v) {});
}
''';
      final lints = await runLintRule(
        AvoidUnmanagedSignalSubscription(),
        dynamicCode,
      );
      expect(lints, isEmpty);
    });
  });
}
