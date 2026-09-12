import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `TextField` component with fine-grained state updates.
class A2uiTextField extends StatefulWidget {
  /// Creates an [A2uiTextField].
  const A2uiTextField({
    required this.componentContext,
    super.key,
  });

  /// The component context holding properties and data model access.
  final A2uiComponentContext componentContext;

  @override
  State<A2uiTextField> createState() => _A2uiTextFieldState();
}

class _A2uiTextFieldState extends State<A2uiTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _lastSyncedValue = '';

  @override
  void initState() {
    super.initState();
    final initialValue =
        widget.componentContext.props['value']?.toString() ?? '';
    _lastSyncedValue = initialValue;
    _controller = TextEditingController(text: initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(A2uiTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalValue =
        widget.componentContext.props['value']?.toString() ?? '';
    // If the field is currently focused by the user, do not clobber
    // active typing.
    if (_focusNode.hasFocus) {
      return;
    }
    if (externalValue != _lastSyncedValue &&
        externalValue != _controller.text) {
      _lastSyncedValue = externalValue;
      _controller.value = _controller.value.copyWith(
        text: externalValue,
        selection: TextSelection.collapsed(offset: externalValue.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String newValue) {
    _lastSyncedValue = newValue;
    final rawProps = widget.componentContext.component.properties;
    final valueProp = rawProps['value'];
    if (valueProp is Map && valueProp.containsKey('path')) {
      final path = valueProp['path'] as String;
      widget.componentContext.updateFormField(path, newValue);
    } else {
      // Fallback path based on component ID
      final path = '/${widget.componentContext.component.id}';
      widget.componentContext.updateFormField(path, newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.componentContext.props;
    final label = props['label']?.toString();
    final placeholder = props['placeholder']?.toString();
    final helperText = props['helperText']?.toString();
    final errorText = props['errorText']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        focusNode: _focusNode,
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          helperText: helperText,
          errorText: errorText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Builder function for registering [A2uiTextField] in catalog.
Widget buildA2uiTextField(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  return A2uiTextField(componentContext: componentContext);
}
