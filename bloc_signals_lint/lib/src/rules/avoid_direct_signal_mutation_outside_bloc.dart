// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that prevents external code from invoking protected state
/// emissions (`emit()`) outside the owning state container class.
class AvoidDirectSignalMutationOutsideBloc extends DartLintRule {
  /// Creates an [AvoidDirectSignalMutationOutsideBloc] lint rule.
  const AvoidDirectSignalMutationOutsideBloc() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_direct_signal_mutation_outside_bloc',
    problemMessage:
        "Protected state emission 'emit()' should not be invoked directly "
        "outside class '{0}'.",
    correctionMessage:
        "Dispatch an event via '.add()' or invoke a public method on the "
        'state container instead.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  /// Returns `true` if the emission call is executed inside a valid state
  /// container class or mixin on a state container.
  static bool isAllowedEmission({
    ClassDeclaration? enclosingClass,
    MixinDeclaration? enclosingMixin,
  }) {
    if (enclosingClass != null) {
      final element = enclosingClass.declaredFragment?.element;
      if (element != null && _blocSignalBaseChecker.isSuperOf(element)) {
        return true;
      }
      final extendsSource =
          enclosingClass.extendsClause?.superclass.toSource() ?? '';
      final withSource = enclosingClass.withClause?.toSource() ?? '';
      final implementsSource =
          enclosingClass.implementsClause?.toSource() ?? '';
      if (extendsSource.contains('BlocSignal') ||
          extendsSource.contains('CubitSignal') ||
          withSource.contains('BlocSignalMixin') ||
          withSource.contains('CubitSignalMixin') ||
          implementsSource.contains('BlocSignalBase')) {
        return true;
      }
      return false;
    }

    if (enclosingMixin != null) {
      final element = enclosingMixin.declaredFragment?.element;
      if (element != null && _blocSignalBaseChecker.isSuperOf(element)) {
        return true;
      }
      final onClause = enclosingMixin.onClause;
      if (onClause != null) {
        for (final constraint in onClause.superclassConstraints) {
          final type = constraint.type;
          if (type != null &&
              _blocSignalBaseChecker.isAssignableFromType(type)) {
            return true;
          }
          final source = constraint.toSource();
          if (source.contains('BlocSignal') || source.contains('CubitSignal')) {
            return true;
          }
        }
      }
      return false;
    }

    return false;
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'emit') return;

      final target = node.target;
      if (target == null) return;

      final targetType = target.staticType;
      if (targetType == null) return;

      if (_blocSignalBaseChecker.isAssignableFromType(targetType)) {
        final enclosingDeclaration = node.thisOrAncestorMatching(
          (n) => n is ClassDeclaration || n is MixinDeclaration,
        );
        final enclosingClass = enclosingDeclaration is ClassDeclaration
            ? enclosingDeclaration
            : null;
        final enclosingMixin = enclosingDeclaration is MixinDeclaration
            ? enclosingDeclaration
            : null;

        if (isAllowedEmission(
          enclosingClass: enclosingClass,
          enclosingMixin: enclosingMixin,
        )) {
          return;
        }

        reporter.atNode(
          node.methodName,
          code,
          arguments: [targetType.getDisplayString()],
        );
      }
    });
  }
}
