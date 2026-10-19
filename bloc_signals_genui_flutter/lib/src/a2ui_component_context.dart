import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/src/a2ui_flutter_catalog.dart';
import 'package:flutter/widgets.dart';

/// Context provided to component builders in [A2uiFlutterCatalog].
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
  });

  /// The underlying A2UI [ComponentModel].
  final ComponentModel component;

  /// The resolved dynamic properties for this component.
  final Map<String, dynamic> props;

  /// The raw binder properties before unwrapping [ResolvedBinding] and
  /// [WritableBinding] instances.
  final Map<String, dynamic> rawProps;

  /// The parent [A2uiSurfaceBloc] orchestrating this surface.
  final A2uiSurfaceBloc surfaceBloc;

  /// The active surface identifier.
  final String surfaceId;

  /// Internal callback to recursively render a child component by its ID.
  final Widget Function(String childId) buildChildCallback;

  /// Internal callback to recursively render a list of child component IDs.
  final List<Widget> Function(List<String> childIds) buildChildrenCallback;

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
  /// back to [fallbackPath] or `'/${component.id}'`.
  ///
  /// ```dart
  /// final path = componentContext.resolveBoundPath('value');
  /// ```
  String resolveBoundPath(String propKey, {String? fallbackPath}) {
    final rawBinding = rawProps[propKey];
    if (rawBinding is WritableBinding && rawBinding.path.isNotEmpty) {
      return rawBinding.path;
    }
    final rawProp = component.properties[propKey];
    if (rawProp is Map &&
        (rawProp.containsKey('path') || rawProp.containsKey('@path'))) {
      final path = (rawProp['path'] ?? rawProp['@path'])?.toString();
      if (path != null && path.isNotEmpty) {
        return path;
      }
    }
    return fallbackPath ?? '/${component.id}';
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
  Widget buildChild(String childId) => buildChildCallback(childId);

  /// Recursively renders a list of child components with [childIds].
  List<Widget> buildChildren(List<String> childIds) =>
      buildChildrenCallback(childIds);

  /// Dispatches a form field update event synchronously to the [surfaceBloc].
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
  /// // Example: aborting action from a cancellation button or timeout
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
  /// // Example: completing action after backend acknowledgment
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
  /// // Example: navigating from a catalog tab button
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
  /// // Example: dismissing the current modal surface
  /// componentContext.closeSurface();
  ///
  /// // Example: closing a specific background surface
  /// componentContext.closeSurface('surf_sidebar');
  /// ```
  void closeSurface([String? targetSurfaceId]) {
    surfaceBloc.add(
      CloseSurface(
        surfaceId: targetSurfaceId ?? surfaceId,
      ),
    );
  }
}
