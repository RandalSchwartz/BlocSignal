import 'package:bloc_signals_lint/src/rules/avoid_context_select_outside_build.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #482) AvoidContextSelectOutsideBuild', () {
    test('flags context.select and context.value inside callbacks, '
        'computed/effect, and non-build lifecycle methods', () async {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyState extends State<StatefulWidget> {
  @override
  void initState() {
    final a = context.select<CounterCubit, int>((b) => b.value);
    final b = context.value<CounterCubit, int>();
  }

  @override
  void didChangeDependencies() {
    final c = context.select<CounterCubit, int>((b) => b.value);
  }

  @override
  void dispose() {
    final d = context.value<CounterCubit, int>();
  }

  @override
  Widget build(BuildContext context) {
    final stop = effect(() {
      final e = context.select<CounterCubit, int>((b) => b.value);
    });
    return Button(
      onPressed: () {
        final f = context.select<CounterCubit, int>((b) => b.value);
        final g = context.value<CounterCubit, int>();
      },
    );
  }
}
''';
      final lints = await runLintRule(
        AvoidContextSelectOutsideBuild(),
        badCode,
      );
      expect(lints, hasLength(7));
    });

    test('allows context.select and context.value directly in build() and '
        'build* helper methods', () async {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  Widget _buildHeader(BuildContext context) {
    final count = context.select<CounterCubit, int>((b) => b.value);
    return Text('count');
  }

  @override
  Widget build(BuildContext context) {
    final count = context.value<CounterCubit, int>();
    return _buildHeader(context);
  }
}
''';
      final lints = await runLintRule(
        AvoidContextSelectOutsideBuild(),
        goodCode,
      );
      expect(lints, isEmpty);
    });

    test('(Issue #482: NBO-3) allows Builder/LayoutBuilder callbacks inside '
        'build()', () async {
      const builderCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class Builder extends Widget {
  Builder({required Widget Function(BuildContext context) builder});
}

class LayoutBuilder extends Widget {
  LayoutBuilder({
    required Widget Function(BuildContext context, Object constraints) builder,
  });
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        final a = ctx.select<CounterCubit, int>((b) => b.value);
        return LayoutBuilder(
          builder: (innerCtx, _) =>
              Text(innerCtx.value<CounterCubit, int>().toString()),
        );
      },
    );
  }
}
''';
      final lints = await runLintRule(
        AvoidContextSelectOutsideBuild(),
        builderCode,
      );
      expect(lints, isEmpty);
    });

    test('(Issue #482: Round 2 BLOCKER-12) ignores non-BuildContext '
        'select() and value() outside build()', () async {
      const code = '''
class Db {
  int select(String query) => 0;
}
class Box {
  int value() => 1;
}

void nonUi(Db db, Box box) {
  final a = db.select('SELECT 1');
  final b = box.value();
}
''';
      final lints = await runLintRule(AvoidContextSelectOutsideBuild(), code);
      expect(lints, isEmpty);
    });
  });
}
