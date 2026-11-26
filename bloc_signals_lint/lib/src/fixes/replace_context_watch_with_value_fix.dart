import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// An alternative automated IDE quick-fix for `AvoidContextWatchForBlocState`
/// that rewrites `context.watch<B>()` to `context.value<B, S>()` when `S` can
/// be resolved from `B`'s `BlocSignalBase<S>` supertype.
class ReplaceContextWatchWithValueFix extends ResolvedCorrectionProducer {
  /// Creates a [ReplaceContextWatchWithValueFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.replaceContextWatchWithValue',
    DartFixKindPriority.standard - 1,
    "Replace 'watch<B>()' with 'value<B, S>()'",
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

    final typeArgs = invocation.typeArguments?.arguments;
    if (typeArgs == null || typeArgs.isEmpty) return;

    final blocTypeArg = typeArgs.first;
    final blocType = blocTypeArg.type;
    final stateTypeName = _resolveStateTypeName(blocType);
    if (stateTypeName == null) return;

    final blocTypeName = blocTypeArg.toSource();
    final start = invocation.methodName.offset;
    final end = invocation.typeArguments?.end ?? invocation.methodName.end;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(start, end - start),
        'value<$blocTypeName, $stateTypeName>',
      );
    });
  }

  static String? _resolveStateTypeName(DartType? blocType) {
    if (blocType is! InterfaceType) return null;

    if (BlocContainerUtils.blocSignalBaseChecker.isExactlyType(blocType) &&
        blocType.typeArguments.isNotEmpty) {
      return blocType.typeArguments.first.getDisplayString();
    }

    for (final supertype in blocType.allSupertypes) {
      if (BlocContainerUtils.blocSignalBaseChecker.isExactlyType(supertype) &&
          supertype.typeArguments.isNotEmpty) {
        return supertype.typeArguments.first.getDisplayString();
      }
    }
    return null;
  }
}
