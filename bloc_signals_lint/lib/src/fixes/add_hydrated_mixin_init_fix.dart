import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `RequireHydratedMixinInit` that inserts
/// `hydrate();` into uninitialized constructor bodies.
class AddHydratedMixinInitFix extends ResolvedCorrectionProducer {
  /// Creates an [AddHydratedMixinInitFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.addHydratedMixinInit',
    DartFixKindPriority.standard,
    "Add 'hydrate();'",
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
      await _insertInFunctionBody(builder, ctor.body);
      return;
    }

    final primaryBody = node.thisOrAncestorOfType<PrimaryConstructorBody>();
    if (primaryBody != null) {
      await _insertInFunctionBody(builder, primaryBody.body);
      return;
    }

    final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    final body = classDecl.body;
    final namePart = classDecl.namePart;
    final hasPrimaryConstructor = namePart is PrimaryConstructorDeclaration;

    if (hasPrimaryConstructor) {
      if (body is EmptyClassBody) {
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleReplacement(
            body.sourceRange,
            ' {\n  this {\n    hydrate();\n  }\n}',
          );
        });
        return;
      }
      if (body is BlockClassBody &&
          body.members.whereType<PrimaryConstructorBody>().isEmpty) {
        await builder.addDartFileEdit(file, (builder) {
          builder.addSimpleInsertion(
            body.leftBracket.end,
            '\n  this {\n    hydrate();\n  }\n',
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
          ' {\n  $className() {\n    hydrate();\n  }\n}',
        );
      });
      return;
    }

    if (body is BlockClassBody &&
        body.members.whereType<ConstructorDeclaration>().isEmpty) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleInsertion(
          body.leftBracket.end,
          '\n  $className() {\n    hydrate();\n  }\n',
        );
      });
    }
  }

  Future<void> _insertInFunctionBody(
    ChangeBuilder builder,
    FunctionBody body,
  ) async {
    await builder.addDartFileEdit(file, (builder) {
      if (body is BlockFunctionBody) {
        final initStmt = _findInitCubitSignalStatement(body);
        if (initStmt != null) {
          builder.addSimpleInsertion(initStmt.end, '\n    hydrate();');
        } else {
          builder.addSimpleInsertion(
            body.block.leftBracket.end,
            '\n    hydrate();',
          );
        }
      } else if (body is EmptyFunctionBody) {
        builder.addSimpleReplacement(
          body.sourceRange,
          ' {\n    hydrate();\n  }',
        );
      }
    });
  }

  static Statement? _findInitCubitSignalStatement(BlockFunctionBody body) {
    Statement? found;
    body.block.visitChildren(
      _InitStmtFinder(body.block, (stmt) {
        found ??= stmt;
      }),
    );
    return found;
  }
}

class _InitStmtFinder extends RecursiveAstVisitor<void> {
  new(this.targetBlock, this.onFound);

  final Block targetBlock;
  final void Function(Statement) onFound;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Do not recurse into nested closures.
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'initCubitSignal') {
      final stmt = node.thisOrAncestorOfType<Statement>();
      if (stmt != null && stmt.parent == targetBlock) {
        onFound(stmt);
      }
    }
    super.visitMethodInvocation(node);
  }
}
