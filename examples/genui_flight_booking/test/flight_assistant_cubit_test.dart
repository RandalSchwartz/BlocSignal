import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flight_booking/src/models/chat_message.dart';
import 'package:genui_flight_booking/src/models/flight_models.dart';
import 'package:genui_flight_booking/src/services/flight_mock_streamer.dart';
import 'package:genui_flight_booking/src/state/flight_assistant_cubit.dart';

class _FailingRpcSurfaceBloc extends A2uiSurfaceBloc {
  @override
  Future<Object?> callAgentFunction(
    String surfaceId,
    FunctionCall call, {
    CallOptions? options,
  }) =>
      Future<Object?>.error(Exception('Transient RPC timeout'));
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> values = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = <String>[value.toString()];
  }

  @override
  String? value(String name) => values[name.toLowerCase()]?.firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.statusCode,
    required List<int> bodyBytes,
  }) : _stream = Stream<List<int>>.value(bodyBytes);

  @override
  final int statusCode;

  final Stream<List<int>> _stream;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._response);

  final HttpClientResponse _response;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this._response);

  final HttpClientResponse _response;
  Uri? capturedUri;
  late _FakeHttpClientRequest capturedRequest;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    capturedUri = url;
    capturedRequest = _FakeHttpClientRequest(_response);
    return capturedRequest;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FlightAssistantCubit', () {
    late A2uiSurfaceBloc surfaceBloc;
    late FlightAssistantCubit cubit;

    setUp(() {
      surfaceBloc = A2uiSurfaceBloc();
      cubit = FlightAssistantCubit(surfaceBloc: surfaceBloc);
    });

    tearDown(() async {
      await cubit.close();
      await surfaceBloc.close();
    });

    test('initial state has empty messages and default economy tier', () {
      expect(cubit.value.messages, isEmpty);
      expect(cubit.value.mode, equals(ExecutionMode.mockSimulation));
      expect(cubit.value.selectedTier, equals(SeatTier.economy));
      expect(cubit.value.calculatedTotal, equals(420));
      expect(cubit.totalPriceSignal.value, equals(420));
    });

    test('mode toggle updates execution mode', () {
      cubit.toggleMode(ExecutionMode.liveGemini);
      expect(cubit.value.mode, equals(ExecutionMode.liveGemini));

      cubit.toggleMode(ExecutionMode.mockSimulation);
      expect(cubit.value.mode, equals(ExecutionMode.mockSimulation));
    });

    test('price calculation reacts to seat tier and add-ons', () {
      // Economy base = 420
      expect(cubit.value.calculatedTotal, equals(420));

      // Premium = 650
      cubit.setSeatTier(SeatTier.premium);
      expect(cubit.value.calculatedTotal, equals(650));
      expect(cubit.totalPriceSignal.value, equals(650));

      // Business = 1250
      cubit.setSeatTier(SeatTier.business);
      expect(cubit.value.calculatedTotal, equals(1250));

      // Luggage + 45
      cubit.toggleLuggage(true);
      expect(cubit.value.calculatedTotal, equals(1295));

      // Priority boarding + 30
      cubit.togglePriorityBoarding(true);
      expect(cubit.value.calculatedTotal, equals(1325));

      cubit.toggleLuggage(false);
      expect(cubit.value.calculatedTotal, equals(1280));
    });

    test('passenger name update updates state', () {
      cubit.updatePassengerName('Wilhelm Perdahl');
      expect(cubit.value.passengerName, equals('Wilhelm Perdahl'));
    });

    test('startDiscoverySearch streams discovery surface and adds messages',
        () async {
      await cubit.startDiscoverySearch(delay: Duration.zero);

      expect(cubit.value.messages.length, equals(2));
      expect(cubit.value.messages.first.role, equals(ChatRole.user));
      expect(cubit.value.messages.last.role, equals(ChatRole.assistant));
      expect(
        cubit.value.activeSurfaceId,
        equals('surf-flight-discovery'),
      );
      expect(surfaceBloc.value, isA<SurfaceReady>());
    });

    test('surface action selectFlight transitions to customization surface',
        () async {
      await cubit.startDiscoverySearch(delay: Duration.zero);

      surfaceBloc.add(
        const SubmitAction(
          actionName: 'selectFlight',
          sourceComponentId: 'btn_select_flight',
          surfaceId: 'surf-flight-discovery',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        cubit.value.activeSurfaceId,
        equals('surf-seat-customization'),
      );
      expect(surfaceBloc.value, isA<SurfaceReady>());
    });

    test('surface action proceedBooking transitions to confirmation receipt',
        () async {
      await cubit.startDiscoverySearch(delay: Duration.zero);

      surfaceBloc.add(
        const SubmitAction(
          actionName: 'selectFlight',
          sourceComponentId: 'btn_select_flight',
          surfaceId: 'surf-flight-discovery',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Submit customization with passenger name
      surfaceBloc.add(
        const SubmitAction(
          actionName: 'proceedBooking',
          sourceComponentId: 'btn_proceed_booking',
          surfaceId: 'surf-seat-customization',
          context: {
            'input_passenger_name': 'Randal Schwartz',
            'input_seat_tier': 'Business Class',
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        cubit.value.activeSurfaceId,
        equals('surf-booking-confirmation'),
      );
      expect(surfaceBloc.value, isA<SurfaceReady>());
    });

    test('reentrancy: subsequent search preempts in-flight search response',
        () async {
      cubit.streamDelay = const Duration(milliseconds: 50);

      // Trigger first search with query A
      final firstSearch = cubit.startDiscoverySearch(query: 'Search A');

      // Rapidly trigger second search before first completes
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await cubit.startDiscoverySearch(query: 'Search B');

      await firstSearch;

      // Ensure that only the second search assistant message exists
      final assistantMessages = cubit.value.messages
          .where((m) => m.role == ChatRole.assistant)
          .toList();
      expect(assistantMessages.length, equals(1));
    });

    test('restartSearch clears previous messages and re-initializes search',
        () async {
      await cubit.startDiscoverySearch(delay: Duration.zero);
      expect(cubit.value.messages.length, equals(2));

      // Mutate tier, passenger name, and add-ons to non-defaults
      cubit.updatePassengerName('Custom Passenger');
      cubit.toggleLuggage(true);
      cubit.togglePriorityBoarding(true);
      expect(cubit.totalPriceSignal.value, equals(420 + 45 + 30));

      surfaceBloc.add(
        const SubmitAction(
          actionName: 'restartSearch',
          sourceComponentId: 'btn_restart',
          surfaceId: 'surf-flight-discovery',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(cubit.value.messages.length, equals(2));
      expect(cubit.value.messages.first.role, equals(ChatRole.user));
      expect(cubit.value.messages.last.role, equals(ChatRole.assistant));
      expect(cubit.value.selectedTier, equals(SeatTier.economy));
      expect(cubit.value.passengerName, equals('Merlyn Schwartz'));
      expect(cubit.value.hasCheckedLuggage, isFalse);
      expect(cubit.value.hasPriorityBoarding, isFalse);
      expect(cubit.totalPriceSignal.value, equals(420));
      expect(cubit.value.activeSurfaceId, equals('surf-flight-discovery'));
    });

    test(
        'FlightAssistantState.copyWith clearActiveSurfaceId explicitly clears field',
        () {
      const state = FlightAssistantState(
        messages: [],
        mode: ExecutionMode.mockSimulation,
        activeSurfaceId: 'surf-initial',
      );
      expect(state.activeSurfaceId, equals('surf-initial'));

      final preserved = state.copyWith(isStreaming: true);
      expect(preserved.activeSurfaceId, equals('surf-initial'));

      final cleared = state.copyWith(clearActiveSurfaceId: true);
      expect(cleared.activeSurfaceId, isNull);
    });

    test(
        'zero-chunk stream failure prunes optimistic user turn to prevent consecutive user turns on retry',
        () async {
      final errorStream = Stream<Map<String, dynamic>>.error(
        Exception('Network connection failed before any chunks arrived'),
      );

      await cubit.startDiscoverySearch(
        query: 'First attempt',
        delay: Duration.zero,
        streamOverride: errorStream,
      );

      // Verify optimistic user message was pruned on zero-chunk failure
      expect(cubit.value.messages, isEmpty);
      expect(cubit.value.isStreaming, isFalse);
      expect(surfaceBloc.value, isA<SurfaceError>());

      // Subsequent retry should succeed cleanly without consecutive user turns
      await cubit.startDiscoverySearch(
        query: 'Retry attempt',
        delay: Duration.zero,
      );

      expect(cubit.value.messages.length, equals(2));
      expect(cubit.value.messages.first.role, equals(ChatRole.user));
      expect(cubit.value.messages.first.text, equals('Retry attempt'));
      expect(cubit.value.messages.last.role, equals(ChatRole.assistant));
      expect(surfaceBloc.value, isA<SurfaceReady>());
    });

    group('(Issue #373) Modernized GenUI Flight Booking Behavioral Contract',
        () {
      test(
          '(Issue #373) Scenario: Flight discovery surface expands repeated '
          'flight cards via NodeResolver ChildList template', () async {
        await cubit.startDiscoverySearch(delay: Duration.zero);

        expect(surfaceBloc.value, isA<SurfaceReady>());
        final ready = surfaceBloc.value as SurfaceReady;
        expect(ready.surfaceId, equals('surf-flight-discovery'));

        // Verify root component exists and uses ChildList template on /flights
        final rootComp = ready.surface.componentsModel.get('root');
        expect(rootComp, isNotNull);

        final flightsData = ready.surface.dataModel.get('/flights');
        expect(flightsData, isA<List<dynamic>>());
        expect((flightsData as List<dynamic>).length, greaterThanOrEqualTo(2));

        // Verify NodeResolver resolves repeated card_flight nodes
        final resolver = NodeResolver<ComponentApi>(ready.surface);
        addTearDown(resolver.dispose);
        final rootNode = resolver.rootNode.value;
        expect(rootNode, isNotNull);
        expect(rootNode!.state, equals(NodeState.resolved));
      });

      test(
          '(Issue #373) Scenario Outline: Interactive BasicCatalog v0.9/v1.0 '
          'widgets on customization surface synchronize with DataModel and '
          'reactive total price', () async {
        await cubit.startDiscoverySearch(delay: Duration.zero);

        surfaceBloc.add(
          const SubmitAction(
            actionName: 'selectFlight',
            sourceComponentId: 'btn_select_flight',
            surfaceId: 'surf-flight-discovery',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(cubit.value.activeSurfaceId, equals('surf-seat-customization'));

        // Example 1: ChoicePicker /booking/tier -> ["Premium Economy"] -> 650
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/booking/tier',
            value: <String>['Premium Economy'],
          ),
        );
        expect(cubit.value.selectedTier, equals(SeatTier.premium));
        expect(cubit.totalPriceSignal.value, equals(650));

        // Example 2: ChoicePicker /booking/tier -> ["Business Class"] -> 1250
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/booking/tier',
            value: <String>['Business Class'],
          ),
        );
        expect(cubit.value.selectedTier, equals(SeatTier.business));
        expect(cubit.totalPriceSignal.value, equals(1250));

        // Reset back to Economy (420) for add-on examples
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/booking/tier',
            value: <String>['Economy'],
          ),
        );
        expect(cubit.totalPriceSignal.value, equals(420));

        // Example 3: CheckBox /addons/checkedLuggage -> true -> 465
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/addons/checkedLuggage',
            value: true,
          ),
        );
        expect(cubit.value.hasCheckedLuggage, isTrue);
        expect(cubit.totalPriceSignal.value, equals(465));

        // Reset checkedLuggage to false
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/addons/checkedLuggage',
            value: false,
          ),
        );

        // Example 4: CheckBox /addons/priorityBoarding -> true -> 450
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/addons/priorityBoarding',
            value: true,
          ),
        );
        expect(cubit.value.hasPriorityBoarding, isTrue);
        expect(cubit.totalPriceSignal.value, equals(450));

        // Reset priorityBoarding to false
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/addons/priorityBoarding',
            value: false,
          ),
        );

        // Example 5: DateTimeInput /booking/departureDate -> "2026-10-20" -> 420
        surfaceBloc.add(
          const UpdateFormField(
            surfaceId: 'surf-seat-customization',
            path: '/booking/departureDate',
            value: '2026-10-20',
          ),
        );
        expect(cubit.value.departureDate, equals('2026-10-20'));
        expect(cubit.totalPriceSignal.value, equals(420));
      });

      test(
          '(Issue #373) Scenario: Bidirectional RPC seat assignment in '
          'FlightAssistantCubit', () async {
        await cubit.startDiscoverySearch(delay: Duration.zero);

        surfaceBloc.add(
          const SubmitAction(
            actionName: 'selectFlight',
            sourceComponentId: 'btn_select_flight',
            surfaceId: 'surf-flight-discovery',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final assignedSeat = await cubit.requestSeatAssignment();
        expect(assignedSeat, isNotEmpty);
        expect(cubit.value.assignedSeat, equals(assignedSeat));
        expect(surfaceBloc.outboundMessageHistory, isNotEmpty);
        expect(
          surfaceBloc.outboundMessageHistory.last,
          isA<CallAgentFunctionMessage>(),
        );
      });

      test(
          '(Issue #373) Scenario: Transient RPC timeout during seat assignment '
          'falls back gracefully without throwing uncaught exceptions',
          () async {
        final timeoutBloc = _FailingRpcSurfaceBloc();
        final timeoutCubit = FlightAssistantCubit(surfaceBloc: timeoutBloc);
        addTearDown(() async {
          await timeoutCubit.close();
          await timeoutBloc.close();
        });

        await timeoutCubit.startDiscoverySearch(delay: Duration.zero);
        timeoutCubit.setSeatTier(SeatTier.business);

        final fallbackSeat = await timeoutCubit.requestSeatAssignment();
        expect(fallbackSeat, equals('2A (Lie-Flat Suite)'));
        expect(timeoutCubit.value.assignedSeat, equals('2A (Lie-Flat Suite)'));
      });
    });

    group('(Issue #411) Deterministic Stream Completion and Live Gemini Wiring',
        () {
      test(
          '(Issue #411) startDiscoverySearch waits for full slow stream '
          'completion before emitting isStreaming: false and SurfaceReady',
          () async {
        cubit.streamDelay = Duration.zero;
        final controller = StreamController<Map<String, dynamic>>();
        addTearDown(controller.close);

        final searchFuture = cubit.startDiscoverySearch(
          query: 'Slow stream query',
          delay: Duration.zero,
          streamOverride: controller.stream,
        );

        // Wait longer than the legacy effectiveDelay * 3 + 20ms (20ms) window
        // before emitting the first chunk.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(cubit.value.isStreaming, isTrue);

        controller
          ..add(<String, dynamic>{
            'version': 'v0.9',
            'createSurface': <String, dynamic>{
              'surfaceId': 'surf-flight-discovery',
              'catalogId': FlightMockStreamer.basicCatalogId,
            },
          })
          ..add(<String, dynamic>{
            'version': 'v0.9',
            'updateComponents': <String, dynamic>{
              'surfaceId': 'surf-flight-discovery',
              'components': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'root',
                  'component': 'Text',
                  'text': 'Slow flight loaded',
                },
              ],
            },
          });
        await controller.close();

        await searchFuture;

        expect(cubit.value.isStreaming, isFalse);
        expect(cubit.value.messages, hasLength(2));
        expect(cubit.value.activeSurfaceId, equals('surf-flight-discovery'));
        expect(surfaceBloc.value, isA<SurfaceReady>());
      });

      test(
          '(Issue #411) ExecutionMode.liveGemini wires GeminiSseStreamer with '
          'injected HttpClient and reaches SurfaceReady', () async {
        final sseChunks = <String>[
          jsonEncode(<String, dynamic>{
            'version': 'v0.9',
            'createSurface': <String, dynamic>{
              'surfaceId': 'surf-flight-discovery',
              'catalogId': FlightMockStreamer.basicCatalogId,
            },
          }),
          jsonEncode(<String, dynamic>{
            'version': 'v0.9',
            'updateComponents': <String, dynamic>{
              'surfaceId': 'surf-flight-discovery',
              'components': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'root',
                  'component': 'Text',
                  'text': 'Live Gemini Flight Result',
                },
              ],
            },
          }),
        ];
        final ssePayload = sseChunks.map((c) => 'data: $c\n\n').join();
        final fakeResponse = _FakeHttpClientResponse(
          statusCode: HttpStatus.ok,
          bodyBytes: utf8.encode(ssePayload),
        );
        final fakeClient = _FakeHttpClient(fakeResponse);

        final liveSurfaceBloc = A2uiSurfaceBloc();
        final liveCubit = FlightAssistantCubit(
          surfaceBloc: liveSurfaceBloc,
          geminiApiKey: '  test-gemini-key  ',
          httpClient: fakeClient,
        );
        addTearDown(() async {
          await liveCubit.close();
          await liveSurfaceBloc.close();
        });

        liveCubit.toggleMode(ExecutionMode.liveGemini);
        await liveCubit.startDiscoverySearch(query: 'Fly SFO to HND');

        expect(fakeClient.capturedUri, isNotNull);
        expect(
          fakeClient.capturedRequest.headers.value('x-goog-api-key'),
          equals('test-gemini-key'),
        );
        expect(liveCubit.value.isStreaming, isFalse);
        expect(liveCubit.value.messages, hasLength(2));
        expect(liveSurfaceBloc.value, isA<SurfaceReady>());
      });

      test(
          '(Issue #411) ExecutionMode.liveGemini with empty or null '
          'geminiApiKey transitions surfaceBloc to SurfaceError and prunes '
          'optimistic user turn', () async {
        for (final blankKey in <String?>['', '   ', null]) {
          final errSurfaceBloc = A2uiSurfaceBloc();
          final errCubit = FlightAssistantCubit(
            surfaceBloc: errSurfaceBloc,
            geminiApiKey: blankKey,
          );
          addTearDown(() async {
            await errCubit.close();
            await errSurfaceBloc.close();
          });

          errCubit.toggleMode(ExecutionMode.liveGemini);
          await errCubit.startDiscoverySearch(query: 'Fly SFO to HND');

          expect(errSurfaceBloc.value, isA<SurfaceError>());
          expect(errCubit.value.isStreaming, isFalse);
          expect(errCubit.value.messages, isEmpty);
        }
      });
    });
  });
}
