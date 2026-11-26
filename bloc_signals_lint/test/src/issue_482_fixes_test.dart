import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:bloc_signals_lint/src/fixes/add_hydrated_mixin_init_fix.dart';
import 'package:bloc_signals_lint/src/fixes/add_hydrated_storage_prefix_fix.dart';
import 'package:bloc_signals_lint/src/fixes/bind_unused_select_result_fix.dart';
import 'package:bloc_signals_lint/src/fixes/fix_context_select_generics_fix.dart';
import 'package:bloc_signals_lint/src/fixes/insert_to_stream_for_transformer_fix.dart';
import 'package:bloc_signals_lint/src/fixes/remove_duplicate_event_handler_fix.dart';
import 'package:bloc_signals_lint/src/fixes/remove_manual_close_on_provided_bloc_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_select_outside_build_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_watch_with_value_fix.dart';
import 'package:bloc_signals_lint/src/rules/avoid_context_select_outside_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_context_watch_for_bloc_state.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_invalid_context_select_generics.dart';
import 'package:bloc_signals_lint/src/rules/avoid_manual_close_on_provided_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_stream_transformers_on_bloc_signal.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unused_select_result.dart';
import 'package:bloc_signals_lint/src/rules/require_hydrated_mixin_init.dart';
import 'package:bloc_signals_lint/src/rules/require_hydrated_storage_prefix.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #482) 9 New IDE Quick-Fixes', () {
    test(
      'AddHydratedStoragePrefixFix inserts snake_case storagePrefix',
      () async {
        const source = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class UserProfileCubit extends HydratedCubitSignal<int> {
  UserProfileCubit() : super(initialState: 0);
}
''';
        final transformed = await runLintFix(
          RequireHydratedStoragePrefix(),
          AddHydratedStoragePrefixFix.new,
          source,
        );
        expect(
          transformed,
          contains("String get storagePrefix => 'user_profile_cubit';"),
        );
        parseString(content: transformed);
      },
    );

    test(
      'AddHydratedStoragePrefixFix converts EmptyClassBody to BlockClassBody',
      () async {
        const source = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class SettingsCubit extends CubitSignal<int> with HydratedMixin<int>;
''';
        final transformed = await runLintFix(
          RequireHydratedStoragePrefix(),
          AddHydratedStoragePrefixFix.new,
          source,
        );
        expect(
          transformed,
          contains("String get storagePrefix => 'settings_cubit';"),
        );
        parseString(content: transformed);
      },
    );

    test(
      'AddHydratedMixinInitFix inserts hydrate(); in constructor body',
      () async {
        const source = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class MyCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  MyCubit() {
    initCubitSignal(initialState: 0);
  }
}
''';
        final transformed = await runLintFix(
          RequireHydratedMixinInit(),
          AddHydratedMixinInitFix.new,
          source,
        );
        expect(transformed, contains('hydrate();'));
        parseString(content: transformed);
      },
    );

    test(
      'ReplaceContextSelectOutsideBuildFix rewrites select/value to read',
      () async {
        const selectSource = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        final v = context.select<CounterCubit, int>((b) => b.value);
      },
    );
  }
}
''';
        final transformedSelect = await runLintFix(
          AvoidContextSelectOutsideBuild(),
          ReplaceContextSelectOutsideBuildFix.new,
          selectSource,
        );
        expect(transformedSelect, contains('context.read<CounterCubit>()'));
        parseString(content: transformedSelect);

        const valueSource = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        final v = context.value<CounterCubit, int>();
      },
    );
  }
}
''';
        final transformedValue = await runLintFix(
          AvoidContextSelectOutsideBuild(),
          ReplaceContextSelectOutsideBuildFix.new,
          valueSource,
        );
        expect(
          transformedValue,
          contains('context.read<CounterCubit>().value'),
        );
        parseString(content: transformedValue);
      },
    );

    test('FixContextSelectGenericsFix reduces 3 type args to <B, R>', () async {
      const source = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final v = context.select<CounterCubit, int, String>((b) => b.value.toString());
    return Text(v);
  }
}
''';
      final transformed = await runLintFix(
        AvoidInvalidContextSelectGenerics(),
        FixContextSelectGenericsFix.new,
        source,
      );
      expect(transformed, contains('context.select<CounterCubit, String>'));
      parseString(content: transformed);
    });

    test('InsertToStreamForTransformerFix inserts .toStream()', () async {
      const source = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

void f(CounterCubit bloc) {
  bloc.transform((s) => s);
}
''';
      final transformed = await runLintFix(
        AvoidStreamTransformersOnBlocSignal(),
        InsertToStreamForTransformerFix.new,
        source,
      );
      expect(transformed, contains('bloc.toStream().transform('));
      parseString(content: transformed);
    });

    test('BindUnusedSelectResultFix binds final value =', () async {
      const source = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.select<CounterCubit, int>((b) => b.value);
    return Container();
  }
}
''';
      final transformed = await runLintFix(
        AvoidUnusedSelectResult(),
        BindUnusedSelectResultFix.new,
        source,
      );
      expect(
        transformed,
        contains('final value = context.select<CounterCubit, int>'),
      );
      parseString(content: transformed);
    });

    test(
      'RemoveManualCloseOnProvidedBlocFix removes close() statement',
      () async {
        const source = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

void f(BuildContext context) {
  context.read<CounterCubit>().close();
}
''';
        final transformed = await runLintFix(
          AvoidManualCloseOnProvidedBloc(),
          RemoveManualCloseOnProvidedBlocFix.new,
          source,
        );
        expect(transformed, isNot(contains('close()')));
        parseString(content: transformed);
      },
    );

    test(
      'RemoveDuplicateEventHandlerFix removes duplicate on<Event>()',
      () async {
        const source = '''
class MyEvent {}
class MyBloc extends BlocSignal<MyEvent, int> {
  MyBloc() : super(initialState: 0) {
    on<MyEvent>((event, emit) {});
    on<MyEvent>((event, emit) {});
  }
}
''';
        final transformed = await runLintFix(
          AvoidDuplicateEventHandlers(),
          RemoveDuplicateEventHandlerFix.new,
          source,
        );
        expect('on<MyEvent>'.allMatches(transformed).length, equals(1));
        parseString(content: transformed);
      },
    );

    test(
      'ReplaceContextWatchWithValueFix rewrites watch<B>() to value<B, S>()',
      () async {
        const source = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<CounterCubit>();
    return Container();
  }
}
''';
        final transformed = await runLintFix(
          AvoidContextWatchForBlocState(),
          ReplaceContextWatchWithValueFix.new,
          source,
        );
        expect(transformed, contains('context.value<CounterCubit, int>()'));
        parseString(content: transformed);
      },
    );

    test(
      '(Issue #482: BLOCKER-2) RemoveManualCloseOnProvidedBlocFix handles '
      'closures, await, and unbraced if without deleting outer statements',
      () async {
        const arrowCallback = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget f(BuildContext context) {
  return Button(
    onPressed: () => context.read<CounterCubit>().close(),
  );
}
''';
        final transformedArrow = await runLintFix(
          AvoidManualCloseOnProvidedBloc(),
          RemoveManualCloseOnProvidedBlocFix.new,
          arrowCallback,
        );
        expect(transformedArrow, contains('Button('));
        expect(transformedArrow, isNot(contains('close()')));
        parseString(content: transformedArrow);

        const blockCallback = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget f(BuildContext context) {
  return Button(
    onPressed: () {
      context.read<CounterCubit>().close();
    },
  );
}
''';
        final transformedBlock = await runLintFix(
          AvoidManualCloseOnProvidedBloc(),
          RemoveManualCloseOnProvidedBlocFix.new,
          blockCallback,
        );
        expect(transformedBlock, contains('Button('));
        expect(transformedBlock, isNot(contains('close()')));
        parseString(content: transformedBlock);

        const unbracedIf = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

void f(BuildContext context, bool cond) {
  if (cond) context.read<CounterCubit>().close();
}
''';
        final transformedIf = await runLintFix(
          AvoidManualCloseOnProvidedBloc(),
          RemoveManualCloseOnProvidedBlocFix.new,
          unbracedIf,
        );
        expect(transformedIf, contains('if (cond) {}'));
        expect(transformedIf, isNot(contains('close()')));
        parseString(content: transformedIf);

        const awaitedClose = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Future<void> f(BuildContext context) async {
  await context.read<CounterCubit>().close();
}
''';
        final transformedAwait = await runLintFix(
          AvoidManualCloseOnProvidedBloc(),
          RemoveManualCloseOnProvidedBlocFix.new,
          awaitedClose,
        );
        expect(transformedAwait, isNot(contains('close()')));
        parseString(content: transformedAwait);
      },
    );

    test('(Issue #482: BLOCKER-3) RemoveDuplicateEventHandlerFix deletes only '
        'duplicate cascade section and handles unbraced if', () async {
      const cascadeSource = '''
class EventA {}
class EventB {}
class MyBloc extends BlocSignal<Object, int> {
  MyBloc() : super(initialState: 0) {
    this
      ..on<EventA>((e, emit) {})
      ..on<EventB>((e, emit) {})
      ..on<EventA>((e, emit) {});
  }
}
''';
      final transformedCascade = await runLintFix(
        AvoidDuplicateEventHandlers(),
        RemoveDuplicateEventHandlerFix.new,
        cascadeSource,
      );
      expect('on<EventA>'.allMatches(transformedCascade).length, equals(1));
      expect(transformedCascade, contains('..on<EventB>'));
      parseString(content: transformedCascade);

      const unbracedIf = '''
class EventA {}
class MyBloc extends BlocSignal<EventA, int> {
  MyBloc(bool cond) : super(initialState: 0) {
    on<EventA>((e, emit) {});
    if (cond) on<EventA>((e, emit) {});
  }
}
''';
      final transformedIf = await runLintFix(
        AvoidDuplicateEventHandlers(),
        RemoveDuplicateEventHandlerFix.new,
        unbracedIf,
      );
      expect('on<EventA>'.allMatches(transformedIf).length, equals(1));
      expect(transformedIf, contains('if (cond) {}'));
      parseString(content: transformedIf);
    });

    test('(Issue #482: BLOCKER-5) AddHydratedMixinInitFix covers all AST '
        'constructor and class body branches', () async {
      const primaryBodySource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class A(int i) extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  this {
    initCubitSignal(initialState: 0);
  }
}
''';
      final primaryBodyOut = await runLintFix(
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
        primaryBodySource,
      );
      expect(primaryBodyOut, contains('hydrate();'));
      parseString(content: primaryBodyOut);

      const primaryEmptyClassSource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class B(int i) extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int>;
''';
      final primaryEmptyClassOut = await runLintFix(
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
        primaryEmptyClassSource,
      );
      expect(primaryEmptyClassOut, contains('this {\n    hydrate();\n  }'));
      parseString(content: primaryEmptyClassOut);

      const primaryNoBodyClassSource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class C(int i) extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {}
''';
      final primaryNoBodyOut = await runLintFix(
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
        primaryNoBodyClassSource,
      );
      expect(primaryNoBodyOut, contains('this {\n    hydrate();\n  }'));
      parseString(content: primaryNoBodyOut);

      const emptyClassSource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class D extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int>;
''';
      final emptyClassOut = await runLintFix(
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
        emptyClassSource,
      );
      expect(emptyClassOut, contains('D() {\n    hydrate();\n  }'));
      parseString(content: emptyClassOut);

      const ctorlessBlockClassSource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class E extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {}
''';
      final ctorlessBlockOut = await runLintFix(
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
        ctorlessBlockClassSource,
      );
      expect(ctorlessBlockOut, contains('E() {\n    hydrate();\n  }'));
      parseString(content: ctorlessBlockOut);

      const emptyFnBodySource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class F extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  F();
}
''';
      final emptyFnBodyOut = await runLintFix(
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
        emptyFnBodySource,
      );
      expect(emptyFnBodyOut, contains('F() {\n    hydrate();\n  }'));
      parseString(content: emptyFnBodyOut);

      const blockWithoutInitSource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class G extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  G() {}
}
''';
      final blockWithoutInitOut = await runLintFix(
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
        blockWithoutInitSource,
      );
      expect(blockWithoutInitOut, contains('hydrate();'));
      parseString(content: blockWithoutInitOut);
    });

    test('(Issue #482: NBO-4) secondary branches and fixKind uniqueness for '
        'all 9 new fix producers', () async {
      const directBaseSource = '''
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = context.watch<BlocSignalBase<int>>();
    return Container();
  }
}
''';
      final directBaseOut = await runLintFix(
        AvoidContextWatchForBlocState(),
        ReplaceContextWatchWithValueFix.new,
        directBaseSource,
      );
      expect(
        directBaseOut,
        contains('context.value<BlocSignalBase<int>, int>()'),
      );

      const untypedSelectSource = '''
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        final v = context.select((b) => b);
      },
    );
  }
}
''';
      final untypedSelectOut = await runLintFix(
        AvoidContextSelectOutsideBuild(),
        ReplaceContextSelectOutsideBuildFix.new,
        untypedSelectSource,
      );
      expect(untypedSelectOut, contains('context.read()'));

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
        "import 'package:bloc_signals/bloc_signals.dart';\n"
        "import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';\n"
        'class H extends HydratedCubitSignal<int> {}\n',
        RequireHydratedStoragePrefix(),
        AddHydratedStoragePrefixFix.new,
      );
      await verifyFix(
        "import 'package:bloc_signals/bloc_signals.dart';\n"
        "import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';\n"
        'class I extends BlocSignalBase<int> '
        'with CubitSignalMixin<int>, HydratedMixin<int>;\n',
        RequireHydratedMixinInit(),
        AddHydratedMixinInitFix.new,
      );
      await verifyFix(
        untypedSelectSource,
        AvoidContextSelectOutsideBuild(),
        ReplaceContextSelectOutsideBuildFix.new,
      );
      await verifyFix(
        'class C extends CubitSignal<int> { C() : super(initialState: 0); }\n'
        'Widget f(BuildContext c) => '
        'Text(c.select<C, int, String>((b) => ""));\n',
        AvoidInvalidContextSelectGenerics(),
        FixContextSelectGenericsFix.new,
      );
      await verifyFix(
        'class C extends CubitSignal<int> { C() : super(initialState: 0); }\n'
        'void f(C b) { b.transform((s) => s); }\n',
        AvoidStreamTransformersOnBlocSignal(),
        InsertToStreamForTransformerFix.new,
      );
      await verifyFix(
        'class C extends CubitSignal<int> { C() : super(initialState: 0); }\n'
        'void f(BuildContext c) { c.select<C, int>((b) => b.value); }\n',
        AvoidUnusedSelectResult(),
        BindUnusedSelectResultFix.new,
      );
      await verifyFix(
        'class C extends CubitSignal<int> { C() : super(initialState: 0); }\n'
        'void f(BuildContext c) { c.read<C>().close(); }\n',
        AvoidManualCloseOnProvidedBloc(),
        RemoveManualCloseOnProvidedBlocFix.new,
      );
      await verifyFix(
        'class E {}\nclass B extends BlocSignal<E, int> {\n'
        '  B() : super(initialState: 0) { '
        'on<E>((e, emit) {}); on<E>((e, emit) {}); }\n}\n',
        AvoidDuplicateEventHandlers(),
        RemoveDuplicateEventHandlerFix.new,
      );
      await verifyFix(
        'class C extends CubitSignal<int> { C() : super(initialState: 0); }\n'
        'class W extends StatelessWidget { '
        'Widget build(BuildContext c) { '
        'c.watch<C>(); return Container(); } }\n',
        AvoidContextWatchForBlocState(),
        ReplaceContextWatchWithValueFix.new,
      );

      expect(seenKinds, hasLength(9));
    });

    test('(Issue #482: Round 2 BLOCKER-1) BindUnusedSelectResultFix wraps '
        'unbraced if statement in block braces', () async {
      const source = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget f(BuildContext context, bool show) {
  if (show) context.select<CounterCubit, int>((b) => b.value);
  return Container();
}
''';
      final transformed = await runLintFix(
        AvoidUnusedSelectResult(),
        BindUnusedSelectResultFix.new,
        source,
      );
      expect(
        transformed,
        contains(
          'if (show) { final value = '
          'context.select<CounterCubit, int>((b) => b.value); }',
        ),
      );
      parseString(content: transformed);
    });

    test('(Issue #482: Round 2 BLOCKER-7) RemoveManualCloseOnProvidedBlocFix '
        'handles async arrow and no-ops on return statement', () async {
      const asyncArrow = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget f(BuildContext context) {
  return Button(
    onPressed: () async => await context.read<CounterCubit>().close(),
  );
}
''';
      final transformedAsync = await runLintFix(
        AvoidManualCloseOnProvidedBloc(),
        RemoveManualCloseOnProvidedBlocFix.new,
        asyncArrow,
      );
      expect(transformedAsync, contains('() async {}'));
      parseString(content: transformedAsync);

      const returnStmt = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Future<void> f(BuildContext context) {
  return context.read<CounterCubit>().close();
}
''';
      final transformedReturn = await runLintFix(
        AvoidManualCloseOnProvidedBloc(),
        RemoveManualCloseOnProvidedBlocFix.new,
        returnStmt,
      );
      expect(transformedReturn, equals(returnStmt));
    });

    test('(Issue #482: Round 2 BLOCKER-8) RemoveDuplicateEventHandlerFix '
        'no-ops on arrow helper', () async {
      const arrowDup = '''
class EventA {}
class MyBloc extends BlocSignal<EventA, int> {
  MyBloc() : super(initialState: 0) {
    on<EventA>((e, emit) {});
    _dup();
  }
  void _dup() => on<EventA>((e, emit) {});
}
''';
      final transformed = await runLintFix(
        AvoidDuplicateEventHandlers(),
        RemoveDuplicateEventHandlerFix.new,
        arrowDup,
      );
      expect(transformed, equals(arrowDup));
    });

    test('(Issue #482: Round 2 BLOCKER-9) ReplaceContextSelectOutsideBuildFix '
        'rewrites untyped context.value() to context.read().value', () async {
      const source = '''
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        final v = context.value();
      },
    );
  }
}
''';
      final transformed = await runLintFix(
        AvoidContextSelectOutsideBuild(),
        ReplaceContextSelectOutsideBuildFix.new,
        source,
      );
      expect(transformed, contains('context.read().value'));
    });

    test('(Issue #482: Round 2 BLOCKER-10) ReplaceContextWatchWithValueFix '
        'no-ops on non-BlocSignalBase and non-InterfaceType', () async {
      const fakeBlocSource = '''
class FakeBloc {}
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = context.watch<FakeBloc>();
    return Container();
  }
}
''';
      final offsetFake = fakeBlocSource.indexOf('watch<FakeBloc>');
      final outFake = await runLintFix(
        AvoidContextWatchForBlocState(),
        ReplaceContextWatchWithValueFix.new,
        fakeBlocSource,
        selectionOffset: offsetFake,
      );
      expect(outFake, equals(fakeBlocSource));

      const dynamicSource = '''
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = context.watch<dynamic>();
    return Container();
  }
}
''';
      final offsetDyn = dynamicSource.indexOf('watch<dynamic>');
      final outDyn = await runLintFix(
        AvoidContextWatchForBlocState(),
        ReplaceContextWatchWithValueFix.new,
        dynamicSource,
        selectionOffset: offsetDyn,
      );
      expect(outDyn, equals(dynamicSource));
    });

    test(
      '(Issue #482: Round 3 BLOCKER-3) AddHydratedMixinInitFix ignores '
      'unbraced if/else and nested closures when locating initCubitSignal',
      () async {
        const unbracedIfElseSource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class UnbracedIfCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  UnbracedIfCubit(bool flag) {
    if (flag) initCubitSignal(initialState: 0); else initCubitSignal(initialState: 1);
  }
}
''';
        final unbracedOut = await runLintFix(
          RequireHydratedMixinInit(),
          AddHydratedMixinInitFix.new,
          unbracedIfElseSource,
        );
        expect(
          unbracedOut,
          contains(
            'UnbracedIfCubit(bool flag) {\n'
            '    hydrate();',
          ),
        );
        parseString(content: unbracedOut);

        const nestedClosureSource = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class NestedClosureCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  NestedClosureCubit() {
    final fn = () => initCubitSignal(initialState: 0);
  }
}
''';
        final closureOut = await runLintFix(
          RequireHydratedMixinInit(),
          AddHydratedMixinInitFix.new,
          nestedClosureSource,
        );
        expect(
          closureOut,
          contains(
            'NestedClosureCubit() {\n'
            '    hydrate();',
          ),
        );
        parseString(content: closureOut);
      },
    );

    test('(Issue #482: Round 4 BLOCKER-1) InsertToStreamForTransformerFix '
        'preserves ?. on nullable receivers', () async {
      const source = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

void f(CounterCubit? bloc) {
  bloc?.transform((s) => s);
}
''';
      final transformed = await runLintFix(
        AvoidStreamTransformersOnBlocSignal(),
        InsertToStreamForTransformerFix.new,
        source,
      );
      expect(transformed, contains('bloc?.toStream().transform('));
      parseString(content: transformed);
    });

    test('(Issue #482: Round 4 BLOCKER-2) ReplaceContextSelectOutsideBuildFix '
        'preserves ?. on nullable BuildContext receivers', () async {
      const selectSource = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget f(BuildContext? ctx) {
  return Button(
    onPressed: () {
      final v = ctx?.select<CounterCubit, int>((b) => b.value);
    },
  );
}
''';
      final selectOut = await runLintFix(
        AvoidContextSelectOutsideBuild(),
        ReplaceContextSelectOutsideBuildFix.new,
        selectSource,
      );
      expect(selectOut, contains('ctx?.read<CounterCubit>()'));
      parseString(content: selectOut);

      const valueSource = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget f(BuildContext? ctx) {
  return Button(
    onPressed: () {
      final v = ctx?.value<CounterCubit, int>();
    },
  );
}
''';
      final valueOut = await runLintFix(
        AvoidContextSelectOutsideBuild(),
        ReplaceContextSelectOutsideBuildFix.new,
        valueSource,
      );
      expect(valueOut, contains('ctx?.read<CounterCubit>().value'));
      parseString(content: valueOut);
    });

    test('(Issue #482: Round 4 BLOCKER-3) AddHydratedStoragePrefixFix '
        r'escapes $ in class names', () async {
      const source = r'''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class Pay$Cubit extends HydratedCubitSignal<int> {
  Pay$Cubit() : super(initialState: 0);
}
''';
      final transformed = await runLintFix(
        RequireHydratedStoragePrefix(),
        AddHydratedStoragePrefixFix.new,
        source,
      );
      expect(
        transformed,
        contains(r"String get storagePrefix => 'pay\$cubit';"),
      );
      parseString(content: transformed);
    });
  });
}
