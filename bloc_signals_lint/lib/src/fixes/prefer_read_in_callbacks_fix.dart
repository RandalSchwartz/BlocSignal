import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for
/// `PreferBlocSignalProviderReadInCallbacks` that rewrites
/// `context.watch<T>()` to `context.read<T>()`.
///
/// Example:
/// ```dart
/// // Before:
/// onPressed: () => context.watch<CounterBloc>().add(Increment())
///
/// // After:
/// onPressed: () => context.read<CounterBloc>().add(Increment())
/// ```
class PreferReadInCallbacksFix extends ResolvedCorrectionProducer {
  /// Creates a [PreferReadInCallbacksFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.preferReadInCallbacks',
    DartFixKindPriority.standard,
    "Replace 'watch' with 'read'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null || invocation.methodName.name != 'watch') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(invocation.methodName.sourceRange, 'read');
    });
  }
}
