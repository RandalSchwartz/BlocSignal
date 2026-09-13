import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:flutter/foundation.dart';
import 'package:genui_flight_booking/src/models/chat_message.dart';
import 'package:genui_flight_booking/src/models/flight_models.dart';
import 'package:genui_flight_booking/src/services/flight_mock_streamer.dart';
import 'package:genui_flight_booking/src/services/gemini_sse_streamer.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Execution mode for Generative UI generation.
enum ExecutionMode {
  /// Zero-key offline mock simulation mode (deterministic, rapid, CI-ready).
  mockSimulation,

  /// Live SSE stream mode using Google Gemini API key.
  liveGemini,
}

/// The state of the flight assistant conversation and booking workflow.
@immutable
class FlightAssistantState {
  /// Creates a [FlightAssistantState].
  const FlightAssistantState({
    required this.messages,
    required this.mode,
    this.isStreaming = false,
    this.activeSurfaceId,
    this.selectedTier = SeatTier.economy,
    this.passengerName = 'Merlyn Schwartz',
    this.hasCheckedLuggage = false,
    this.hasPriorityBoarding = false,
  });

  /// The list of chat messages exchanged so far.
  final List<ChatMessage> messages;

  /// Current execution mode (mock or live).
  final ExecutionMode mode;

  /// Whether an assistant response or A2UI surface is actively streaming.
  final bool isStreaming;

  /// The currently active A2UI surface ID, if any.
  final String? activeSurfaceId;

  /// The currently selected cabin tier.
  final SeatTier selectedTier;

  /// Passenger name captured from form inputs or defaults.
  final String passengerName;

  /// Optional add-on: checked luggage (+$45).
  final bool hasCheckedLuggage;

  /// Optional add-on: priority boarding (+$30).
  final bool hasPriorityBoarding;

  /// Dynamically calculated total price in USD.
  int get calculatedTotal {
    var total = selectedTier.basePrice;
    if (hasCheckedLuggage) total += 45;
    if (hasPriorityBoarding) total += 30;
    return total;
  }

  /// Creates a copy of this state with updated properties.
  FlightAssistantState copyWith({
    List<ChatMessage>? messages,
    ExecutionMode? mode,
    bool? isStreaming,
    String? activeSurfaceId,
    bool clearActiveSurfaceId = false,
    SeatTier? selectedTier,
    String? passengerName,
    bool? hasCheckedLuggage,
    bool? hasPriorityBoarding,
  }) {
    return FlightAssistantState(
      messages: messages ?? this.messages,
      mode: mode ?? this.mode,
      isStreaming: isStreaming ?? this.isStreaming,
      activeSurfaceId: clearActiveSurfaceId
          ? null
          : (activeSurfaceId ?? this.activeSurfaceId),
      selectedTier: selectedTier ?? this.selectedTier,
      passengerName: passengerName ?? this.passengerName,
      hasCheckedLuggage: hasCheckedLuggage ?? this.hasCheckedLuggage,
      hasPriorityBoarding: hasPriorityBoarding ?? this.hasPriorityBoarding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightAssistantState &&
          runtimeType == other.runtimeType &&
          listEquals(messages, other.messages) &&
          mode == other.mode &&
          isStreaming == other.isStreaming &&
          activeSurfaceId == other.activeSurfaceId &&
          selectedTier == other.selectedTier &&
          passengerName == other.passengerName &&
          hasCheckedLuggage == other.hasCheckedLuggage &&
          hasPriorityBoarding == other.hasPriorityBoarding;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(messages),
        mode,
        isStreaming,
        activeSurfaceId,
        selectedTier,
        passengerName,
        hasCheckedLuggage,
        hasPriorityBoarding,
      );
}

/// Orchestrates chat turns, A2UI surface lifecycle streaming, and reactive pricing.
///
/// **Production Architecture Note**:
/// In a production enterprise system, this cubit would not execute mock stream
/// generators or interface directly with client-held LLM API keys. Instead:
/// 1. A remote Backend-for-Frontend (BFF) gateway would authenticate client
///    sessions, securely manage agent credentials, and stream A2UI JSON over SSE
///    or WebSockets.
/// 2. Action submissions ([A2uiActionResponse]) would be dispatched back to the
///    remote agent as tool execution inputs.
/// 3. While client-side signals calculate dynamic prices for immediate user
///    feedback, authoritative pricing and seat availability locks would be
///    enforced and cryptographically verified on the server.
class FlightAssistantCubit extends CubitSignal<FlightAssistantState> {
  /// Creates a [FlightAssistantCubit].
  FlightAssistantCubit({
    required this.surfaceBloc,
    String? geminiApiKey,
  })  : _geminiApiKey = geminiApiKey,
        super(
          initialState: const FlightAssistantState(
            messages: [],
            mode: ExecutionMode.mockSimulation,
          ),
        ) {
    // Listen to action submissions from A2uiSurfaceBloc
    _actionSubscription =
        surfaceBloc.actionResponses.listen(_handleSurfaceAction);
  }

