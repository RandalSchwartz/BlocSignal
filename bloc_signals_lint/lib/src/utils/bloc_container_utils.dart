import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// Shared `TypeChecker` and AST helpers for identifying `BlocSignal` /
/// `CubitSignal` containers, mixins, UI hosts, and `BuildContext` receivers.
abstract final class BlocContainerUtils {
  /// Matches `BlocSignalBase` from `package:bloc_signals`.
  static const blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  /// Matches `BlocSignal` from `package:bloc_signals`.
  static const blocSignalChecker = TypeChecker.fromName(
    'BlocSignal',
    packageName: 'bloc_signals',
  );

  /// Matches `CubitSignal` from `package:bloc_signals`.
  static const cubitSignalChecker = TypeChecker.fromName(
    'CubitSignal',
    packageName: 'bloc_signals',
  );

  /// Matches `BlocSignalMixin` from `package:bloc_signals`.
  static const blocSignalMixinChecker = TypeChecker.fromName(
    'BlocSignalMixin',
    packageName: 'bloc_signals',
  );

  /// Matches `CubitSignalMixin` from `package:bloc_signals`.
  static const cubitSignalMixinChecker = TypeChecker.fromName(
    'CubitSignalMixin',
    packageName: 'bloc_signals',
  );

  /// Matches Flutter's `BuildContext`.
  static const flutterBuildContextChecker = TypeChecker.fromName(
    'BuildContext',
    packageName: 'flutter',
  );

  /// Matches Jaspr's `BuildContext`.
  static const jasprBuildContextChecker = TypeChecker.fromName(
    'BuildContext',
    packageName: 'jaspr',
  );

  /// Matches Flutter's `Widget`.
  static const flutterWidgetChecker = TypeChecker.fromName(
    'Widget',
    packageName: 'flutter',
  );

  /// Matches Flutter's `State`.
  static const flutterStateChecker = TypeChecker.fromName(
    'State',
    packageName: 'flutter',
  );

  /// Matches `HookWidget` from `package:flutter_hooks`.
  static const hookWidgetChecker = TypeChecker.fromName(
    'HookWidget',
    packageName: 'flutter_hooks',
  );

  /// Matches Jaspr's `Component`.
  static const jasprComponentChecker = TypeChecker.fromName(
    'Component',
    packageName: 'jaspr',
  );

  /// Matches Jaspr's `State`.
  static const jasprStateChecker = TypeChecker.fromName(
    'State',
    packageName: 'jaspr',
  );

  static const _blocHostNames = <String>{
    'BlocSignal',
    'ReplayBloc',
    'HydratedBloc',
    'HydratedBlocSignal',
    'BlocSignalMixin',
    'ReplayBlocMixin',
  };

  static const _cubitHostNames = <String>{
    'CubitSignal',
    'ReplayCubit',
    'HydratedCubit',
    'HydratedCubitSignal',
    'CubitSignalMixin',
    'ReplayCubitMixin',
    'ReplayMixin',
    'HydratedMixin',
  };

  static const _allContainerNames = <String>{
    'BlocSignalBase',
    ..._blocHostNames,
    ..._cubitHostNames,
  };

  static const _uiSupertypeNames = <String>{
    'State',
    'StatelessWidget',
    'StatefulWidget',
    'HookWidget',
    'StatelessComponent',
    'StatefulComponent',
    'Component',
  };

  /// Returns the nearest enclosing [ClassDeclaration] or [MixinDeclaration]
  /// containing [node], or `null` if none exists.
  static AstNode? nearestContainerDeclaration(AstNode node) {
    return node.thisOrAncestorMatching(
      (n) => n is ClassDeclaration || n is MixinDeclaration,
    );
  }

  /// Returns `true` if [declaration] is a `BlocSignalBase`, `BlocSignal`,
  /// `CubitSignal`, or container-mixin host (`ClassDeclaration` or
  /// `MixinDeclaration`).
  static bool isBlocContainerDeclaration(AstNode declaration) {
    const checkers = [
      blocSignalBaseChecker,
      blocSignalMixinChecker,
      cubitSignalMixinChecker,
    ];
    return _matchesContainer(declaration, checkers, _allContainerNames);
  }

