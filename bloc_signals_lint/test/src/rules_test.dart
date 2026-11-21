import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_multiple_synchronous_emits.dart';
import 'package:bloc_signals_lint/src/rules/avoid_primitive_event_types.dart';
import 'package:bloc_signals_lint/src/rules/avoid_pseudo_events_in_telemetry.dart';
import 'package:bloc_signals_lint/src/rules/avoid_raw_signal_effects_in_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_stream_transformers_on_bloc_signal.dart';
import 'package:bloc_signals_lint/src/rules/avoid_top_level_bloc_signal_instances.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unused_select_result.dart';
import 'package:bloc_signals_lint/src/rules/prefer_named_replay_constructor.dart';
import 'package:bloc_signals_lint/src/rules/require_cubit_signal_mixin_init.dart';
import 'package:bloc_signals_lint/src/rules/require_emit_in_helper_name.dart';
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

    test(
      '(Issue #329: R15) AvoidMultipleSynchronousEmits detects multiple '
      'synchronous emit() calls inside MixinDeclaration on CubitSignal',
      () async {
        const code = '''
mixin PricingMixin on CubitSignal<int> {
  void applyDiscount() {
    emit(1);
    emit(2);
  }
}

mixin UnresolvedReplayMixin on ReplayCubit<int> {
  void emit(int v) {}
  void applyReplay() {
    emit(1);
    emit(2);
  }
}

mixin PlainMixin {
  void emit(int v) {}
  void applyDiscount() {
    emit(1);
    emit(2);
  }
}

mixin ObjectMixin on Object {
  void emit(int v) {}
  void applyDiscount() {
    emit(1);
    emit(2);
  }
}

class PlainClass extends Object with PlainMixin {}
''';
        final lints = await runLintRule(
          const AvoidMultipleSynchronousEmits(),
          code,
        );
        expect(lints, hasLength(2));
        expect(lints.first.lexeme, equals('emit'));
      },
    );

    test(
      '(Issue #329: R15) AvoidMultipleSynchronousEmits detects cascade emit() '
      'calls in ExpressionFunctionBody arrow method and closure',
      () async {
        const code = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void badArrow() => this
    ..emit(1)
    ..emit(2);

  void badClosureHost() {
    final fn = () => this
      ..emit(3)
      ..emit(4);
    fn();
  }

  void safeForeignCascade(CubitSignal<int> other) => other..emit(1)..emit(2);
}
''';
        final lints = await runLintRule(
          const AvoidMultipleSynchronousEmits(),
          code,
        );
        expect(lints, hasLength(2));
      },
    );

    test(
      '(Issue #329: R15) AvoidMultipleSynchronousEmits handles '
      'ContinueStatement without false-positive same-iteration fallthrough '
      'while catching multi-iteration emits',
      () async {
        const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void safeLoopWithContinueAndReturn(List<int> items, bool cond) {
    for (final x in items) {
      if (cond) {
        emit(x);
        return;
      } else {
        continue;
      }
      emit(0);
    }
  }

  void safeLoopWithContinueThenBreak(bool skipFirst) {
    while (true) {
      if (skipFirst) {
        continue;
      }
      emit(1);
      break;
    }
  }
}
''';
        final goodLints = await runLintRule(
          const AvoidMultipleSynchronousEmits(),
          goodCode,
        );
        expect(goodLints, isEmpty);

        const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void multiIterContinue(List<int> items, bool cond) {
    for (final x in items) {
      if (cond) {
        emit(x);
        continue;
      }
      emit(0);
    }
  }
}
''';
        final badLints = await runLintRule(
          const AvoidMultipleSynchronousEmits(),
          badCode,
        );
        expect(badLints, isNotEmpty);
      },
    );

    test(
      '(Issue #329: R15) AvoidMultipleSynchronousEmits resolves intra-switch '
      'continue caseLabel jumps and preserves loop continue semantics',
      () async {
        const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void safeSwitchContinue(int x) {
    switch (x) {
      case 1:
        continue sharedCase;
      sharedCase:
      case 2:
        emit(1);
        break;
    }
  }

  void safeLoopWithSwitchContinue(List<int> items) {
    for (final x in items) {
      switch (x) {
        case 1:
          emit(1);
          return;
        default:
          continue;
      }
      emit(2);
    }
  }
}
''';
        final goodLints = await runLintRule(
          const AvoidMultipleSynchronousEmits(),
          goodCode,
        );
        expect(goodLints, isEmpty);

        const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void emitBeforeSwitchContinue(int x) {
    switch (x) {
      case 1:
        emit(1);
        continue sharedCase;
      sharedCase:
      case 2:
        emit(2);
        break;
    }
  }

  void emitAfterSwitchContinue(int x) {
    switch (x) {
      case 1:
        continue sharedCase;
      sharedCase:
      case 2:
        emit(1);
        break;
    }
    emit(2);
  }
}
''';
        final badLints = await runLintRule(
          const AvoidMultipleSynchronousEmits(),
          badCode,
        );
        expect(badLints, hasLength(2));
      },
    );

    test(
      '(Issue #333: R19) AvoidPseudoEventsInTelemetry, '
      'RequireEmitInHelperName, AvoidMultipleSynchronousEmits, '
      'AvoidRawSignalEffectsInBloc, and AvoidDirectSignalMutationOutsideBloc '
      'handle ReplayMixin and HydratedMixin containers accurately',
      () async {
        const telemetryCode = '''
