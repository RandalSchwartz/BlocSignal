import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/a2ui_flutter_catalog.dart';
import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Callback signature for rendering when surface is in [SurfaceInitial] state.
typedef A2uiInitialBuilder = Widget Function(BuildContext context);

/// Callback signature for rendering when surface is in
/// [SurfaceStreaming] state.
typedef A2uiStreamingBuilder = Widget Function(
  BuildContext context,
  SurfaceStreaming streaming,
);

/// Callback signature for rendering when surface is in
/// [SurfaceSubmitting] state.
typedef A2uiSubmittingBuilder = Widget Function(
  BuildContext context,
  SurfaceSubmitting submitting,
);

/// Callback signature for rendering when surface encountered a [SurfaceError].
typedef A2uiErrorBuilder = Widget Function(
  BuildContext context,
  SurfaceError error,
);

/// A reactive Flutter widget that connects an [A2uiSurfaceBloc] to Flutter's
/// widget hierarchy.
///
/// Handles all states of the A2UI surface lifecycle:
/// - [SurfaceInitial]: Renders [placeholderBuilder] or empty container.
/// - [SurfaceStreaming]: Renders [streamingBuilder] or a skeleton indicator.
/// - [SurfaceReady]: Recursively evaluates component models and renders
///   catalog widgets.
/// - [SurfaceSubmitting]: Renders [submittingBuilder] or interaction barrier.
/// - [SurfaceError]: Renders [errorBuilder] or a default error alert.
class A2uiSurfaceView extends StatelessWidget {
  /// Creates an [A2uiSurfaceView].
  ///
  /// If [catalog] is omitted, defaults to [A2uiFlutterCatalog.standard].
  A2uiSurfaceView({
    required this.bloc,
    A2uiFlutterCatalog? catalog,
    this.placeholderBuilder,
    this.streamingBuilder,
    this.submittingBuilder,
    this.errorBuilder,
    super.key,
  }) : catalog = catalog ?? A2uiFlutterCatalog.standard();

  /// The underlying [A2uiSurfaceBloc] orchestrating generative state.
  final A2uiSurfaceBloc bloc;

  /// The widget catalog providing UI builders for each A2UI component type.
  final A2uiFlutterCatalog catalog;

  /// Optional custom builder rendered during [SurfaceInitial].
  final A2uiInitialBuilder? placeholderBuilder;

  /// Optional custom builder rendered during [SurfaceStreaming].
  final A2uiStreamingBuilder? streamingBuilder;

  /// Optional custom builder rendered during [SurfaceSubmitting].
  final A2uiSubmittingBuilder? submittingBuilder;