  /// The underlying A2UI surface bloc managing declarative UI state.
  final A2uiSurfaceBloc surfaceBloc;

  final String? _geminiApiKey;
  StreamSubscription<A2uiActionResponse>? _actionSubscription;

  /// Computed reactive signal exposing the real-time total price.
  late final totalPriceSignal = computed(() => value.calculatedTotal);

  /// Toggles between offline mock simulation and live Gemini stream.
  void toggleMode(ExecutionMode newMode) {
    emit(value.copyWith(mode: newMode));
  }

  /// Sets the selected cabin seat tier.
  void setSeatTier(SeatTier tier) {
    emit(value.copyWith(selectedTier: tier));
  }

  /// Toggles checked luggage add-on.
  void toggleLuggage(bool enabled) {
    emit(value.copyWith(hasCheckedLuggage: enabled));
  }

  /// Toggles priority boarding add-on.
  void togglePriorityBoarding(bool enabled) {
    emit(value.copyWith(hasPriorityBoarding: enabled));
  }

  /// Updates the passenger name.
  void updatePassengerName(String name) {
    emit(value.copyWith(passengerName: name));
  }

  /// Operation generation ID tracking active asynchronous pipeline requests.
  int _activeOperationId = 0;

  /// Stream delay duration for mock responses.
  Duration streamDelay = const Duration(milliseconds: 10);

  /// Initiates the flight search discovery turn.
  Future<void> startDiscoverySearch({
    String query = 'Find flights from San Francisco to Tokyo',
    Duration? delay,
    bool clearMessages = false,
  }) async {
    final operationId = ++_activeOperationId;
    final effectiveDelay = delay ?? streamDelay;
    final userMsg = ChatMessage.user(query);
    final updatedMessages = clearMessages
        ? [userMsg]
        : (List<ChatMessage>.from(value.messages)..add(userMsg));

    emit(
      value.copyWith(
        messages: updatedMessages,
        isStreaming: true,
        selectedTier: clearMessages ? SeatTier.economy : value.selectedTier,
        passengerName: clearMessages ? 'Merlyn Schwartz' : value.passengerName,
        hasCheckedLuggage: clearMessages ? false : value.hasCheckedLuggage,
        hasPriorityBoarding: clearMessages ? false : value.hasPriorityBoarding,
        clearActiveSurfaceId: clearMessages,
      ),
    );

    // Stream the flight discovery surface
    final stream =
        FlightMockStreamer.streamDiscoverySurface(delay: effectiveDelay);
    surfaceBloc.add(IngestStream(stream));

    // Wait briefly for ingestion to settle
    await Future<void>.delayed(
        effectiveDelay * 3 + const Duration(milliseconds: 20));
    if (isClosed || _activeOperationId != operationId) return;

    final assistantMsg = ChatMessage.assistant(
      'Here is the best flight match I found for SFO ➔ HND on Pacific Rim Airways:',
      surfaceId: 'surf-flight-discovery',
    );

    emit(
      value.copyWith(
        messages: List<ChatMessage>.from(value.messages)..add(assistantMsg),
        isStreaming: false,
        activeSurfaceId: 'surf-flight-discovery',
      ),
    );
  }

