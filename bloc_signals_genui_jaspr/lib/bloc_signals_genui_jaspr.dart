/// Jaspr web component bindings, declarative surface views, and HTML DOM
/// catalog adapters for Generative UI (A2UI) with BlocSignal.
///
/// ```dart
/// import 'package:bloc_signals_genui/bloc_signals_genui.dart';
/// import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
/// import 'package:jaspr/jaspr.dart';
///
/// Component buildSurface(A2uiSurfaceBloc bloc) {
///   return A2uiSurfaceView(
///     bloc: bloc,
///     catalog: A2uiJasprCatalog.standard(),
///   );
/// }
/// ```
library;

export 'src/a2ui_component_context.dart';
export 'src/a2ui_jaspr_catalog.dart';
export 'src/a2ui_surface_view.dart';
export 'src/catalog/components/a2ui_button.dart';
export 'src/catalog/components/a2ui_card.dart';
export 'src/catalog/components/a2ui_column.dart';
export 'src/catalog/components/a2ui_divider.dart';
export 'src/catalog/components/a2ui_row.dart';
export 'src/catalog/components/a2ui_text.dart';
export 'src/catalog/components/a2ui_text_field.dart';
export 'src/catalog/safe_prop_parser.dart';
export 'src/catalog/standard_catalog.dart';
