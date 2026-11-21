import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `RequireCubitSignalMixinInit` that inserts
/// `initCubitSignal(initialState: ...);` into uninitialized constructor bodies.
///
/// Example:
/// ```dart
/// // Before:
/// MyService() {}
///
/// // After:
/// MyService() {
///   initCubitSignal(initialState: TODO_INITIAL_STATE);
/// }
/// ```
class RequireCubitSignalMixinInitFix extends ResolvedCorrectionProducer {
  /// Creates a [RequireCubitSignalMixinInitFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.requireCubitSignalMixinInit',
    DartFixKindPriority.standard,
    "Add 'initCubitSignal(initialState: ...);'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final ctor = node.thisOrAncestorOfType<ConstructorDeclaration>();
    if (ctor != null) {
      final body = ctor.body;
      await builder.addDartFileEdit(file, (builder) {
        if (body is BlockFunctionBody) {
          builder.addSimpleInsertion(
            body.block.leftBracket.end,
            '\n    initCubitSignal(initialState: TODO_INITIAL_STATE);',
          );
        } else if (body is EmptyFunctionBody) {
          builder.addSimpleReplacement(
            body.sourceRange,
            '{\n    initCubitSignal(initialState: TODO_INITIAL_STATE);\n  }',
          );
        }
      });
      return;
    }

    final primaryBody = node.thisOrAncestorOfType<PrimaryConstructorBody>();
    if (primaryBody != null) {
      final body = primaryBody.body;
      await builder.addDartFileEdit(file, (builder) {
        if (body is BlockFunctionBody) {
          builder.addSimpleInsertion(
            body.block.leftBracket.end,
            '\n    initCubitSignal(initialState: TODO_INITIAL_STATE);',
          );
        } else if (body is EmptyFunctionBody) {
          builder.addSimpleReplacement(
            body.sourceRange,
            '{\n    initCubitSignal(initialState: TODO_INITIAL_STATE);\n  }',
          );
        }
      });
      return;
    }

    final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl != null) {
      final body = classDecl.body;
      final namePart = classDecl.namePart;
      final hasPrimaryConstructor = namePart is PrimaryConstructorDeclaration;

      if (hasPrimaryConstructor) {
        if (body is EmptyClassBody) {
          await builder.addDartFileEdit(file, (builder) {
            builder.addSimpleReplacement(
              body.sourceRange,
              ' {\n  this {\n'
              '    initCubitSignal(initialState: TODO_INITIAL_STATE);\n'
              '  }\n}',
            );
          });
          return;
        }
        if (body is BlockClassBody &&
            body.members.whereType<PrimaryConstructorBody>().isEmpty) {
          await builder.addDartFileEdit(file, (builder) {
            builder.addSimpleInsertion(
              body.leftBracket.end,
              '\n  this {\n'
              '    initCubitSignal(initialState: TODO_INITIAL_STATE);\n'
              '  }\n',
            );
          });
        }
        return;
      }

      final className = namePart.typeName.lexeme;
      if (body is EmptyClassBody) {
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleReplacement(
            body.sourceRange,
            ' {\n  $className() {\n'
            '    initCubitSignal(initialState: TODO_INITIAL_STATE);\n'
            '  }\n}',
          );
        });
        return;
      }

      if (body is BlockClassBody &&
          body.members.whereType<ConstructorDeclaration>().isEmpty) {
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleInsertion(
            body.leftBracket.end,
            '\n  $className() {\n'
            '    initCubitSignal(initialState: TODO_INITIAL_STATE);\n'
            '  }\n',
          );
        });
      }
    }
  }
}
