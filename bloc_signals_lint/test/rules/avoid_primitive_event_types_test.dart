import 'package:bloc_signals_lint/src/rules/avoid_primitive_event_types.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('AvoidPrimitiveEventTypes Semantic Detection', () {
    test('rule metadata is properly configured', () {
      final rule = AvoidPrimitiveEventTypes();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_primitive_event_types'),
      );
      expect(
        rule.diagnosticCode.problemMessage,
        equals(
          'Avoid using primitive or untyped types ("{0}") for BlocSignal '
          'events. Events should be dedicated sealed classes or records.',
        ),
      );
      expect(
        rule.diagnosticCode.correctionMessage,
        equals(
          'Define a dedicated event class or record (for example, '
          '"sealed class MyEvent {}") to model state transitions cleanly.',
        ),
      );
    });

    test('detects primitive int event type in BlocSignal', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterBloc extends BlocSignal<int, int> {
  CounterBloc() : super(initialState: 0);
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        badCode,
      );
      expect(diagnostics, hasLength(1));
    });

    test('detects primitive String event type in BlocSignal', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class TextBloc extends BlocSignal<String, String> {
  TextBloc() : super(initialState: '');
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        badCode,
      );
      expect(diagnostics, hasLength(1));
    });

    test(
      'detects primitive bool and double event types in BlocSignal',
      () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class BoolBloc extends BlocSignal<bool, bool> {
  BoolBloc() : super(initialState: false);
}
class DoubleBloc extends BlocSignal<double, double> {
  DoubleBloc() : super(initialState: 0.0);
}
''';
        final diagnostics = await runLintRule(
          AvoidPrimitiveEventTypes(),
          badCode,
        );
        expect(diagnostics, hasLength(2));
      },
    );

    test(
      'detects num, dynamic, Object, and nullable primitive event types',
      () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class NumBloc extends BlocSignal<num, int> {
  NumBloc() : super(initialState: 0);
}
class DynamicBloc extends BlocSignal<dynamic, int> {
  DynamicBloc() : super(initialState: 0);
}
class ObjectBloc extends BlocSignal<Object, int> {
  ObjectBloc() : super(initialState: 0);
}
class NullableIntBloc extends BlocSignal<int?, int> {
  NullableIntBloc() : super(initialState: 0);
}
''';
        final diagnostics = await runLintRule(
          AvoidPrimitiveEventTypes(),
          badCode,
        );
        expect(diagnostics, hasLength(4));
      },
    );

    test('detects primitive event type when using BlocSignalMixin', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class BaseService extends BlocSignalBase<int> {
  BaseService() : super(initialState: 0);
}

class ServiceBloc extends BaseService with BlocSignalMixin<int, int> {
  ServiceBloc() {
    initCubitSignal(initialState: 0);
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        badCode,
      );
      expect(diagnostics, hasLength(1));
    });

    test('detects primitive event type when extending ReplayBloc', () async {
      const badCode = '''
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

class ReplayCounterBloc extends ReplayBloc<int, int> {
  ReplayCounterBloc() : super(initialState: 0);
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        badCode,
      );
      expect(diagnostics, hasLength(1));
    });

    test('detects raw BlocSignal without type arguments', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class RawBloc extends BlocSignal {
  RawBloc() : super(initialState: 0);
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        badCode,
      );
      expect(diagnostics, hasLength(1));
    });

    test('accepts dedicated event class in BlocSignal', () async {
      const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });

    test('accepts record event type in BlocSignal', () async {
      const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CoordinateBloc extends BlocSignal<(int x, int y), int> {
  CoordinateBloc() : super(initialState: 0);
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });

    test('accepts CubitSignal with primitive state', () async {
      const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });

    test('accepts unrelated non-bloc class with primitive generic', () async {
      const goodCode = '''
class GenericContainer<T> {}
class IntContainer extends GenericContainer<int> {}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });

    test('accepts non-bloc superclass with valid BlocSignalMixin', () async {
      const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class UserEvent {}
class BaseRepository extends BlocSignalBase<int> {
  BaseRepository() : super(initialState: 0);
}
mixin DiagnosticableTreeMixin {}

class UserBloc extends BaseRepository
    with DiagnosticableTreeMixin, BlocSignalMixin<UserEvent, int> {
  UserBloc() {
    initCubitSignal(initialState: 0);
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPrimitiveEventTypes(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });

    test(
      'detects primitive event in BlocSignalMixin alongside other mixins',
      () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class BaseRepository extends BlocSignalBase<int> {
  BaseRepository() : super(initialState: 0);
}
mixin DiagnosticableTreeMixin {}

class BadUserBloc extends BaseRepository
    with DiagnosticableTreeMixin, BlocSignalMixin<int, int> {
  BadUserBloc() {
    initCubitSignal(initialState: 0);
  }
}
''';
        final diagnostics = await runLintRule(
          AvoidPrimitiveEventTypes(),
          badCode,
        );
        expect(diagnostics, hasLength(1));
      },
    );
  });
}