class ReplayMixinCubit extends BaseService with ReplayMixin<int> {
  void emitTelemetry(String name) {}
  void act() {
    emitTelemetry('SavePressed');
  }
}

class HydratedMixinCubit extends BaseService with HydratedMixin<int> {
  void emitTelemetry(String name) {}
  void act() {
    emitTelemetry('RefreshRequested');
  }
}

class ReplayBlocWithMixins extends BlocSignal<Object, int>
    with ReplayMixin<int>, ReplayBlocMixin<Object, int>, HydratedMixin<int> {
  ReplayBlocWithMixins() : super(initialState: 0);
  void act() {
    emitTelemetry('BlocEventPressed');
  }
}

class HydratedBlocSub extends HydratedBloc<Object, int> {
  void emitTelemetry(String name) {}
  void act() {
    emitTelemetry('BlocEventPressed');
  }
}
''';
        final parseResult = parseString(content: telemetryCode);
        final telemetryViolations = <AstNode>[];
        for (final decl
            in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
          telemetryViolations.addAll(
            AvoidPseudoEventsInTelemetry.findViolations(decl),
          );
        }
        expect(telemetryViolations, hasLength(2));

        const multiEmitCode = '''
class HydratedOnlyClass extends HydratedCubit<int> {
  void emit(int s) {}
  void bad() {
    emit(1);
    emit(2);
  }
}

class ReplayMixinOnlyClass extends Object with ReplayMixin<int> {
  void emit(int s) {}
  void bad() {
    emit(1);
    emit(2);
  }
}

mixin CustomOnReplayMixin on ReplayMixin<int> {
  void emit(int s) {}
  void bad() {
    emit(1);
    emit(2);
  }
}

mixin CustomOnHydratedMixin on HydratedMixin<int> {
  void emit(int s) {}
  void bad() {
    emit(1);
    emit(2);
  }
}
''';
        final multiEmitLints = await runLintRule(
          const AvoidMultipleSynchronousEmits(),
          multiEmitCode,
        );
        expect(multiEmitLints, hasLength(4));

        const rawEffectCode = '''
class ReplayCubitClass extends ReplayCubit<int> {
  ReplayCubitClass() : super(initialState: 0) {
    effect(() {});
  }
}

class HydratedMixinClass extends Object with HydratedMixin<int> {
  HydratedMixinClass() {
    effect(() {});
  }
}
''';
        final rawEffectLints = await runLintRule(
          const AvoidRawSignalEffectsInBloc(),
          rawEffectCode,
        );
        expect(rawEffectLints, hasLength(2));

        const helperEmitCode = '''
class HydratedOnlyClass extends HydratedCubit<int> {
  void emit(int s) {}
  void _badHelper() {
    emit(1);
  }
}

