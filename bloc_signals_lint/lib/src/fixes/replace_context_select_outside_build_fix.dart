import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidContextSelectOutsideBuild` that
/// rewrites `context.select<B, R>(...)` to `context.read<B>()` and
/// `context.value<B, S>()` to `context.read<B>().value`.
class ReplaceContextSelectOutsideBuildFix extends ResolvedCorrectionProducer {
  /// Creates a [ReplaceContextSelectOutsideBuildFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.replaceContextSelectOutsideBuild',
    DartFixKindPriority.standard,
    "Replace with 'context.read<B>()'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;

    final methodName = invocation.methodName.name;
    if (methodName != 'select' && methodName != 'value') return;

    final targetSource = invocation.target?.toSource() ?? 'context';
    final op = invocation.operator?.lexeme ?? '.';
    final typeArgs = invocation.typeArguments?.arguments;
    final blocType = (typeArgs != null && typeArgs.isNotEmpty)
        ? typeArgs.first.toSource()
        : null;

    final replacement = switch ((methodName, blocType)) {
      ('value', final String b) => '$targetSource${op}read<$b>().value',
      (_, final String b) => '$targetSource${op}read<$b>()',
      ('value', null) => '$targetSource${op}read().value',
      (_, null) => '$targetSource${op}read()',
    };

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(invocation.sourceRange, replacement);
    });
  }
}
