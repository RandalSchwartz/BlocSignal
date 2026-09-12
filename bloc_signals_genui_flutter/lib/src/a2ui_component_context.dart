import 'package:a2ui_core/a2ui_core.dart';
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
  });

  /// The underlying A2UI [ComponentModel].
  final ComponentModel component;

  /// The resolved dynamic properties for this component.
  final Map<String, dynamic> props;

  /// The parent [A2uiSurfaceBloc] orchestrating this surface.
  final A2uiSurfaceBloc surfaceBloc;

  /// The active surface identifier.
  final String surfaceId;

  /// Internal callback to recursively render a child component by its ID.
  final Widget Function(String childId) buildChildCallback;

  /// Internal callback to recursively render a list of child component IDs.
  final List<Widget> Function(List<String> childIds) buildChildrenCallback;

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
}
