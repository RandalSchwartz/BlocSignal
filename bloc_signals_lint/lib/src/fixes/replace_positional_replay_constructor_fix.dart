import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `PreferNamedReplayConstructor` that rewrites
/// `super.positional(...)` to `super(initialState: ...)`.
///
/// Example:
/// ```dart
/// // Before:
/// CounterCubit(int initial, {int? limit})
///     : super.positional(initial, limit: limit);
///
/// // After:
/// CounterCubit(int initial, {int? limit})
///     : super(initialState: initial, limit: limit);
/// ```
class ReplacePositionalReplayConstructorFix extends ResolvedCorrectionProducer {
  /// Creates a [ReplacePositionalReplayConstructorFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.replacePositionalReplayConstructor',
    DartFixKindPriority.standard,
    "Replace 'super.positional(...)' with 'super(initialState: ...)'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final superCall = node.thisOrAncestorOfType<SuperConstructorInvocation>();
    if (superCall == null || superCall.constructorName?.name != 'positional') {
      return;
    }

    final period = superCall.period;
    final constructorName = superCall.constructorName;
    if (period == null || constructorName == null) return;

    final args = superCall.argumentList.arguments;
    if (args.isEmpty) return;

    final positionalArg = args
        .where((arg) => arg is! NamedArgument)
        .firstOrNull;
    if (positionalArg == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder
        ..addDeletion(
          SourceRange(period.offset, constructorName.end - period.offset),
        )
        ..addSimpleInsertion(positionalArg.offset, 'initialState: ');
    });
  }
}
