import 'dart:async';

import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `DateTimeInput` component supporting ISO 8601 date and time
/// selection (`enableDate` and `enableTime`), two-way data binding, and
/// `CheckRule` validation error display.
///
/// ```dart
/// final widget = buildA2uiDateTimeInput(context, componentContext);
/// ```
Widget buildA2uiDateTimeInput(
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

  Future<void> pickDateTime() async {
    final parsed = DateTime.tryParse(rawValue) ?? DateTime(2026, 10, 15, 12);
    var selectedDate = parsed;
    if (selectedDate.isBefore(firstDate)) selectedDate = firstDate;
    if (selectedDate.isAfter(lastDate)) selectedDate = lastDate;

    if (enableDate) {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );
      if (pickedDate == null || !context.mounted) return;
      selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        selectedDate.hour,
        selectedDate.minute,
      );
    }

    if (enableTime) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDate),
      );
      if (pickedTime == null || !context.mounted) return;
      selectedDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    }

    final dateStr = '${selectedDate.year}-'
        '${twoDigits(selectedDate.month)}-'
        '${twoDigits(selectedDate.day)}';
    final timeStr = '${twoDigits(selectedDate.hour)}:'
        '${twoDigits(selectedDate.minute)}:00';

    final String formatted;
    if (enableDate && enableTime) {
      formatted = '${dateStr}T$timeStr';
    } else if (!enableDate && enableTime) {
      formatted = timeStr;
    } else {
      formatted = dateStr;
    }

    componentContext.updateBoundValue('value', formatted);
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: InkWell(
      onTap: pickDateTime,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(
            enableTime && !enableDate
                ? Icons.access_time
                : Icons.calendar_today,
          ),
        ),
        child: Text(rawValue.isEmpty ? 'Select date' : rawValue),
      ),
    ),
  );
}
