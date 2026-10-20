/// Pure-Dart A2UI state machine and Generative UI adapter for the BlocSignal ecosystem.
library;

import 'package:a2ui_core/a2ui_core.dart';

export 'package:a2ui_core/a2ui_core.dart'
    show
        A2uiError,
        A2uiFunctionResponse,
        A2uiFunctionResponseError,
        A2uiProtocolVersion,
        A2uiRendererAction,
        A2uiRendererError,
        A2uiReturnType,
        A2uiRpcError,
        AgentFunctionResponseMessage,
        AgentToRendererMessage,
        AllowedCallers,
        BasicCatalog,
        CallAgentFunctionMessage,
        CallOptions,
        CallRendererFunctionMessage,
        CancellationSignal,
        Catalog,
        ChildNode,
        CommonSchemas,
        CommonSchemasV1,
        ComponentApi,
        ComponentContext,
        ComponentModel,
        ComponentNode,
        CreateSurfaceMessage,
        DataBinding,
        DataContext,
        DataModel,
        DeleteSurfaceMessage,
        ExecutionContext,
        FunctionCall,
        FunctionImplementation,
        GenericBinder,
        MessageProcessor,
        NodeProps,
        NodeResolver,
        NodeState,
        OutboundMessageListener,
        RendererFunctionResponseMessage,
        RendererToAgentMessage,
        ResolvedBinding,
        RpcErrorCode,
        RpcHandler,
        SurfaceGroupModel,
        SurfaceModel,
        UpdateComponentsMessage,
        UpdateDataModelMessage,
        ValidationResult,
        WritableBinding;

export 'src/a2ui_action_response.dart';
export 'src/a2ui_surface_bloc.dart';
export 'src/a2ui_surface_event.dart';
export 'src/a2ui_surface_state.dart';
export 'src/standard_catalog.dart';

/// Backward-compatible type alias for [AgentToRendererMessage].
///
/// ```dart
/// final A2uiMessage msg = CreateSurfaceMessage(
///   version: 'v0.9',
///   surfaceId: 'surf-1',
///   catalogId: 'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json',
/// );
/// ```
typedef A2uiMessage = AgentToRendererMessage;

/// Backward-compatible type alias for [A2uiRendererAction].
///
/// ```dart
/// final action = A2uiClientAction(
///   name: 'submit',
///   surfaceId: 'surf-1',
///   sourceComponentId: 'btn-1',
///   timestamp: DateTime.utc(2026, 10, 19),
///   context: const <String, Object?>{},
/// );
/// ```
typedef A2uiClientAction = A2uiRendererAction;

/// Backward-compatible type alias for [A2uiRendererError].
///
/// ```dart
/// final error = A2uiClientError(
///   code: 'ERR_INVALID',
///   surfaceId: 'surf-1',
///   message: 'Invalid component state',
/// );
/// ```
typedef A2uiClientError = A2uiRendererError;
