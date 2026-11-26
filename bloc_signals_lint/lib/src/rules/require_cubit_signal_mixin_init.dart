import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that requires classes mixing in `CubitSignalMixin` or
/// `BlocSignalMixin` to call `initCubitSignal(initialState: ...)` in their
/// constructor bodies.
class RequireCubitSignalMixinInit extends AnalysisRule {
  /// Creates a [RequireCubitSignalMixinInit] lint rule.
  new()
    : super(
        name: 'require_cubit_signal_mixin_init',
        description:
            'Require classes mixing in CubitSignalMixin or BlocSignalMixin '
            'to invoke initCubitSignal(initialState: ...) in constructors.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'require_cubit_signal_mixin_init',
    'Classes mixing in "{0}" must invoke "{1}" in their '
        'constructor body before accessing state.',
    correctionMessage:
        'Add "{1}(initialState: ...);" inside the constructor '
        'body.',
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
  /// initialization violations.
  static List<({Token token, String mixinName, String expectedMethod})>
  findViolations(ClassDeclaration node) {
    final withClause = node.withClause;
    if (withClause == null) return const [];

    var mixinName = '';
    for (final type in withClause.mixinTypes) {
      final typeSource = type.toSource();
      if (typeSource.contains('BlocSignalMixin')) {
        mixinName = 'BlocSignalMixin';
        break;
      }
      if (typeSource.contains('CubitSignalMixin')) {
        mixinName = 'CubitSignalMixin';
        break;
      }
      final staticType = type.type;
      if (staticType != null) {
        if (_blocMixinChecker.isAssignableFromType(staticType)) {
          mixinName = 'BlocSignalMixin';
          break;
        }
        if (_cubitMixinChecker.isAssignableFromType(staticType)) {
          mixinName = 'CubitSignalMixin';
          break;
        }
      }
    }

    if (mixinName.isEmpty) return const [];

    const expectedMethod = 'initCubitSignal';

    final body = node.body;
    final namePart = node.namePart;
    final hasPrimaryConstructor = namePart is PrimaryConstructorDeclaration;

    if (body is! BlockClassBody) {
      return [
        (
          token: hasPrimaryConstructor
              ? (namePart.constructorName?.name ?? namePart.typeName)
              : namePart.typeName,
          mixinName: mixinName,
          expectedMethod: expectedMethod,
        ),
      ];
    }

    final violations =
        <({Token token, String mixinName, String expectedMethod})>[];

    if (hasPrimaryConstructor) {
      final primaryBodies = body.members
          .whereType<PrimaryConstructorBody>()
          .toList();
      if (primaryBodies.isEmpty) {
        violations.add((
          token: namePart.constructorName?.name ?? namePart.typeName,
          mixinName: mixinName,
          expectedMethod: expectedMethod,
        ));
      } else {
        for (final primaryBody in primaryBodies) {
          var callsInit = false;
          primaryBody.body.visitChildren(
            _InitInvocationVisitor(expectedMethod, () {
              callsInit = true;
            }),
          );
          if (!callsInit) {
            violations.add((
              token: primaryBody.thisKeyword,
              mixinName: mixinName,
              expectedMethod: expectedMethod,
            ));
          }
        }
      }
    }

    final constructors = body.members
        .whereType<ConstructorDeclaration>()
        .toList();
    if (!hasPrimaryConstructor && constructors.isEmpty) {
      return [
        (
          token: namePart.typeName,
          mixinName: mixinName,
          expectedMethod: expectedMethod,
        ),
      ];
    }

    for (final ctor in constructors) {
      // Factory constructors cannot access `this` or invoke instance methods.
      if (ctor.factoryKeyword != null) {
        continue;
      }

      // Redirecting generative constructors (`Foo.redirect() : this();`)
      // cannot have bodies and delegate initialization to the target
      // constructor.
      if (ctor.initializers.any((i) => i is RedirectingConstructorInvocation)) {
        continue;
      }

      var callsInit = false;
      ctor.body.visitChildren(
        _InitInvocationVisitor(expectedMethod, () {
          callsInit = true;
        }),
      );

      if (!callsInit) {
        violations.add((
          token: ctor.name ?? ctor.typeName2 ?? ctor.beginToken,
          mixinName: mixinName,
          expectedMethod: expectedMethod,
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

  final RequireCubitSignalMixinInit rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final violations = RequireCubitSignalMixinInit.findViolations(node);
    for (final v in violations) {
      rule.reportAtToken(v.token, arguments: [v.mixinName, v.expectedMethod]);
    }
  }
}

class _InitInvocationVisitor extends RecursiveAstVisitor<void> {
  new(this.expectedMethod, this.onInitCallFound);

  final String expectedMethod;
  final void Function() onInitCallFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == expectedMethod) {
      onInitCallFound();
    }
    super.visitMethodInvocation(node);
  }
}
