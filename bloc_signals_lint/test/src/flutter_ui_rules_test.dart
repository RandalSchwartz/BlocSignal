import 'package:bloc_signals_lint/src/rules/avoid_context_watch_for_bloc_state.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_invalid_context_select_generics.dart';
import 'package:bloc_signals_lint/src/rules/avoid_manual_close_on_provided_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_providing_existing_instance_with_create.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_effects.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unused_select_result.dart';
import 'package:bloc_signals_lint/src/rules/prefer_bloc_signal_provider_read_in_callbacks.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #315: R1) Flutter UI Rule AST Detection via rule.run()', () {
    test('AvoidEmitInBuild detects emit or add inside build method', () async {
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
      final lints = await runLintRule(AvoidEmitInBuild(), badCode);
      expect(lints, hasLength(2));
      expect(lints.map((l) => l.lexeme), containsAll(['emit', 'add']));
      expect(
        lints.map((l) => l.arguments?.first),
        containsAll(['emit', 'add']),
      );
    });

    test(
      'AvoidEmitInBuild accepts emit or add inside event callbacks',
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
        final lints = await runLintRule(AvoidEmitInBuild(), goodCode);
        expect(lints, isEmpty);
      },
    );

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
        final lints = await runLintRule(AvoidEmitInBuild(), goodCode);
        expect(lints, isEmpty);
      },
    );

    test(
      'AvoidUnmanagedSignalEffects detects unassigned effect in widget',
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
        final lints = await runLintRule(AvoidUnmanagedSignalEffects(), badCode);
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('effect'));
      },
    );

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
          AvoidUnmanagedSignalEffects(),
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
          PreferBlocSignalProviderReadInCallbacks(),
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
          PreferBlocSignalProviderReadInCallbacks(),
          goodCode,
        );
        expect(lints, isEmpty);
      },
    );

    test('AvoidProvidingExistingInstanceWithCreate detects existing ref in '
        'create', () async {
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
        AvoidProvidingExistingInstanceWithCreate(),
        badCode,
      );
      expect(lints, hasLength(1));
      expect(lints.first.lexeme, equals('myGlobalBloc'));
    });

    test('AvoidProvidingExistingInstanceWithCreate accepts fresh constructor '
        'in create', () async {
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
        AvoidProvidingExistingInstanceWithCreate(),
        goodCode,
      );
      expect(lints, isEmpty);
    });

    test(
      'AvoidManualCloseOnProvidedBloc detects context.read().close()',
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
          AvoidManualCloseOnProvidedBloc(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('close'));
      },
    );

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
          AvoidContextWatchForBlocState(),
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
          AvoidContextWatchForBlocState(),
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
          AvoidInvalidContextSelectGenerics(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('<CounterBloc, CounterState, int>'));
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
          AvoidInvalidContextSelectGenerics(),
          goodCode,
        );
        expect(lints, isEmpty);
      },
    );
  });

  group('(Issue #326: R12) Closure and Receiver Guards', () {
    test('AvoidContextWatchForBlocState ignores context.watch<T>() inside '
        'closures in build(), while PreferBlocSignalProviderReadInCallbacks '
        'flags it once', () async {
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
        AvoidContextWatchForBlocState(),
        code,
      );
      expect(watchInBuildLints, isEmpty);

      final readInCallbacksLints = await runLintRule(
        PreferBlocSignalProviderReadInCallbacks(),
        code,
      );
      expect(readInCallbacksLints, hasLength(2));
    });

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
          AvoidInvalidContextSelectGenerics(),
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
          AvoidInvalidContextSelectGenerics(),
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
          AvoidManualCloseOnProvidedBloc(),
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
          AvoidManualCloseOnProvidedBloc(),
          providerCloseCode,
        );
        expect(providerCloseLints, hasLength(2));
      },
    );
  });

  group('(Issue #477: Areas 2 & 3) Jaspr, HookWidget, build() effects, and '
      'BuildContext rules', () {
    test('(Issue #477: Area 2) AvoidUnmanagedSignalEffects flags Jaspr '
        'components, HookWidget, subclasses, and assigned effect/computed in '
        'build(), while allowing initState and useEffect', () async {
      const jasprCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:jaspr/jaspr.dart';

class MyJasprStateless extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    final stop = effect(() {});
    final c = computed(() => 1);
    return Component();
  }
}

class MyJasprState extends State<StatefulComponent> {
  late final void Function() _stop;

  @override
  void initState() {
    _stop = effect(() {});
  }

  void _initComputed() {
    final c = computed(() => 2);
  }

  @override
  Component build(BuildContext context) {
    effect(() {});
    return Component();
  }
}
''';
      final jasprLints = await runLintRule(
        AvoidUnmanagedSignalEffects(),
        jasprCode,
      );
      // 2 in MyJasprStateless.build (stop = effect, c = computed) +
      // 1 in MyJasprState.build (effect)
      expect(jasprLints, hasLength(3));

      const hooksAndSubclassCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class BaseWidget extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}

class SubWidget extends BaseWidget {
  @override
  Widget build(BuildContext context) {
    final stop = effect(() {});
    return Container();
  }
}

class MyHookWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    useEffect(() {
      return effect(() {});
    }, const []);
    final leaked = computed(() => 42);
    return Container();
  }
}
''';
      final hooksLints = await runLintRule(
        AvoidUnmanagedSignalEffects(),
        hooksAndSubclassCode,
      );
      // 1 in SubWidget.build (effect) + 1 in MyHookWidget.build (computed);
      // useEffect callback allowed
      expect(hooksLints, hasLength(2));
    });

    test(
      '(Issue #477: Area 3) AvoidInvalidContextSelectGenerics flags omitted '
      'generics, 1 arg, >2 args, non-BlocSignalBase, and raw BlocSignalBase',
      () async {
        const code = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    final a = context.select((CounterCubit b) => b.value);
    final b = context.select<CounterCubit>((b) => b.value);
    final c = context.select<CounterCubit, int, String>((b) => b.value);
    final d = context.select<int, String>((i) => i.toString());
    final e = context.select<BlocSignalBase, int>((b) => 0);
    final valid = context.select<CounterCubit, int>((b) => b.value);
    return Container();
  }
}
''';
        final lints = await runLintRule(
          AvoidInvalidContextSelectGenerics(),
          code,
        );
        expect(lints, hasLength(5));
      },
    );

    test(
      '(Issue #477: Area 3) PreferBlocSignalProviderReadInCallbacks and '
      'AvoidUnusedSelectResult recognize non-context BuildContext variables',
      () async {
        const watchCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  Widget build(BuildContext ctx) {
    return Button(
      onPressed: () {
        ctx.watch<CounterCubit>();
      },
    );
  }
}
''';
        final watchLints = await runLintRule(
          PreferBlocSignalProviderReadInCallbacks(),
          watchCode,
        );
        expect(watchLints, hasLength(1));
        expect(watchLints.first.lexeme, equals('watch'));

        const selectCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  Widget build(BuildContext buildContext) {
    buildContext.select<CounterCubit, int>((b) => b.value);
    return Container();
  }
}
''';
        final selectLints = await runLintRule(
          AvoidUnusedSelectResult(),
          selectCode,
        );
        expect(selectLints, hasLength(1));
        expect(selectLints.first.lexeme, equals('select'));
      },
    );

    test('(Issue #477: BLOCKER-1) AvoidUnmanagedSignalEffects ignores non-UI '
        'classes extending user-defined State or Component', () async {
      const nonUiCode = '''
