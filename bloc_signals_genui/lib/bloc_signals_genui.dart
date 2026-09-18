/// Pure-Dart A2UI state machine and Generative UI adapter for the BlocSignal ecosystem.
library;

export 'package:a2ui_core/a2ui_core.dart'
    show
        A2uiClientAction,
        A2uiMessage,
        Catalog,
        ChildNode,
        ComponentApi,
        ComponentModel,
        CreateSurfaceMessage,
        DataModel,
        DeleteSurfaceMessage,
        FunctionImplementation,
        GenericBinder,
        MessageProcessor,
        MinimalCatalog,
        SurfaceGroupModel,
        SurfaceModel,
        UpdateComponentsMessage,
        UpdateDataModelMessage;

export 'src/a2ui_action_response.dart';
export 'src/a2ui_surface_bloc.dart';
export 'src/a2ui_surface_event.dart';
export 'src/a2ui_surface_state.dart';
export 'src/standard_catalog.dart';
