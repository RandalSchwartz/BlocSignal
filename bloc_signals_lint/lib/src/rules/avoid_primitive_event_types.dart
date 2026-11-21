import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags `BlocSignal` and `BlocSignalMixin` declarations
/// that use primitive or untyped types (`int`, `String`, `bool`, `double`,
/// `num`, `dynamic`, `Object`, etc.) for their `Event` generic type parameter.
class AvoidPrimitiveEventTypes extends AnalysisRule {
  /// Creates an [AvoidPrimitiveEventTypes] lint rule.
  new()
    : super(
        name: 'avoid_primitive_event_types',
        description:
            'Flag BlocSignal and BlocSignalMixin declarations that use '
            'primitive or untyped Event generic type parameters.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_primitive_event_types',
    'Avoid using primitive or untyped types ("{0}") for BlocSignal '
        'events. Events should be dedicated sealed classes or records.',
    correctionMessage:
        'Define a dedicated event class or record (for example, '
        '"sealed class MyEvent {}") to model state transitions cleanly.',
  );

  static const _primitiveTypeNames = <String>{
    'int',
    'String',
    'bool',
    'double',
    'num',
    'dynamic',
    'Object',
    'void',
    'Null',
  };

  /// Returns whether [typeName] represents a primitive or untyped Dart type.
  static bool isPrimitiveType(String typeName) {
    final clean = typeName.replaceAll('?', '').trim();
    return _primitiveTypeNames.contains(clean);
  }

  /// Finds all AST nodes violating this rule within a class declaration.
  static List<AstNode> findViolations(ClassDeclaration node) {
    final violations = <AstNode>[];

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      _checkNamedType(extendsClause.superclass, violations);
    }

    final withClause = node.withClause;
    if (withClause != null) {
      for (final mixinType in withClause.mixinTypes) {
        _checkNamedType(mixinType, violations);
      }
    }

    return violations;
  }

  /// Finds all AST nodes violating this rule within a mixin declaration's
  /// `on` constraints.
  static List<AstNode> findMixinViolations(MixinDeclaration node) {
    final violations = <AstNode>[];
    final onClause = node.onClause;
    if (onClause != null) {
      for (final constraint in onClause.superclassConstraints) {
        _checkNamedType(constraint, violations);
      }
    }
    return violations;
  }

  static void _checkNamedType(NamedType namedType, List<AstNode> violations) {
    final typeName = namedType.toSource().split('<').first.trim();
    final staticType = namedType.type;
    final isBlocType =
        _isBlocClassName(typeName) ||
        (staticType != null &&
            (BlocContainerUtils.blocSignalChecker.isAssignableFromType(
                  staticType,
                ) ||
                BlocContainerUtils.blocSignalMixinChecker.isAssignableFromType(
                  staticType,
                )));

    if (!isBlocType) return;

    final typeArgs = namedType.typeArguments?.arguments;
    if (typeArgs == null || typeArgs.isEmpty) {
      if (_isBlocClassName(typeName)) {
        violations.add(namedType);
      }
    } else {
      final eventTypeNode = typeArgs.first;
      if (isPrimitiveType(eventTypeNode.toSource())) {
        violations.add(eventTypeNode);
      }
    }
  }

  static bool _isBlocClassName(String name) {
    return name == 'BlocSignal' ||
        name == 'ReplayBloc' ||
        name == 'HydratedBloc' ||
        name == 'HydratedBlocSignal' ||
        name == 'BlocSignalMixin' ||
        name == 'ReplayBlocMixin';
  }

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addClassDeclaration(this, visitor)
      ..addMixinDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidPrimitiveEventTypes rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (final violation in AvoidPrimitiveEventTypes.findViolations(node)) {
      rule.reportAtNode(violation, arguments: [violation.toSource()]);
    }
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    for (final violation in AvoidPrimitiveEventTypes.findMixinViolations(
      node,
    )) {
      rule.reportAtNode(violation, arguments: [violation.toSource()]);
    }
  }
}
