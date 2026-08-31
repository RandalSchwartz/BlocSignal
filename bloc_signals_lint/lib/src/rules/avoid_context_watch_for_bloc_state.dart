// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_watch_with_read_fix.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags calling `context.watch<T>()` where `T` is a
/// `BlocSignalBase` container inside Flutter widget `build()` methods.
class AvoidContextWatchForBlocState extends DartLintRule {
  /// Creates an [AvoidContextWatchForBlocState] lint rule.
  const AvoidContextWatchForBlocState() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_context_watch_for_bloc_state',
    problemMessage:
        'Calling "context.watch<{0}>()" inside build() only tracks container '
        'instance swapping and will not rebuild when state emits.',
    correctionMessage:
        'Use "context.read<{0}>()" with "context.select(...)" or '
        '"BlocSignalBuilder" for reactive UI rebuilds.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  @override
  List<Fix> getFixes() => [ReplaceContextWatchWithReadFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'watch') return;

      final target = node.target;
      if (target == null) return;
      final targetSource = target.toSource();
      final targetType = target.staticType;
      final isContext = targetSource == 'context' ||
          targetSource.endsWith('context') ||
          (targetType != null &&
              targetType
                  .getDisplayString(withNullability: false)
                  .contains('BuildContext'));
      if (!isContext) return;

      final typeArgs = node.typeArguments?.arguments;
      if (typeArgs == null || typeArgs.isEmpty) return;

      final typeArg = typeArgs.first;
      final typeName = typeArg.toSource();

      final staticType = typeArg.type;
      final isBloc = (staticType != null &&
              _blocSignalBaseChecker.isAssignableFromType(staticType)) ||
          typeName.endsWith('Bloc') ||
          typeName.endsWith('Cubit') ||
          typeName.endsWith('BlocSignal') ||
          typeName.endsWith('CubitSignal');

      if (!isBloc) return;

      final enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
      if (enclosingMethod != null && enclosingMethod.name.lexeme == 'build') {
        reporter.atNode(
          node.methodName,
          code,
          arguments: [typeName],
        );
      }
    });
  }
}
