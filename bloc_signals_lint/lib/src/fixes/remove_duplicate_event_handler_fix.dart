import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidDuplicateEventHandlers` that removes
/// the duplicate `on<Event>(...)` registration statement.
class RemoveDuplicateEventHandlerFix extends ResolvedCorrectionProducer {
  /// Creates a [RemoveDuplicateEventHandlerFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.removeDuplicateEventHandler',
    DartFixKindPriority.standard,
    'Remove duplicate event handler',
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null || invocation.methodName.name != 'on') return;

    final parent = invocation.parent;
    if (parent is CascadeExpression &&
        parent.cascadeSections.contains(invocation)) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addDeletion(invocation.sourceRange);
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
