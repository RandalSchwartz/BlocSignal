// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
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

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final withClause = node.withClause;
      if (withClause == null) return;

      var mixinName = '';
      for (final type in withClause.mixinTypes) {
        final typeName = type.name.lexeme;
        if (typeName.contains('CubitSignalMixin') ||
            typeName.contains('BlocSignalMixin')) {
          mixinName = typeName;
          break;
        }
        final staticType = type.type;
        if (staticType != null &&
            (_cubitMixinChecker.isAssignableFromType(staticType) ||
                _blocMixinChecker.isAssignableFromType(staticType))) {
          mixinName = typeName;
          break;
        }
      }

      if (mixinName.isEmpty) return;

      final expectedMethod = mixinName.contains('BlocSignalMixin')
          ? 'initBlocSignal'
          : 'initCubitSignal';

      final constructors =
          node.members.whereType<ConstructorDeclaration>().toList();
      if (constructors.isEmpty) {
        // Implicit default constructor with no body - flag class name
        reporter.atToken(
          node.name,
          code,
          arguments: [mixinName, expectedMethod],
        );
        return;
      }

      for (final ctor in constructors) {
        // Factory redirect constructors do not need init in the redirect
        if (ctor.factoryKeyword != null && ctor.redirectedConstructor != null) {
          continue;
        }

        var callsInit = false;
        ctor.body.visitChildren(
          _InitInvocationVisitor(() {
            callsInit = true;
          }),
        );

        if (!callsInit) {
          reporter.atToken(
            ctor.name ?? node.name,
            code,
            arguments: [mixinName, expectedMethod],
          );
        }
      }
    });
  }
}

class _InitInvocationVisitor extends RecursiveAstVisitor<void> {
  _InitInvocationVisitor(this.onInitCallFound);

  final void Function() onInitCallFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'initCubitSignal' || name == 'initBlocSignal') {
      onInitCallFound();
    }
    super.visitMethodInvocation(node);
  }
}
