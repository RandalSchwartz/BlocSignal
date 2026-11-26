import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that requires concrete subclasses of `HydratedCubitSignal` /
/// `HydratedBlocSignal` or classes mixing in `HydratedMixin` to override
/// `storagePrefix` to prevent key collisions across hydrated containers.
class RequireHydratedStoragePrefix extends AnalysisRule {
  /// Creates a [RequireHydratedStoragePrefix] lint rule.
  new()
    : super(
        name: 'require_hydrated_storage_prefix',
        description:
            'Require concrete HydratedCubitSignal, HydratedBlocSignal, and '
            'HydratedMixin classes to override storagePrefix.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'require_hydrated_storage_prefix',
    'Concrete hydrated container "{0}" must override "storagePrefix" to '
        'prevent persistence key collisions.',
    correctionMessage:
        "Add '@override String get storagePrefix => ...;' to this class.",
  );

  static const _hydratedMixinChecker = TypeChecker.fromName(
    'HydratedMixin',
    packageName: 'bloc_signals_hydrate',
  );

  static const _hydratedBaseNames = <String>{
    'HydratedMixin',
    'HydratedCubitSignal',
    'HydratedBlocSignal',
  };

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

  final RequireHydratedStoragePrefix rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.abstractKeyword != null ||
        node.sealedKeyword != null ||
        (node.declaredFragment?.element.isAbstract ?? false)) {
      return;
    }
    if (!_isHydratedContainer(node)) return;
    if (_hasStoragePrefixOverride(node)) return;

    final typeName = node.namePart.typeName;
    rule.reportAtToken(typeName, arguments: [typeName.lexeme]);
  }

  static bool _isHydratedContainer(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element != null &&
        RequireHydratedStoragePrefix._hydratedMixinChecker.isSuperOf(element)) {
      return true;
    }

    final superclass = node.extendsClause?.superclass;
    if (superclass != null && _matchesHydratedType(superclass)) {
      return true;
    }

    final withClause = node.withClause;
    if (withClause != null) {
      for (final mixinType in withClause.mixinTypes) {
        if (_matchesHydratedType(mixinType)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _matchesHydratedType(NamedType namedType) {
    final type = namedType.type;
    if (type != null && type is! InvalidType && type is! DynamicType) {
      return RequireHydratedStoragePrefix._hydratedMixinChecker
          .isAssignableFromType(type);
    }
    return RequireHydratedStoragePrefix._hydratedBaseNames.contains(
      namedType.name.lexeme,
    );
  }

  static bool _hasStoragePrefixOverride(ClassDeclaration node) {
    final body = node.body;
    if (body is BlockClassBody) {
      for (final member in body.members) {
        if (member is MethodDeclaration &&
            member.isGetter &&
            member.name.lexeme == 'storagePrefix') {
          return true;
        }
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            if (variable.name.lexeme == 'storagePrefix') {
              return true;
            }
          }
        }
      }
    }

    final element = node.declaredFragment?.element;
    if (element != null) {
      final getter = element.lookUpGetter(
        name: 'storagePrefix',
        library: element.library,
      );
      if (getter != null) {
        final ownerName = getter.enclosingElement.name;
        if (ownerName != null &&
            !RequireHydratedStoragePrefix._hydratedBaseNames.contains(
              ownerName,
            )) {
          return true;
        }
      }
    }

    return false;
  }
}
