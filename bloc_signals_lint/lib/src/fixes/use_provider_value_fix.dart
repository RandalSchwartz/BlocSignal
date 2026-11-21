import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidProvidingExistingInstanceWithCreate`
/// that rewrites `create:` to `value:` using the `.value` constructor.
///
/// Example:
/// ```dart
/// // Before:
/// BlocSignalProvider(create: (_) => existingBloc)
///
/// // After:
/// BlocSignalProvider.value(value: existingBloc)
/// ```
class UseProviderValueFix extends ResolvedCorrectionProducer {
  /// Creates a [UseProviderValueFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.useProviderValue',
    DartFixKindPriority.standard,
    "Use 'BlocSignalProvider.value(value: ...)'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final namedExpr = node.thisOrAncestorOfType<NamedArgument>();
    if (namedExpr == null || namedExpr.name.lexeme != 'create') return;

    Expression? returnedExpr;
    final expr = namedExpr.argumentExpression;
    if (expr is FunctionExpression) {
      final body = expr.body;
      if (body is ExpressionFunctionBody) {
        returnedExpr = body.expression;
      } else if (body is BlockFunctionBody) {
        for (final statement in body.block.statements) {
          if (statement is ReturnStatement) {
            returnedExpr = statement.expression;
            break;
          }
        }
      }
    }

    await builder.addDartFileEdit(file, (builder) {
      final parent = namedExpr.parent?.parent;
      if (parent is InstanceCreationExpression) {
        final ctor = parent.constructorName;
        if (ctor.name == null) {
          builder.addSimpleInsertion(ctor.type.end, '.value');
        }
      } else if (parent is MethodInvocation) {
        if (parent.target == null &&
            !parent.methodName.name.endsWith('.value')) {
          if (parent.typeArguments != null) {
            builder.addSimpleInsertion(parent.typeArguments!.end, '.value');
          } else {
            builder.addSimpleReplacement(
              parent.methodName.sourceRange,
              '${parent.methodName.name}.value',
            );
          }
        }
      }

      if (returnedExpr != null) {
        builder.addSimpleReplacement(
          namedExpr.sourceRange,
          'value: ${returnedExpr.toSource()}',
        );
      } else {
        builder.addSimpleReplacement(namedExpr.name.sourceRange, 'value');
      }
    });
  }
}
