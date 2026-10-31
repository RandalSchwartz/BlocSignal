import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `TextField` component using [CupertinoTextField] with
/// fine-grained state updates.
class A2uiCupertinoTextField extends StatefulWidget {
  /// Creates an [A2uiCupertinoTextField].
  const A2uiCupertinoTextField({
    required this.componentContext,
    this.tokens,
    super.key,
  });

  /// The component context holding properties and data model access.
  final A2uiComponentContext componentContext;

  /// Optional design tokens for custom styling.
  final CupertinoCatalogTokens? tokens;

  @override
  State<A2uiCupertinoTextField> createState() => _A2uiCupertinoTextFieldState();
}

class _A2uiCupertinoTextFieldState extends State<A2uiCupertinoTextField> {
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
  void didUpdateWidget(A2uiCupertinoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalValue = asString(widget.componentContext.props['value']);
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

    final borderRadius = widget.tokens?.borderRadius ??
        const BorderRadius.all(Radius.circular(8));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null && label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                label,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
              ),
            ),
          CupertinoTextField(
            focusNode: _focusNode,
            controller: _controller,
            onChanged: _onChanged,
            obscureText: obscureText,
            maxLines: maxLines,
            keyboardType: keyboardType,
            placeholder: placeholder,
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.tertiarySystemFill,
                context,
              ),
              borderRadius: borderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          if (helperText != null && helperText.isNotEmpty && errorText == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                helperText,
                style: CupertinoTheme.of(context)
                    .textTheme
                    .tabLabelTextStyle
                    .copyWith(fontSize: 12),
              ),
            ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText,
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Builder function for registering [A2uiCupertinoTextField] in catalog.
Widget buildCupertinoTextField(
  BuildContext context,
  A2uiComponentContext componentContext, {
  CupertinoCatalogTokens? tokens,
}) {
  return A2uiCupertinoTextField(
    componentContext: componentContext,
    tokens: tokens,
  );
}
