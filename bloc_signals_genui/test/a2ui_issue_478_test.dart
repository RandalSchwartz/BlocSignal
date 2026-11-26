import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;
import 'package:test/test.dart';

class _SlowContextFunction extends FunctionImplementation {
  _SlowContextFunction(this.completer)
      : super(
          name: 'slowContext',
          returnType: A2uiReturnType.string,
          allowedCallers: AllowedCallers.rendererOrAgent,
          argumentSchema: Schema.object(properties: const {}),
        );

  final Completer<String> completer;

  @override
  Object? execute(
    Map<String, Object?> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) {
    return completer.future;
  }
}

void main() {
  group('(Issue #478) A2uiSurfaceBloc Async & RPC Lifecycle Isolation', () {
    test(
      '(Issue #478) _onSubmitAction aborts when surface is reset, replaced, '
      'or evicted while resolving async action context',
      () async {
        Future<void> verifyAbort(
          void Function(
            A2uiSurfaceBloc bloc,
            Catalog<ComponentApi, FunctionImplementation> catalog,
          ) triggerMutation,
        ) async {
          final completer = Completer<String>();
          final catalog = StandardCatalog().copyWith(
            functions: [
              _SlowContextFunction(completer),
              ...BasicCatalog.v0_9().functions.values,
            ],
          );

          final bloc = A2uiSurfaceBloc(catalogs: [catalog], maxSurfaces: 1);
          addTearDown(bloc.close);

          bloc
            ..add(
              ProcessJsonMessage({
                'version': '0.9',
                'createSurface': {'surfaceId': 's1', 'catalogId': catalog.id},
              }),
            )
            ..add(
              const ProcessJsonMessage({
                'version': '0.9',
                'updateComponents': {
                  'surfaceId': 's1',
                  'components': [
                    {'id': 'root', 'component': 'Button', 'child': 'lbl'},
                    {'id': 'lbl', 'component': 'Text', 'text': 'Go'},
                  ],
                },
              }),
            );
          await Future<void>.microtask(() {});

          final responses = <A2uiActionResponse>[];
          final sub = bloc.actionResponses.listen(responses.add);
          addTearDown(sub.cancel);

          bloc.add(
            const SubmitAction(
              actionName: 'go',
              sourceComponentId: 'root',
              surfaceId: 's1',
              context: {
                'token': {'call': 'slowContext'},
              },
            ),
          );
          await Future<void>.microtask(() {});

          triggerMutation(bloc, catalog);
          await Future<void>.microtask(() {});

          completer.complete('late_value');
          await pumpEventQueue();

          expect(responses, isEmpty);
        }

        // 1. Targeted ResetSurface
        await verifyAbort(
          (bloc, _) => bloc.add(const ResetSurface(surfaceId: 's1')),
        );

        // 2. Surface replacement via CreateSurfaceMessage reusing 's1'
        await verifyAbort(
          (bloc, catalog) => bloc
            ..add(
              ProcessJsonMessage({
                'version': '0.9',
                'createSurface': {'surfaceId': 's1', 'catalogId': catalog.id},
              }),
            )
            ..add(
              const ProcessJsonMessage({
                'version': '0.9',
                'updateComponents': {
                  'surfaceId': 's1',
                  'components': [
                    {'id': 'root', 'component': 'Text', 'text': 'Replaced'},
                  ],
                },
              }),
            ),
        );

        // 3. LRU eviction via maxSurfaces: 1 when creating 's2'
        await verifyAbort(
          (bloc, catalog) => bloc
            ..add(
              ProcessJsonMessage({
                'version': '0.9',
                'createSurface': {'surfaceId': 's2', 'catalogId': catalog.id},
              }),
            )
            ..add(
              const ProcessJsonMessage({
                'version': '0.9',
                'updateComponents': {
                  'surfaceId': 's2',
                  'components': [
                    {'id': 'root', 'component': 'Text', 'text': 'New'},
                  ],
                },
              }),
            ),
        );
      },
    );

    test(
      '(Issue #478) cancelSurfaceCalls cancels with RpcErrorCode.cancelled on '
      'eviction, recreation, global reset, targeted reset, and CloseSurface',
      () async {
        final catalog = BasicCatalog.v1_0();
        final bloc = A2uiSurfaceBloc(
          catalogs: [catalog],
          maxSurfaces: 1,
        );
        addTearDown(bloc.close);

        void createSurface(String id) {
          bloc
            ..add(
              ProcessJsonMessage({
                'version': '1.0',
                'createSurface': {'surfaceId': id, 'catalogId': catalog.id},
              }),
            )
            ..add(
              ProcessJsonMessage({
                'version': '1.0',
                'updateComponents': {
                  'surfaceId': id,
                  'components': const [
                    {'id': 'root', 'component': 'Text', 'text': 'Hi'},
                  ],
                },
              }),
            );
        }

        final isCancelledError = isA<A2uiRpcError>().having(
          (e) => e.rpcCode,
          'rpcCode',
          RpcErrorCode.cancelled,
        );

        createSurface('s1');
        await Future<void>.microtask(() {});
        expect(bloc.stateValue, isA<SurfaceReady>());

        // 1. Recreation of s1 should cancel s1's pending RPC.
        final f1 = bloc.callAgentFunction(
          's1',
          FunctionCall(call: 'ping', args: const {}),
        );
        await Future<void>.microtask(() {});
        createSurface('s1');
        await expectLater(f1, throwsA(isCancelledError));

        // 2. Global ResetSurface should cancel pending RPCs for all surfaces.
        final f1b = bloc.callAgentFunction(
          's1',
          FunctionCall(call: 'ping', args: const {}),
        );
        await Future<void>.microtask(() {});
        bloc.add(const ResetSurface());
        await expectLater(f1b, throwsA(isCancelledError));

        // 3. Targeted ResetSurface should cancel pending RPCs for that surface.
        createSurface('s1');
        await Future<void>.microtask(() {});
        final f1c = bloc.callAgentFunction(
          's1',
          FunctionCall(call: 'ping', args: const {}),
        );
        await Future<void>.microtask(() {});
        bloc.add(const ResetSurface(surfaceId: 's1'));
        await expectLater(f1c, throwsA(isCancelledError));

        // 4. CloseSurface should cancel pending RPCs for that surface.
        createSurface('s1');
        await Future<void>.microtask(() {});
        final f1close = bloc.callAgentFunction(
          's1',
          FunctionCall(call: 'ping', args: const {}),
        );
        await Future<void>.microtask(() {});
        bloc.add(const CloseSurface(surfaceId: 's1'));
        await expectLater(f1close, throwsA(isCancelledError));

        // 5. Eviction due to maxSurfaces: 1 should cancel s1's pending RPC.
        createSurface('s1');
        await Future<void>.microtask(() {});
        final f1d = bloc.callAgentFunction(
          's1',
          FunctionCall(call: 'ping', args: const {}),
        );
        await Future<void>.microtask(() {});
        createSurface('s2');
        await expectLater(f1d, throwsA(isCancelledError));
      },
    );
  });
}