class State {}
class Component {}

class DomainState extends State {
  void run() {
    effect(() {});
  }
}

class DomainComponent extends Component {
  Object build(Object context) {
    final stop = effect(() {});
    return stop;
  }
}
''';
      final lints = await runLintRule(AvoidUnmanagedSignalEffects(), nonUiCode);
      expect(lints, isEmpty);
    });

    test(
      '(Issue #477: BLOCKER-2) AvoidInvalidContextSelectGenerics flags '
      'dynamic and void first type args while allowing BlocSignalBase<int>',
      () async {
        const code = '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    final a = context.select<dynamic, int>((b) => 0);
    final b = context.select<void, int>((b) => 0);
    final valid = context.select<BlocSignalBase<int>, int>((b) => b.value);
    return Container();
  }
}
''';
        final lints = await runLintRule(
          AvoidInvalidContextSelectGenerics(),
          code,
        );
        expect(
          lints.map((l) => l.lexeme),
          equals(['<dynamic, int>', '<void, int>']),
        );
      },
    );

    test('(Issue #477: NBO-1) PreferBlocSignalProviderReadInCallbacks and '
        'AvoidUnusedSelectResult skip non-BuildContext named context and '
        'detect Jaspr BuildContext', () async {
      const fakeContextCode = '''
class FakeCtx {
  T watch<T>() => throw UnimplementedError();
  R select<B, R>(R Function(B) fn) => throw UnimplementedError();
}

void runFake(FakeCtx context) {
  Button(onPressed: () {
    context.watch<int>();
  });
  context.select<int, int>((i) => i);
}
''';
      expect(
        await runLintRule(
          PreferBlocSignalProviderReadInCallbacks(),
          fakeContextCode,
        ),
        isEmpty,
      );
      expect(
        await runLintRule(AvoidUnusedSelectResult(), fakeContextCode),
        isEmpty,
      );

      const jasprContextCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:jaspr/jaspr.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyButton {
  MyButton({void Function()? onPressed});
}

class MyJasprComp extends StatelessComponent {
  @override
  Component build(BuildContext ctx) {
    ctx.select<CounterCubit, int>((b) => b.value);
    MyButton(
      onPressed: () {
        ctx.watch<CounterCubit>();
      },
    );
    return Component();
  }
}
''';
      expect(
        await runLintRule(
          PreferBlocSignalProviderReadInCallbacks(),
          jasprContextCode,
        ),
        hasLength(1),
      );
      expect(
        await runLintRule(AvoidUnusedSelectResult(), jasprContextCode),
        hasLength(1),
      );
    });
  });
}
