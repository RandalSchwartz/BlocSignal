import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags bridging calls (`.toBlocSignal()`,
/// `.toAsyncBlocSignal()`, `.toValueListenable()`, `.toClassicBloc()`,
/// `.toClassicCubit()`, `.toStream()`, and official adapter constructors such
/// as `ListenableBlocSignal`, `StreamBlocSignal`, `FutureBlocSignal`,
/// `SignalBlocSignal`, `ClassicBlocSignal`, `ClassicCubitSignal`,
/// `BlocSignalToClassicBloc`, `BlocSignalToClassicCubit`, `RiverpodBlocSignal`,
/// and `RiverpodNotifierBlocSignal`) directly inside UI `build()` methods.
class AvoidBridgingInBuild extends AnalysisRule {
  /// Creates an [AvoidBridgingInBuild] lint rule.
  new()
    : super(
        name: 'avoid_bridging_in_build',
        description:
            'Avoid calling bridging adapters (.toBlocSignal(), '
            '.toAsyncBlocSignal(), .toValueListenable(), .toClassicBloc(), '
            '.toClassicCubit(), .toStream(), or adapter constructors) '
            'directly inside build() methods.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_bridging_in_build',
    'Avoid calling "{0}" directly inside build() methods.',
    correctionMessage:
        'Create and store the bridged signal or listenable in initState(), '
        'a BlocSignalProvider.create callback, or a state container instead.',
  );

  static const _adapterCheckers = <TypeChecker>[
    TypeChecker.fromName(
      'ListenableBlocSignal',
      packageName: 'bloc_signals_flutter',
    ),
    TypeChecker.fromName('StreamBlocSignal', packageName: 'bloc_signals'),
    TypeChecker.fromName('FutureBlocSignal', packageName: 'bloc_signals'),
    TypeChecker.fromName('SignalBlocSignal', packageName: 'bloc_signals'),
    TypeChecker.fromName('ClassicBlocSignal', packageName: 'bloc_signals_bloc'),
    TypeChecker.fromName(
      'ClassicCubitSignal',
      packageName: 'bloc_signals_bloc',
    ),
    TypeChecker.fromName(
      'BlocSignalToClassicBloc',
      packageName: 'bloc_signals_bloc',
    ),
    TypeChecker.fromName(
      'BlocSignalToClassicCubit',
      packageName: 'bloc_signals_bloc',
    ),
    TypeChecker.fromName(
      'RiverpodBlocSignal',
      packageName: 'bloc_signals_riverpod',
    ),
    TypeChecker.fromName(
      'RiverpodNotifierBlocSignal',
      packageName: 'bloc_signals_riverpod',
    ),
  ];

  static const _bridgingMethods = <String>{
    'toBlocSignal',
    'toAsyncBlocSignal',
    'toValueListenable',
    'toClassicBloc',
    'toClassicCubit',
    'toStream',
  };

  static const _officialPackages = <String>{
    'bloc_signals',
    'bloc_signals_flutter',
    'bloc_signals_bloc',
    'bloc_signals_riverpod',
  };

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addMethodInvocation(this, visitor)
      ..addInstanceCreationExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidBridgingInBuild rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (!AvoidBridgingInBuild._bridgingMethods.contains(methodName)) return;

    final libraryUri = node.methodName.element?.library?.uri;
    if (libraryUri == null ||
        !libraryUri.isScheme('package') ||
        !AvoidBridgingInBuild._officialPackages.contains(
          libraryUri.pathSegments.firstOrNull,
        )) {
      return;
    }

    if (BlocContainerUtils.isDirectInUiBuild(node)) {
      rule.reportAtNode(node.methodName, arguments: [methodName]);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorType = node.constructorName.type.type;
    if (constructorType == null ||
        !AvoidBridgingInBuild._adapterCheckers.any(
          (checker) => checker.isAssignableFromType(constructorType),
        )) {
      return;
    }

    if (BlocContainerUtils.isDirectInUiBuild(node)) {
      rule.reportAtNode(
        node.constructorName,
        arguments: [node.constructorName.toSource()],
      );
    }
  }
}
