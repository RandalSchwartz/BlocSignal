import 'dart:async';

import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `DateTimeInput` component using [CupertinoDatePicker] and
/// [showCupertinoModalPopup] supporting ISO 8601 date and time selection
/// (`enableDate` and `enableTime`), two-way data binding, and `CheckRule`
/// validation error display.
///
/// ```dart
/// final widget = buildCupertinoDateTimeInput(context, componentContext);
/// ```
Widget buildCupertinoDateTimeInput(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final label = unwrapBinding(props['label'])?.toString();
  final rawValue = asString(props['value']);
  final enableDate = asBool(props['enableDate'], defaultValue: true);
  final enableTime = asBool(props['enableTime']);
  final minDate = DateTime.tryParse(asString(props['min'])) ?? DateTime(1900);
  final maxDate = DateTime.tryParse(asString(props['max'])) ?? DateTime(2100);
  final firstDate = minDate.isBefore(maxDate) ? minDate : DateTime(1900);
  final lastDate = maxDate.isAfter(firstDate) ? maxDate : DateTime(2100);

  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  String formatDateTime(DateTime dt) {
    final dateStr = '${dt.year}-'
        '${twoDigits(dt.month)}-'
        '${twoDigits(dt.day)}';
    final timeStr = '${twoDigits(dt.hour)}:'
        '${twoDigits(dt.minute)}:00';

    if (enableDate && enableTime) {
      return '${dateStr}T$timeStr';
    } else if (!enableDate && enableTime) {
      return timeStr;
    }
    return dateStr;
  }

  void pickDateTime() {
    final parsed = DateTime.tryParse(rawValue) ?? DateTime(2026, 10, 15, 12);
    var selectedDate = parsed;
    if (selectedDate.isBefore(firstDate)) selectedDate = firstDate;
    if (selectedDate.isAfter(lastDate)) selectedDate = lastDate;

    final CupertinoDatePickerMode mode;
    if (enableDate && enableTime) {
      mode = CupertinoDatePickerMode.dateAndTime;
    } else if (!enableDate && enableTime) {
      mode = CupertinoDatePickerMode.time;
    } else {
      mode = CupertinoDatePickerMode.date;
    }

    unawaited(
      showCupertinoModalPopup<void>(
        context: context,
        builder: (modalContext) => Container(
          height: 280,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground,
            modalContext,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(modalContext).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: mode,
                  initialDateTime: selectedDate,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (newDateTime) {
                    selectedDate = newDateTime;
                    componentContext.updateBoundValue(
                      'value',
                      formatDateTime(selectedDate),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final borderSide = BorderSide(
    color: errorText != null
        ? CupertinoColors.destructiveRed
        : CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
  );

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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: pickDateTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.fromBorderSide(borderSide),
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.tertiarySystemFill,
                context,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rawValue.isEmpty ? 'Select date' : rawValue,
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
                Icon(
                  enableTime && !enableDate
                      ? CupertinoIcons.time
                      : CupertinoIcons.calendar,
                  size: 20,
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.secondaryLabel,
                    context,
                  ),
                ),
              ],
            ),
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
