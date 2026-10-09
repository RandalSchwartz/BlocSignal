import 'package:bloc_signals_lint/src/rules/avoid_context_watch_for_bloc_state.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_invalid_context_select_generics.dart';
import 'package:bloc_signals_lint/src/rules/avoid_manual_close_on_provided_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_providing_existing_instance_with_create.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_effects.dart';
import 'package:bloc_signals_lint/src/rules/prefer_bloc_signal_provider_read_in_callbacks.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group(
    '(Issue #315: R1) Flutter UI Rule AST Detection via rule.run()',
    () {
      test('AvoidEmitInBuild detects emit or add inside build method',
          () async {
        const badCode = '''
class MyEvent {}
class MyBloc extends BlocSignal<MyEvent, int> {
  MyBloc() : super(initialState: 0);
}

class MyWidget {
  final MyBloc bloc = MyBloc();
  Widget build(BuildContext context) {
    bloc.emit(42);
    bloc.add(MyEvent());
    return Container();
  }
}
''';
        final lints = await runLintRule(const AvoidEmitInBuild(), badCode);
        expect(lints, hasLength(2));
        expect(lints.map((l) => l.lexeme), containsAll(['emit', 'add']));
        expect(
          lints.map((l) => l.arguments?.first),
          containsAll(['emit', 'add']),
        );
      });

      test('AvoidEmitInBuild accepts emit or add inside event callbacks',
          () async {
        const goodCode = '''
class MyEvent {}
class MyBloc extends BlocSignal<MyEvent, int> {
  MyBloc() : super(initialState: 0);
}

class MyWidget {
  final MyBloc bloc = MyBloc();
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        bloc.add(MyEvent());
      },
    );
  }
}
''';
        final lints = await runLintRule(const AvoidEmitInBuild(), goodCode);
        expect(lints, isEmpty);
      });

      test(
        'AvoidEmitInBuild ignores emit or add on non-bloc objects in build',
        () async {
          const goodCode = '''
class CustomEmitter {
  void emit(int v) {}
}

class MyWidget {
  final CustomEmitter streamController = CustomEmitter();
  final CustomEmitter otherObject = CustomEmitter();
  final List<int> items = [];
  Widget build(BuildContext context) {
    streamController.emit(42);
    otherObject.emit(42);
    items.add(1);
    return Container();
  }
}
''';
          final lints = await runLintRule(const AvoidEmitInBuild(), goodCode);
          expect(lints, isEmpty);
        },
      );

      test('AvoidUnmanagedSignalEffects detects unassigned effect in widget',
          () async {
        const badCode = '''
class MyStatefulWidget extends State {
  void initState() {
    effect(() {
      print('unmanaged');
    });
  }
}
''';
        final lints =
            await runLintRule(const AvoidUnmanagedSignalEffects(), badCode);
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('effect'));
      });

      test(
        'AvoidUnmanagedSignalEffects accepts assigned effect in widget',
        () async {
          const goodCode = '''
class MyStatefulWidget extends State {
  late final void Function() _dispose;
  void initState() {
    _dispose = effect(() {
      print('managed');
    });
  }
}
''';
          final lints = await runLintRule(
            const AvoidUnmanagedSignalEffects(),
            goodCode,
          );
          expect(lints, isEmpty);
        },
      );

      test(
        'PreferBlocSignalProviderReadInCallbacks detects watch in onPressed',
        () async {
          const badCode = '''
class MyBloc extends CubitSignal<int> {
  MyBloc() : super(initialState: 0);
}

class MyWidget {
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        final bloc = context.watch<MyBloc>();
      },
    );
  }
}
''';
          final lints = await runLintRule(
            const PreferBlocSignalProviderReadInCallbacks(),
            badCode,
          );
          expect(lints, hasLength(1));
          expect(lints.first.lexeme, equals('watch'));
        },
      );

      test(
        'PreferBlocSignalProviderReadInCallbacks accepts read in onPressed',
        () async {
          const goodCode = '''
class MyBloc extends CubitSignal<int> {
  MyBloc() : super(initialState: 0);
}

class MyWidget {
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        final bloc = context.read<MyBloc>();
      },
    );
  }
}
''';
          final lints = await runLintRule(
            const PreferBlocSignalProviderReadInCallbacks(),
            goodCode,
          );
          expect(lints, isEmpty);
        },
      );

      test(
        'AvoidProvidingExistingInstanceWithCreate detects existing ref in '
        'create',
        () async {
          const badCode = '''
class MyBloc extends CubitSignal<int> {
  MyBloc() : super(initialState: 0);
}

final myGlobalBloc = MyBloc();

class MyWidget {
  Widget build(BuildContext context) {
    return BlocSignalProvider(
      create: (context) => myGlobalBloc,
      child: Container(),
    );
  }
}
''';
          final lints = await runLintRule(
            const AvoidProvidingExistingInstanceWithCreate(),
            badCode,
          );
          expect(lints, hasLength(1));
          expect(lints.first.lexeme, equals('myGlobalBloc'));
        },
      );

      test(
        'AvoidProvidingExistingInstanceWithCreate accepts fresh constructor '
        'in create',
        () async {
          const goodCode = '''
class MyBloc extends CubitSignal<int> {
  MyBloc() : super(initialState: 0);
}

class MyWidget {
  Widget build(BuildContext context) {
    return BlocSignalProvider(
      create: (context) => MyBloc(),
      child: Container(),
    );
  }
}
''';
          final lints = await runLintRule(
            const AvoidProvidingExistingInstanceWithCreate(),
            goodCode,
          );
          expect(lints, isEmpty);
        },
      );

      test('AvoidManualCloseOnProvidedBloc detects context.read().close()',
          () async {
        const badCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

void dispose(BuildContext context) {
  context.read<CounterBloc>().close();
}
''';
        final lints = await runLintRule(
          const AvoidManualCloseOnProvidedBloc(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('close'));
      });

      test(
        'AvoidContextWatchForBlocState detects context.watch<T>() in build',
        () async {
          const badCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

class CounterView {
  Widget build(BuildContext context) {
    final bloc = context.watch<CounterBloc>();
    return Container();
  }
}
''';
          final lints = await runLintRule(
            const AvoidContextWatchForBlocState(),
            badCode,
          );
          expect(lints, hasLength(1));
          expect(lints.first.lexeme, equals('watch'));
          expect(lints.first.arguments, equals(['CounterBloc']));
        },
      );

      test(
        'AvoidContextWatchForBlocState accepts context.read<T>() in build',
        () async {
          const goodCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

class CounterView {
  Widget build(BuildContext context) {
    final bloc = context.read<CounterBloc>();
    return Container();
  }
}
''';
          final lints = await runLintRule(
            const AvoidContextWatchForBlocState(),
            goodCode,
          );
          expect(lints, isEmpty);
        },
      );

      test(
        'AvoidInvalidContextSelectGenerics detects 3 generic type parameters',
        () async {
          const badCode = '''
class CounterState {}
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

class CounterView {
  Widget build(BuildContext context) {
    final count = context.select<CounterBloc, CounterState, int>((b) => b.value);
    return Container();
  }
}
''';
          final lints = await runLintRule(
            const AvoidInvalidContextSelectGenerics(),
            badCode,
          );
          expect(lints, hasLength(1));
          expect(
            lints.first.lexeme,
            equals('<CounterBloc, CounterState, int>'),
          );
        },
      );

      test(
        'AvoidInvalidContextSelectGenerics accepts 2 generic type parameters',
        () async {
          const goodCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

class CounterView {
  Widget build(BuildContext context) {
    final count = context.select<CounterBloc, int>((b) => b.value);
    return Container();
  }
}
''';
          final lints = await runLintRule(
            const AvoidInvalidContextSelectGenerics(),
            goodCode,
          );
          expect(lints, isEmpty);
        },
      );
    },
  );

  group('(Issue #326: R12) Closure and Receiver Guards', () {
    test(
      'AvoidContextWatchForBlocState ignores context.watch<T>() inside '
      'closures in build(), while PreferBlocSignalProviderReadInCallbacks '
      'flags it once',
      () async {
        const code = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

class CounterView {
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            context.watch<CounterBloc>();
          },
          child: Text('Block'),
        ),
        ElevatedButton(
          onPressed: () => context.watch<CounterBloc>(),
          child: Text('Arrow'),
        ),
      ],
    );
  }
}
''';
        final watchInBuildLints = await runLintRule(
          const AvoidContextWatchForBlocState(),
          code,
        );
        expect(watchInBuildLints, isEmpty);

        final readInCallbacksLints = await runLintRule(
          const PreferBlocSignalProviderReadInCallbacks(),
          code,
        );
        expect(readInCallbacksLints, hasLength(2));
      },
    );

    test(
      'AvoidInvalidContextSelectGenerics ignores non-BuildContext and implicit '
      'select calls while detecting BuildContext ctx.select',
      () async {
        const nonContextCode = '''
