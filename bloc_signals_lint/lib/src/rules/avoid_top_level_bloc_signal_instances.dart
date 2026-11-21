import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags top-level variable and static field declarations
/// initialized directly with `BlocSignalBase` instances.
class AvoidTopLevelBlocSignalInstances extends AnalysisRule {
  /// Creates an [AvoidTopLevelBlocSignalInstances] lint rule.
  new()
    : super(
        name: 'avoid_top_level_bloc_signal_instances',
        description:
            'Prevent declaring BlocSignalBase instances as top-level or '
            'static variables.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_top_level_bloc_signal_instances',
    'Stateful container "{0}" should not be declared as a top-level or '
        'static variable.',
    correctionMessage:
        'Scope containers using BlocSignalProvider, dependency injection, or '
        'factory getters. Primitive signals (for example signal(0)) can remain '
        'global.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addTopLevelVariableDeclaration(this, visitor)
      ..addFieldDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidTopLevelBlocSignalInstances rule;

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      final initializer = variable.initializer;
      if (initializer == null) continue;

      if (_isBlocOrCubit(variable, initializer)) {
        rule.reportAtNode(variable, arguments: [variable.name.lexeme]);
      }
    }
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!node.isStatic) return;

    for (final variable in node.fields.variables) {
      final initializer = variable.initializer;
      if (initializer == null) continue;

      if (_isBlocOrCubit(variable, initializer)) {
        rule.reportAtNode(variable, arguments: [variable.name.lexeme]);
      }
    }
  }

  bool _isBlocOrCubit(VariableDeclaration variable, Expression initializer) {
    final type =
        variable.declaredFragment?.element.type ?? initializer.staticType;
    if (type != null &&
        AvoidTopLevelBlocSignalInstances._blocSignalBaseChecker
            .isAssignableFromType(type)) {
      return true;
    }

    if (initializer is InstanceCreationExpression) {
      final className = initializer.constructorName.type
          .toSource()
          .split('<')
          .first;
      if (className.endsWith('Bloc') ||
          className.endsWith('Cubit') ||
          className.contains('BlocSignal')) {
        return true;
      }
    }

    return false;
  }
}
