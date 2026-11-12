import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Context provided to component builders in Jaspr web catalogs.
///
/// Encapsulates the target [component], resolved [props], the host
/// [surfaceBloc], and helper methods to render child components or
/// dispatch user interactions.
class A2uiComponentContext {
  /// Creates an [A2uiComponentContext].
  const A2uiComponentContext({
    required this.component,
    required this.props,
    required this.surfaceBloc,
    required this.buildChildCallback,
    required this.buildChildrenCallback,
    required this.surfaceId,
    this.rawProps = const {},
    this.node,
    this.dataPath = '/',
  });

  /// The underlying A2UI [ComponentModel].
  final ComponentModel component;

  /// The resolved dynamic properties for this component.
  final Map<String, dynamic> props;

  /// The raw binder properties before unwrapping [ResolvedBinding] and
  /// [WritableBinding] instances.
  final Map<String, dynamic> rawProps;

  /// The optional resolved [ComponentNode] when rendered via [NodeResolver].
  ///
  /// ```dart
  /// final instanceId = componentContext.node?.instanceId;
  /// ```
  final ComponentNode<ComponentApi>? node;

  /// The optional component-level `metadata` envelope (A2UI 1.0+), resolved
  /// from [node] when available or [ComponentModel.metadata] otherwise.
  ///
  /// ```dart
  /// final meta = componentContext.metadata;
  /// ```
  Map<String, Object?>? get metadata =>
      node?.metadata.value ?? component.metadata;

  /// The data model scope path this component resolves against (for example
  /// `'/'` at the surface root or `'/items/0'` inside a template list item).
  ///
  /// ```dart
  /// final scope = componentContext.dataPath;
  /// ```
  final String dataPath;

  /// The parent [A2uiSurfaceBloc] orchestrating this surface.
  final A2uiSurfaceBloc surfaceBloc;

  /// The active surface identifier.
  final String surfaceId;

  /// Internal callback to recursively render a child component by its ID.
  final Component Function(String childId) buildChildCallback;

  /// Internal callback to recursively render a list of child component IDs.
  final List<Component> Function(List<String> childIds) buildChildrenCallback;

  /// Whether this component currently passes all attached `CheckRule`
  /// validations.
  ///
  /// Defaults to `true` when no validation rules fail.
  ///
  /// ```dart
  /// final valid = componentContext.isValid;
  /// ```
  bool get isValid {
    final rawValid = props['isValid'];
    if (rawValid is bool) return rawValid;
    return validationErrors.isEmpty;
  }

  /// The list of error messages produced by failing `CheckRule` validations on
  /// this component.
  ///
  /// ```dart
  /// final errors = componentContext.validationErrors;
  /// ```
  List<String> get validationErrors {
    final rawErrors = props['validationErrors'];
    if (rawErrors is Iterable) {
      return List<String>.unmodifiable(
        rawErrors
            .where((item) => item != null)
            .map((item) => item.toString())
            .where((msg) => msg.isNotEmpty),
      );
    }
    return const <String>[];
  }

  /// The structured [ValidationResult] records produced by failing `CheckRule`
  /// validations on this component.
  ///
  /// ```dart
  /// final results = componentContext.validationResults;
  /// ```
  List<ValidationResult> get validationResults {
    final rawResults = props['validationResults'];
    if (rawResults is Iterable) {
      return List<ValidationResult>.unmodifiable(
        rawResults.whereType<ValidationResult>(),
      );
    }
    return const <ValidationResult>[];
  }

  /// Resolves the bound data model path for [propKey].
  ///
  /// Inspects [rawProps] for a [WritableBinding], then checks
  /// [ComponentModel.properties] for a `path` or `@path` binding map, falling
  /// back to [fallbackPath] or `'/${component.id}'` (scoped to [dataPath]).
  ///
  /// ```dart
  /// final path = componentContext.resolveBoundPath('value');
  /// ```
  String resolveBoundPath(String propKey, {String? fallbackPath}) {
    final rawBinding = rawProps[propKey];
    if (rawBinding is WritableBinding && rawBinding.path.isNotEmpty) {
      return _resolveOrScopePath(rawBinding.path);
    }
    final rawProp = component.properties[propKey];
    if (rawProp is Map &&
        (rawProp.containsKey('path') || rawProp.containsKey('@path'))) {
      final rawPath = (rawProp['path'] ?? rawProp['@path'])?.toString();
      if (rawPath != null && rawPath.isNotEmpty) {
        return _resolveOrScopePath(rawPath);
      }
    }
    if (fallbackPath != null) {
      if (!fallbackPath.startsWith('/') && dataPath != '/') {
        return _scopeRelativePath(fallbackPath);
      }
      return fallbackPath;
    }
    return _scopeRelativePath(component.id);
  }

