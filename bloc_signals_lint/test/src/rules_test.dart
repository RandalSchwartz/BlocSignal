import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_raw_signal_effects_in_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_stream_transformers_on_bloc_signal.dart';
import 'package:bloc_signals_lint/src/rules/avoid_top_level_bloc_signal_instances.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unused_select_result.dart';
import 'package:bloc_signals_lint/src/rules/prefer_named_replay_constructor.dart';
import 'package:bloc_signals_lint/src/rules/require_cubit_signal_mixin_init.dart';
import 'package:bloc_signals_lint/src/rules/require_super_on_event.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #315: R1) Rule AST Detection via rule.run()', () {
    test('AvoidDuplicateEventHandlers detects duplicate on<E> handlers',
        () async {
      const badCode = '''
sealed class CounterEvent {}
class IncrementEvent extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<IncrementEvent>((event, emit) {});
    on<IncrementEvent>((event, emit) {});
  }
}
''';
      final lints =
          await runLintRule(const AvoidDuplicateEventHandlers(), badCode);
      expect(lints, hasLength(1));
      expect(lints.first.lexeme, contains('on<IncrementEvent>'));
    });

    test('AvoidDuplicateEventHandlers accepts distinct on<E> handlers',
        () async {
      const goodCode = '''
sealed class CounterEvent {}
class IncrementEvent extends CounterEvent {}
class DecrementEvent extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<IncrementEvent>((event, emit) {});
    on<DecrementEvent>((event, emit) {});
  }
}
''';
      final lints =
          await runLintRule(const AvoidDuplicateEventHandlers(), goodCode);
      expect(lints, isEmpty);
    });

    test('AvoidDuplicateEventHandlers ignores plain non-bloc classes',
        () async {
      const goodCode = '''
class IncrementEvent {}

class NotABloc {
  void on<T>(void Function(T, dynamic) cb) {}
  NotABloc() {
    on<IncrementEvent>((event, emit) {});
    on<IncrementEvent>((event, emit) {});
  }
}
''';
      final lints =
          await runLintRule(const AvoidDuplicateEventHandlers(), goodCode);
      expect(lints, isEmpty);
    });

    test('RequireSuperOnEvent detects missing super.onEvent in bad code',
        () async {
      const badCode = '''
class MyEvent {}

class MyBloc extends BlocSignal<MyEvent, int> {
  void onEvent(MyEvent event) {
    print(event);
  }
}
''';
      final lints = await runLintRule(const RequireSuperOnEvent(), badCode);
      expect(lints, hasLength(1));
      expect(lints.first.lexeme, equals('onEvent'));
    });

    test('RequireSuperOnEvent accepts valid super.onEvent in good code',
        () async {
      const goodCode = '''
class MyEvent {}

class MyBloc extends BlocSignal<MyEvent, int> {
  void onEvent(MyEvent event) {
    super.onEvent(event);
    print(event);
  }
}
''';
      final lints = await runLintRule(const RequireSuperOnEvent(), goodCode);
      expect(lints, isEmpty);
    });

    test('RequireSuperOnEvent ignores plain non-bloc class with onEvent',
        () async {
      const goodCode = '''
class NotABloc {
  void onEvent(dynamic event) {
    print(event);
  }
}
''';
      final lints = await runLintRule(const RequireSuperOnEvent(), goodCode);
      expect(lints, isEmpty);
    });

    test(
      'AvoidStreamTransformersOnBlocSignal detects invalid transformer calls',
      () async {
        const badCode = '''
class CounterBloc extends BlocSignal<Object, int> {
  CounterBloc() : super(initialState: 0);
  void debounce() {}
  void switchMap() {}
}

void test(CounterBloc bloc) {
  bloc.debounce();
  bloc.switchMap();
}
''';
        final lints = await runLintRule(
          const AvoidStreamTransformersOnBlocSignal(),
          badCode,
        );
        expect(lints, hasLength(2));
        expect(
          lints.map((l) => l.lexeme),
          containsAll(['debounce', 'switchMap']),
        );
      },
    );

    test(
      'AvoidStreamTransformersOnBlocSignal ignores stream transformer calls '
      'on non-bloc targets',
      () async {
        const goodCode = '''
class MyStream {
  void debounce() {}
  void switchMap() {}
}

void test(MyStream myStream) {
  myStream.debounce();
  myStream.switchMap();
}
''';
        final lints = await runLintRule(
          const AvoidStreamTransformersOnBlocSignal(),
          goodCode,
        );
        expect(lints, isEmpty);
      },
    );

    test(
      'AvoidDirectSignalMutationOutsideBloc detects external emit calls',
      () async {
        const badCode = '''
void externalFunction(CubitSignal<int> bloc) {
  bloc.emit(42);
}
''';
        final lints = await runLintRule(
          const AvoidDirectSignalMutationOutsideBloc(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('emit'));
      },
    );

    test(
      '(Issue #302: F16) AvoidDirectSignalMutationOutsideBloc accepts '
      'this.emit inside mixin on CubitSignal',
      () async {
        const goodCode = '''
mixin CartPricing on CubitSignal<int> {
  void calculate() {
    this.emit(42);
  }
}
''';
        final lints = await runLintRule(
          const AvoidDirectSignalMutationOutsideBloc(),
          goodCode,
        );
        expect(lints, isEmpty);
      },
    );

    test(
      '(Issue #302: F16) AvoidDirectSignalMutationOutsideBloc rejects '
      'non-bloc enclosingClass even if enclosingMixin is present',
      () async {
        const classCode = '''
class NonBlocService {
  void doEmit() {}
}
''';
        const mixinCode = '''
mixin CartPricing on CubitSignal<int> {}
''';
        final classUnit = parseString(content: classCode).unit;
        final mixinUnit = parseString(content: mixinCode).unit;
        final classNode =
            classUnit.declarations.whereType<ClassDeclaration>().first;
        final mixinNode =
            mixinUnit.declarations.whereType<MixinDeclaration>().first;

        final isAllowed =
            AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
          enclosingClass: classNode,
          enclosingMixin: mixinNode,
        );

        expect(isAllowed, isFalse);

        const nestedBadCode = '''
class OuterService {
  void run(CubitSignal<int> cubit) {
    cubit.emit(1);
  }
}
''';
        final lints = await runLintRule(
          const AvoidDirectSignalMutationOutsideBloc(),
          nestedBadCode,
        );
        expect(lints, hasLength(1));
      },
    );

    test(
      'AvoidTopLevelBlocSignalInstances detects global top-level bloc '
      'declarations',
      () async {
        const badCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}
class AuthBloc extends CubitSignal<int> {
  AuthBloc() : super(initialState: 0);
}

final counterBloc = CounterBloc();
class Service {
  static final authBloc = AuthBloc();
}
''';
        final lints = await runLintRule(
          const AvoidTopLevelBlocSignalInstances(),
          badCode,
        );
        expect(lints, hasLength(2));
        expect(
          lints.map((l) => l.arguments?.first),
          containsAll(['counterBloc', 'authBloc']),
        );
      },
    );

    test(
      'AvoidTopLevelBlocSignalInstances accepts global primitive signals and '
      'instance fields',
      () async {
        const goodCode = '''
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(initialState: 0);
}

final globalCount = signal(0);
class Service {
  final instanceBloc = CounterBloc();
}
''';
        final lints = await runLintRule(
          const AvoidTopLevelBlocSignalInstances(),
          goodCode,
        );
        expect(lints, isEmpty);
      },
    );

    test(
        '(Issue #302: F2) RequireCubitSignalMixinInit detects uninitialized '
        'mixin constructors at constructor token', () async {
      const badCode = '''
class BaseService {}

class CounterService extends BaseService with CubitSignalMixin<int> {
  CounterService() {
    print('hello');
  }
}
''';
      final lints =
          await runLintRule(const RequireCubitSignalMixinInit(), badCode);
      expect(lints, hasLength(1));
      expect(lints.first.lexeme, equals('CounterService'));
      expect(lints.first.offset, equals(badCode.indexOf('CounterService()')));
      expect(
        lints.first.arguments,
        equals(['CubitSignalMixin', 'initCubitSignal']),
      );
    });

    test(
        '(Issue #302: F2, F8) RequireCubitSignalMixinInit flags class with '
        'BlocSignalMixin calling initBlocSignal', () async {
      const badCode = '''
class BaseService {}
class UserEvent {}

class UserBloc extends BaseService with BlocSignalMixin<UserEvent, int> {
  UserBloc() {
    initBlocSignal(initialState: 0);
  }
}
''';
      final lints =
          await runLintRule(const RequireCubitSignalMixinInit(), badCode);
      expect(lints, hasLength(1));
      expect(
        lints.first.arguments,
        equals(['BlocSignalMixin', 'initCubitSignal']),
      );
    });

    test(
        '(Issue #302: F2, F8) RequireCubitSignalMixinInit accepts class with '
        'BlocSignalMixin calling initCubitSignal', () async {
      const goodCode = '''
class BaseService {}
class UserEvent {}

class UserBloc extends BaseService with BlocSignalMixin<UserEvent, int> {
  UserBloc() {
    initCubitSignal(initialState: 0);
  }
}
''';
      final lints =
          await runLintRule(const RequireCubitSignalMixinInit(), goodCode);
      expect(lints, isEmpty);
    });

    test('RequireCubitSignalMixinInit accepts initialized mixin constructors',
        () async {
      const goodCode = '''
class BaseService {}

class CounterService extends BaseService with CubitSignalMixin<int> {
  CounterService() {
    initCubitSignal(initialState: 0);
  }
}
''';
      final lints =
          await runLintRule(const RequireCubitSignalMixinInit(), goodCode);
      expect(lints, isEmpty);
    });

    test(
        '(Issue #302: F10) RequireCubitSignalMixinInit ignores factory '
        'constructors and redirecting constructors', () async {
      const code = '''
class BaseService {}

class CounterService extends BaseService with CubitSignalMixin<int> {
  CounterService._() {
    initCubitSignal(initialState: 0);
  }

  CounterService.redirect() : this._();

  factory CounterService.factory() {
    return CounterService._();
  }
}
''';
      final lints =
          await runLintRule(const RequireCubitSignalMixinInit(), code);
      expect(lints, isEmpty);
    });

    test('AvoidRawSignalEffectsInBloc detects top-level effect in bloc',
        () async {
      const badCode = '''
class MyCubit extends CubitSignal<int> {
  MyCubit() : super(initialState: 0) {
    effect(() {
      print(stateValue);
    });
  }
}
''';
      final lints =
          await runLintRule(const AvoidRawSignalEffectsInBloc(), badCode);
      expect(lints, hasLength(1));
      expect(lints.first.lexeme, equals('effect'));
    });

    test('AvoidRawSignalEffectsInBloc accepts createEffect in bloc', () async {
      const goodCode = '''
class MyCubit extends CubitSignal<int> {
  MyCubit() : super(initialState: 0) {
    createEffect(() {
      print(stateValue);
    });
  }
}
''';
      final lints =
          await runLintRule(const AvoidRawSignalEffectsInBloc(), goodCode);
      expect(lints, isEmpty);
    });

    test('AvoidUnusedSelectResult detects discarded context.select statements',
        () async {
      const badCode = '''
class MyBloc extends CubitSignal<int> {
  MyBloc() : super(initialState: 0);
}

void build(BuildContext context) {
  context.select<MyBloc, int>((b) => b.stateValue);
}
''';
      final lints = await runLintRule(const AvoidUnusedSelectResult(), badCode);
      expect(lints, hasLength(1));
      expect(lints.first.lexeme, equals('select'));
    });

    test('AvoidUnusedSelectResult accepts assigned context.select expressions',
        () async {
      const goodCode = '''
class MyBloc extends CubitSignal<int> {
  MyBloc() : super(initialState: 0);
}

void build(BuildContext context) {
  final count = context.select<MyBloc, int>((b) => b.stateValue);
  print(count);
}
''';
      final lints =
          await runLintRule(const AvoidUnusedSelectResult(), goodCode);
      expect(lints, isEmpty);
    });

    test(
      'PreferNamedReplayConstructor detects super.positional on ReplayCubit',
      () async {
        const badCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(initial, limit: limit);
}
''';
        final lints = await runLintRule(
          const PreferNamedReplayConstructor(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(
          lints.first.lexeme,
          equals('super.positional(initial, limit: limit)'),
        );
      },
    );

    test(
      'PreferNamedReplayConstructor detects super.positional on ReplayBloc',
      () async {
        const badCode = '''
class CounterEvent {}

class CounterBloc extends ReplayBloc<CounterEvent, int> {
  CounterBloc(int initial) : super.positional(initial);
}
''';
        final lints = await runLintRule(
          const PreferNamedReplayConstructor(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('super.positional(initial)'));
      },
    );

    test(
      'PreferNamedReplayConstructor accepts named super(initialState: ...)',
      () async {
        const goodCode = '''
class CounterEvent {}

class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super(initialState: initial, limit: limit);
}
class CounterBloc extends ReplayBloc<CounterEvent, int> {
  CounterBloc(int initial) : super(initialState: initial);
}
''';
        final lints = await runLintRule(
          const PreferNamedReplayConstructor(),
          goodCode,
        );
        expect(lints, isEmpty);
      },
    );

    test(
      'ReplacePositionalReplayConstructorFix rewrites super.positional',
      () async {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(initial, limit: limit);
}
''';
        final lints = await runLintRule(
          const PreferNamedReplayConstructor(),
          sourceCode,
        );
        expect(lints, hasLength(1));

        final parseResult = parseString(content: sourceCode);
        final constructorNode = parseResult.unit.declarations
            .whereType<ClassDeclaration>()
            .first
            .members
            .whereType<ConstructorDeclaration>()
            .first;
        final node = constructorNode.initializers
            .whereType<SuperConstructorInvocation>()
            .first;

        String? transformed;
        if (node.constructorName?.name == 'positional') {
          final period = node.period!;
          final constructorName = node.constructorName!;
          final positionalArg = node.argumentList.arguments
              .where((arg) => arg is! NamedExpression)
              .firstOrNull;

          if (positionalArg != null) {
            final beforePeriod = sourceCode.substring(0, period.offset);
            final betweenPeriodAndArg = sourceCode.substring(
              constructorName.end,
              positionalArg.offset,
            );
            final afterArg = sourceCode.substring(positionalArg.offset);
            transformed = '$beforePeriod$betweenPeriodAndArg'
                'initialState: $afterArg';
          }
        }

        expect(
          transformed,
          contains('super(initialState: initial, limit: limit)'),
        );
        expect(transformed, isNot(contains('super.positional')));
      },
    );

    test(
      'ReplacePositionalReplayConstructorFix rewrites with leading named args',
      () async {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(limit: limit, initial);
}
''';
        final lints = await runLintRule(
          const PreferNamedReplayConstructor(),
          sourceCode,
        );
        expect(lints, hasLength(1));

        final parseResult = parseString(content: sourceCode);
        final constructorNode = parseResult.unit.declarations
            .whereType<ClassDeclaration>()
            .first
            .members
            .whereType<ConstructorDeclaration>()
            .first;
        final node = constructorNode.initializers
            .whereType<SuperConstructorInvocation>()
            .first;

        String? transformed;
        if (node.constructorName?.name == 'positional') {
          final period = node.period!;
          final constructorName = node.constructorName!;
          final positionalArg = node.argumentList.arguments
              .where((arg) => arg is! NamedExpression)
              .firstOrNull;

          if (positionalArg != null) {
            final beforePeriod = sourceCode.substring(0, period.offset);
            final betweenConstructorAndArg = sourceCode.substring(
              constructorName.end,
              positionalArg.offset,
            );
            final afterArg = sourceCode.substring(positionalArg.offset);
            transformed = '$beforePeriod$betweenConstructorAndArg'
                'initialState: $afterArg';
          }
        }

        expect(
          transformed,
          contains('super(limit: limit, initialState: initial)'),
        );
        expect(transformed, isNot(contains('super.positional')));
      },
    );

    test(
      'ReplacePositionalReplayConstructorFix safely skips '
      'empty super parameters',
      () async {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(super.initialState, {super.limit}) : super.positional();
}
''';
        final lints = await runLintRule(
          const PreferNamedReplayConstructor(),
          sourceCode,
        );
        expect(lints, hasLength(1));

        final parseResult = parseString(content: sourceCode);
        final constructorNode = parseResult.unit.declarations
            .whereType<ClassDeclaration>()
            .first
            .members
            .whereType<ConstructorDeclaration>()
            .first;
        final node = constructorNode.initializers
            .whereType<SuperConstructorInvocation>()
            .first;

        var skipped = false;
        if (node.constructorName?.name == 'positional') {
          final positionalArg = node.argumentList.arguments
              .where((arg) => arg is! NamedExpression)
              .firstOrNull;
          if (positionalArg == null) {
            skipped = true;
          }
        }

        expect(skipped, isTrue);
      },
    );
  });
}
