import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidUnusedSelectResult` that binds the
/// unused `context.select(...)` expression to `final value = ...`.
class BindUnusedSelectResultFix extends ResolvedCorrectionProducer {
  /// Creates a [BindUnusedSelectResultFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.bindUnusedSelectResult',
    DartFixKindPriority.standard,
    "Bind result to 'final value'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final stmt = node.thisOrAncestorOfType<ExpressionStatement>();
    if (stmt == null) return;

    await builder.addDartFileEdit(file, (builder) {
      final parent = stmt.parent;
      if (parent is Block || parent is SwitchMember) {
        builder.addSimpleInsertion(stmt.offset, 'final value = ');
      } else {
        builder
          ..addSimpleInsertion(stmt.offset, '{ final value = ')
          ..addSimpleInsertion(stmt.end, ' }');
      }
    });
  }
}
