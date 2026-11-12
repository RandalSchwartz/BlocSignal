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
  final filterable = asBool(props['filterable']);
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

  Widget buildOptions(List<({String label, String value})> displayed) {
    if (!isMultiple && displayed.length >= 2) {
      final segmentedChildren = <String, Widget>{
        for (final option in displayed)
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
              displayed.any((o) => o.value == selectedValues.first)
          ? selectedValues.first
          : null;

      return CupertinoSlidingSegmentedControl<String>(
        groupValue: currentSelected,
        children: segmentedChildren,
        onValueChanged: (val) {
          if (val != null) {
            toggleOption(val, selected: true);
          }
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in displayed)
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
      if (filterable)
        _CupertinoFilterableOptions(
          options: options,
          builder: buildOptions,
        )
      else
        buildOptions(options),
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

class _CupertinoFilterableOptions extends StatefulWidget {
  const _CupertinoFilterableOptions({
    required this.options,
    required this.builder,
  });

  final List<({String label, String value})> options;
  final Widget Function(List<({String label, String value})> options) builder;

  @override
  State<_CupertinoFilterableOptions> createState() =>
      _CupertinoFilterableOptionsState();
}

class _CupertinoFilterableOptionsState
    extends State<_CupertinoFilterableOptions> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? widget.options
        : widget.options
            .where(
              (o) =>
                  o.label.toLowerCase().contains(normalized) ||
                  o.value.toLowerCase().contains(normalized),
            )
            .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CupertinoSearchTextField(
            controller: _controller,
            placeholder: 'Filter options...',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        widget.builder(filtered),
      ],
    );
  }
}
