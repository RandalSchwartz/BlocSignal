import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags calling `context.watch<T>()` where `T` is a
/// `BlocSignalBase` container inside Flutter widget `build()` methods.
class AvoidContextWatchForBlocState extends AnalysisRule {
  /// Creates an [AvoidContextWatchForBlocState] lint rule.
  new()
    : super(
        name: 'avoid_context_watch_for_bloc_state',
        description:
            'Avoid calling context.watch<T>() on BlocSignalBase containers '
            'inside build() methods.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_context_watch_for_bloc_state',
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

  final AvoidContextWatchForBlocState rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'watch') return;

    final target = node.target;
    if (target == null) return;
    final targetSource = target.toSource();
    final targetType = target.staticType;
    final isContext =
        targetSource == 'context' ||
        targetSource.endsWith('context') ||
        (targetType != null &&
            targetType.getDisplayString().contains('BuildContext'));
    if (!isContext) return;

    final typeArgs = node.typeArguments?.arguments;
    if (typeArgs == null || typeArgs.isEmpty) return;

    final typeArg = typeArgs.first;
    final typeName = typeArg.toSource();

    final staticType = typeArg.type;
    final isBloc =
        (staticType != null &&
            AvoidContextWatchForBlocState._blocSignalBaseChecker
                .isAssignableFromType(staticType)) ||
        typeName.endsWith('Bloc') ||
        typeName.endsWith('Cubit') ||
        typeName.endsWith('BlocSignal') ||
        typeName.endsWith('CubitSignal');

    if (!isBloc) return;

    final enclosingClosure = node.thisOrAncestorOfType<FunctionExpression>();
    if (enclosingClosure != null) return;

    final enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
    if (enclosingMethod != null && enclosingMethod.name.lexeme == 'build') {
      rule.reportAtNode(node.methodName, arguments: [typeName]);
    }
  }
}