  /// Returns `true` if [declaration] is a `BlocSignal` or `BlocSignalMixin`
  /// host (`ClassDeclaration` or `MixinDeclaration`).
  static bool isBlocSignalHost(AstNode declaration) {
    const checkers = [blocSignalChecker, blocSignalMixinChecker];
    return _matchesContainer(declaration, checkers, _blocHostNames);
  }

  /// Returns `true` if [declaration] is a Cubit-only container or mixin
  /// (excluding `BlocSignal` / `BlocSignalMixin` hosts).
  static bool isCubitOnlyContainer(AstNode declaration) {
    if (isBlocSignalHost(declaration)) return false;
    const checkers = [cubitSignalChecker, cubitSignalMixinChecker];
    return _matchesContainer(declaration, checkers, _cubitHostNames);
  }

  /// Returns `true` if [realTarget] is `null` (implicit `this`) or an
  /// explicit `this` expression.
  static bool isSelfOrUnqualifiedTarget(Expression? realTarget) {
    return realTarget == null || realTarget is ThisExpression;
  }

  /// Returns `true` if [target] resolves to a Flutter or Jaspr `BuildContext`,
  /// or uses a canonical `BuildContext` variable name when unresolved.
  static bool isBuildContextReceiver(Expression? target) {
    if (target == null) return false;
    final targetType = target.staticType;
    if (targetType != null &&
        targetType is! DynamicType &&
        targetType is! InvalidType) {
      return flutterBuildContextChecker.isAssignableFromType(targetType) ||
          jasprBuildContextChecker.isAssignableFromType(targetType);
    }
    final source = target.toSource();
    return source == 'context' ||
        source.endsWith('.context') ||
        source == 'ctx' ||
        source.endsWith('.ctx') ||
        source == 'buildContext' ||
        source.endsWith('.buildContext');
  }

  /// Returns `true` if [node] is a Flutter `Widget`/`State`/`HookWidget` or
  /// Jaspr `StatelessComponent`/`StatefulComponent`/`State` subclass.
  static bool isUiComponentOrState(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element != null &&
        (flutterWidgetChecker.isSuperOf(element) ||
            flutterStateChecker.isSuperOf(element) ||
            hookWidgetChecker.isSuperOf(element) ||
            jasprComponentChecker.isSuperOf(element) ||
            jasprStateChecker.isSuperOf(element))) {
      return true;
    }
    final superclass = node.extendsClause?.superclass;
    if (superclass == null) return false;
    return _matchesNamedType(superclass, const [
      flutterWidgetChecker,
      flutterStateChecker,
      hookWidgetChecker,
      jasprComponentChecker,
      jasprStateChecker,
    ], _uiSupertypeNames);
  }

  static bool _matchesContainer(
    AstNode declaration,
    List<TypeChecker> checkers,
    Set<String> exactFallbackNames,
  ) {
    if (declaration is ClassDeclaration) {
      final element = declaration.declaredFragment?.element;
      if (element != null) {
        for (final checker in checkers) {
          if (checker.isSuperOf(element)) return true;
        }
      }

      final superclass = declaration.extendsClause?.superclass;
      if (superclass != null &&
          _matchesNamedType(superclass, checkers, exactFallbackNames)) {
        return true;
      }

      final withClause = declaration.withClause;
      if (withClause != null) {
        for (final mixinType in withClause.mixinTypes) {
          if (_matchesNamedType(mixinType, checkers, exactFallbackNames)) {
            return true;
          }
        }
      }

      final implementsClause = declaration.implementsClause;
      if (implementsClause != null) {
        for (final interfaceType in implementsClause.interfaces) {
          if (_matchesNamedType(interfaceType, checkers, exactFallbackNames)) {
            return true;
          }
        }
      }

      return false;
    }

    if (declaration is MixinDeclaration) {
      final onClause = declaration.onClause;
      if (onClause == null) return false;
      for (final constraint in onClause.superclassConstraints) {
        if (_matchesNamedType(constraint, checkers, exactFallbackNames)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _matchesNamedType(
    NamedType namedType,
    List<TypeChecker> checkers,
    Set<String> exactFallbackNames,
  ) {
    final type = namedType.type;
    if (type != null && type is! InvalidType && type is! DynamicType) {
      for (final checker in checkers) {
        if (checker.isAssignableFromType(type)) return true;
      }
      return false;
    }
    final rawName = namedType
        .toSource()
        .split('<')
        .first
        .trim()
        .split('.')
        .last;
    return exactFallbackNames.contains(rawName);
  }
}
