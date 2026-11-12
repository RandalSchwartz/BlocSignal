import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `ChoicePicker` component supporting `mutuallyExclusive` and
/// `multipleSelection` variants, `checkbox` and `chips` display styles,
/// `filterable` option search, two-way data binding, and `CheckRule`
/// validation error display.
///
/// ```dart
/// final component = buildA2uiChoicePicker(context, componentContext);
/// ```
Component buildA2uiChoicePicker(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  return _A2uiChoicePicker(componentContext: componentContext);
}

class _A2uiChoicePicker extends StatefulComponent {
  const _A2uiChoicePicker({
    required this.componentContext,
  });

  final A2uiComponentContext componentContext;

  @override
  State<_A2uiChoicePicker> createState() => _A2uiChoicePickerState();
}

class _A2uiChoicePickerState extends State<_A2uiChoicePicker> {
  String _query = '';

  @override
  Component build(BuildContext context) {
    final componentContext = component.componentContext;
    final props = componentContext.props;
    final labelText = unwrapBinding(props['label'])?.toString();
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

    final normalized = _query.trim().toLowerCase();
    final displayed = !filterable || normalized.isEmpty
        ? options
        : options
            .where(
              (entry) =>
                  entry.label.toLowerCase().contains(normalized) ||
                  entry.value.toLowerCase().contains(normalized),
            )
            .toList();

    final checkErrors = componentContext.validationErrors;
    final errorText = !componentContext.isValid && checkErrors.isNotEmpty
        ? checkErrors.first
        : null;

    final Component optionsComponent;
    if (displayStyle == 'chips') {
      optionsComponent = div(
        classes: 'a2ui-choice-chips',
        styles: const Styles(
          display: Display.flex,
          flexWrap: FlexWrap.wrap,
        ),
        [
          for (final option in displayed)
            button(
              classes: selectedValues.contains(option.value)
                  ? 'a2ui-choice-chip a2ui-choice-chip-selected'
                  : 'a2ui-choice-chip',
              attributes: {
                'aria-pressed':
                    selectedValues.contains(option.value).toString(),
              },
              onClick: () {
                final isSelected = selectedValues.contains(option.value);
                toggleOption(option.value, selected: !isSelected);
              },
              styles: Styles(
                margin: const Spacing.only(
                  right: Unit.pixels(8),
                  bottom: Unit.pixels(8),
                ),
                padding: const Spacing.symmetric(
                  vertical: Unit.pixels(6),
                  horizontal: Unit.pixels(12),
                ),
                radius: const BorderRadius.circular(Unit.pixels(16)),
                border: Border.all(
                  color: selectedValues.contains(option.value)
                      ? const Color('#2563eb')
                      : const Color('#d1d5db'),
                  width: const Unit.pixels(1),
                ),
                backgroundColor: selectedValues.contains(option.value)
                    ? const Color('#dbeafe')
                    : Colors.white,
                cursor: Cursor.pointer,
              ),
              [Component.text(option.label)],
            ),
        ],
      );
    } else {
      optionsComponent = div(
        classes: 'a2ui-choice-list',
        styles: const Styles(
          display: Display.flex,
          flexDirection: FlexDirection.column,
        ),
        [
          for (final option in displayed)
            label(
              classes: 'a2ui-choice-option',
              styles: const Styles(
                display: Display.inlineFlex,
                alignItems: AlignItems.center,
                margin: Spacing.only(bottom: Unit.pixels(4)),
                cursor: Cursor.pointer,
              ),
              [
                input<bool>(
                  type: isMultiple ? InputType.checkbox : InputType.radio,
                  checked: selectedValues.contains(option.value),
                  name: isMultiple
                      ? null
                      : 'a2ui_choice_${componentContext.component.id}',
                  onChange: (isSelected) =>
                      toggleOption(option.value, selected: isSelected),
                  styles: const Styles(
                    margin: Spacing.only(right: Unit.pixels(8)),
                  ),
                ),
                Component.text(option.label),
              ],
            ),
        ],
      );
    }

    return div(
      classes: 'a2ui-choice-picker',
      styles: const Styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        margin: Spacing.symmetric(vertical: Unit.pixels(6)),
      ),
      [
        if (labelText != null && labelText.isNotEmpty)
          span(
            classes: 'a2ui-label',
            styles: const Styles(
              fontSize: Unit.pixels(14),
              fontWeight: FontWeight.w600,
              margin: Spacing.only(bottom: Unit.pixels(6)),
              color: Color('#374151'),
            ),
            [Component.text(labelText)],
          ),
        if (filterable)
          input<String>(
            type: InputType.search,
            value: _query,
            classes: 'a2ui-choice-filter',
            attributes: const {'placeholder': 'Filter options...'},
            onInput: (queryValue) {
              setState(() {
                _query = queryValue;
              });
            },
            styles: const Styles(
              margin: Spacing.only(bottom: Unit.pixels(8)),
              padding: Spacing.symmetric(
                vertical: Unit.pixels(6),
                horizontal: Unit.pixels(10),
              ),
              border: Border.all(
                color: Color('#d1d5db'),
                width: Unit.pixels(1),
              ),
              radius: BorderRadius.circular(Unit.pixels(4)),
            ),
          ),
        optionsComponent,
        if (errorText != null)
          span(
            classes: 'a2ui-error-text',
            styles: const Styles(
              color: Color('#dc2626'),
              fontSize: Unit.pixels(12),
              margin: Spacing.only(top: Unit.pixels(4)),
            ),
            [Component.text(errorText)],
          ),
      ],
    );
  }
}
