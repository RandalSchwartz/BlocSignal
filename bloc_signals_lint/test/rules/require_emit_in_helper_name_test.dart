import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/rules/require_emit_in_helper_name.dart';
import 'package:test/test.dart';

void main() {
  group('RequireEmitInHelperName AST Detection', () {
    test('rule metadata is properly configured', () {
      const rule = RequireEmitInHelperName();
      expect(rule.code.name, equals('require_emit_in_helper_name'));
      expect(
        rule.code.problemMessage,
        equals(
          "Private helper method '{0}' calls `emit()`, but its name does "
          'not reflect state emission.',
        ),
      );
      expect(
        rule.code.correctionMessage,
        equals(
          "Rename to '{0}AndEmit' to declare state transition side-effects.",
        ),
      );
    });

    test('flags private helper method calling emit() with non-emitting name',
        () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void _prune() {
    emit(stateValue + 1);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flagged = <String>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        for (final method
            in declaration.members.whereType<MethodDeclaration>()) {
          if (RequireEmitInHelperName.isFlaggedHelper(method)) {
            flagged.add(method.name.lexeme);
          }
        }
      }

      expect(flagged, contains('_prune'));
    });

    test(
        'flags private helper method calling this.emit() '
        'with non-emitting name', () {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void _update() {
    this.emit(stateValue + 1);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flagged = <String>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        for (final method
            in declaration.members.whereType<MethodDeclaration>()) {
          if (RequireEmitInHelperName.isFlaggedHelper(method)) {
            flagged.add(method.name.lexeme);
          }
        }
      }

      expect(flagged, contains('_update'));
    });

    test('accepts private helper methods ending with AndEmit or Emit', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void _pruneAndEmit() {
    emit(stateValue + 1);
  }

  void _updateEmit() {
    emit(stateValue + 2);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flagged = <String>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        for (final method
            in declaration.members.whereType<MethodDeclaration>()) {
          if (RequireEmitInHelperName.isFlaggedHelper(method)) {
            flagged.add(method.name.lexeme);
          }
        }
      }

      expect(flagged, isEmpty);
    });

    test('accepts private helper methods starting with _emit', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void _emitPosition(int pos) {
    emit(pos);
  }

  void _emit() {
    emit(0);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flagged = <String>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        for (final method
            in declaration.members.whereType<MethodDeclaration>()) {
          if (RequireEmitInHelperName.isFlaggedHelper(method)) {
            flagged.add(method.name.lexeme);
          }
        }
      }

      expect(flagged, isEmpty);
    });

    test('accepts public methods regardless of name', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void update() {
    emit(stateValue + 1);
  }

  void prune() {
    emit(stateValue - 1);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flagged = <String>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        for (final method
            in declaration.members.whereType<MethodDeclaration>()) {
          if (RequireEmitInHelperName.isFlaggedHelper(method)) {
            flagged.add(method.name.lexeme);
          }
        }
      }

      expect(flagged, isEmpty);
    });

    test('accepts private helper methods that do not call emit()', () {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  int _calculateSum(int a, int b) {
    return a + b;
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flagged = <String>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        for (final method
            in declaration.members.whereType<MethodDeclaration>()) {
          if (RequireEmitInHelperName.isFlaggedHelper(method)) {
            flagged.add(method.name.lexeme);
          }
        }
      }

      expect(flagged, isEmpty);
    });

    test('does not flag words containing "emit" as substring like "semitone"',
        () {
      expect(RequireEmitInHelperName.isEmittingName('_transmit'), isFalse);
      expect(RequireEmitInHelperName.isEmittingName('_permit'), isFalse);
      expect(RequireEmitInHelperName.isEmittingName('_delimiter'), isFalse);
      expect(RequireEmitInHelperName.isEmittingName('_prune'), isFalse);
      expect(RequireEmitInHelperName.isEmittingName('_semitone'), isFalse);
      expect(RequireEmitInHelperName.isEmittingName('_extremity'), isFalse);
      expect(RequireEmitInHelperName.isEmittingName('_remittance'), isFalse);
      expect(RequireEmitInHelperName.isEmittingName('_demit'), isFalse);

      expect(RequireEmitInHelperName.isEmittingName('_emit'), isTrue);
      expect(RequireEmitInHelperName.isEmittingName('_emitData'), isTrue);
      expect(RequireEmitInHelperName.isEmittingName('_pruneAndEmit'), isTrue);
      expect(RequireEmitInHelperName.isEmittingName('_updateEmit'), isTrue);
      expect(
        RequireEmitInHelperName.isEmittingName('_recalculateAndEmitValue'),
        isTrue,
      );
      expect(RequireEmitInHelperName.isEmittingName('_prune_and_emit'), isTrue);
    });
  });
}
