import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/fixes/add_super_on_event_fix.dart';
import 'package:bloc_signals_lint/src/fixes/avoid_raw_signal_effects_in_bloc_fix.dart';
import 'package:bloc_signals_lint/src/fixes/prefer_read_in_callbacks_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_watch_with_read_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_positional_replay_constructor_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_cubit_signal_mixin_init_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_emit_in_helper_name_fix.dart';
import 'package:bloc_signals_lint/src/fixes/use_provider_value_fix.dart';
import 'package:bloc_signals_lint/src/rules/avoid_context_watch_for_bloc_state.dart';
import 'package:bloc_signals_lint/src/rules/avoid_providing_existing_instance_with_create.dart';
import 'package:bloc_signals_lint/src/rules/avoid_raw_signal_effects_in_bloc.dart';
import 'package:bloc_signals_lint/src/rules/prefer_bloc_signal_provider_read_in_callbacks.dart';
import 'package:bloc_signals_lint/src/rules/prefer_named_replay_constructor.dart';
import 'package:bloc_signals_lint/src/rules/require_cubit_signal_mixin_init.dart';
import 'package:bloc_signals_lint/src/rules/require_emit_in_helper_name.dart';
import 'package:bloc_signals_lint/src/rules/require_super_on_event.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('IDE Quick Fix Functional ChangeBuilder Verification', () {
    test(
      'AddSuperOnEventFix inserts super.onEvent(event); in onEvent body',
      () async {
        const sourceCode = '''
sealed class MyEvent {}

class MyBloc extends BlocSignal<MyEvent, int> {
  MyBloc() : super(initialState: 0);

  @override
  void onEvent(MyEvent event) {
    doSomething();
  }
}

void doSomething() {}
''';
        final transformed = await runLintFix(
          RequireSuperOnEvent(),
          AddSuperOnEventFix.new,
          sourceCode,
        );

        expect(transformed, contains('super.onEvent(event);'));
        expect(transformed, contains('doSomething();'));
      },
    );

    test('(Issue #322: R8) AddSuperOnEventFix respects custom parameter name '
        'in block body', () async {
      const sourceCode = '''
sealed class CounterEvent {}

class MyBloc extends BlocSignal<CounterEvent, int> {
  MyBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent e) {
    doSomething(e);
  }
}

void doSomething(CounterEvent e) {}
''';
      final transformed = await runLintFix(
        RequireSuperOnEvent(),
        AddSuperOnEventFix.new,
        sourceCode,
      );

      expect(transformed, contains('super.onEvent(e);'));
      expect(transformed, isNot(contains('super.onEvent(event);')));
      expect(transformed, contains('doSomething(e);'));
      parseString(content: transformed);
    });

    test('(Issue #322: R8) AddSuperOnEventFix converts arrow function body '
        'to block body with custom parameter name', () async {
      const sourceCode = '''
sealed class CounterEvent {}

class MyBloc extends BlocSignal<CounterEvent, int> {
  MyBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent e) => log(e);
}

void log(CounterEvent e) {}
''';
      final transformed = await runLintFix(
        RequireSuperOnEvent(),
        AddSuperOnEventFix.new,
        sourceCode,
      );

      expect(
        transformed,
        contains('{\n    super.onEvent(e);\n    log(e);\n  }'),
      );
      expect(transformed, isNot(contains('=>\n')));
      parseString(content: transformed);
    });

    test('(Issue #322: R8) AddSuperOnEventFix handles async block body '
        'and empty function body', () async {
      const asyncSource = '''
sealed class CounterEvent {}

class MyBloc extends BlocSignal<CounterEvent, int> {
  MyBloc() : super(initialState: 0);

  @override
  Future<void> onEvent(CounterEvent e) async {
    doSomething(e);
  }
}

void doSomething(CounterEvent e) {}
''';
      final asyncTransformed = await runLintFix(
        RequireSuperOnEvent(),
        AddSuperOnEventFix.new,
        asyncSource,
      );

      expect(asyncTransformed, contains('async {\n    super.onEvent(e);'));
      parseString(content: asyncTransformed);

      const emptySource = '''
sealed class CounterEvent {}

class MyBloc extends BlocSignal<CounterEvent, int> {
  MyBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent e);
}
''';
      final emptyTransformed = await runLintFix(
        RequireSuperOnEvent(),
        AddSuperOnEventFix.new,
        emptySource,
      );

      expect(emptyTransformed, contains('{\n    super.onEvent(e);\n  }'));
      parseString(content: emptyTransformed);

      const asyncArrowSource = '''
sealed class CounterEvent {}

class MyBloc extends BlocSignal<CounterEvent, int> {
  MyBloc() : super(initialState: 0);

  @override
  Future<void> onEvent(CounterEvent e) async => await log(e);
}

Future<void> log(CounterEvent e) async {}
''';
      final asyncArrowTransformed = await runLintFix(
        RequireSuperOnEvent(),
        AddSuperOnEventFix.new,
        asyncArrowSource,
      );

      expect(
        asyncArrowTransformed,
        contains('async {\n    super.onEvent(e);\n    await log(e);\n  }'),
      );
      parseString(content: asyncArrowTransformed);
    });

    test('PreferReadInCallbacksFix replaces watch with read', () async {
      const sourceCode = '''
sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);
}

Widget build(BuildContext context) {
  return ElevatedButton(
    onPressed: () => context.watch<CounterBloc>().add(Increment()),
    child: Text('Add'),
  );
}
''';
      final transformed = await runLintFix(
        PreferBlocSignalProviderReadInCallbacks(),
        PreferReadInCallbacksFix.new,
        sourceCode,
      );

      expect(transformed, contains('context.read<CounterBloc>()'));
      expect(transformed, isNot(contains('context.watch<CounterBloc>()')));
    });

    test(
      'RequireCubitSignalMixinInitFix handles block constructor body',
      () async {
        const sourceCode = '''
class MyService with CubitSignalMixin<int> {
  MyService() {
    doInit();
  }
}

void doInit() {}
''';
        final transformed = await runLintFix(
          RequireCubitSignalMixinInit(),
          RequireCubitSignalMixinInitFix.new,
          sourceCode,
        );

        expect(
          transformed,
          contains('initCubitSignal(initialState: TODO_INITIAL_STATE);'),
        );
        expect(transformed, contains('doInit();'));
      },
    );

    test(
      'RequireCubitSignalMixinInitFix handles empty constructor body',
      () async {
        const sourceCode = '''
class MyService with CubitSignalMixin<int> {
  MyService();
}
''';
        final transformed = await runLintFix(
          RequireCubitSignalMixinInit(),
          RequireCubitSignalMixinInitFix.new,
          sourceCode,
        );

        expect(
          transformed,
          contains(
            '{\n    initCubitSignal(initialState: TODO_INITIAL_STATE);\n  }',
          ),
        );
      },
    );

    test(
      '(Issue #302: F2, F8) RequireCubitSignalMixinInitFix fires for unnamed '
      'constructor at constructor token',
      () async {
        const sourceCode = '''
class MyService with CubitSignalMixin<int> {
  MyService() {
    doInit();
  }
}

void doInit() {}
''';
        final transformed = await runLintFix(
          RequireCubitSignalMixinInit(),
          RequireCubitSignalMixinInitFix.new,
          sourceCode,
        );

        expect(
          transformed,
          contains('initCubitSignal(initialState: TODO_INITIAL_STATE);'),
        );
        expect(transformed, contains('doInit();'));
      },
    );

    test('(Issue #302: F2, F8) RequireCubitSignalMixinInitFix generates '
        'constructor for class without constructor', () async {
      const sourceCode = '''
class MyService with CubitSignalMixin<int> {
}
''';
      final transformed = await runLintFix(
        RequireCubitSignalMixinInit(),
        RequireCubitSignalMixinInitFix.new,
        sourceCode,
      );

      expect(transformed, contains('MyService() {'));
      expect(
        transformed,
        contains('initCubitSignal(initialState: TODO_INITIAL_STATE);'),
      );
    });

    test('ReplaceContextWatchWithReadFix replaces watch with read', () async {
      const sourceCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    final bloc = context.watch<CounterBloc>();
    return Container();
  }
}
''';
      final transformed = await runLintFix(
        AvoidContextWatchForBlocState(),
        ReplaceContextWatchWithReadFix.new,
        sourceCode,
      );

      expect(transformed, contains('context.read<CounterBloc>()'));
      expect(transformed, isNot(contains('context.watch<CounterBloc>()')));
    });

    test(
      'AvoidRawSignalEffectsInBlocFix replaces effect with createEffect',
      () async {
        const sourceCode = '''