  String _resolveOrScopePath(String rawPath) {
    if (!rawPath.startsWith('/')) {
      return node?.context?.dataContext.resolvePath(rawPath) ??
          _scopeRelativePath(rawPath);
    }
    return rawPath;
  }

  String _scopeRelativePath(String relativePath) {
    if (dataPath == '/' || dataPath.isEmpty) {
      return '/$relativePath';
    }
    return '$dataPath/$relativePath';
  }

  /// Updates the two-way bound data model value for [propKey] with [newValue]
  /// synchronously via [updateFormField].
  ///
  /// ```dart
  /// componentContext.updateBoundValue('value', true);
  /// ```
  void updateBoundValue(
    String propKey,
    Object? newValue, {
    String? fallbackPath,
  }) {
    final path = resolveBoundPath(propKey, fallbackPath: fallbackPath);
    updateFormField(path, newValue);
  }

  /// Recursively renders a child component with the specified [childId].
  ///
  /// ```dart
  /// final childComponent = componentContext.buildChild('child_1');
  /// ```
  Component buildChild(String childId) => buildChildCallback(childId);

  /// Recursively renders a list of child components with [childIds].
  ///
  /// ```dart
  /// final children = componentContext.buildChildren(['child_1', 'child_2']);
  /// ```
  List<Component> buildChildren(List<String> childIds) =>
      buildChildrenCallback(childIds);

  /// Recursively renders [childIds] and wraps any child declaring a positive
  /// finite `weight` in a `div` with `flex-grow` matching `weight`.
  ///
  /// Intended for `Row` and `Column` flex containers.
  ///
  /// ```dart
  /// final children = componentContext.buildWeightedChildren(childIds);
  /// ```
  List<Component> buildWeightedChildren(List<String> childIds) {
    final built = buildChildren(childIds);
    if (childIds.isEmpty) return built;

    final childNodeWeights = <String, Object?>{};
    final currentNode = node;
    if (currentNode != null) {
      void collect(Object? valueNode) {
        final unwrapped = unwrapBinding(valueNode);
        if (unwrapped is ComponentNode<ComponentApi>) {
          final weight = unwrapBinding(unwrapped.props.value['weight']);
          childNodeWeights[unwrapped.instanceId] = weight;
          childNodeWeights.putIfAbsent(unwrapped.componentId, () => weight);
        } else if (unwrapped is Iterable) {
          unwrapped.forEach(collect);
        } else if (unwrapped is Map) {
          unwrapped.values.forEach(collect);
        }
      }

      currentNode.props.value.values.forEach(collect);
    }

    final componentsModel =
        surfaceBloc.getSurfaceReady(surfaceId)?.surface.componentsModel;

    return [
      for (var index = 0; index < built.length; index++)
        _wrapWithWeight(
          built[index],
          index < childIds.length
              ? (childNodeWeights.containsKey(childIds[index])
                  ? childNodeWeights[childIds[index]]
                  : unwrapBinding(
                      componentsModel
                          ?.get(childIds[index])
                          ?.properties['weight'],
                    ))
              : null,
        ),
    ];
  }

  Component _wrapWithWeight(Component child, Object? rawWeight) {
    if (rawWeight is num && rawWeight.isFinite && rawWeight > 0) {
      return div(
        classes: 'a2ui-weighted-child',
        styles: Styles(
          flex: Flex(grow: rawWeight.toDouble()),
        ),
        [child],
      );
    }
    return child;
  }

