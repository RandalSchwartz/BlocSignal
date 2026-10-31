import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/a2ui_jaspr_catalog.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;

/// Callback signature for rendering when surface is in [SurfaceInitial] state.
typedef A2uiInitialBuilder = Component Function(BuildContext context);

/// Callback signature for rendering when surface is in
/// [SurfaceStreaming] state.
typedef A2uiStreamingBuilder = Component Function(
  BuildContext context,
  SurfaceStreaming streaming,
);

/// Callback signature for rendering when surface is in
/// [SurfaceSubmitting] state.
typedef A2uiSubmittingBuilder = Component Function(
  BuildContext context,
  SurfaceSubmitting submitting,
);

/// Callback signature for rendering when surface encountered a [SurfaceError].
typedef A2uiErrorBuilder = Component Function(
  BuildContext context,
  SurfaceError error,
);

/// Callback signature for rendering validation errors when
/// [SurfaceReady.isValid] is false.
typedef A2uiValidationErrorsBuilder = Component Function(
  BuildContext context,
  List<String> errors,
);

/// A reactive Jaspr web component that connects an [A2uiSurfaceBloc] to
/// the HTML DOM.
///
/// Handles all states of the A2UI surface lifecycle:
/// - [SurfaceInitial]: Renders [placeholderBuilder] or empty container.
/// - [SurfaceStreaming]: Renders [streamingBuilder] or a skeleton indicator.
/// - [SurfaceReady]: Recursively evaluates component models and renders
///   catalog web components. Displays validation errors via
///   [validationErrorsBuilder] or default error banner when
///   [SurfaceReady.isValid] is false.
/// - [SurfaceSubmitting]: Renders [submittingBuilder] or interaction barrier.
/// - [SurfaceError]: Renders [errorBuilder] or a default error alert.
class A2uiSurfaceView extends StatefulComponent {
  /// Creates an [A2uiSurfaceView].
  ///
  /// If [catalog] is omitted, defaults to [A2uiJasprCatalog.standard].
  /// If [surfaceId] is specified, targets and renders that specific surface
  /// rather than the globally active surface in [bloc].
  A2uiSurfaceView({
    required this.bloc,
    this.surfaceId,
    A2uiJasprCatalog? catalog,
    this.placeholderBuilder,
    this.streamingBuilder,
    this.submittingBuilder,
    this.errorBuilder,
    this.validationErrorsBuilder,
    super.key,
  }) : catalog = catalog ?? A2uiJasprCatalog.standard();

  /// The underlying [A2uiSurfaceBloc] orchestrating generative state.
  final A2uiSurfaceBloc bloc;

  /// An optional specific surface identifier to target and render.
  ///
  /// When provided, this view will exclusively render components belonging to
  /// [surfaceId], even if another surface is currently active in [bloc].
  final String? surfaceId;

  /// The web component catalog providing UI builders for each A2UI component
  /// type.
  final A2uiJasprCatalog catalog;

  /// Optional custom builder rendered during [SurfaceInitial].
  final A2uiInitialBuilder? placeholderBuilder;

  /// Optional custom builder rendered during [SurfaceStreaming].
  final A2uiStreamingBuilder? streamingBuilder;

  /// Optional custom builder rendered during [SurfaceSubmitting].
  final A2uiSubmittingBuilder? submittingBuilder;

  /// Optional custom builder rendered during [SurfaceError].
  final A2uiErrorBuilder? errorBuilder;

  /// Optional custom builder rendered when [SurfaceReady.isValid] is false.
  final A2uiValidationErrorsBuilder? validationErrorsBuilder;

  @override
  State<A2uiSurfaceView> createState() => _A2uiSurfaceViewState();
}

class _A2uiSurfaceViewState extends State<A2uiSurfaceView> {
  void Function()? _activeSurfaceUnsubscribe;
  String? _lastActiveSurfaceId;

  @override
  void initState() {
    super.initState();
    _subscribeActiveSurfaceId();
  }

