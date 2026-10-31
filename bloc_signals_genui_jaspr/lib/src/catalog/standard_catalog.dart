import 'package:bloc_signals_genui_jaspr/src/a2ui_jaspr_catalog.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_button.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_card.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_column.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_divider.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_row.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_text.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/components/a2ui_text_field.dart';

/// Registers the 7 standard A2UI component builders into the provided
/// [catalog].
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
    ..register('Divider', buildA2uiDivider);
}
