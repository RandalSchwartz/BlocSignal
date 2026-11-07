import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;
import 'package:test/test.dart';

class CalculateCostFunction extends FunctionImplementation {
  CalculateCostFunction({
    super.allowedCallers = AllowedCallers.rendererOrAgent,
  }) : super(
          name: 'calculateCost',
          returnType: A2uiReturnType.number,
          argumentSchema: Schema.object(
            properties: {
              'unitPrice': CommonSchemas.dynamicNumber,
              'quantity': CommonSchemas.dynamicNumber,
              'discount': CommonSchemas.dynamicNumber,
            },
            required: ['unitPrice', 'quantity'],
          ),
        );

  @override
  Object? execute(
    Map<String, Object?> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) {
    final unitPrice = (args['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final quantity = (args['quantity'] as num?)?.toDouble() ?? 0.0;
    final discount = (args['discount'] as num?)?.toDouble() ?? 0.0;

    return (unitPrice * quantity) * (1.0 - discount);
  }
}

void main() {
  group('(Issue #403) Client-Side Functions in A2UI', () {
    test(
      'CalculateCostFunction resolves synchronously and updates on form field mutation',
      () async {
        final customCatalog = StandardCatalog().copyWith(
          functions: [
            CalculateCostFunction(),
            ...BasicCatalog.v0_9().functions.values,
          ],
        );

        final bloc = A2uiSurfaceBloc(catalogs: [customCatalog]);
        addTearDown(bloc.close);

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              version: 'v0.9',
              surfaceId: 'surf_calc',
              catalogId: customCatalog.id,
            ),
            UpdateDataModelMessage(
              version: 'v0.9',
              surfaceId: 'surf_calc',
              path: '/cart/items/0/qty',
              value: 2,
            ),
            UpdateComponentsMessage(
              version: 'v0.9',
              surfaceId: 'surf_calc',
              components: const [
                {
                  'id': 'root',
                  'component': 'Text',
                  'text': {
                    'call': 'calculateCost',
                    'args': {
                      'unitPrice': 4.50,
                      'quantity': {'path': '/cart/items/0/qty'},
                      'discount': 0.10,
                    },
                  },
                },
              ],
            ),
          ]),
        );

        expect(bloc.stateValue, isA<SurfaceReady>());
        final ready = bloc.stateValue as SurfaceReady;
        final resolver = NodeResolver<ComponentApi>(ready.surface);
        addTearDown(resolver.dispose);

        final rootNode = resolver.rootNode.value;
        expect(rootNode, isNotNull);
        final textBinding = rootNode!.props.value['text']! as ResolvedBinding;
        expect(textBinding.value, closeTo(8.1, 0.0001));

        // Dispatch UpdateFormField
        bloc.add(
          const UpdateFormField(
            path: '/cart/items/0/qty',
            value: 6,
            surfaceId: 'surf_calc',
          ),
        );

        // Assert synchronous 0ms update to 24.3 in the exact same frame!
        final updatedBinding = rootNode.props.value['text']! as ResolvedBinding;
        expect(updatedBinding.value, closeTo(24.3, 0.0001));
      },
    );

    test(
      'Scenario: Inbound CallRendererFunctionMessage executes CalculateCostFunction via bidirectional RPC',
      () async {
        final customCatalog = StandardCatalog().copyWith(
          protocolVersion: A2uiProtocolVersion.v1_0,
          functions: [
            CalculateCostFunction(),
            ...BasicCatalog.v0_9().functions.values,
          ],
        );

        final outboundMessages = <RendererToAgentMessage>[];
        final bloc = A2uiSurfaceBloc(
          catalogs: [customCatalog],
          outboundListener: outboundMessages.add,
        );
        addTearDown(bloc.close);

        final responseFuture = bloc.outboundMessages.first;

        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              version: 'v1.0',
              surfaceId: 'surf_rpc',
              catalogId: customCatalog.id,
              components: const [
                {
                  'id': 'root',
                  'component': 'Text',
                  'text': 'Active Surface',
                },
              ],
            ),
          ),
        );

        bloc.add(
          ProcessMessage(
            CallRendererFunctionMessage(
              version: 'v1.0',
              surfaceId: 'surf_rpc',
              functionCallId: 'rpc-cost-1',
              callFunction: {
                '@call': 'calculateCost',
                'catalogId': customCatalog.id,
                'args': const {
                  'unitPrice': 100.0,
                  'quantity': 3,
                  'discount': 0.15,
                },
              },
            ),
          ),
        );

        final firstOutbound = await responseFuture;
        expect(firstOutbound, isA<RendererFunctionResponseMessage>());
        final response = firstOutbound as RendererFunctionResponseMessage;
        expect(response.response.functionCallId, equals('rpc-cost-1'));
        expect(response.response.error, isNull);
        expect(
          (response.response.value as num?)?.toDouble(),
          closeTo(255.0, 0.0001),
        );
      },
    );

    test(
      'DataContext.resolveSignal compiles calculateCost into computed signal with instant reactivity',
      () {
        final customCatalog = StandardCatalog().copyWith(
          functions: [
            CalculateCostFunction(),
            ...BasicCatalog.v0_9().functions.values,
          ],
        );
        final surface = SurfaceModel<ComponentApi>(
          'surf_signal',
          defaultCatalog: customCatalog,
        );
        addTearDown(surface.dispose);

        surface.dataModel.set('/cart/items/0/qty', 2);

        final context = DataContext(
          surface.dataModel,
          surface.resolveCatalog(null).invoke,
          '/',
        );

        final costSignal = context.resolveSignal(const {
          'call': 'calculateCost',
          'args': {
            'unitPrice': 4.50,
            'quantity': {'path': '/cart/items/0/qty'},
            'discount': 0.10,
          },
        });

        expect(costSignal.value, closeTo(8.1, 0.0001));

        // Mutating underlying data model updates signal synchronously
        surface.dataModel.set('/cart/items/0/qty', 6);
        expect(costSignal.value, closeTo(24.3, 0.0001));
      },
    );
  });
}
