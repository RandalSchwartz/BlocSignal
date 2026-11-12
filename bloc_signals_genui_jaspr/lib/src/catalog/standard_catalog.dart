import 'package:bloc_signals_genui_jaspr/src/a2ui_jaspr_catalog.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_button.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_card.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_check_box.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_choice_picker.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_column.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_date_time_input.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_divider.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_icon.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_image.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_list.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_modal.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_row.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_slider.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_tabs.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_text.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_text_field.dart';

/// Registers the 16 standard A2UI `BasicCatalog` component builders into the
/// provided [catalog].
///
/// ```dart
/// final catalog = A2uiJasprCatalog();
/// registerStandardComponents(catalog);
/// ```
void registerStandardComponents(A2uiJasprCatalog catalog) {
  catalog
    ..register('Text', buildA2uiText)
    ..register('Row', buildA2uiRow)
    ..register('Column', buildA2uiColumn)
    ..register('Button', buildA2uiButton)
    ..register('TextField', buildA2uiTextField)
    ..register('Card', buildA2uiCard)
    ..register('Divider', buildA2uiDivider)
    ..register('List', buildA2uiList)
    ..register('Tabs', buildA2uiTabs)
    ..register('Modal', buildA2uiModal)
    ..register('Icon', buildA2uiIcon)
    ..register('Image', buildA2uiImage)
    ..register('CheckBox', buildA2uiCheckBox)
    ..register('ChoicePicker', buildA2uiChoicePicker)
    ..register('Slider', buildA2uiSlider)
    ..register('DateTimeInput', buildA2uiDateTimeInput);
}
