import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/standard_catalog.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Builder signature for mapping an A2UI component model to a Jaspr component.
typedef A2uiJasprComponentBuilder = Component Function(
  BuildContext context,
  A2uiComponentContext componentContext,
);

/// A registry connecting A2UI component types to Jaspr web component builders.
///
/// Supports standard baseline DOM components as well as custom extension
/// components.
class A2uiJasprCatalog {
  /// Creates an empty [A2uiJasprCatalog] or one pre-populated with
  /// [initialBuilders].
  A2uiJasprCatalog({
    Map<String, A2uiJasprComponentBuilder>? initialBuilders,
  }) : _builders = initialBuilders != null
            ? Map.of(initialBuilders)
            : <String, A2uiJasprComponentBuilder>{};

  /// Creates a standard catalog pre-populated with standard component builders
  /// (for example Text, Row, Column, Button, TextField, Card, Divider).
  factory A2uiJasprCatalog.standard() {
    final catalog = A2uiJasprCatalog();
    registerStandardComponents(catalog);
    return catalog;
  }

  final Map<String, A2uiJasprComponentBuilder> _builders;

  /// Returns an unmodifiable snapshot of all currently registered component
  /// type names.
  ///
  /// ```dart
  /// final types = catalog.registeredTypes;
  /// print(types.contains('Button')); // true
  /// ```
  Iterable<String> get registeredTypes =>
      List<String>.unmodifiable(_builders.keys);

  /// Registers or overrides a builder for the given component [typeName].
  ///
  /// ```dart
  /// catalog.register('CustomWidget', (context, compCtx) => div([]));
  /// ```
  void register(String typeName, A2uiJasprComponentBuilder builder) {
    _builders[typeName] = builder;
  }

  /// Bulk-registers multiple component [builders] into this catalog.
  ///
  /// Any existing builder with an overlapping key will be overridden.
  ///
  /// ```dart
  /// catalog.registerAll({
  ///   'MetricCard': metricCardComponentBuilder,
  ///   'LineChart': lineChartComponentBuilder,
  /// });
  /// ```
  void registerAll(Map<String, A2uiJasprComponentBuilder> builders) {
    _builders.addAll(builders);
  }

  /// Creates a new [A2uiJasprCatalog] containing all existing builders,
  /// extended or overridden by the provided [builders].
  ///
  /// The returned catalog is an isolated, independent copy; modifying either
  /// catalog will not affect the other.
  ///
  /// ```dart
  /// final customCatalog = baseCatalog.copyWith({
  ///   'SpecialButton': specialButtonComponentBuilder,
  /// });
  /// ```
  A2uiJasprCatalog copyWith(
    Map<String, A2uiJasprComponentBuilder> builders,
  ) {
    return A2uiJasprCatalog(
      initialBuilders: <String, A2uiJasprComponentBuilder>{
        ..._builders,
        ...builders,
      },
    );
  }

  /// Creates a new [A2uiJasprCatalog] containing all existing builders
  /// except those specified in [typesToRemove].
  ///
  /// The returned catalog is an isolated, independent copy; modifying either
  /// catalog will not affect the other.
  ///
  /// ```dart
  /// final restrictedCatalog = baseCatalog.copyWithout(['Button', 'Divider']);
  /// ```
  A2uiJasprCatalog copyWithout(Iterable<String> typesToRemove) {
    final toRemove = typesToRemove.toSet();
    final newBuilders = Map<String, A2uiJasprComponentBuilder>.of(_builders)
      ..removeWhere((key, _) => toRemove.contains(key));
    return A2uiJasprCatalog(initialBuilders: newBuilders);
  }

  /// Returns true if a builder is registered for [typeName].
  ///
  /// ```dart
  /// final hasText = catalog.hasBuilder('Text');
  /// ```
  bool hasBuilder(String typeName) => _builders.containsKey(typeName);

  /// Builds a component for the given [componentContext], or returns a fallback
  /// container if no builder was registered for this component type.
  Component build(
    BuildContext context,
    A2uiComponentContext componentContext,
  ) {
    final typeName = componentContext.component.type;
    final builder = _builders[typeName];
    if (builder != null) {
      return builder(context, componentContext);
    }
    return _UnknownComponent(componentType: typeName);
  }
}

class _UnknownComponent extends StatelessComponent {
  const _UnknownComponent({required this.componentType});

  final String componentType;

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'a2ui-unknown-component',
      styles: const Styles(
        padding: Spacing.all(Unit.pixels(8)),
        margin: Spacing.symmetric(vertical: Unit.pixels(4)),
        backgroundColor: Color('#fef3c7'),
        border: Border.all(
          color: Color('#92400e'),
          width: Unit.pixels(1),
        ),
        radius: BorderRadius.circular(Unit.pixels(4)),
        color: Color('#78350f'),
        fontFamily: FontFamily.list([FontFamily('monospace')]),
        fontSize: Unit.pixels(12),
      ),
      [
        Component.text('Unknown A2UI Component: <$componentType>'),
      ],
    );
  }
}
