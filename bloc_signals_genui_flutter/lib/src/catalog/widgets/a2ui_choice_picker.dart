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
    if (displayStyle == 'chips') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in displayed)
            FilterChip(
              label: Text(option.label),
              selected: selectedValues.contains(option.value),
              onSelected: (isSelected) =>
                  toggleOption(option.value, selected: isSelected),
            ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in displayed)
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
      if (filterable)
        _MaterialFilterableOptions(
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}

class _MaterialFilterableOptions extends StatefulWidget {
  const _MaterialFilterableOptions({
    required this.options,
    required this.builder,
  });

  final List<({String label, String value})> options;
  final Widget Function(List<({String label, String value})> options) builder;

  @override
  State<_MaterialFilterableOptions> createState() =>
      _MaterialFilterableOptionsState();
}

class _MaterialFilterableOptionsState
    extends State<_MaterialFilterableOptions> {
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
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Filter options...',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        widget.builder(filtered),
      ],
    );
  }
}
