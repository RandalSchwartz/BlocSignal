// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags top-level variable and static field declarations
/// initialized directly with [BlocSignalBase] instances.
class AvoidTopLevelBlocSignalInstances extends DartLintRule {
  /// Creates an [AvoidTopLevelBlocSignalInstances] lint rule.
  const AvoidTopLevelBlocSignalInstances() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_top_level_bloc_signal_instances',
    problemMessage:
        'Stateful container "{0}" should not be declared as a top-level or static variable.',
    correctionMessage:
        'Scope containers using BlocSignalProvider, dependency injection, or factory getters. Primitive signals (e.g. signal(0)) can remain global.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTopLevelVariableDeclaration((node) {
      for (final variable in node.variables.variables) {
        final initializer = variable.initializer;
        if (initializer == null) continue;

        if (_isBlocOrCubit(variable, initializer)) {
          reporter.atNode(
            variable,
            code,
            arguments: [variable.name.lexeme],
          );
        }
      }
    });

    context.registry.addFieldDeclaration((node) {
      if (!node.isStatic) return;

      for (final variable in node.fields.variables) {
        final initializer = variable.initializer;
        if (initializer == null) continue;

        if (_isBlocOrCubit(variable, initializer)) {
          reporter.atNode(
            variable,
            code,
            arguments: [variable.name.lexeme],
          );
        }
      }
    });
  }

  bool _isBlocOrCubit(VariableDeclaration variable, Expression initializer) {
    final type = variable.declaredElement?.type ?? initializer.staticType;
    if (type != null && _blocSignalBaseChecker.isAssignableFromType(type)) {
      return true;
    }

    if (initializer is InstanceCreationExpression) {
      final className = initializer.constructorName.type.name2.lexeme;
      if (className.endsWith('Bloc') ||
          className.endsWith('Cubit') ||
          className.contains('BlocSignal')) {
        return true;
      }
    }

    return false;
  }
}
