import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `TextField` component in the DOM.
///
/// Supports `shortText`, `longText`, `obscured`, and `number` input variants,
/// two-way binding synchronization, labels, helper texts, and validation
/// error messaging.
///
/// ```dart
/// final component = buildA2uiTextField(context, componentContext);
/// ```
Component buildA2uiTextField(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final labelText = unwrapBinding(props['label'])?.toString();
  final placeholder = unwrapBinding(props['placeholder'])?.toString();
  final helperText = unwrapBinding(props['helperText'])?.toString();
  final explicitError = unwrapBinding(props['errorText'])?.toString();
  final checkErrors = componentContext.validationErrors;
  final errorText = (explicitError != null && explicitError.isNotEmpty)
      ? explicitError
      : (checkErrors.isNotEmpty ? checkErrors.first : null);

  final variant = asString(
    props['variant'] ?? props['textFieldType'],
    'shortText',
  );
  final currentValue = asString(props['value']);

  final Component control;
  if (variant == 'longText') {
    control = textarea(
      classes: 'a2ui-input a2ui-textarea',
      placeholder: placeholder,
      onInput: (textValue) {
        componentContext.updateBoundValue('value', textValue);
      },
      styles: Styles(
        padding: const Spacing.all(Unit.pixels(8)),
        border: Border.all(
          color: errorText != null
              ? const Color('#dc2626')
              : const Color('#d1d5db'),
          width: const Unit.pixels(1),
        ),
        radius: const BorderRadius.circular(Unit.pixels(4)),
        fontFamily: const FontFamily.list([FontFamily('sans-serif')]),
        fontSize: const Unit.pixels(14),
        width: const Unit.percent(100),
        boxSizing: BoxSizing.borderBox,
      ),
      [Component.text(currentValue)],
    );
  } else {
    final inputType = switch (variant) {
      'obscured' => InputType.password,
      'number' => InputType.number,
      _ => InputType.text,
    };

    final attributes = <String, String>{
      if (placeholder != null && placeholder.isNotEmpty)
        'placeholder': placeholder,
    };

    control = input<String>(
      type: inputType,
      value: currentValue,
      classes: 'a2ui-input',
      attributes: attributes.isNotEmpty ? attributes : null,
      onInput: (textValue) {
        componentContext.updateBoundValue('value', textValue);
      },
      styles: Styles(
        padding: const Spacing.symmetric(
          vertical: Unit.pixels(8),
          horizontal: Unit.pixels(12),
        ),
        border: Border.all(
          color: errorText != null
              ? const Color('#dc2626')
              : const Color('#d1d5db'),
          width: const Unit.pixels(1),
        ),
        radius: const BorderRadius.circular(Unit.pixels(4)),
        fontFamily: const FontFamily.list([FontFamily('sans-serif')]),
        fontSize: const Unit.pixels(14),
        width: const Unit.percent(100),
        boxSizing: BoxSizing.borderBox,
      ),
    );
  }

  return div(
    classes: 'a2ui-text-field-container',
    styles: const Styles(
      margin: Spacing.symmetric(vertical: Unit.pixels(6)),
      display: Display.flex,
      flexDirection: FlexDirection.column,
    ),
    [
      if (labelText != null && labelText.isNotEmpty)
        label(
          classes: 'a2ui-label',
          styles: const Styles(
            fontSize: Unit.pixels(14),
            fontWeight: FontWeight.w600,
            margin: Spacing.only(bottom: Unit.pixels(4)),
            color: Color('#374151'),
          ),
          [Component.text(labelText)],
        ),
      control,
      if (errorText != null)
        span(
          classes: 'a2ui-error-text',
          styles: const Styles(
            color: Color('#dc2626'),
            fontSize: Unit.pixels(12),
            margin: Spacing.only(top: Unit.pixels(4)),
          ),
          [Component.text(errorText)],
        )
      else if (helperText != null && helperText.isNotEmpty)
        span(
          classes: 'a2ui-helper-text',
          styles: const Styles(
            color: Color('#6b7280'),
            fontSize: Unit.pixels(12),
            margin: Spacing.only(top: Unit.pixels(4)),
          ),
          [Component.text(helperText)],
        ),
    ],
  );
}
