import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/standard_catalog.dart';
import 'package:flutter/material.dart';

/// Builder signature for mapping an A2UI component model to a Flutter widget.
typedef A2uiComponentWidgetBuilder = Widget Function(
  BuildContext context,
  A2uiComponentContext componentContext,
);

/// A registry connecting A2UI component types to Flutter widget builders.
///
/// Supports standard baseline widgets as well as custom extension components.
class A2uiFlutterCatalog {
  /// Creates an empty [A2uiFlutterCatalog].
  A2uiFlutterCatalog({
    Map<String, A2uiComponentWidgetBuilder>? initialBuilders,
  }) : _builders = initialBuilders != null
            ? Map.of(initialBuilders)
            : <String, A2uiComponentWidgetBuilder>{};

  /// Creates a standard catalog pre-populated with standard component builders
  /// (for example Text, Row, Column, Button, TextField, Card, Divider).
  factory A2uiFlutterCatalog.standard() {
    final catalog = A2uiFlutterCatalog();
    registerStandardComponents(catalog);
    return catalog;
  }

  final Map<String, A2uiComponentWidgetBuilder> _builders;

  /// Registers or overrides a builder for the given component [typeName].
  void register(String typeName, A2uiComponentWidgetBuilder builder) {
    _builders[typeName] = builder;
  }

  /// Returns true if a builder is registered for [typeName].
  bool hasBuilder(String typeName) => _builders.containsKey(typeName);

  /// Builds a widget for the given [componentContext], or returns a fallback
  /// container if no builder was registered for this component type.
  Widget build(BuildContext context, A2uiComponentContext componentContext) {
    final typeName = componentContext.component.type;
    final builder = _builders[typeName];
    if (builder != null) {
      return builder(context, componentContext);
    }
    return _UnknownComponentWidget(componentType: typeName);
  }
}

class _UnknownComponentWidget extends StatelessWidget {
  const _UnknownComponentWidget({required this.componentType});

  final String componentType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.shade800),
      ),
      child: Text(
        'Unknown A2UI Component: <$componentType>',
        style: TextStyle(
          color: Colors.amber.shade900,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}
