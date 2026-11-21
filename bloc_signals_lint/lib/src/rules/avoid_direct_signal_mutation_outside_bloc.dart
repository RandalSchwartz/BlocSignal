import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that prevents external code from invoking protected state
/// emissions (`emit()`) outside the owning state container class.
class AvoidDirectSignalMutationOutsideBloc extends AnalysisRule {
  /// Creates an [AvoidDirectSignalMutationOutsideBloc] lint rule.
  new()
    : super(
        name: 'avoid_direct_signal_mutation_outside_bloc',
        description:
            'Prevent external code from invoking emit() outside the owning '
            'state container class.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_direct_signal_mutation_outside_bloc',
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
          extendsSource.contains('ReplayCubit') ||
          extendsSource.contains('ReplayBloc') ||
          extendsSource.contains('HydratedCubit') ||
          extendsSource.contains('HydratedBloc') ||
          withSource.contains('BlocSignalMixin') ||
          withSource.contains('CubitSignalMixin') ||
          withSource.contains('ReplayMixin') ||
          withSource.contains('ReplayCubitMixin') ||
          withSource.contains('ReplayBlocMixin') ||
          withSource.contains('HydratedMixin') ||
          implementsSource.contains('BlocSignalBase')) {
        return true;
      }
      return false;
    }

    if (enclosingMixin != null) {
      final onClause = enclosingMixin.onClause;
      if (onClause != null) {
        for (final constraint in onClause.superclassConstraints) {
          final type = constraint.type;
          if (type != null &&
              _blocSignalBaseChecker.isAssignableFromType(type)) {
            return true;
          }
          final source = constraint.toSource();
          if (source.contains('BlocSignal') ||
              source.contains('CubitSignal') ||
              source.contains('ReplayCubit') ||
              source.contains('ReplayBloc') ||
              source.contains('ReplayMixin') ||
              source.contains('HydratedCubit') ||
              source.contains('HydratedBloc') ||
              source.contains('HydratedMixin')) {
            return true;
          }
        }
      }
      return false;
    }

    return false;
  }

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidDirectSignalMutationOutsideBloc rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'emit') return;

    final target = node.target;
    if (target == null) return;

    final targetType = target.staticType;
    if (targetType == null) return;

    if (AvoidDirectSignalMutationOutsideBloc._blocSignalBaseChecker
        .isAssignableFromType(targetType)) {
      final enclosingDeclaration = node.thisOrAncestorMatching(
        (n) => n is ClassDeclaration || n is MixinDeclaration,
      );
      final enclosingClass = enclosingDeclaration is ClassDeclaration
          ? enclosingDeclaration
          : null;
      final enclosingMixin = enclosingDeclaration is MixinDeclaration
          ? enclosingDeclaration
          : null;

      if (AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
        enclosingClass: enclosingClass,
        enclosingMixin: enclosingMixin,
      )) {
        return;
      }

      rule.reportAtNode(
        node.methodName,
        arguments: [targetType.getDisplayString()],
      );
    }
  }
}
