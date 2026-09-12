import 'package:bloc_signals_genui_flutter/src/a2ui_flutter_catalog.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_button.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_card.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_column.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_divider.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_row.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_text.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/a2ui_text_field.dart';

/// Registers the standard A2UI component builders into the provided [catalog].
void registerStandardComponents(A2uiFlutterCatalog catalog) {
  catalog
    ..register('Text', buildA2uiText)
    ..register('Row', buildA2uiRow)
    ..register('Column', buildA2uiColumn)
    ..register('Button', buildA2uiButton)
    ..register('TextField', buildA2uiTextField)
    ..register('Card', buildA2uiCard)
    ..register('Divider', buildA2uiDivider);
}
