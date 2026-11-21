import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `RequireSuperOnEvent` that inserts
/// `super.onEvent(event);` into `onEvent` overrides.
///
/// Respects the declared parameter name and converts arrow (`=>`) or empty
/// (`;`) function bodies into block bodies.
///
/// Example:
/// ```dart
/// // Before:
/// @override
/// void onEvent(MyEvent event) {
///   doSomething();
/// }
///
/// // After:
/// @override
/// void onEvent(MyEvent event) {
///   super.onEvent(event);
///   doSomething();
/// }
/// ```
class AddSuperOnEventFix extends ResolvedCorrectionProducer {
  /// Creates an [AddSuperOnEventFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.addSuperOnEvent',
    DartFixKindPriority.standard,
    "Add 'super.onEvent(...);'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null || method.name.lexeme != 'onEvent') return;

    final paramName =
        method.parameters?.parameters.firstOrNull?.name?.lexeme ?? 'event';
    final body = method.body;

    await builder.addDartFileEdit(file, (builder) {
      if (body is BlockFunctionBody) {
        builder.addSimpleInsertion(
          body.block.leftBracket.end,
          '\n    super.onEvent($paramName);',
        );
      } else if (body is ExpressionFunctionBody) {
        final keyword = body.keyword != null
            ? '${body.keyword!.lexeme}${body.star?.lexeme ?? ''} '
            : '';
        final expr = body.expression.toSource();
        builder.addSimpleReplacement(
          body.sourceRange,
          '$keyword{\n    super.onEvent($paramName);\n    $expr;\n  }',
        );
      } else if (body is EmptyFunctionBody) {
        builder.addSimpleReplacement(
          body.sourceRange,
          ' {\n    super.onEvent($paramName);\n  }',
        );
      }
    });
  }
}
