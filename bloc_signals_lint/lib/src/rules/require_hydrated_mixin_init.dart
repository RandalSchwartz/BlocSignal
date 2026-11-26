import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that requires classes mixing in `HydratedMixin` alongside
/// `CubitSignalMixin` or `BlocSignalMixin` to call `hydrate()` in their
/// non-factory, non-redirecting constructors.
class RequireHydratedMixinInit extends AnalysisRule {
  /// Creates a [RequireHydratedMixinInit] lint rule.
  new()
    : super(
        name: 'require_hydrated_mixin_init',
        description:
            'Require classes mixing in HydratedMixin alongside '
            'CubitSignalMixin or BlocSignalMixin to invoke hydrate() in '
            'constructors.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'require_hydrated_mixin_init',
    'Classes mixing in "HydratedMixin" with "{0}" must invoke "hydrate()" '
        'in their constructor body.',
    correctionMessage:
        'Add "hydrate();" inside the constructor body after '
        'initCubitSignal(...).',
  );

  static const _hydratedMixinChecker = TypeChecker.fromName(
    'HydratedMixin',
    packageName: 'bloc_signals_hydrate',
  );

  static const _cubitMixinChecker = TypeChecker.fromName(
    'CubitSignalMixin',
    packageName: 'bloc_signals',
  );

  static const _blocMixinChecker = TypeChecker.fromName(
    'BlocSignalMixin',
    packageName: 'bloc_signals',
  );

  /// Analyzes a [ClassDeclaration] and returns any constructor or class
  /// hydration initialization violations.
  static List<({Token token, String signalMixinName})> findViolations(
    ClassDeclaration node,
  ) {
    final withClause = node.withClause;
    if (withClause == null) return const [];

    var hasHydratedMixin = false;
    var signalMixinName = '';

    for (final type in withClause.mixinTypes) {
      final staticType = type.type;
      if (staticType != null &&
          staticType is! InvalidType &&
          staticType is! DynamicType) {
        if (_hydratedMixinChecker.isAssignableFromType(staticType)) {
          hasHydratedMixin = true;
        }
        if (_blocMixinChecker.isAssignableFromType(staticType)) {
          signalMixinName = 'BlocSignalMixin';
        } else if (_cubitMixinChecker.isAssignableFromType(staticType)) {
          if (signalMixinName.isEmpty) {
            signalMixinName = 'CubitSignalMixin';
          }
        }
        continue;
      }

      final typeSource = type.toSource();
      if (typeSource.contains('HydratedMixin')) {
        hasHydratedMixin = true;
      }
      if (typeSource.contains('BlocSignalMixin')) {
        signalMixinName = 'BlocSignalMixin';
      } else if (typeSource.contains('CubitSignalMixin')) {
        if (signalMixinName.isEmpty) {
          signalMixinName = 'CubitSignalMixin';
        }
      }
    }

    if (!hasHydratedMixin || signalMixinName.isEmpty) return const [];

    final body = node.body;
    final namePart = node.namePart;
    final hasPrimaryConstructor = namePart is PrimaryConstructorDeclaration;

    if (body is! BlockClassBody) {
      return [
        (
          token: hasPrimaryConstructor
              ? (namePart.constructorName?.name ?? namePart.typeName)
              : namePart.typeName,
          signalMixinName: signalMixinName,
        ),
      ];
    }

    final violations = <({Token token, String signalMixinName})>[];

    if (hasPrimaryConstructor) {
      final primaryBodies = body.members
          .whereType<PrimaryConstructorBody>()
          .toList();
      if (primaryBodies.isEmpty) {
        violations.add((
          token: namePart.constructorName?.name ?? namePart.typeName,
          signalMixinName: signalMixinName,
        ));
      } else {
        for (final primaryBody in primaryBodies) {
          var callsHydrate = false;
          primaryBody.body.visitChildren(
            _HydrateInvocationVisitor(() {
              callsHydrate = true;
            }),
          );
          if (!callsHydrate) {
            violations.add((
              token: primaryBody.thisKeyword,
              signalMixinName: signalMixinName,
            ));
          }
        }
      }
    }

    final constructors = body.members
        .whereType<ConstructorDeclaration>()
        .toList();
    if (!hasPrimaryConstructor && constructors.isEmpty) {
      return [(token: namePart.typeName, signalMixinName: signalMixinName)];
    }

    for (final ctor in constructors) {
      if (ctor.factoryKeyword != null) {
        continue;
      }
      if (ctor.initializers.any((i) => i is RedirectingConstructorInvocation)) {
        continue;
      }

      var callsHydrate = false;
      ctor.body.visitChildren(
        _HydrateInvocationVisitor(() {
          callsHydrate = true;
        }),
      );
      if (!callsHydrate) {
        violations.add((
          token: ctor.name ?? ctor.typeName2 ?? ctor.beginToken,
          signalMixinName: signalMixinName,
        ));
      }
    }

    return violations;
  }

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final RequireHydratedMixinInit rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final violations = RequireHydratedMixinInit.findViolations(node);
    for (final v in violations) {
      rule.reportAtToken(v.token, arguments: [v.signalMixinName]);
    }
  }
}

class _HydrateInvocationVisitor extends RecursiveAstVisitor<void> {
  new(this.onHydrateFound);

  final void Function() onHydrateFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'hydrate' &&
        BlocContainerUtils.isSelfOrUnqualifiedTarget(node.realTarget)) {
      onHydrateFound();
    }
    super.visitMethodInvocation(node);
  }
}