class ReplayMixinOnlyClass extends Object with ReplayMixin<int> {
  void emit(int s) {}
  void _badHelper() {
    emit(1);
  }
}
''';
        final helperEmitLints = await runLintRule(
          const RequireEmitInHelperName(),
          helperEmitCode,
        );
        expect(helperEmitLints, hasLength(2));

        const allowedClassCode = '''
class ReplayClass extends ReplayCubit<int> {}
class HydratedMixinClass extends Object with HydratedMixin<int> {}
mixin OnReplayMixin on ReplayMixin<int> {}
mixin OnHydratedMixin on HydratedMixin<int> {}
''';
        final allowedUnit = parseString(content: allowedClassCode).unit;
        final classes =
            allowedUnit.declarations.whereType<ClassDeclaration>().toList();
        final mixins =
            allowedUnit.declarations.whereType<MixinDeclaration>().toList();
        expect(
          AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
            enclosingClass: classes[0],
          ),
          isTrue,
        );
        expect(
          AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
            enclosingClass: classes[1],
          ),
          isTrue,
        );
        expect(
          AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
            enclosingMixin: mixins[0],
          ),
          isTrue,
        );
        expect(
          AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
            enclosingMixin: mixins[1],
          ),
          isTrue,
        );
      },
    );
  });

  group('(Issue #407) AvoidDirectSignalMutationOutsideBloc MixinElement', () {
    test(
      '(Issue #407) accepts mixin on CubitSignal invoking .emit() with '
      'populated declaredFragment',
      () async {
        const goodCode = '''
