import 'package:bloc_signals_genui_flutter/src/a2ui_flutter_catalog.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
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

/// Registers the 16 dedicated Cupertino A2UI component builders into the
/// provided [catalog].
///
/// An optional [tokens] and/or [theme] can be provided to customize accent
/// colors, typography, or corner radiuses across all registered builders.
///
/// ```dart
/// final catalog = A2uiFlutterCatalog();
/// registerCupertinoComponents(catalog);
/// ```
void registerCupertinoComponents(
  A2uiFlutterCatalog catalog, {
  CupertinoCatalogTokens? tokens,
  CupertinoThemeData? theme,
}) {
  var effectiveTheme = theme;
  if (tokens != null) {
    effectiveTheme = (effectiveTheme ?? const CupertinoThemeData()).copyWith(
      primaryColor: tokens.primaryColor,
      barBackgroundColor: tokens.barBackgroundColor,
      scaffoldBackgroundColor: tokens.scaffoldBackgroundColor,
      textTheme: tokens.textTheme,
    );
  }

  A2uiComponentWidgetBuilder wrapWithTheme(
    A2uiComponentWidgetBuilder builder,
  ) {
    if (effectiveTheme == null) return builder;
    return (context, componentContext) => CupertinoTheme(
          data: effectiveTheme!,
          child: builder(context, componentContext),
        );
  }

  catalog
    ..register('Text', wrapWithTheme(buildCupertinoText))
    ..register('Row', wrapWithTheme(buildCupertinoRow))
    ..register('Column', wrapWithTheme(buildCupertinoColumn))
    ..register(
      'Button',
      wrapWithTheme(
        (context, componentContext) => buildCupertinoButton(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'TextField',
      wrapWithTheme(
        (context, componentContext) => buildCupertinoTextField(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'Card',
      wrapWithTheme(
        (context, componentContext) => buildCupertinoCard(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register('Divider', wrapWithTheme(buildCupertinoDivider))
    ..register('List', wrapWithTheme(buildCupertinoList))
    ..register('Tabs', wrapWithTheme(buildCupertinoTabs))
    ..register('Modal', wrapWithTheme(buildCupertinoModal))
    ..register('Icon', wrapWithTheme(buildCupertinoIcon))
    ..register('Image', wrapWithTheme(buildCupertinoImage))
    ..register(
      'CheckBox',
      wrapWithTheme(
        (context, componentContext) => buildCupertinoCheckBox(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'ChoicePicker',
      wrapWithTheme(
        (context, componentContext) => buildCupertinoChoicePicker(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register(
      'Slider',
      wrapWithTheme(
        (context, componentContext) => buildCupertinoSlider(
          context,
          componentContext,
          tokens: tokens,
        ),
      ),
    )
    ..register('DateTimeInput', wrapWithTheme(buildCupertinoDateTimeInput));
}
