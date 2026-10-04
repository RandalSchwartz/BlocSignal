// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/require_cubit_signal_mixin_init_fix.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that requires classes mixing in `CubitSignalMixin` or
/// `BlocSignalMixin` to call `initCubitSignal(initialState: ...)` in their
/// constructor bodies.
class RequireCubitSignalMixinInit extends DartLintRule {
  /// Creates a [RequireCubitSignalMixinInit] lint rule.
  const RequireCubitSignalMixinInit() : super(code: _code);

  static const _code = LintCode(
    name: 'require_cubit_signal_mixin_init',
    problemMessage: 'Classes mixing in "{0}" must invoke "{1}" in their '
        'constructor body before accessing state.',
    correctionMessage: 'Add "{1}(initialState: ...);" inside the constructor '
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

  @override
  List<Fix> getFixes() => [RequireCubitSignalMixinInitFix()];

  /// Analyzes a [ClassDeclaration] and returns any constructor or class
  /// initialization violations.
  static List<
      ({
        Token token,
        String mixinName,
        String expectedMethod,
      })> findViolations(ClassDeclaration node) {
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

    final constructors =
        node.members.whereType<ConstructorDeclaration>().toList();
    if (constructors.isEmpty) {
      return [
        (
          token: node.name,
          mixinName: mixinName,
          expectedMethod: expectedMethod,
        ),
      ];
    }

    final violations = <({
      Token token,
      String mixinName,
      String expectedMethod,
    })>[];

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
        violations.add(
          (
            token: ctor.name ?? ctor.returnType.beginToken,
            mixinName: mixinName,
            expectedMethod: expectedMethod,
          ),
        );
      }
    }

    return violations;
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final violations = findViolations(node);
      for (final v in violations) {
        reporter.atToken(
          v.token,
          code,
          arguments: [v.mixinName, v.expectedMethod],
        );
      }
    });
  }
}

class _InitInvocationVisitor extends RecursiveAstVisitor<void> {
  _InitInvocationVisitor(this.expectedMethod, this.onInitCallFound);

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