  /// Optional custom builder rendered during [SurfaceError].
  final A2uiErrorBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<A2uiSurfaceBloc, A2uiSurfaceState>(
      bloc: bloc,
      builder: (context, state) {
        return switch (state) {
          final SurfaceInitial _ => _buildInitial(context),
          final SurfaceStreaming streaming =>
            _buildStreaming(context, streaming),
          final SurfaceReady ready => _SurfaceTreeRenderer(
              surfaceReady: ready,
              catalog: catalog,
              bloc: bloc,
            ),
          final SurfaceSubmitting submitting =>
            _buildSubmitting(context, submitting),
          final SurfaceError error => _buildError(context, error),
        };
      },
    );
  }

  Widget _buildInitial(BuildContext context) {
    if (placeholderBuilder != null) {
      return placeholderBuilder!(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildStreaming(BuildContext context, SurfaceStreaming streaming) {
    if (streamingBuilder != null) {
      return streamingBuilder!(context, streaming);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Generating UI (${streaming.messageCount} chunks)...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitting(BuildContext context, SurfaceSubmitting submitting) {
    if (submittingBuilder != null) {
      return submittingBuilder!(context, submitting);
    }
    return Stack(
      children: [
        const Opacity(
          opacity: 0.5,
          child: ModalBarrier(dismissible: false, color: Colors.black12),
        ),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text('Submitting ${submitting.actionName}...'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, SurfaceError error) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Generative UI Error',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceTreeRenderer extends StatefulWidget {
  const _SurfaceTreeRenderer({
    required this.surfaceReady,
    required this.catalog,
    required this.bloc,
  });

  final SurfaceReady surfaceReady;
  final A2uiFlutterCatalog catalog;
  final A2uiSurfaceBloc bloc;

  @override
  State<_SurfaceTreeRenderer> createState() => _SurfaceTreeRendererState();
}

class _SurfaceTreeRendererState extends State<_SurfaceTreeRenderer> {
  final Map<String, GenericBinder> _binders = {};
  final Map<String, ComponentModel> _boundComponents = {};
  final Set<String> _activeBuildPath = <String>{};

  @override
  void initState() {
    super.initState();
    _reconcileBinders();
  }

  @override
  void didUpdateWidget(_SurfaceTreeRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.surfaceReady.version != oldWidget.surfaceReady.version ||
        !identical(
          widget.surfaceReady.surface,
          oldWidget.surfaceReady.surface,
        )) {
      _reconcileBinders();
    }
  }

  void _reconcileBinders() {
    final surface = widget.surfaceReady.surface;
    final currentComponents = surface.componentsModel.all;
    final activeIds = <String>{};

    for (final c in currentComponents) {
      activeIds.add(c.id);
      final existingBinder = _binders[c.id];
      final previousComponent = _boundComponents[c.id];
      // Only recreate binder if the component instance or type has changed
      if (existingBinder == null || previousComponent != c) {
        existingBinder?.dispose();
        final componentApi = surface.catalog.components[c.type];
        final schema = componentApi?.schema ?? Schema.fromMap(const {});
        final componentContext = ComponentContext(surface, c);
        _binders[c.id] = GenericBinder(componentContext, schema);
        _boundComponents[c.id] = c;
      }
    }

    // Prune stale binders for components removed from the surface
    _binders.removeWhere((id, binder) {
      if (!activeIds.contains(id)) {
        binder.dispose();
        _boundComponents.remove(id);
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    for (final binder in _binders.values) {
      binder.dispose();
    }
    _binders.clear();
    _boundComponents.clear();
    super.dispose();
  }

  Widget _buildComponent(String componentId) {
    if (_activeBuildPath.contains(componentId)) {
      return SizedBox.shrink(
        key: ValueKey('circular_ref_$componentId'),
      );
    }

    final surface = widget.surfaceReady.surface;
    final component = surface.componentsModel.get(componentId);
    if (component == null) {
      return SizedBox.shrink(key: ValueKey('missing_$componentId'));
    }

    final binder = _binders[componentId];
    final resolvedProps = binder?.resolvedProps.value ?? component.properties;

    final componentCtx = A2uiComponentContext(
      component: component,
      props: resolvedProps,
      surfaceBloc: widget.bloc,
      surfaceId: widget.surfaceReady.surfaceId,
      buildChildCallback: _buildComponent,
      buildChildrenCallback: (ids) => ids.map(_buildComponent).toList(),
    );

    _activeBuildPath.add(componentId);
    try {
      final childWidget = widget.catalog.build(context, componentCtx);
      return KeyedSubtree(
        key: ValueKey('a2ui_$componentId'),
        child: childWidget,
      );
    } finally {
      _activeBuildPath.remove(componentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final components = widget.surfaceReady.surface.componentsModel.all;
    if (components.isEmpty) {
      return const SizedBox.shrink();
    }

    // Identify root components not referenced as a child by any other component
    final childIds = <String>{};
    void collectId(dynamic item) {
      if (item is ChildNode) {
        childIds.add(item.id);
      } else if (item is Map && item.containsKey('id')) {
        childIds.add(item['id'].toString());
      } else if (item != null) {
        childIds.add(item.toString());
      }
    }

    for (final c in components) {
      final binder = _binders[c.id];
      final props = binder?.resolvedProps.value ?? c.properties;

      collectId(props['child'] ?? c.properties['child']);

      final childrenProp = props['children'] ?? c.properties['children'];
      if (childrenProp is List) {
        childrenProp.forEach(collectId);
      }
    }

    final rootComponents =
        components.where((c) => !childIds.contains(c.id)).toList();

    if (rootComponents.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: components.map((c) => _buildComponent(c.id)).toList(),
      );
    }

    if (rootComponents.length == 1) {
      return _buildComponent(rootComponents.first.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rootComponents.map((c) => _buildComponent(c.id)).toList(),
    );
  }
}
