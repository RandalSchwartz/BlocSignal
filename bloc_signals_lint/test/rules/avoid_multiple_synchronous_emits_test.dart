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

    test(
      '(Issue #329: R15) detects multiple synchronous emit() calls inside '
      'MixinDeclaration via findMixinViolations',
      () {
        const badCode = '''
mixin PricingMixin on CubitSignal<int> {
  void applyDiscount() {
    emit(1);
    _helperEmit();
  }

  void _helperEmit() => emit(2);
}
''';
        final parseResult = parseString(content: badCode);
        final flaggedNodes = <AstNode>[];

        for (final declaration
            in parseResult.unit.declarations.whereType<MixinDeclaration>()) {
          flaggedNodes.addAll(
            AvoidMultipleSynchronousEmits.findMixinViolations(declaration),
          );
        }

        expect(flaggedNodes, hasLength(1));
      },
    );

    test(
      '(Issue #329: R15) detects cascade emit() calls in '
      'ExpressionFunctionBody arrow method and closure',
      () {
        const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void badArrow() => this
    ..emit(1)
    ..emit(2);

  void badClosure() {
    final fn = () => this
      ..emit(3)
      ..emit(4);
    fn();
  }

  void safeForeignCascade(CubitSignal<int> other) => other..emit(1)..emit(2);
}
''';
        final parseResult = parseString(content: badCode);
        final flaggedNodes = <AstNode>[];

        for (final declaration
            in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
          flaggedNodes.addAll(
            AvoidMultipleSynchronousEmits.findViolations(declaration),
          );
        }

        expect(flaggedNodes, hasLength(2));
      },
    );

    test(
      '(Issue #329: R15) handles ContinueStatement without false-positive '
      'same-iteration fallthrough while catching multi-iteration emits',
      () {
        const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void safeLoop(List<int> items, bool cond) {
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
}
''';
        final goodParse = parseString(content: goodCode);
        final goodFlagged = <AstNode>[];
        for (final declaration
            in goodParse.unit.declarations.whereType<ClassDeclaration>()) {
          goodFlagged.addAll(
            AvoidMultipleSynchronousEmits.findViolations(declaration),
          );
        }
        expect(goodFlagged, isEmpty);

        const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void multiIterContinue(List<int> items) {
    do {
      this.emit(1);
      continue;
    } while (items.isNotEmpty);
  }

  void continueCarriesEmitToPostLoop(List<int> items, bool cond) {
    for (final x in items) {
      if (cond) {
        emit(x);
        continue;
      }
      break;
    }
    try {
      switch (items.length) {
        case 1:
          other.emit(1);
          break;
      }
    } finally {
      emit(99);
    }
  }

  Future<void> _asyncBlockHelper() async {
    await Future<void>.delayed(Duration.zero);
    emit(1);
  }

  Future<void> _asyncArrowHelper() async =>
      await Future<void>.delayed(Duration.zero);
}
''';
        final badParse = parseString(content: badCode);
        final badFlagged = <AstNode>[];
        for (final declaration
            in badParse.unit.declarations.whereType<ClassDeclaration>()) {
          badFlagged.addAll(
            AvoidMultipleSynchronousEmits.findViolations(declaration),
          );
        }
        expect(badFlagged, hasLength(3));
      },
    );

    test(
      '(Issue #329: R15) resolves intra-switch continue caseLabel jumps and '
      'preserves unlabeled continue inside switch for enclosing loops',
      () {
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
        final goodParse = parseString(content: goodCode);
        final goodFlagged = <AstNode>[];
        for (final declaration
            in goodParse.unit.declarations.whereType<ClassDeclaration>()) {
          goodFlagged.addAll(
            AvoidMultipleSynchronousEmits.findViolations(declaration),
          );
        }
        expect(goodFlagged, isEmpty);

        const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void emitBeforeSwitchContinue(int x, bool jump) {
    switch (x) {
      case 1:
        emit(1);
        if (jump) {
          continue sharedCase;
        }
        break;
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
        final badParse = parseString(content: badCode);
        final badFlagged = <AstNode>[];
        for (final declaration
            in badParse.unit.declarations.whereType<ClassDeclaration>()) {
          badFlagged.addAll(
            AvoidMultipleSynchronousEmits.findViolations(declaration),
          );
        }
        expect(badFlagged, hasLength(2));
      },
    );
  });
}
