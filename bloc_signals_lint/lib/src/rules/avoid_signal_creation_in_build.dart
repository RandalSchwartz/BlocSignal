import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags direct `signal()`, `computed()`, and `effect()`
/// allocations inside UI `build()` methods (outside nested closures).
class AvoidSignalCreationInBuild extends AnalysisRule {
  /// Creates an [AvoidSignalCreationInBuild] lint rule.
  new()
    : super(
        name: 'avoid_signal_creation_in_build',
        description:
            'Avoid creating signal(), computed(), or effect() directly inside '
            'build() methods.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_signal_creation_in_build',
    'Avoid calling "{0}()" directly inside build(), as it recreates the '
        'reactive node on every rebuild.',
    correctionMessage:
        'Move signal/computed/effect creation to a state container, '
        'initState(), or a persistent field.',
  );

  static const _signalFactoryNames = <String>{'signal', 'computed', 'effect'};

  static const _signalPackages = <String>{
    'bloc_signals',
    'signals',
    'signals_core',
    'signals_flutter',
    'preact_signals',
  };

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

  final AvoidSignalCreationInBuild rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (!AvoidSignalCreationInBuild._signalFactoryNames.contains(methodName)) {
      return;
    }
    final target = node.target;
    if (target != null &&
        (target is! SimpleIdentifier || target.element is! PrefixElement)) {
      return;
    }

    final libraryUri = node.methodName.element?.library?.uri;
    if (libraryUri == null ||
        !libraryUri.isScheme('package') ||
        !AvoidSignalCreationInBuild._signalPackages.contains(
          libraryUri.pathSegments.firstOrNull,
        )) {
      return;
    }

    if (BlocContainerUtils.isDirectInUiBuild(node)) {
      rule.reportAtNode(node.methodName, arguments: [methodName]);
    }
  }
}