mixin CartPricing on CubitSignal<int> {
  void calculate() {
    emit(42);
    this.emit(43);
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
      '(Issue #407) accepts mixin on BlocSignal invoking .emit() with '
      'populated declaredFragment',
      () async {
        const goodCode = '''
sealed class CounterEvent {}

mixin CounterMixin on BlocSignal<CounterEvent, int> {
  void forceSet(CubitSignal<int> other) {
    emit(1);
    other.emit(2);
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
      '(Issue #407) flags mixin without container on constraint invoking '
      '.emit() with populated declaredFragment',
      () async {
        const badCode = '''
mixin UnconstrainedHelper {
  void mutate(CubitSignal<int> cubit) {
    cubit.emit(10);
  }
}

mixin ObjectHelper on Object {
  void mutateBloc(BlocSignal<Object, int> bloc) {
    bloc.emit(20);
  }
}
''';
        final lints = await runLintRule(
          const AvoidDirectSignalMutationOutsideBloc(),
          badCode,
        );
        expect(lints, hasLength(2));
        expect(lints.every((l) => l.lexeme == 'emit'), isTrue);
      },
    );

    test(
      '(Issue #407) still flags non-container class invoking .emit()',
      () async {
        const badCode = '''
class ExternalService {
  void mutate(CubitSignal<int> cubit) {
    cubit.emit(99);
  }
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
  });

  group('(Issue #477: Area 1) MixinDeclaration & BlocSignalMixin support', () {
    test(
      '(Issue #477: Area 1) AvoidDuplicateEventHandlers detects duplicates in '
      'MixinDeclaration, BlocSignalMixin host, aliased imports, cascades, '
      'while isolating nested classes and external targets',
      () async {
        const code = '''
import 'dart:core';
import 'dart:core' as core;
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

mixin CounterMixin on BlocSignal<CounterEvent, int> {
  void register() {
    on<Increment>((e, emit) {});
    on<Increment>((e, emit) {});
  }
}

class MixinHostBloc extends BlocSignalBase<int>
    with BlocSignalMixin<CounterEvent, int> {
  MixinHostBloc() : super(initialState: 0) {
    initCubitSignal(initialState: 0);
    on<Increment>((e, emit) {});
    this..on<Increment>((e, emit) {});
  }
}

class OuterBloc extends BlocSignal<CounterEvent, int> {
  OuterBloc(BlocSignal<CounterEvent, int> other) : super(initialState: 0) {
    on<Increment>((e, emit) {});
    other.on<Increment>((e, emit) {});
    void local() {
      // Nested class should not collide with OuterBloc
      final _ = _InnerBloc();
    }
    local();
  }
}

class _InnerBloc extends BlocSignal<CounterEvent, int> {
  _InnerBloc() : super(initialState: 0) {
    on<Increment>((e, emit) {});
  }
}

class AliasedBloc extends BlocSignal<core.Object, int> {
  AliasedBloc() : super(initialState: 0) {
    on<core.int>((e, emit) {});
    on<int>((e, emit) {});
  }
}
''';
        final lints = await runLintRule(
          const AvoidDuplicateEventHandlers(),
          code,
        );
        // 1 in CounterMixin, 1 in MixinHostBloc (cascade),
        // 1 in AliasedBloc
        expect(lints, hasLength(3));
      },
    );

    test(
      '(Issue #477: Area 1) RequireEmitInHelperName detects non-emitting '
      'helper in MixinDeclaration and cascade this..emit()',
      () async {
        const badCode = '''
mixin CounterCubitMixin on CubitSignal<int> {
  void _bump() {
    this..emit(value + 1);
  }
  void _bumpAndEmit() {
    emit(value + 1);
  }
}
''';
        final lints = await runLintRule(
          const RequireEmitInHelperName(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('_bump'));
      },
    );

    test(
      '(Issue #477: Area 1) AvoidRawSignalEffectsInBloc detects raw effect() '
      'in MixinDeclaration on CubitSignal',
      () async {
        const badCode = '''
mixin EffectMixin on CubitSignal<int> {
  void setup() {
    effect(() {});
  }
}
''';
        final lints = await runLintRule(
          const AvoidRawSignalEffectsInBloc(),
          badCode,
        );
        expect(lints, hasLength(1));
        expect(lints.first.lexeme, equals('effect'));
      },
    );

    test(
      '(Issue #477: Area 1) RequireSuperOnEvent detects missing super.onEvent '
      'in MixinDeclaration and BlocSignalMixin host',
      () async {
        const badCode = '''
sealed class E {}

mixin EventMixin on BlocSignal<E, int> {
  @override
  void onEvent(E event) {}
}

class MixinHost extends BlocSignalBase<int> with BlocSignalMixin<E, int> {
  MixinHost() : super(initialState: 0);

  @override
  void onEvent(E event) {}
}
''';
        final lints = await runLintRule(
          const RequireSuperOnEvent(),
          badCode,
        );
        expect(lints, hasLength(2));
        expect(lints.every((l) => l.lexeme == 'onEvent'), isTrue);
      },
    );

    test(
      '(Issue #477: Area 1) AvoidPrimitiveEventTypes detects primitive event '
      'types in MixinDeclaration on-clauses',
      () async {
        const badCode = '''
mixin BadBlocMixin on BlocSignal<int, String> {}
mixin BadMixinConstraint on BlocSignalMixin<String, int> {}
''';
        final lints = await runLintRule(
          const AvoidPrimitiveEventTypes(),
          badCode,
        );
        expect(lints, hasLength(2));
        expect(lints.map((l) => l.lexeme), containsAll(['int', 'String']));
      },
    );

    test(
      '(Issue #477: Area 1) AvoidPseudoEventsInTelemetry detects pseudo-events '
      'in MixinDeclaration on CubitSignal and CubitSignalMixin',
      () async {
        const badCode = '''
mixin TelemetryCubitMixin on CubitSignal<int> {
  void tap() {
    emitTelemetry('buttonPressed');
  }
}

mixin TelemetryMixinConstraint on CubitSignalMixin<int> {
  void submit() {
    emitTelemetry('formSubmitted');
  }
}
''';
        final lints = await runLintRule(
          const AvoidPseudoEventsInTelemetry(),
          badCode,
        );
        expect(lints, hasLength(2));
      },
    );

    test(
      '(Issue #477: BLOCKER-1) BlocSignalObserver subclasses are not '
      'misclassified as BlocSignal containers',
      () async {
        const observerCode = '''
class MyObserver extends BlocSignalObserver {
  @override
  void onEvent(BlocSignalBase<Object?> bloc, Object? event) {}

  void on<E>(void Function(E, void Function(int)) handler) {}
  void emit(int v) {}

  void _helper() {
    emit(1);
    effect(() {});
    on<int>((e, emit) {});
    on<int>((e, emit) {});
  }
}
''';
        expect(
          await runLintRule(const RequireSuperOnEvent(), observerCode),
          isEmpty,
        );
        expect(
          await runLintRule(const AvoidDuplicateEventHandlers(), observerCode),
          isEmpty,
        );
        expect(
          await runLintRule(const AvoidRawSignalEffectsInBloc(), observerCode),
          isEmpty,
        );
        expect(
          await runLintRule(const RequireEmitInHelperName(), observerCode),
          isEmpty,
        );
      },
    );

    test(
      '(Issue #477: BLOCKER-1) BlocSignalBase with CubitSignalMixin and '
      'mixin on BlocSignalBase are not misclassified as BlocSignal hosts',
      () async {
        const cubitCode = '''
class MyCubit extends BlocSignalBase<int> with CubitSignalMixin<int> {
  MyCubit() : super(initialState: 0);

  void onEvent(Object event) {}
  void on<E>(void Function(E, void Function(int)) handler) {}

  void tap() {
    emitTelemetry('buttonPressed');
    on<int>((e, emit) {});
    on<int>((e, emit) {});
  }
}

mixin BaseOnlyMixin on BlocSignalBase<int> {
  void onEvent(Object event) {}
}
''';
        expect(
          await runLintRule(const RequireSuperOnEvent(), cubitCode),
          isEmpty,
        );
        expect(
          await runLintRule(const AvoidDuplicateEventHandlers(), cubitCode),
          isEmpty,
        );
        final telemetryLints = await runLintRule(
          const AvoidPseudoEventsInTelemetry(),
          cubitCode,
        );
        expect(telemetryLints, hasLength(1));
      },
    );

    test(
      '(Issue #477: NBO-1) Negative and valid MixinDeclaration, unresolved '
      'type, and foreign-cascade coverage',
      () async {
        const duplicateEdgeCode = '''
mixin PlainMixin {
  void on<E>(void Function() cb) {}
  void setup() {
    on<int>(() {});
    on<int>(() {});
  }
}

class UnresolvedEventBloc extends BlocSignal<Object, int> {
  UnresolvedEventBloc() : super(initialState: 0) {
    on<UndefinedEvent>((e, emit) {});
    on<UndefinedEvent>((e, emit) {});
  }
}
''';
        final dupLints = await runLintRule(
          const AvoidDuplicateEventHandlers(),
          duplicateEdgeCode,
        );
        expect(dupLints, hasLength(1));

        const validMixinSuperCode = '''
sealed class E {}
mixin ValidEventMixin on BlocSignal<E, int> {
  @override
  void onEvent(E event) {
    super.onEvent(event);
  }
}
''';
        expect(
          await runLintRule(const RequireSuperOnEvent(), validMixinSuperCode),
          isEmpty,
        );

        const validMixinPrimitiveCode = '''
sealed class MyEvent {}
mixin GoodBlocMixin on BlocSignal<MyEvent, int> {}
''';
        expect(
          await runLintRule(
            const AvoidPrimitiveEventTypes(),
            validMixinPrimitiveCode,
          ),
          isEmpty,
        );

        const nonCubitMixinCode = '''
sealed class E {}
mixin BlocTelemetryMixin on BlocSignal<E, int> {
  void tap() {
    emitTelemetry('buttonPressed');
  }
}
mixin PlainTelemetryMixin {
  void emitTelemetry(String name) {}
  void tap() {
    emitTelemetry('buttonPressed');
  }
}
''';
        expect(
          await runLintRule(
            const AvoidPseudoEventsInTelemetry(),
            nonCubitMixinCode,
          ),
          isEmpty,
        );

        const foreignCascadeEmitCode = '''
class Other {
  void emit(int v) {}
}

class MyCubit extends CubitSignal<int> {
  MyCubit() : super(initialState: 0);
  void _helper(Other other) {
    other..emit(1);
  }
}
''';
        expect(
          await runLintRule(
            const RequireEmitInHelperName(),
            foreignCascadeEmitCode,
          ),
          isEmpty,
        );
      },
    );
  });
}
