import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `ChoicePicker` component using Cupertino controls:
/// [CupertinoSlidingSegmentedControl] for `mutuallyExclusive` selection and
/// Cupertino check rows for `multipleSelection`.
///
/// ```dart
/// final widget = buildCupertinoChoicePicker(context, componentContext);
/// ```
Widget buildCupertinoChoicePicker(
  BuildContext context,
  A2uiComponentContext componentContext, {
  CupertinoCatalogTokens? tokens,
}) {
  final props = componentContext.props;
  final label = unwrapBinding(props['label'])?.toString();
  final variant = asString(props['variant'], 'mutuallyExclusive');
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
  if (!isMultiple && options.isNotEmpty) {
    final segmentedChildren = <String, Widget>{
      for (final option in options)
        option.value: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            option.label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 13,
                ),
          ),
        ),
    };
    final currentSelected = selectedValues.isNotEmpty &&
            options.any((o) => o.value == selectedValues.first)
        ? selectedValues.first
        : null;

    optionsWidget = CupertinoSlidingSegmentedControl<String>(
      groupValue: currentSelected,
      children: segmentedChildren,
      onValueChanged: (val) {
        if (val != null) {
          toggleOption(val, selected: true);
        }
      },
    );
  } else {
    optionsWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in options)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final isCurrentlySelected = selectedValues.contains(option.value);
              toggleOption(option.value, selected: !isCurrentlySelected);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoCheckbox(
                    value: selectedValues.contains(option.value),
                    activeColor: tokens?.primaryColor,
                    onChanged: (isSelected) => toggleOption(
                      option.value,
                      selected: isSelected ?? false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    option.label,
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                  ),
                ],
              ),
            ),
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
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
        ),
      optionsWidget,
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
  );
}