class Database {
  R select<A, B, R>() => throw UnimplementedError();
  void query() {
    select<int, String, bool>();
  }
}

void runQuery(Database db) {
  db.select<int, String, bool>();
}
''';
        final nonContextLints = await runLintRule(
          const AvoidInvalidContextSelectGenerics(),
          nonContextCode,
        );
        expect(nonContextLints, isEmpty);

        const ctxCode = '''
class CounterState {}
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

Widget buildWidget(BuildContext ctx) {
  final count = ctx.select<CounterBloc, CounterState, int>((b) => b.value);
  return Container();
}
''';
        final ctxLints = await runLintRule(
          const AvoidInvalidContextSelectGenerics(),
          ctxCode,
        );
        expect(ctxLints, hasLength(1));
        expect(
          ctxLints.first.lexeme,
          equals('<CounterBloc, CounterState, int>'),
        );
      },
    );

    test(
      'AvoidManualCloseOnProvidedBloc ignores unrelated .of().close() and '
      '.read().close() while detecting BlocSignalProvider.of and context.watch',
      () async {
        const unrelatedCode = '''
class MyStream {
  static MyStream of(int value) => MyStream();
  void close() {}
}

class Navigator {
  static Navigator of(BuildContext context) => Navigator();
  void close() {}
}

class Box {
  MyStream read() => MyStream();
}

void cleanup(BuildContext context, Box box) {
  MyStream.of(1).close();
  Navigator.of(context).close();
  box.read().close();
}
''';
        final unrelatedLints = await runLintRule(
          const AvoidManualCloseOnProvidedBloc(),
          unrelatedCode,
        );
        expect(unrelatedLints, isEmpty);

        const providerCloseCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

void badCleanup(BuildContext context) {
  BlocSignalProvider.of<CounterBloc>(context).close();
  context.watch<CounterBloc>().close();
}
''';
        final providerCloseLints = await runLintRule(
          const AvoidManualCloseOnProvidedBloc(),
          providerCloseCode,
        );
        expect(providerCloseLints, hasLength(2));
      },
    );
  });
}
