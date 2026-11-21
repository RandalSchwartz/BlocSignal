import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `AvoidRawSignalEffectsInBloc` that rewrites
/// unmanaged `effect(...)` calls to `createEffect(...)`.
///
/// Example:
/// ```dart
/// // Before:
/// effect(() { print(stateValue); });
///
/// // After:
/// createEffect(() { print(stateValue); });
/// ```
class AvoidRawSignalEffectsInBlocFix extends ResolvedCorrectionProducer {
  /// Creates an [AvoidRawSignalEffectsInBlocFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.avoidRawSignalEffectsInBloc',
    DartFixKindPriority.standard,
    "Replace 'effect' with 'createEffect'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null || invocation.methodName.name != 'effect') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        invocation.methodName.sourceRange,
        'createEffect',
      );
    });
  }
}
