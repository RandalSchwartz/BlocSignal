import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/rules/avoid_primitive_event_types.dart';
import 'package:test/test.dart';

void main() {
  group('AvoidPrimitiveEventTypes AST Detection', () {
    test('rule metadata is properly configured', () {
      const rule = AvoidPrimitiveEventTypes();
      expect(rule.code.name, equals('avoid_primitive_event_types'));
      expect(
        rule.code.problemMessage,
        equals(
          'Avoid using primitive or untyped types ("{0}") for BlocSignal '
          'events. Events should be dedicated sealed classes or records.',
        ),
      );
      expect(
        rule.code.correctionMessage,
        equals(
          'Define a dedicated event class or record (for example, '
          '"sealed class MyEvent {}") to model state transitions cleanly.',
        ),
      );
    });

    test('detects primitive int event type in BlocSignal', () {
      const badCode = '''
class CounterBloc extends BlocSignal<int, int> {
  CounterBloc() : super(initialState: 0);
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects primitive String event type in BlocSignal', () {
      const badCode = '''
class TextBloc extends BlocSignal<String, String> {
  TextBloc() : super(initialState: '');
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects primitive bool and double event types in BlocSignal', () {
      const badCode = '''
class BoolBloc extends BlocSignal<bool, bool> {
  BoolBloc() : super(initialState: false);
}
class DoubleBloc extends BlocSignal<double, double> {
  DoubleBloc() : super(initialState: 0.0);
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(2));
    });

    test('detects num, dynamic, Object, and nullable primitive event types',
        () {
      const badCode = '''
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
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(4));
    });

    test('detects primitive event type when using BlocSignalMixin', () {
      const badCode = '''
class ServiceBloc extends BaseService with BlocSignalMixin<int, int> {
  ServiceBloc() {
    initBlocSignal(initialState: 0);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects primitive event type when extending ReplayBloc', () {
      const badCode = '''
class ReplayCounterBloc extends ReplayBloc<int, int> {
  ReplayCounterBloc() : super(initialState: 0);
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects raw BlocSignal without type arguments', () {
      const badCode = '''
class RawBloc extends BlocSignal {
  RawBloc() : super(initialState: 0);
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('accepts dedicated event class in BlocSignal', () {
      const goodCode = '''
sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts record event type in BlocSignal', () {
      const goodCode = '''
class CoordinateBloc extends BlocSignal<(int x, int y), int> {
  CoordinateBloc() : super(initialState: 0);
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts CubitSignal with primitive state', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts unrelated non-bloc class with primitive generic', () {
      const goodCode = '''
class GenericContainer<T> {}
class IntContainer extends GenericContainer<int> {}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts non-bloc superclass with valid BlocSignalMixin', () {
      const goodCode = '''
sealed class UserEvent {}

class UserBloc extends BaseRepository
    with DiagnosticableTreeMixin, BlocSignalMixin<UserEvent, int> {
  UserBloc() {
    initBlocSignal(initialState: 0);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('detects primitive event in BlocSignalMixin alongside other mixins',
        () {
      const badCode = '''
class BadUserBloc extends BaseRepository
    with DiagnosticableTreeMixin, BlocSignalMixin<int, int> {
  BadUserBloc() {
    initBlocSignal(initialState: 0);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPrimitiveEventTypes.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });
  });
}
