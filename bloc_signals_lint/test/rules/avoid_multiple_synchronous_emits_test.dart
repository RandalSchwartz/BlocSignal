import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/rules/avoid_multiple_synchronous_emits.dart';
import 'package:test/test.dart';

void main() {
  group('AvoidMultipleSynchronousEmits AST Detection', () {
    test('rule metadata is properly configured', () {
      const rule = AvoidMultipleSynchronousEmits();
      expect(rule.code.name, equals('avoid_multiple_synchronous_emits'));
      expect(
        rule.code.problemMessage,
        equals(
          'Multiple synchronous `emit()` calls detected along the '
          'same execution path.',
        ),
      );
      expect(
        rule.code.correctionMessage,
        equals(
          'Consolidate into a single atomic state transition to prevent '
          'intermediate state leakage.',
        ),
      );
    });

    test('detects multiple direct synchronous emit() calls in a method', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void badMethod() {
    emit(1);
    emit(2);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects emit() followed by synchronous call to emitting helper', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void updateCoordinates(int pos) {
    emit(pos);
    _pruneAndEmit();
  }

  void _pruneAndEmit() {
    emit(stateValue + 1);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects multiple emissions in synchronous for-in loop', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void emitAll(List<int> items) {
    for (final item in items) {
      emit(item);
    }
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test(
        'detects emit() in if branch and subsequent emit() '
        'without early return', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void checkAndEmit(bool condition) {
    if (condition) {
      emit(1);
    }
    emit(2);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('accepts emit() calls separated by await', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  Future<void> loadData() async {
    emit(1);
    await Future<void>.delayed(Duration.zero);
    emit(2);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts emit() calls in mutually exclusive if-else branches', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void handleResult(bool success) {
    if (success) {
      emit(1);
    } else {
      emit(2);
    }
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts emit() in if branch with early return followed by emit()',
        () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void checkAndEmit(bool condition) {
    if (condition) {
      emit(1);
      return;
    }
    emit(2);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test(
        'accepts emit() inside nested closure callbacks '
        '(different execution contexts)', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void setup() {
    emit(1);
    Future<void>.delayed(Duration.zero, () {
      emit(2);
    });
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('detects multiple emissions when calling arrow function helper', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void update() {
    emit(1);
    _helperAndEmit();
  }

  void _helperAndEmit() => emit(2);
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects emission in variable declaration initializer', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void update() {
    emit(1);
    final res = _helperAndEmit();
  }

  int _helperAndEmit() {
    emit(2);
    return 42;
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects multiple emissions in while loops', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void run(bool condition) {
    while (condition) {
      emit(1);
    }
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects multiple emissions across sequential blocks', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void run() {
    {
      emit(1);
    }
    {
      emit(2);
    }
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('detects multiple emissions within a switch case', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void handleEvent(int event) {
    switch (event) {
      case 1:
        emit(10);
        emit(20);
        break;
      default:
        break;
    }
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(1));
    });

    test('accepts mutually exclusive emissions across switch cases', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void handleEvent(int event) {
    switch (event) {
      case 1:
        emit(10);
        break;
      case 2:
        emit(20);
        break;
      default:
        emit(0);
        break;
    }
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts mutually exclusive emit() in ternary ConditionalExpression',
        () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void toggle(bool flag) {
    flag ? emit(1) : emit(2);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts rethrow in catch block after error handling', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void execute(bool willFail) {
    try {
      if (willFail) throw Exception();
      return;
    } catch (_) {
      emit(1);
      rethrow;
    }
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts single-iteration while loop that breaks immediately', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void runOnce() {
    while (true) {
      emit(1);
      break;
    }
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidMultipleSynchronousEmits.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });
  });
}
