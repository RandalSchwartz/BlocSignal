import 'package:bloc_signals_genui_flutter/src/a2ui_flutter_catalog.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_button.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_card.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_check_box.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_choice_picker.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_column.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_date_time_input.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_divider.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_icon.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_image.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_list.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_modal.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_row.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_slider.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_tabs.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_text.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_text_field.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_button.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_card.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_check_box.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_choice_picker.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_column.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_date_time_input.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_divider.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_icon.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_image.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_list.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_modal.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_row.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_slider.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_tabs.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_text.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Returns whether the target runtime platform corresponds to an Apple design
/// ecosystem (iOS or macOS).
///
/// Defensively inspects [platformOverride] first, then falls back to
/// `Theme.maybeOf(context)?.platform`, and finally defaults to
/// [defaultTargetPlatform]. This avoids throwing exceptions in pure
/// `CupertinoApp` widget trees where no `Theme` ancestor exists (per BEL-07).
///
/// ```dart
/// if (isCupertinoPlatform(context)) {
///   print('Render Apple Cupertino UI');
/// }
/// ```
bool isCupertinoPlatform(
  BuildContext context, [
  TargetPlatform? platformOverride,
]) {
  final platform = platformOverride ??
      (() {
        try {
          return Theme.of(context).platform;
        } on Object catch (_) {
          return defaultTargetPlatform;
        }
      })();
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// Registers adaptive A2UI component builders into the provided [catalog],
/// dynamically switching between Cupertino and Material widgets depending on
/// the runtime platform or [platformOverride].
///
/// ```dart
/// final catalog = A2uiFlutterCatalog();
/// registerAdaptiveComponents(catalog);
/// ```
void registerAdaptiveComponents(
  A2uiFlutterCatalog catalog, {
  CupertinoCatalogTokens? tokens,
  CupertinoThemeData? cupertinoTheme,
  TargetPlatform? platformOverride,
}) {
  var effectiveCupertinoTheme = cupertinoTheme;
  if (tokens != null) {
    effectiveCupertinoTheme =
        (effectiveCupertinoTheme ?? const CupertinoThemeData()).copyWith(
      primaryColor: tokens.primaryColor,
      barBackgroundColor: tokens.barBackgroundColor,
      scaffoldBackgroundColor: tokens.scaffoldBackgroundColor,
      textTheme: tokens.textTheme,
    );
  }

  A2uiComponentWidgetBuilder adaptive({
    required A2uiComponentWidgetBuilder materialBuilder,
    required A2uiComponentWidgetBuilder cupertinoBuilder,
  }) {
    return (context, componentContext) {
      if (isCupertinoPlatform(context, platformOverride)) {
        final widget = cupertinoBuilder(context, componentContext);
        if (effectiveCupertinoTheme != null) {
          return CupertinoTheme(
            data: effectiveCupertinoTheme,
            child: widget,
          );
        }
        return widget;
      }
      return materialBuilder(context, componentContext);
    };
  }

  catalog
    ..register(
      'Text',
      adaptive(
        materialBuilder: buildA2uiText,
        cupertinoBuilder: buildCupertinoText,
      ),
    )
    ..register(
      'Row',
      adaptive(
        materialBuilder: buildA2uiRow,
        cupertinoBuilder: buildCupertinoRow,
      ),
    )
    ..register(
      'Column',
      adaptive(
        materialBuilder: buildA2uiColumn,
        cupertinoBuilder: buildCupertinoColumn,
      ),
    )
    ..register(
      'Button',
      adaptive(
        materialBuilder: buildA2uiButton,
        cupertinoBuilder: (context, componentContext) => buildCupertinoButton(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'TextField',
      adaptive(
        materialBuilder: buildA2uiTextField,
        cupertinoBuilder: (context, componentContext) =>
            buildCupertinoTextField(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'Card',
      adaptive(
        materialBuilder: buildA2uiCard,
        cupertinoBuilder: (context, componentContext) => buildCupertinoCard(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'Divider',
      adaptive(
        materialBuilder: buildA2uiDivider,
        cupertinoBuilder: buildCupertinoDivider,
      ),
    )
    ..register(
      'List',
      adaptive(
        materialBuilder: buildA2uiList,
        cupertinoBuilder: buildCupertinoList,
      ),
    )
    ..register(
      'Tabs',
      adaptive(
        materialBuilder: buildA2uiTabs,
        cupertinoBuilder: buildCupertinoTabs,
      ),
    )
    ..register(
      'Modal',
      adaptive(
        materialBuilder: buildA2uiModal,
        cupertinoBuilder: buildCupertinoModal,
      ),
    )
    ..register(
      'Icon',
      adaptive(
        materialBuilder: buildA2uiIcon,
        cupertinoBuilder: buildCupertinoIcon,
      ),
    )
    ..register(
      'Image',
      adaptive(
        materialBuilder: buildA2uiImage,
        cupertinoBuilder: buildCupertinoImage,
      ),
    )
    ..register(
      'CheckBox',
      adaptive(
        materialBuilder: buildA2uiCheckBox,
        cupertinoBuilder: (context, componentContext) => buildCupertinoCheckBox(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'ChoicePicker',
      adaptive(
        materialBuilder: buildA2uiChoicePicker,
        cupertinoBuilder: (context, componentContext) =>
            buildCupertinoChoicePicker(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'Slider',
      adaptive(
        materialBuilder: buildA2uiSlider,
        cupertinoBuilder: (context, componentContext) => buildCupertinoSlider(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'DateTimeInput',
      adaptive(
        materialBuilder: buildA2uiDateTimeInput,
        cupertinoBuilder: buildCupertinoDateTimeInput,
      ),
    );
}
