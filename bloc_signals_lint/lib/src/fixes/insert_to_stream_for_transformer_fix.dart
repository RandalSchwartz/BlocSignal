import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidStreamTransformersOnBlocSignal` that
/// inserts `.toStream()` before the stream transformer method call.
class InsertToStreamForTransformerFix extends ResolvedCorrectionProducer {
  /// Creates an [InsertToStreamForTransformerFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.insertToStreamForTransformer',
    DartFixKindPriority.standard,
    "Insert '.toStream()'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    final target = invocation?.target;
    if (invocation == null || target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      final op = invocation.operator;
      if (op?.type == TokenType.QUESTION_PERIOD) {
        builder.addSimpleInsertion(op!.end, 'toStream().');
      } else {
        builder.addSimpleInsertion(target.end, '.toStream()');
      }
    });
  }
}