sealed class CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    effect(() {
      print(stateValue);
    });
  }
}
''';
        final transformed = await runLintFix(
          AvoidRawSignalEffectsInBloc(),
          AvoidRawSignalEffectsInBlocFix.new,
          sourceCode,
        );

        expect(transformed, contains('createEffect(() {'));
        expect(transformed, isNot(contains(' effect(() {')));
      },
    );

    test('(Issue #302: F9) UseProviderValueFix rewrites to '
        'BlocSignalProvider.value with unwrapped closure', () async {
      const sourceCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

Widget build(BuildContext context, CounterBloc existingBloc) {
  return BlocSignalProvider(
    create: (_) => existingBloc,
    child: Container(),
  );
}
''';
      final transformed = await runLintFix(
        AvoidProvidingExistingInstanceWithCreate(),
        UseProviderValueFix.new,
        sourceCode,
      );

      expect(transformed, contains('BlocSignalProvider.value('));
      expect(transformed, contains('value: existingBloc,'));
      expect(transformed, isNot(contains('create: (_) => existingBloc')));
      expect(transformed, isNot(contains('value: (_) => existingBloc')));
    });

    test('(Issue #302: F9) UseProviderValueFix supports generic type arguments '
        'and block function body', () async {
      const sourceCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

Widget build(BuildContext context, CounterBloc existingBloc) {
  return BlocSignalProvider<CounterBloc>(
    create: (context) {
      return existingBloc;
    },
    child: Container(),
  );
}
''';
      final transformed = await runLintFix(
        AvoidProvidingExistingInstanceWithCreate(),
        UseProviderValueFix.new,
        sourceCode,
      );

      expect(transformed, contains('BlocSignalProvider<CounterBloc>.value('));
      expect(transformed, contains('value: existingBloc,'));
      expect(transformed, isNot(contains('create:')));
    });

    test(
      'ReplacePositionalReplayConstructorFix rewrites constructor',
      () async {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(initial, limit: limit);
}
''';
        final transformed = await runLintFix(
          PreferNamedReplayConstructor(),
          ReplacePositionalReplayConstructorFix.new,
          sourceCode,
        );

        expect(
          transformed,
          contains('super(initialState: initial, limit: limit);'),
        );
        expect(transformed, isNot(contains('super.positional')));
      },
    );

    test(
      'RequireEmitInHelperNameFix renames helper declaration and call sites',
      () async {
        const sourceCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void update() {
    _prune();
    this._prune();
  }

  void _prune() {
    emit(stateValue + 1);
  }
}
''';
        final transformed = await runLintFix(
          RequireEmitInHelperName(),
          RequireEmitInHelperNameFix.new,
          sourceCode,
        );

        expect(transformed, contains('void _pruneAndEmit()'));
        expect(transformed, contains('_pruneAndEmit();'));
        expect(transformed, contains('this._pruneAndEmit();'));
        expect(transformed, isNot(contains('void _prune()')));
      },
    );

    test(
      'ReplacePositionalReplayConstructorFix rewrites with leading named args '
      'via runLintFix',
      () async {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(limit: limit, initial);
}
''';
        final transformed = await runLintFix(
          PreferNamedReplayConstructor(),
          ReplacePositionalReplayConstructorFix.new,
          sourceCode,
        );

        expect(
          transformed,
          contains('super(limit: limit, initialState: initial);'),
        );
        expect(transformed, isNot(contains('super.positional')));
      },
    );

    test('UseProviderValueFix handles MethodInvocation with and without type '
        'arguments', () async {
      const untypedFnSource = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

Object BlocSignalProvider({Object? create, Object? child}) => Object();

Object build(CounterBloc existingBloc) {
  return BlocSignalProvider(
    create: (_) => existingBloc,
    child: Object(),
  );
}
''';
      final untypedTransformed = await runLintFix(
        AvoidProvidingExistingInstanceWithCreate(),
        UseProviderValueFix.new,
        untypedFnSource,
      );
      expect(untypedTransformed, contains('BlocSignalProvider.value('));
      expect(untypedTransformed, contains('value: existingBloc,'));

      const typedFnSource = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

Object BlocSignalProvider<T>({Object? create, Object? child}) => Object();

Object build(CounterBloc existingBloc) {
  return BlocSignalProvider<CounterBloc>(
    create: (_) => existingBloc,
    child: Object(),
  );
}
''';
      final typedTransformed = await runLintFix(
        AvoidProvidingExistingInstanceWithCreate(),
        UseProviderValueFix.new,
        typedFnSource,
      );
      expect(
        typedTransformed,
        contains('BlocSignalProvider<CounterBloc>.value('),
      );
      expect(typedTransformed, contains('value: existingBloc,'));

      const tearOffSource = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

Object BlocSignalProvider({Object? create, Object? child}) => Object();

Object build(CounterBloc Function(Object) makeBloc) {
  return BlocSignalProvider(
    create: makeBloc,
    child: Object(),
  );
}
''';
      final tearOffTransformed = await runLintFix(
        AvoidProvidingExistingInstanceWithCreate(),
        UseProviderValueFix.new,
        tearOffSource,
        selectionOffset: tearOffSource.indexOf('create: makeBloc'),
      );
      expect(tearOffTransformed, contains('BlocSignalProvider.value('));
      expect(tearOffTransformed, contains('value: makeBloc,'));
    });
    test('(Issue #477: Area 1) RequireEmitInHelperNameFix renames helper '
        'declaration and cascade call sites inside MixinDeclaration', () async {
      const sourceCode = '''
import 'package:bloc_signals/bloc_signals.dart';

mixin CounterMixin on CubitSignal<int> {
  void update() {
    _prune();
    this._prune();
    this.._prune();
  }

  void _prune() {
    emit(stateValue + 1);
  }
}
''';
      final transformed = await runLintFix(
        RequireEmitInHelperName(),
        RequireEmitInHelperNameFix.new,
        sourceCode,
      );

      expect(transformed, contains('void _pruneAndEmit()'));
      expect(transformed, contains('_pruneAndEmit();'));
      expect(transformed, contains('this._pruneAndEmit();'));
      expect(transformed, contains('this.._pruneAndEmit();'));
      expect(transformed, isNot(contains('void _prune()')));
    });

    test(
      '(Issue #477: NBO-1) RequireEmitInHelperNameFix ignores foreign cascade '
      'calls and supports computeRename(mixinDeclaration: ...)',
      () {
        const sourceCode = '''
class Other {
  void _prune() {}
}

mixin CounterMixin on CubitSignal<int> {
  void update(Other other) {
    other.._prune();
    _prune();
  }

  void _prune() {
    emit(stateValue + 1);
  }
}
''';
        final parseResult = parseString(content: sourceCode);
        final mixinDecl = parseResult.unit.declarations
            .whereType<MixinDeclaration>()
            .first;
        final body = mixinDecl.body as BlockClassBody;
        final methodDecl = body.members
            .whereType<MethodDeclaration>()
            .firstWhere((m) => m.name.lexeme == '_prune');

        final computed = RequireEmitInHelperNameFix.computeRename(
          source: sourceCode,
          mixinDeclaration: mixinDecl,
          methodToRename: methodDecl,
        );

        expect(computed, contains('other.._prune();'));
        expect(computed, contains('_pruneAndEmit();'));
        expect(computed, contains('void _pruneAndEmit()'));
      },
    );

    test(
      'All 8 quick-fix producers expose valid applicability and fixKind',
      () async {
        final seenKinds = <String>{};

        Future<void> verifyFix(
          String source,
          AnalysisRule rule,
          ResolvedCorrectionProducer Function({
            required CorrectionProducerContext context,
          })
          factory,
        ) async {
          await runLintFix(
            rule,
            factory,
            source,
            onProducer: (producer) {
              expect(
                // Testing protected applicability getter.
                // ignore: invalid_use_of_protected_member
                producer.applicability,
                equals(CorrectionApplicability.singleLocation),
              );
              final kindId = producer.fixKind?.id;
              expect(kindId, isNotNull);
              expect(seenKinds.add(kindId!), isTrue);
            },
          );
        }

        await verifyFix(
          'sealed class E {}\nclass B extends BlocSignal<E, int> {\n'
          '  B() : super(initialState: 0);\n'
          '  @override void onEvent(E e) {}\n}\n',
          RequireSuperOnEvent(),
          AddSuperOnEventFix.new,
        );
        await verifyFix(
          'sealed class E {}\nclass B extends BlocSignal<E, int> {\n'
          '  B() : super(initialState: 0) { effect(() {}); }\n}\n',
          AvoidRawSignalEffectsInBloc(),
          AvoidRawSignalEffectsInBlocFix.new,
        );
        await verifyFix(
          'class B extends CubitSignal<int> { B() : super(initialState: 0); }\n'
          'Widget f(BuildContext context) => ElevatedButton(\n'
          '  onPressed: () => context.watch<B>(), child: Container());\n',
          PreferBlocSignalProviderReadInCallbacks(),
          PreferReadInCallbacksFix.new,
        );
        await verifyFix(
          'class B extends CubitSignal<int> { B() : super(initialState: 0); }\n'
          'class W extends StatelessWidget {\n'
          '  Widget build(BuildContext context) {\n'
          '    context.watch<B>(); return Container();\n  }\n}\n',
          AvoidContextWatchForBlocState(),
          ReplaceContextWatchWithReadFix.new,
        );
        await verifyFix(
          'class C extends ReplayCubit<int> {\n'
          '  C(int i) : super.positional(i);\n}\n',
          PreferNamedReplayConstructor(),
          ReplacePositionalReplayConstructorFix.new,
        );
        await verifyFix(
          'class S with CubitSignalMixin<int> { S(); }\n',
          RequireCubitSignalMixinInit(),
          RequireCubitSignalMixinInitFix.new,
        );
        await verifyFix(
          'class C extends CubitSignal<int> {\n'
          '  C() : super(initialState: 0);\n  void _h() { emit(1); }\n}\n',
          RequireEmitInHelperName(),
          RequireEmitInHelperNameFix.new,
        );
        await verifyFix(
          'class B extends CubitSignal<int> { B() : super(initialState: 0); }\n'
          'Widget f(B b) => BlocSignalProvider(create: (_) => b);\n',
          AvoidProvidingExistingInstanceWithCreate(),
          UseProviderValueFix.new,
        );

        expect(seenKinds, hasLength(8));
      },
    );
  });
}