  /// Dispatches an action response triggered from the A2UI surface.
  Future<void> _handleSurfaceAction(A2uiActionResponse response) async {
    switch (response.actionName) {
      case 'selectFlight':
        await _selectFlightAndEmit(response);
      case 'proceedBooking':
        await _proceedBookingAndEmit(response);
      case 'restartSearch':
        await _restartSearchAndEmit();
      default:
        break;
    }
  }

  Future<void> _selectFlightAndEmit(A2uiActionResponse response) async {
    final operationId = ++_activeOperationId;
    final userMsg = ChatMessage.user('I will select flight PR-774.');
    emit(
      value.copyWith(
        messages: List<ChatMessage>.from(value.messages)..add(userMsg),
        isStreaming: true,
      ),
    );

    final stream = FlightMockStreamer.streamCustomizationSurface(
      delay: streamDelay,
    );
    surfaceBloc.add(IngestStream(stream));

    await Future<void>.delayed(
        streamDelay * 3 + const Duration(milliseconds: 20));
    if (isClosed || _activeOperationId != operationId) return;

    final assistantMsg = ChatMessage.assistant(
      'Please customize your cabin tier, enter your passenger name, and adjust add-ons below:',
      surfaceId: 'surf-seat-customization',
    );

    emit(
      value.copyWith(
        messages: List<ChatMessage>.from(value.messages)..add(assistantMsg),
        isStreaming: false,
        activeSurfaceId: 'surf-seat-customization',
      ),
    );
  }

  Future<void> _proceedBookingAndEmit(A2uiActionResponse response) async {
    final operationId = ++_activeOperationId;

    // Extract form data from action response or dataModel
    var name = value.passengerName;
    var tier = value.selectedTier;

    final formName = response.getFormValue<String>('/passenger/name') ??
        response.getFormValue<String>('passenger.name') ??
        response.getFormValue<String>('input_passenger_name');
    if (formName != null && formName.trim().isNotEmpty) {
      name = formName.trim();
    }

    final formTier = response.getFormValue<String>('/booking/tier') ??
        response.getFormValue<String>('booking.tier') ??
        response.getFormValue<String>('input_seat_tier');
    if (formTier != null) {
      final lower = formTier.toLowerCase();
      if (lower.contains('business')) {
        tier = SeatTier.business;
      } else if (lower.contains('premium')) {
        tier = SeatTier.premium;
      } else {
        tier = SeatTier.economy;
      }
    }

    final userMsg = ChatMessage.user(
      'Proceed with booking for $name in ${tier.label}.',
    );

    // Consolidated single atomic state emission
    emit(
      value.copyWith(
        passengerName: name,
        selectedTier: tier,
        isStreaming: true,
        messages: List<ChatMessage>.from(value.messages)..add(userMsg),
      ),
    );

    final stream = FlightMockStreamer.streamConfirmationSurface(
      passengerName: name,
      seatTier: tier.label,
      finalPrice: value.calculatedTotal,
      delay: streamDelay,
    );
    surfaceBloc.add(IngestStream(stream));

    await Future<void>.delayed(
        streamDelay * 3 + const Duration(milliseconds: 20));
    if (isClosed || _activeOperationId != operationId) return;

    final assistantMsg = ChatMessage.assistant(
      'Your flight to Tokyo (HND) is successfully confirmed! Here is your booking receipt:',
      surfaceId: 'surf-booking-confirmation',
    );

    emit(
      value.copyWith(
        messages: List<ChatMessage>.from(value.messages)..add(assistantMsg),
        isStreaming: false,
        activeSurfaceId: 'surf-booking-confirmation',
      ),
    );
  }

  Future<void> _restartSearchAndEmit() async {
    surfaceBloc.add(const ResetSurface());
    // Directly delegate to startDiscoverySearch clearing prior messages in single emission
    await startDiscoverySearch(
      query: 'Find flights from San Francisco to Tokyo',
      clearMessages: true,
    );
  }

  @override
  Future<void> close() async {
    await _actionSubscription?.cancel();
    return super.close();
  }
}
