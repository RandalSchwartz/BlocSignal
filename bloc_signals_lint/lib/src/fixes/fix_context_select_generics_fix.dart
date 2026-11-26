import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidInvalidContextSelectGenerics` that
/// reduces 3+ generic type arguments (`<B, S, R>`) to `<B, R>`.
class FixContextSelectGenericsFix extends ResolvedCorrectionProducer {
  /// Creates a [FixContextSelectGenericsFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.fixContextSelectGenerics',
    DartFixKindPriority.standard,
    'Reduce type arguments to <B, R>',
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    final typeArguments = invocation?.typeArguments;
    if (typeArguments == null || typeArguments.arguments.length <= 2) return;

    final first = typeArguments.arguments.first.toSource();
    final last = typeArguments.arguments.last.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        typeArguments.sourceRange,
        '<$first, $last>',
      );
    });
  }
}