  /// Executes the resolved `action` on this component, invoking [NodeAction]
  /// closures when present and preserving [SubmitAction] dispatch for event
  /// actions and raw `Map` / `String` payloads.
  ///
  /// ```dart
  /// componentContext.triggerAction();
  /// ```
  void triggerAction() {
    final rawAction = props['action'];
    final modelAction = component.properties['action'];

    if (rawAction is NodeAction) {
      unawaited(rawAction());
      final isFunctionCall = modelAction is Map &&
          (modelAction['functionCall'] is Map || modelAction['call'] != null);
      if (!isFunctionCall && (modelAction is Map || modelAction is String)) {
        _dispatchParsedAction(modelAction);
      }
      return;
    }

    final sourceAction =
        rawAction is Map || rawAction is String ? rawAction : modelAction;
    _dispatchParsedAction(sourceAction);
  }

  void _dispatchParsedAction(Object? sourceAction) {
    var actionName = 'submit';
    var actionContext = const <String, dynamic>{};

    if (sourceAction is Map) {
      final eventMap =
          sourceAction['event'] is Map ? sourceAction['event'] as Map : null;
      if (eventMap != null) {
        actionName = eventMap['name']?.toString() ?? 'submit';
        if (eventMap['context'] is Map) {
          actionContext = Map<String, dynamic>.from(eventMap['context'] as Map);
        }
      } else if (sourceAction['name'] != null) {
        actionName = sourceAction['name'].toString();
      }

      if (actionContext.isEmpty && sourceAction['context'] is Map) {
        actionContext =
            Map<String, dynamic>.from(sourceAction['context'] as Map);
      }
    } else if (sourceAction is String) {
      actionName = sourceAction;
    }

    dispatchAction(actionName, context: actionContext);
  }

  /// Dispatches a form field update event synchronously to the [surfaceBloc].
  ///
  /// ```dart
  /// componentContext.updateFormField('/user/name', 'Alice');
  /// ```
  void updateFormField(String path, Object? value) {
    surfaceBloc.add(
      UpdateFormField(
        path: path,
        value: value,
        surfaceId: surfaceId,
      ),
    );
  }

  /// Dispatches an action submission event back to the [surfaceBloc].
  ///
  /// ```dart
  /// componentContext.dispatchAction('submitForm');
  /// ```
  void dispatchAction(
    String actionName, {
    Map<String, dynamic> context = const {},
  }) {
    surfaceBloc.add(
      SubmitAction(
        actionName: actionName,
        sourceComponentId: component.id,
        surfaceId: surfaceId,
        context: context,
      ),
    );
  }

  /// Cancels an in-flight action submission, restoring the surface to
  /// [SurfaceReady] and preserving entered form field inputs.
  ///
  /// If [error] is provided, it is appended to [SurfaceReady.validationErrors]
  /// and [SurfaceReady.isValid] is set to `false`.
  ///
  /// ```dart
  /// componentContext.cancelSubmission(
  ///   error: 'Submission cancelled by user.',
  /// );
  /// ```
  void cancelSubmission({String? error}) {
    surfaceBloc.add(
      CancelSubmission(
        error: error,
        surfaceId: surfaceId,
      ),
    );
  }

  /// Completes an in-flight action submission, returning the surface to
  /// [SurfaceReady].
  ///
  /// If [error] is provided, the action is marked as failed:
  /// [SurfaceReady.isValid] becomes `false` and [error] is appended to
  /// [SurfaceReady.validationErrors].
  /// If [error] is null, the action succeeded without streaming new UI.
  ///
  /// ```dart
  /// componentContext.completeAction();
  /// ```
  void completeAction({String? error}) {
    surfaceBloc.add(
      CompleteAction(
        error: error,
        surfaceId: surfaceId,
      ),
    );
  }

  /// Dispatches a surface selection event to [surfaceBloc], activating
  /// [targetSurfaceId].
  ///
  /// ```dart
  /// componentContext.selectSurface('surf_budget');
  /// ```
  void selectSurface(String targetSurfaceId) {
    surfaceBloc.add(
      SelectSurface(
        surfaceId: targetSurfaceId,
      ),
    );
  }

  /// Dispatches a [CloseSurface] event to [surfaceBloc], closing and evicting
  /// [targetSurfaceId] (or this component's [surfaceId] when omitted).
  ///
  /// ```dart
  /// componentContext.closeSurface();
  /// ```
  void closeSurface([String? targetSurfaceId]) {
    surfaceBloc.add(
      CloseSurface(
        surfaceId: targetSurfaceId ?? surfaceId,
      ),
    );
  }
}
