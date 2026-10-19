import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
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
    final initialValue = asString(widget.componentContext.props['value']);
    _lastSyncedValue = initialValue;
    _controller = TextEditingController(text: initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(A2uiTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalValue = asString(widget.componentContext.props['value']);
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
    widget.componentContext.updateBoundValue('value', newValue);
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.componentContext.props;
    final label = unwrapBinding(props['label'])?.toString();
    final placeholder = unwrapBinding(props['placeholder'])?.toString();
    final helperText = unwrapBinding(props['helperText'])?.toString();
    final explicitError = unwrapBinding(props['errorText'])?.toString();
    final checkErrors = widget.componentContext.validationErrors;
    final errorText = (explicitError != null && explicitError.isNotEmpty)
        ? explicitError
        : (checkErrors.isNotEmpty ? checkErrors.first : null);

    final variant = asString(
      props['variant'] ?? props['textFieldType'],
      'shortText',
    );
    final obscureText = variant == 'obscured';
    final maxLines = variant == 'longText' ? null : 1;
    final keyboardType = switch (variant) {
      'longText' => TextInputType.multiline,
      'number' => TextInputType.number,
      _ => TextInputType.text,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        focusNode: _focusNode,
        controller: _controller,
        onChanged: _onChanged,
        obscureText: obscureText,
        maxLines: maxLines,
        keyboardType: keyboardType,
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
