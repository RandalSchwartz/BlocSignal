import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flight_booking/src/models/chat_message.dart';
import 'package:genui_flight_booking/src/models/flight_models.dart';
import 'package:genui_flight_booking/src/state/flight_assistant_cubit.dart';

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
  });
}
