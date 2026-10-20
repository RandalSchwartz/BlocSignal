import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;
import 'package:test/test.dart';

class _OpenUrlFunction extends FunctionImplementation {
  _OpenUrlFunction(this.onCalled)
      : super(
          name: 'openUrl',
          returnType: A2uiReturnType.boolean,
          allowedCallers: AllowedCallers.rendererOrAgent,
          argumentSchema: Schema.object(
            properties: {
              'url': Schema.string(),
            },
            required: ['url'],
          ),
        );

  final void Function(String url) onCalled;

  @override
  Object? execute(
    Map<String, Object?> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) {
    final url = args['url']?.toString() ?? '';
    onCalled(url);
    return true;
  }
}

void main() {
  const customCatalogId = 'https://custom.catalog/v1/rpc_catalog.json';

  Catalog<ComponentApi, FunctionImplementation> buildRpcCatalog(
    void Function(String url) onOpenUrl,
  ) {
    return Catalog<ComponentApi, FunctionImplementation>(
      id: customCatalogId,
      protocolVersion: A2uiProtocolVersion.v1_0,
      components: [
        StandardTextApi(),
        StandardColumnApi(),
      ],
      functions: [
        _OpenUrlFunction(onOpenUrl),
      ],
    );
  }

  group('(Issue #370) Bidirectional RPC Integration in A2uiSurfaceBloc', () {
    test(
      'Scenario: Inbound CallRendererFunctionMessage executes registered '
      'catalog function and emits RendererFunctionResponseMessage',
      () async {
        final openedUrls = <String>[];
        final listenerMessages = <RendererToAgentMessage>[];
        final bloc = A2uiSurfaceBloc(
          catalogs: [buildRpcCatalog(openedUrls.add)],
          outboundListener: listenerMessages.add,
        );
        addTearDown(bloc.close);

        final streamMessages = <RendererToAgentMessage>[];
        final sub = bloc.outboundMessages.listen(streamMessages.add);
        addTearDown(sub.cancel);

        final responseFuture = bloc.outboundMessages.first;

        bloc
          ..add(
            ProcessMessage(
              CreateSurfaceMessage(
                version: 'v1.0',
                surfaceId: 'surf-1',
                catalogId: customCatalogId,
                components: const [
                  {
                    'id': 'root',
                    'component': 'Text',
                    'text': 'Active Surface',
                  },
                ],
              ),
            ),
          )
          ..add(
            ProcessMessage(
              CallRendererFunctionMessage(
                version: 'v1.0',
                surfaceId: 'surf-1',
                functionCallId: 'call-1',
                callFunction: const {
                  '@call': 'openUrl',
                  'catalogId': customCatalogId,
                  'args': {'url': 'https://blocsignal.dev'},
                },
              ),
            ),
          );

        final firstOutbound = await responseFuture;
        expect(firstOutbound, isA<RendererFunctionResponseMessage>());

        expect(openedUrls, equals(['https://blocsignal.dev']));
        expect(listenerMessages, hasLength(1));
        expect(listenerMessages.first, isA<RendererFunctionResponseMessage>());
        final reply = listenerMessages.first as RendererFunctionResponseMessage;
        expect(reply.response.functionCallId, equals('call-1'));
        expect(reply.response.value, isTrue);
        expect(reply.response.error, isNull);

        expect(streamMessages, hasLength(1));
        expect(
          (streamMessages.first as RendererFunctionResponseMessage)
              .response
              .functionCallId,
          equals('call-1'),
        );
        expect(bloc.outboundMessageHistory, hasLength(1));
        expect(bloc.rpc, same(bloc.processor.rpc));
      },
    );

    test(
      'Scenario: Outbound callAgentFunction sends CallAgentFunctionMessage '
      'and resolves when AgentFunctionResponseMessage arrives',
      () async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        final outbound = <RendererToAgentMessage>[];
        final firstMsgCompleter = Completer<RendererToAgentMessage>();
        final sub = bloc.outboundMessages.listen((msg) {
          outbound.add(msg);
          if (!firstMsgCompleter.isCompleted) {
            firstMsgCompleter.complete(msg);
          }
        });
        addTearDown(sub.cancel);

        final resultFuture = bloc.callAgentFunction(
          'surf-1',
          FunctionCall(
            call: 'fetchWeather',
            args: const {'city': 'Portland'},
          ),
        );

        await firstMsgCompleter.future;
        expect(outbound, hasLength(1));
        expect(outbound.first, isA<CallAgentFunctionMessage>());
        final callMsg = outbound.first as CallAgentFunctionMessage;
        expect(callMsg.surfaceId, equals('surf-1'));
        expect(callMsg.callFunction['@call'], equals('fetchWeather'));

        bloc.add(
          ProcessMessage(
            AgentFunctionResponseMessage(
              version: 'v1.0',
              response: A2uiFunctionResponse.value(
                callMsg.functionCallId,
                const {'temp': 72},
              ),
            ),
          ),
        );

        final result = await resultFuture;
        expect(result, equals(const {'temp': 72}));
      },
    );

    group(
      'Scenario Outline: Outbound callAgentFunction error, timeout, and '
      'lifecycle cancellation handling',
      () {
        test(
          'Example 1: inbound AgentFunctionResponseMessage has error -> '
          'RpcErrorCode.executionError',
          () async {
            final outbound = <RendererToAgentMessage>[];
            final bloc = A2uiSurfaceBloc(outboundListener: outbound.add);
            addTearDown(bloc.close);

            final future = bloc.callAgentFunction(
              'surf-1',
              FunctionCall(call: 'failFn', args: const {}),
            );

            expect(outbound, hasLength(1));
            final callMsg = outbound.first as CallAgentFunctionMessage;

            bloc.add(
              ProcessJsonMessage({
                'version': 'v1.0',
                'agentFunctionResponse': {
                  'functionCallId': callMsg.functionCallId,
                  'error': const {
                    'code': 'EXECUTION_ERROR',
                    'message': 'Agent failed to run failFn',
                  },
                },
              }),
            );

            await expectLater(
              future,
              throwsA(
                isA<A2uiRpcError>().having(
                  (e) => e.rpcCode,
                  'rpcCode',
                  RpcErrorCode.executionError,
                ),
              ),
            );
          },
        );

        test(
          'Example 2: call times out before response arrives -> '
          'RpcErrorCode.timeout',
          () async {
            final bloc = A2uiSurfaceBloc(
              defaultRpcTimeout: const Duration(seconds: 5),
            );
            addTearDown(bloc.close);

            final future = bloc.callAgentFunction(
              'surf-1',
              FunctionCall(call: 'slowFn', args: const {}),
              options: const CallOptions(
                timeout: Duration(milliseconds: 20),
              ),
            );

            await expectLater(
              future,
              throwsA(
                isA<A2uiRpcError>().having(
                  (e) => e.rpcCode,
                  'rpcCode',
                  RpcErrorCode.timeout,
                ),
              ),
            );
          },
        );

        test(
          'Example 3: bloc.close() is called while call is pending -> '
          'RpcErrorCode.cancelled',
          () async {
            final bloc = A2uiSurfaceBloc();

            final future = bloc.callAgentFunction(
              'surf-1',
              FunctionCall(call: 'hangFn', args: const {}),
            );
            final expectation = expectLater(
              future,
              throwsA(
                isA<A2uiRpcError>().having(
                  (e) => e.rpcCode,
                  'rpcCode',
                  RpcErrorCode.cancelled,
                ),
              ),
            );

            await bloc.close();
            await expectation;
          },
        );

        test(
          'Example 4: bloc.callAgentFunction called after close() -> '
          'RpcErrorCode.disposed',
          () async {
            final bloc = A2uiSurfaceBloc();
            await bloc.close();

            final future = bloc.callAgentFunction(
              'surf-1',
              FunctionCall(call: 'lateFn', args: const {}),
            );

            await expectLater(
              future,
              throwsA(
                isA<A2uiRpcError>().having(
                  (e) => e.rpcCode,
                  'rpcCode',
                  RpcErrorCode.disposed,
                ),
              ),
            );
          },
        );
      },
    );

    test(
      'outboundMessageHistory respects maxResponseHistory FIFO eviction and '
      'ResetSurface() clears buffered outbound RPC messages',
      () async {
        final bloc = A2uiSurfaceBloc(maxResponseHistory: 1);
        addTearDown(bloc.close);

        final f1 = bloc.callAgentFunction(
          'surf-1',
          FunctionCall(call: 'fn1', args: const {}),
        );
        final f2 = bloc.callAgentFunction(
          'surf-1',
          FunctionCall(call: 'fn2', args: const {}),
        );
        final exp1 = expectLater(f1, throwsA(isA<A2uiRpcError>()));
        final exp2 = expectLater(f2, throwsA(isA<A2uiRpcError>()));

        expect(bloc.outboundMessageHistory, hasLength(1));
        final kept =
            bloc.outboundMessageHistory.single as CallAgentFunctionMessage;
        expect(kept.callFunction['@call'], equals('fn2'));

        bloc.add(const ResetSurface());
        expect(bloc.outboundMessageHistory, isEmpty);

        await bloc.close();
        await exp1;
        await exp2;
      },
    );
  });
}
