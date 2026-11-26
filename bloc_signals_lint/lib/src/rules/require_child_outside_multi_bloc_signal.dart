import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags `BlocSignalProvider`, `BlocSignalProvider.value`,
/// and `BlocSignalListener` invocations that omit `child:` when not placed
/// inside `MultiBlocSignalProvider.providers` or
/// `MultiBlocSignalListener.listeners`.
class RequireChildOutsideMultiBlocSignal extends AnalysisRule {
  /// Creates a [RequireChildOutsideMultiBlocSignal] lint rule.
  new()
    : super(
        name: 'require_child_outside_multi_bloc_signal',
        description:
            'Require child: on BlocSignalProvider and BlocSignalListener '
            'outside MultiBlocSignalProvider and MultiBlocSignalListener.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'require_child_outside_multi_bloc_signal',
    '"{0}" must specify a "child:" argument when used outside '
        'MultiBlocSignalProvider or MultiBlocSignalListener.',
    correctionMessage:
        'Provide a "child:" widget/component or move this into '
        'MultiBlocSignalProvider.providers / MultiBlocSignalListener.listeners.',
  );

  static const _providerCheckers = [
    TypeChecker.fromName(
      'BlocSignalProvider',
      packageName: 'bloc_signals_flutter',
    ),
    TypeChecker.fromName(
      'BlocSignalProvider',
      packageName: 'bloc_signals_jaspr',
    ),
    TypeChecker.fromName('BlocSignalProvider', packageName: 'flutter'),
  ];

  static const _listenerCheckers = [
    TypeChecker.fromName(
      'BlocSignalListener',
      packageName: 'bloc_signals_flutter',
    ),
    TypeChecker.fromName(
      'BlocSignalListener',
      packageName: 'bloc_signals_jaspr',
    ),
    TypeChecker.fromName('BlocSignalListener', packageName: 'flutter'),
  ];

  static const _multiProviderCheckers = [
    TypeChecker.fromName(
      'MultiBlocSignalProvider',
      packageName: 'bloc_signals_flutter',
    ),
    TypeChecker.fromName(
      'MultiBlocSignalProvider',
      packageName: 'bloc_signals_jaspr',
    ),
    TypeChecker.fromName('MultiBlocSignalProvider', packageName: 'flutter'),
  ];

  static const _multiListenerCheckers = [
    TypeChecker.fromName(
      'MultiBlocSignalListener',
      packageName: 'bloc_signals_flutter',
    ),
    TypeChecker.fromName(
      'MultiBlocSignalListener',
      packageName: 'bloc_signals_jaspr',
    ),
    TypeChecker.fromName('MultiBlocSignalListener', packageName: 'flutter'),
  ];

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final RequireChildOutsideMultiBlocSignal rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.type;
    final rawName = node.constructorName.type.name.lexeme;

    final isProvider = _matchesAny(
      type,
      rawName,
      RequireChildOutsideMultiBlocSignal._providerCheckers,
      'BlocSignalProvider',
    );
    final isListener = _matchesAny(
      type,
      rawName,
      RequireChildOutsideMultiBlocSignal._listenerCheckers,
      'BlocSignalListener',
    );
    if (!isProvider && !isListener) return;

    final hasChild = node.argumentList.arguments.any(
      (arg) => arg is NamedArgument && arg.name.lexeme == 'child',
    );
    if (hasChild) return;

    if (_isInsideMultiList(node, isProvider: isProvider)) return;

    rule.reportAtNode(
      node.constructorName,
      arguments: [node.constructorName.toSource()],
    );
  }

  static bool _matchesAny(
    DartType? type,
    String rawName,
    List<TypeChecker> checkers,
    String fallbackName,
  ) {
    if (type != null && type is! DynamicType && type is! InvalidType) {
      for (final checker in checkers) {
        if (checker.isAssignableFromType(type)) return true;
      }
      return false;
    }
    return rawName == fallbackName;
  }

  static bool _isInsideMultiList(
    InstanceCreationExpression node, {
    required bool isProvider,
  }) {
    var sawListLiteral = false;
    var current = node.parent;
    while (current != null) {
      if (current is IfElement ||
          current is ForElement ||
          current is ConditionalExpression ||
          current is ParenthesizedExpression ||
          current is SpreadElement) {
        current = current.parent;
        continue;
      }
      if (current is ListLiteral) {
        sawListLiteral = true;
        current = current.parent;
        continue;
      }
      if (current is NamedArgument) {
        if (!sawListLiteral) return false;
        final expectedParam = isProvider ? 'providers' : 'listeners';
        if (current.name.lexeme != expectedParam) return false;

        final argList = current.parent;
        if (argList is! ArgumentList) return false;
        final multiCreation = argList.parent;
        if (multiCreation is! InstanceCreationExpression) return false;

        final multiType = multiCreation.constructorName.type.type;
        final multiName = multiCreation.constructorName.type.name.lexeme;
        if (isProvider) {
          return _matchesAny(
            multiType,
            multiName,
            RequireChildOutsideMultiBlocSignal._multiProviderCheckers,
            'MultiBlocSignalProvider',
          );
        }
        return _matchesAny(
          multiType,
          multiName,
          RequireChildOutsideMultiBlocSignal._multiListenerCheckers,
          'MultiBlocSignalListener',
        );
      }
      return false;
    }
    return false;
  }
}
