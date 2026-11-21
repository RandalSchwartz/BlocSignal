import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Lightweight type matcher for analyzer [Element] and [DartType] nodes.
class TypeChecker {
  /// Creates a [TypeChecker] matching [name] optionally scoped to
  /// [packageName].
  const new fromName(this.name, {this.packageName});

  /// The target class or mixin name.
  final String name;

  /// Optional package name that must own the target declaration.
  final String? packageName;

  /// Returns `true` if [element] itself matches this checker.
  bool isExactly(Element element) {
    if (element is! InterfaceElement) return false;
    if (element.name != name) return false;
    final pkg = packageName;
    if (pkg == null) return true;
    final uri = element.library.uri;
    return uri.isScheme('package') &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == pkg;
  }

  /// Returns `true` if [element] or any of its supertypes matches this checker.
  bool isSuperOf(Element element) {
    if (isExactly(element)) return true;
    if (element is! InterfaceElement) return false;
    return element.allSupertypes.any(
      (supertype) => isExactly(supertype.element),
    );
  }

  /// Returns `true` if [type]'s element itself matches this checker.
  bool isExactlyType(DartType type) =>
      type is InterfaceType && isExactly(type.element);

  /// Returns `true` if [type] is assignable to the target type.
  bool isAssignableFromType(DartType type) =>
      _isAssignableFromType(type, <DartType>{});

  bool _isAssignableFromType(DartType type, Set<DartType> visited) {
    if (type is TypeParameterType) {
      if (!visited.add(type)) return false;
      return _isAssignableFromType(type.bound, visited);
    }
    if (type is! InterfaceType) return false;
    return isSuperOf(type.element);
  }
}