  @override
  void didUpdateComponent(A2uiSurfaceView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.bloc != oldComponent.bloc ||
        component.surfaceId != oldComponent.surfaceId) {
      _subscribeActiveSurfaceId();
    }
  }

  void _subscribeActiveSurfaceId() {
    _activeSurfaceUnsubscribe?.call();
    _activeSurfaceUnsubscribe = null;
    _lastActiveSurfaceId = component.bloc.activeSurfaceId.value;
    if (component.surfaceId == null) {
      _activeSurfaceUnsubscribe = component.bloc.activeSurfaceId.subscribe(
        (currentId) {
          if (_lastActiveSurfaceId != currentId) {
            _lastActiveSurfaceId = currentId;
            if (mounted) {
              setState(() {});
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _activeSurfaceUnsubscribe?.call();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<A2uiSurfaceBloc, A2uiSurfaceState>(
      bloc: component.bloc,
      builder: (context, state) {
        final targetId =
            component.surfaceId ?? component.bloc.activeSurfaceId.value;
        if (targetId != null) {
          if (state is SurfaceSubmitting && state.surfaceId == targetId) {
            return _buildSubmitting(context, state);
          }
          if (state is SurfaceError &&
              (state.surfaceId == targetId || state.surfaceId == null)) {
            return _buildError(context, state);
          }
          if (state is SurfaceStreaming &&
              (state.surfaceId == targetId ||
                  (component.surfaceId == null && state.surfaceId == null))) {
            return _buildStreaming(context, state);
          }
          if (state is SurfaceReady && state.surfaceId == targetId) {
            return _SurfaceTreeRenderer(
              surfaceReady: state,
              catalog: component.catalog,
              bloc: component.bloc,
              validationErrorsBuilder: component.validationErrorsBuilder,
            );
          }

          final targetedReady = component.bloc.getSurfaceReady(targetId);
          if (targetedReady != null) {
            if (targetedReady.surface.componentsModel.all.isEmpty) {
              return _buildStreaming(
                context,
                SurfaceStreaming(surfaceId: targetId, messageCount: 1),
              );
            }
            return _SurfaceTreeRenderer(
              surfaceReady: targetedReady,
              catalog: component.catalog,
              bloc: component.bloc,
              validationErrorsBuilder: component.validationErrorsBuilder,
            );
          }

          if (component.surfaceId != null) {
            return _buildInitial(context);
          }
        }

        if (state is SurfaceStreaming) {
          return _buildStreaming(context, state);
        }
        if (state is SurfaceError) {
          return _buildError(context, state);
        }
        return _buildInitial(context);
      },
    );
  }

  Component _buildInitial(BuildContext context) {
    if (component.placeholderBuilder != null) {
      return component.placeholderBuilder!(context);
    }
    return const div([]);
  }

  Component _buildStreaming(
    BuildContext context,
    SurfaceStreaming streaming,
  ) {
    if (component.streamingBuilder != null) {
      return component.streamingBuilder!(context, streaming);
    }
    return div(
      classes: 'a2ui-streaming-container',
      styles: const Styles(
        padding: Spacing.all(Unit.pixels(16)),
        textAlign: TextAlign.center,
      ),
      [
        p(
          classes: 'a2ui-streaming-text',
          styles: const Styles(
            color: Color('#6b7280'),
            fontSize: Unit.pixels(14),
          ),
          [
            Component.text(
              'Generating UI (${streaming.messageCount} chunks)...',
            ),
          ],
        ),
      ],
    );
  }

  Component _buildSubmitting(
    BuildContext context,
    SurfaceSubmitting submitting,
  ) {
    if (component.submittingBuilder != null) {
      return component.submittingBuilder!(context, submitting);
    }
    return div(
      classes: 'a2ui-submitting-container',
      styles: const Styles(
        padding: Spacing.all(Unit.pixels(16)),
        textAlign: TextAlign.center,
        backgroundColor: Color('rgba(0, 0, 0, 0.05)'),
        radius: BorderRadius.circular(Unit.pixels(8)),
      ),
      [
        p(
          classes: 'a2ui-submitting-text',
          styles: const Styles(
            fontWeight: FontWeight.w600,
            color: Color('#1f2937'),
          ),
          [Component.text('Submitting ${submitting.actionName}...')],
        ),
      ],
    );
  }

  Component _buildError(BuildContext context, SurfaceError error) {
    if (component.errorBuilder != null) {
      return component.errorBuilder!(context, error);
    }
    return div(
      classes: 'a2ui-error-container',
      styles: const Styles(
        padding: Spacing.all(Unit.pixels(16)),
        margin: Spacing.all(Unit.pixels(8)),
        backgroundColor: Color('#fee2e2'),
        border: Border.all(
          color: Color('#ef4444'),
          width: Unit.pixels(1),
        ),
        radius: BorderRadius.circular(Unit.pixels(8)),
        color: Color('#991b1b'),
      ),
      [
        const h4(
          styles: Styles(margin: Spacing.zero, fontWeight: FontWeight.bold),
          [Component.text('Generative UI Error')],
        ),
        p(
          styles: const Styles(
            margin: Spacing.only(top: Unit.pixels(4)),
            fontSize: Unit.pixels(12),
          ),
          [Component.text(error.error.toString())],
        ),
      ],
    );
  }
}

class _SurfaceTreeRenderer extends StatefulComponent {
  const _SurfaceTreeRenderer({
    required this.surfaceReady,
    required this.catalog,
    required this.bloc,
    this.validationErrorsBuilder,
  });

  final SurfaceReady surfaceReady;
  final A2uiJasprCatalog catalog;
  final A2uiSurfaceBloc bloc;
  final A2uiValidationErrorsBuilder? validationErrorsBuilder;

  @override
  State<_SurfaceTreeRenderer> createState() => _SurfaceTreeRendererState();
}

class _SurfaceTreeRendererState extends State<_SurfaceTreeRenderer> {
  final Map<String, GenericBinder> _binders = {};
  final Map<String, ComponentModel> _boundComponents = {};
  NodeResolver<ComponentApi>? _resolver;
  void Function()? _rootNodeUnsubscribe;
  ComponentNode<ComponentApi>? _lastRootNode;

  @override
  void initState() {
    super.initState();
    _initResolver();
    _reconcileBinders();
  }

  @override
  void didUpdateComponent(_SurfaceTreeRenderer oldComponent) {
    super.didUpdateComponent(oldComponent);
    final surfaceChanged = !identical(
      component.surfaceReady.surface,
      oldComponent.surfaceReady.surface,
    );
    if (surfaceChanged) {
      _disposeResolver();
      _initResolver();
    }
    if (component.surfaceReady.version != oldComponent.surfaceReady.version ||
        surfaceChanged) {
      _reconcileBinders();
    }
  }

  void _initResolver() {
    final resolver = NodeResolver<ComponentApi>(component.surfaceReady.surface);
    _resolver = resolver;
    _lastRootNode = resolver.rootNode.value;
    _rootNodeUnsubscribe = resolver.rootNode.subscribe((nextRoot) {
      if (!identical(_lastRootNode, nextRoot)) {
        _lastRootNode = nextRoot;
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  void _disposeResolver() {
    _rootNodeUnsubscribe?.call();
    _rootNodeUnsubscribe = null;
    _resolver?.dispose();
    _resolver = null;
    _lastRootNode = null;
  }

  void _reconcileBinders() {
    final surface = component.surfaceReady.surface;
    final currentComponents = surface.componentsModel.all;
    final activeIds = <String>{};

    for (final comp in currentComponents) {
      activeIds.add(comp.id);
      final existingBinder = _binders[comp.id];
      final previousComponent = _boundComponents[comp.id];
      if (existingBinder == null || previousComponent != comp) {
        existingBinder?.dispose();
        final catalog = surface.resolveCatalog(comp.catalog);
        final schema = catalog.resolvedComponentSchema(comp.type) ??
            Schema.fromMap(const {});
        final componentContext = ComponentContext(surface, comp);
        _binders[comp.id] = GenericBinder(componentContext, schema);
        _boundComponents[comp.id] = comp;
      }
    }

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
    _disposeResolver();
    for (final binder in _binders.values) {
      binder.dispose();
    }
    _binders.clear();
    _boundComponents.clear();
    super.dispose();
  }

  Component _buildNode(
    ComponentNode<ComponentApi> node,
    Set<String> ancestorPath,
  ) {
    switch (node.state) {
      case NodeState.pending:
        return div(
          key: ValueKey('missing_${node.componentId}'),
          const [],
        );
      case NodeState.cyclic:
        return div(
          key: ValueKey('circular_ref_${node.componentId}'),
          const [],
        );
      case NodeState.unknownType:
        return div(
          key: ValueKey('a2ui_error_${node.componentId}'),
          [
            _buildComponentErrorFallback(
              context,
              node.componentId,
              StateError('Unknown component type "${node.type}"'),
            ),
          ],
        );
      case NodeState.resolved:
        return _ResolvedNodeComponent(
          key: ValueKey('a2ui_node_${node.instanceId}'),
          node: node,
          ancestorPath: ancestorPath,
          catalog: component.catalog,
          bloc: component.bloc,
          surfaceId: component.surfaceReady.surfaceId,
          buildNodeCallback: _buildNode,
          buildComponentCallback: _buildComponent,
          errorFallbackBuilder: _buildComponentErrorFallback,
        );
    }
  }

  Component _buildComponent(
    String componentId,
    Set<String> ancestorPath, {
    String dataPath = '/',
    int? index,
  }) {
    final pathKey = dataPath == '/' || dataPath.isEmpty
        ? componentId
        : '$componentId-[$dataPath]';
    if (ancestorPath.contains(pathKey) || ancestorPath.contains(componentId)) {
      return div(
        key: ValueKey('circular_ref_$componentId'),
        const [],
      );
    }

    final surface = component.surfaceReady.surface;
    final comp = surface.componentsModel.get(componentId);
    if (comp == null) {
      return div(
        key: ValueKey('missing_$componentId'),
        const [],
      );
    }

    final binder = dataPath == '/' || dataPath.isEmpty
        ? _binders[componentId]
        : _createScopedBinder(surface, comp, dataPath, index);
    return _BoundComponent(
      key: ValueKey('a2ui_bound_$pathKey'),
      componentModel: comp,
      binder: binder,
      ownsBinder: dataPath != '/' && dataPath.isNotEmpty,
      dataPath: dataPath,
      ancestorPath: ancestorPath,
      catalog: component.catalog,
      bloc: component.bloc,
      surfaceId: component.surfaceReady.surfaceId,
      surfaceVersion: component.surfaceReady.version,
      buildComponentCallback: _buildComponent,
      errorFallbackBuilder: _buildComponentErrorFallback,
    );
  }

  GenericBinder _createScopedBinder(
    SurfaceModel<ComponentApi> surface,
    ComponentModel comp,
    String dataPath,
    int? index,
  ) {
    final catalog = surface.resolveCatalog(comp.catalog);
    final schema =
        catalog.resolvedComponentSchema(comp.type) ?? Schema.fromMap(const {});
    final componentContext = ComponentContext(
      surface,
      comp,
      basePath: dataPath,
      index: index,
    );
    return GenericBinder(componentContext, schema);
  }

  Component _buildComponentErrorFallback(
    BuildContext context,
    String componentId,
    Object error,
  ) {
    return div(
      key: ValueKey('error_fallback_$componentId'),
      classes: 'a2ui-component-error-fallback',
      styles: const Styles(
        padding: Spacing.all(Unit.pixels(8)),
        margin: Spacing.symmetric(vertical: Unit.pixels(4)),
        backgroundColor: Color('#fee2e2'),
        border: Border.all(
          color: Color('#ef4444'),
          width: Unit.pixels(1),
        ),
        radius: BorderRadius.circular(Unit.pixels(4)),
        color: Color('#991b1b'),
        fontSize: Unit.pixels(12),
      ),
      [
        Component.text('Failed to render component "$componentId"'),
      ],
    );
  }

  @override
  Component build(BuildContext context) {
    final hasErrors = !component.surfaceReady.isValid &&
        component.surfaceReady.validationErrors.isNotEmpty;

    Component? errorBanner;
    if (hasErrors) {
      if (component.validationErrorsBuilder != null) {
        errorBanner = component.validationErrorsBuilder!(
          context,
          component.surfaceReady.validationErrors,
        );
      } else {
        errorBanner = div(
          key: const ValueKey('a2ui_validation_errors_banner'),
          classes: 'a2ui-validation-errors-banner',
          styles: const Styles(
            padding: Spacing.all(Unit.pixels(12)),
            margin: Spacing.only(bottom: Unit.pixels(12)),
            backgroundColor: Color('#fee2e2'),
            border: Border.all(
              color: Color('#ef4444'),
              width: Unit.pixels(1),
            ),
            radius: BorderRadius.circular(Unit.pixels(8)),
            color: Color('#991b1b'),
          ),
          [
            for (final error in component.surfaceReady.validationErrors)
              p(
                classes: 'a2ui-validation-error-item',
                styles: const Styles(
                  margin: Spacing.symmetric(vertical: Unit.pixels(2)),
                  fontSize: Unit.pixels(12),
                  fontWeight: FontWeight.w500,
                ),
                [Component.text(error)],
              ),
          ],
        );
      }
    }

    final components = component.surfaceReady.surface.componentsModel.all;
    if (components.isEmpty) {
      return errorBanner ?? const div([]);
    }

    final resolvedRoot = _resolver?.rootNode.value;
    Component content;
    if (resolvedRoot != null) {
      content = _buildNode(resolvedRoot, const <String>{});
    } else {
      final childIds = <String>{};
      void collectId(dynamic rawItem) {
        final item = unwrapBinding(rawItem);
        if (item is ChildNode) {
          childIds.add(item.id);
        } else if (item is Map && item.containsKey('id')) {
          childIds.add(unwrapBinding(item['id']).toString());
        } else if (item != null) {
          childIds.add(item.toString());
        }
      }

      for (final comp in components) {
        final binder = _binders[comp.id];
        final props = binder?.resolvedProps.value ?? comp.properties;

        collectId(
          unwrapBinding(props['child']) ??
              unwrapBinding(comp.properties['child']),
        );
        collectId(
          unwrapBinding(props['trigger']) ??
              unwrapBinding(comp.properties['trigger']),
        );
        collectId(
          unwrapBinding(props['entryPointChild']) ??
              unwrapBinding(comp.properties['entryPointChild']),
        );
        collectId(
          unwrapBinding(props['content']) ??
              unwrapBinding(comp.properties['content']),
        );
        collectId(
          unwrapBinding(props['contentChild']) ??
              unwrapBinding(comp.properties['contentChild']),
        );

        final childrenProp = unwrapBinding(props['children']) ??
            unwrapBinding(comp.properties['children']);
        if (childrenProp is List) {
          childrenProp.forEach(collectId);
        }

        final tabsProp = unwrapBinding(props['tabs']) ??
            unwrapBinding(comp.properties['tabs']);
        if (tabsProp is List) {
          for (final tab in tabsProp) {
            final unwrappedTab = unwrapBinding(tab);
            if (unwrappedTab is Map) {
              collectId(unwrappedTab['child']);
            }
          }
        }
      }

      final rootComponents =
          components.where((comp) => !childIds.contains(comp.id)).toList();

      if (rootComponents.isEmpty) {
        content = div(
          classes: 'a2ui-surface-root',
          components
              .map((comp) => _buildComponent(comp.id, const <String>{}))
              .toList(),
        );
      } else if (rootComponents.length == 1) {
        content = _buildComponent(rootComponents.first.id, const <String>{});
      } else {
        content = div(
          classes: 'a2ui-surface-root',
          rootComponents
              .map((comp) => _buildComponent(comp.id, const <String>{}))
              .toList(),
        );
      }
    }

    if (errorBanner != null) {
      return div(
        classes: 'a2ui-surface-container',
        [
          errorBanner,
          content,
        ],
      );
    }

    return content;
  }
}

class _ResolvedNodeComponent extends StatefulComponent {
  const _ResolvedNodeComponent({
    required this.node,
    required this.ancestorPath,
    required this.catalog,
    required this.bloc,
    required this.surfaceId,
    required this.buildNodeCallback,
    required this.buildComponentCallback,
    required this.errorFallbackBuilder,
    super.key,
  });

  final ComponentNode<ComponentApi> node;
  final Set<String> ancestorPath;
  final A2uiJasprCatalog catalog;
  final A2uiSurfaceBloc bloc;
  final String surfaceId;
  final Component Function(
    ComponentNode<ComponentApi> node,
    Set<String> ancestorPath,
  ) buildNodeCallback;
  final Component Function(
    String componentId,
    Set<String> ancestorPath, {
    String dataPath,
    int? index,
  }) buildComponentCallback;
  final Component Function(
    BuildContext context,
    String componentId,
    Object error,
  ) errorFallbackBuilder;

  @override
  State<_ResolvedNodeComponent> createState() => _ResolvedNodeComponentState();
}

class _ResolvedNodeComponentState extends State<_ResolvedNodeComponent> {
  void Function()? _unsubscribe;
  NodeProps? _lastProps;

  @override
  void initState() {
    super.initState();
    _subscribeNode();
  }

  @override
  void didUpdateComponent(_ResolvedNodeComponent oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(component.node, oldComponent.node)) {
      _subscribeNode();
    }
  }

  void _subscribeNode() {
    _unsubscribe?.call();
    _unsubscribe = null;
    _lastProps = component.node.props.value;
    _unsubscribe = component.node.props.subscribe((nextProps) {
      if (!identical(_lastProps, nextProps)) {
        _lastProps = nextProps;
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unsubscribe = null;
    super.dispose();
  }

  Map<String, ComponentNode<ComponentApi>> _collectChildNodes(
    Map<String, Object?> rawProps,
  ) {
    final childMap = <String, ComponentNode<ComponentApi>>{};
    void visit(Object? valueNode) {
      final unwrapped = unwrapBinding(valueNode);
      if (unwrapped is ComponentNode<ComponentApi>) {
        childMap[unwrapped.instanceId] = unwrapped;
        childMap.putIfAbsent(unwrapped.componentId, () => unwrapped);
      } else if (unwrapped is Iterable) {
        unwrapped.forEach(visit);
      } else if (unwrapped is Map) {
        unwrapped.values.forEach(visit);
      }
    }

    rawProps.values.forEach(visit);
    return childMap;
  }

  @override
  Component build(BuildContext context) {
    final node = component.node;
    final componentId = node.componentId;
    final instanceId = node.instanceId;
    final componentModel = node.context!.componentModel;
    final nextPath = <String>{
      ...component.ancestorPath,
      instanceId,
      if (node.dataPath == '/') componentId,
    };
    final rawProps = node.props.value;
    final resolvedProps = <String, dynamic>{
      for (final entry in rawProps.entries)
        entry.key: unwrapBinding(entry.value),
    };
    final childNodes = _collectChildNodes(rawProps);

    Component buildSingleChild(String childId) {
      final childNode = childNodes[childId];
      if (childNode != null) {
        return component.buildNodeCallback(childNode, nextPath);
      }
      return component.buildComponentCallback(
        childId,
        nextPath,
        dataPath: node.dataPath,
      );
    }

    final componentCtx = A2uiComponentContext(
      component: componentModel,
      props: resolvedProps,
      rawProps: rawProps,
      node: node,
      dataPath: node.dataPath,
      surfaceBloc: component.bloc,
      surfaceId: component.surfaceId,
      buildChildCallback: buildSingleChild,
      buildChildrenCallback: (ids) => ids.map(buildSingleChild).toList(),
    );

    try {
      final builtChild = component.catalog.build(context, componentCtx);
      return div(
        key: ValueKey('a2ui_$instanceId'),
        [builtChild],
      );
    } on Object catch (error) {
      return div(
        key: ValueKey('a2ui_error_$componentId'),
        [component.errorFallbackBuilder(context, componentId, error)],
      );
    }
  }
}

class _BoundComponent extends StatefulComponent {
  const _BoundComponent({
    required this.componentModel,
    required this.binder,
    required this.ancestorPath,
    required this.catalog,
    required this.bloc,
    required this.surfaceId,
    required this.surfaceVersion,
    required this.buildComponentCallback,
    required this.errorFallbackBuilder,
    this.ownsBinder = false,
    this.dataPath = '/',
    super.key,
  });

  final ComponentModel componentModel;
  final GenericBinder? binder;
  final bool ownsBinder;
  final String dataPath;
  final Set<String> ancestorPath;
  final A2uiJasprCatalog catalog;
  final A2uiSurfaceBloc bloc;
  final String surfaceId;
  final int surfaceVersion;
  final Component Function(
    String componentId,
    Set<String> ancestorPath, {
    String dataPath,
    int? index,
  }) buildComponentCallback;
  final Component Function(
    BuildContext context,
    String componentId,
    Object error,
  ) errorFallbackBuilder;

  @override
  State<_BoundComponent> createState() => _BoundComponentState();
}

class _BoundComponentState extends State<_BoundComponent> {
  void Function()? _unsubscribe;
  Map<String, dynamic>? _lastProps;

  @override
  void initState() {
    super.initState();
    _subscribeBinder();
  }

  @override
  void didUpdateComponent(_BoundComponent oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(component.binder, oldComponent.binder)) {
      if (oldComponent.ownsBinder) {
        oldComponent.binder?.dispose();
      }
      _subscribeBinder();
    }
  }

  void _subscribeBinder() {
    _unsubscribe?.call();
    _unsubscribe = null;
    final binder = component.binder;
    _lastProps = binder?.resolvedProps.value;
    if (binder != null) {
      _unsubscribe = binder.resolvedProps.subscribe((nextProps) {
        if (!identical(_lastProps, nextProps)) {
          _lastProps = nextProps;
          if (mounted) {
            setState(() {});
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unsubscribe = null;
    if (component.ownsBinder) {
      component.binder?.dispose();
    }
    super.dispose();
  }

  List<ChildNode> _collectTemplateChildNodes(Map<String, dynamic> rawProps) {
    final childNodes = <ChildNode>[];
    final children = unwrapBinding(rawProps['children']);
    if (children is Iterable) {
      for (final item in children) {
        final unwrapped = unwrapBinding(item);
        if (unwrapped is ChildNode && unwrapped.basePath != '/') {
          childNodes.add(unwrapped);
        }
      }
    }
    return childNodes;
  }

  @override
  Component build(BuildContext context) {
    final componentId = component.componentModel.id;
    final keySuffix = component.dataPath == '/' || component.dataPath.isEmpty
        ? componentId
        : '$componentId-[${component.dataPath}]';
    final nextPath = <String>{...component.ancestorPath, keySuffix};
    final rawProps = component.binder?.resolvedProps.value ??
        component.componentModel.properties;
    final resolvedProps = <String, dynamic>{
      for (final entry in rawProps.entries)
        entry.key: unwrapBinding(entry.value),
    };
    final templateChildNodes = _collectTemplateChildNodes(rawProps);

    final componentCtx = A2uiComponentContext(
      component: component.componentModel,
      props: resolvedProps,
      rawProps: rawProps,
      dataPath: component.dataPath,
      surfaceBloc: component.bloc,
      surfaceId: component.surfaceId,
      buildChildCallback: (childId) => component.buildComponentCallback(
        childId,
        nextPath,
        dataPath: component.dataPath,
      ),
      buildChildrenCallback: (ids) {
        if (templateChildNodes.length == ids.length &&
            templateChildNodes.isNotEmpty) {
          return [
            for (var i = 0; i < ids.length; i++)
              component.buildComponentCallback(
                templateChildNodes[i].id,
                nextPath,
                dataPath: templateChildNodes[i].basePath,
                index: templateChildNodes[i].index,
              ),
          ];
        }
        return ids
            .map(
              (childId) => component.buildComponentCallback(
                childId,
                nextPath,
                dataPath: component.dataPath,
              ),
            )
            .toList();
      },
    );

    try {
      final builtChild = component.catalog.build(context, componentCtx);
      return div(
        key: ValueKey('a2ui_$keySuffix'),
        [builtChild],
      );
    } on Object catch (error) {
      return div(
        key: ValueKey('a2ui_error_$componentId'),
        [component.errorFallbackBuilder(context, componentId, error)],
      );
    }
  }
}
