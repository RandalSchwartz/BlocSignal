import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidManualCloseOnProvidedBloc` that
/// removes the manual `.close()` statement.
class RemoveManualCloseOnProvidedBlocFix extends ResolvedCorrectionProducer {
  /// Creates a [RemoveManualCloseOnProvidedBlocFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.removeManualCloseOnProvidedBloc',
    DartFixKindPriority.standard,
    "Remove manual 'close()' call",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null || invocation.methodName.name != 'close') return;

    final targetExpr = invocation.parent is AwaitExpression
        ? invocation.parent! as AwaitExpression
        : invocation;

    final parent = targetExpr.parent;
    if (parent is ExpressionFunctionBody) {
      final keyword = parent.keyword != null
          ? '${parent.keyword!.lexeme}${parent.star?.lexeme ?? ''} '
          : '';
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(parent.sourceRange, '$keyword{}');
      });
      return;
    }

    if (parent is! ExpressionStatement) return;

    await builder.addDartFileEdit(file, (builder) {
      if (parent.parent is Block) {
        builder.addDeletion(parent.sourceRange);
      } else {
        builder.addSimpleReplacement(parent.sourceRange, '{}');
      }
    });
  }
}
