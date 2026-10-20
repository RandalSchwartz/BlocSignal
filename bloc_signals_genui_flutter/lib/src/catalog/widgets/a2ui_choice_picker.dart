import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `ChoicePicker` component supporting `mutuallyExclusive` and
/// `multipleSelection` variants, `checkbox` and `chips` display styles,
/// two-way data binding, and `CheckRule` validation error display.
///
/// ```dart
/// final widget = buildA2uiChoicePicker(context, componentContext);
/// ```
Widget buildA2uiChoicePicker(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final label = unwrapBinding(props['label'])?.toString();
  final variant = asString(props['variant'], 'mutuallyExclusive');
  final displayStyle = asString(props['displayStyle'], 'checkbox');
  final isMultiple = variant == 'multipleSelection';

  final rawOptions = unwrapBinding(props['options']);
  final options = <({String label, String value})>[];
  if (rawOptions is Iterable) {
    for (final rawOption in rawOptions) {
      final option = unwrapBinding(rawOption);
      if (option is Map) {
        final optValue = asString(option['value']);
        final optLabel = asString(option['label'], optValue);
        options.add((label: optLabel, value: optValue));
      }
    }
  }

  final rawValue = unwrapBinding(props['value']);
  final selectedValues = <String>{};
  if (rawValue is Iterable) {
    for (final item in rawValue) {
      final unwrappedItem = unwrapBinding(item);
      if (unwrappedItem != null) {
        selectedValues.add(unwrappedItem.toString());
      }
    }
  } else if (rawValue is String && rawValue.isNotEmpty) {
    selectedValues.add(rawValue);
  }

  void toggleOption(String optionValue, {required bool selected}) {
    final List<String> nextSelection;
    if (isMultiple) {
      final updated = Set<String>.from(selectedValues);
      if (selected) {
        updated.add(optionValue);
      } else {
        updated.remove(optionValue);
      }
      nextSelection = updated.toList();
    } else {
      nextSelection = selected ? <String>[optionValue] : <String>[];
    }
    componentContext.updateBoundValue('value', nextSelection);
  }

  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  final Widget optionsWidget;
  if (displayStyle == 'chips') {
    optionsWidget = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option.label),
            selected: selectedValues.contains(option.value),
            onSelected: (isSelected) =>
                toggleOption(option.value, selected: isSelected),
          ),
      ],
    );
  } else {
    optionsWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          CheckboxListTile(
            title: Text(option.label),
            value: selectedValues.contains(option.value),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (isSelected) =>
                toggleOption(option.value, selected: isSelected ?? false),
          ),
      ],
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null && label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      optionsWidget,
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            errorText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}
