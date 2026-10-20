import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:flutter/foundation.dart';
import 'package:genui_flight_booking/src/models/chat_message.dart';
import 'package:genui_flight_booking/src/models/flight_models.dart';
import 'package:genui_flight_booking/src/services/flight_mock_streamer.dart';
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
    this.departureDate = '2026-10-15',
    this.assignedSeat,
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

  /// Departure date captured from `DateTimeInput` (`YYYY-MM-DD`).
  final String departureDate;

  /// Seat assignment resolved via bidirectional RPC (`callAgentFunction`).
  final String? assignedSeat;

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
    String? departureDate,
    String? assignedSeat,
    bool clearAssignedSeat = false,
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
      departureDate: departureDate ?? this.departureDate,
      assignedSeat:
          clearAssignedSeat ? null : (assignedSeat ?? this.assignedSeat),
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
          departureDate == other.departureDate &&
          assignedSeat == other.assignedSeat &&
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
        departureDate,
        assignedSeat,
        hasCheckedLuggage,
        hasPriorityBoarding,
      );
}

/// Orchestrates chat turns, A2UI surface lifecycle streaming, two-way
/// `DataModel` synchronization, and bidirectional RPC seat assignment.
///
/// **Production Architecture Note**:
/// In a production enterprise system, this cubit would not execute mock stream
/// generators or interface directly with client-held LLM API keys. Instead:
/// 1. A remote Backend-for-Frontend (BFF) gateway would authenticate client
///    sessions, securely manage agent credentials, and stream A2UI JSON over SSE
///    or WebSockets.
/// 2. Action submissions ([A2uiActionResponse]) and outbound RPC calls
///    ([CallAgentFunctionMessage]) would be dispatched back to the remote agent.
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
    // Ignore unused _geminiApiKey in offline simulation mode while keeping it
    // available for live Gemini extension hooks.
    assert(_geminiApiKey == null || _geminiApiKey.isNotEmpty || true, '');

    // Listen to action submissions from A2uiSurfaceBloc
    _actionSubscription = surfaceBloc.actionResponses.listen((response) {
      unawaited(_handleSurfaceAction(response));
    });

    // Synchronize 0ms DataModel updates from ChoicePicker, CheckBox,
    // DateTimeInput, and TextField on the customization surface.
    _surfaceStateUnsubscribe =
        surfaceBloc.state.subscribe(_syncFromSurfaceState);

    // Subscribe to outbound RPC envelopes to respond to callAgentFunction
    // requests in mock simulation mode.
    _outboundRpcSubscription =
        surfaceBloc.outboundMessages.listen(_handleOutboundRpcMessage);
  }

  /// The underlying A2UI surface bloc managing declarative UI state.
  final A2uiSurfaceBloc surfaceBloc;

  final String? _geminiApiKey;
  StreamSubscription<A2uiActionResponse>? _actionSubscription;
  StreamSubscription<RendererToAgentMessage>? _outboundRpcSubscription;
  void Function()? _surfaceStateUnsubscribe;

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

  void _syncFromSurfaceState(A2uiSurfaceState surfaceState) {
    if (isClosed) return;
    if (surfaceState is! SurfaceReady) return;
    if (surfaceState.surfaceId != 'surf-seat-customization') return;

    final dataModel = surfaceState.surface.dataModel;

    final rawTier = dataModel.get('/booking/tier');
    final parsedTier = _parseSeatTier(rawTier);

    final rawName = dataModel.get('/passenger/name');
    final parsedName = rawName is String ? rawName : value.passengerName;

    final rawDate = dataModel.get('/booking/departureDate');
    final parsedDate =
        rawDate is String && rawDate.isNotEmpty ? rawDate : value.departureDate;

    final rawLuggage = dataModel.get('/addons/checkedLuggage');
    final parsedLuggage =
        rawLuggage is bool ? rawLuggage : value.hasCheckedLuggage;

    final rawPriority = dataModel.get('/addons/priorityBoarding');
    final parsedPriority =
        rawPriority is bool ? rawPriority : value.hasPriorityBoarding;

    emit(
      value.copyWith(
        selectedTier: parsedTier ?? value.selectedTier,
        passengerName: parsedName,
        departureDate: parsedDate,
        hasCheckedLuggage: parsedLuggage,
        hasPriorityBoarding: parsedPriority,
      ),
    );
  }

  static SeatTier? _parseSeatTier(Object? rawTier) {
    String? tierStr;
    if (rawTier is Iterable) {
      if (rawTier.isNotEmpty) {
        tierStr = rawTier.first?.toString();
      }
    } else if (rawTier is String) {
      tierStr = rawTier;
    }
    if (tierStr == null || tierStr.isEmpty) return null;
    final lower = tierStr.toLowerCase();
    if (lower.contains('business')) return SeatTier.business;
    if (lower.contains('premium')) return SeatTier.premium;
    if (lower.contains('economy')) return SeatTier.economy;
    return null;
  }

  void _handleOutboundRpcMessage(RendererToAgentMessage message) {
    if (isClosed) return;
    if (message is CallAgentFunctionMessage) {
      final fnName =
          (message.callFunction['@call'] ?? message.callFunction['call'])
              ?.toString();
      if (fnName == 'assignPreferredSeat') {
        final args = message.callFunction['args'];
        final tierArg = args is Map
            ? args['tier']?.toString() ?? ''
            : value.selectedTier.label;
        final assigned = _seatForTierLabel(tierArg);
        surfaceBloc.add(
          ProcessMessage(
            AgentFunctionResponseMessage(
              version: 'v1.0',
              response: A2uiFunctionResponse.value(
                message.functionCallId,
                assigned,
              ),
            ),
          ),
        );
      }
    }
  }

  static String _seatForTierLabel(String tierLabel) {
    final lower = tierLabel.toLowerCase();
    if (lower.contains('business')) {
      return '2A (Lie-Flat Suite)';
    }
    if (lower.contains('premium')) {
      return '10C (Extra Legroom)';
    }
    return '14A (Window)';
  }

  /// Invokes bidirectional RPC (`callAgentFunction`) on [surfaceBloc] to
  /// request a preferred seat assignment from the agent for the current cabin
  /// tier, and updates both [FlightAssistantState.assignedSeat] and the
  /// surface's `/booking/assignedSeat` data model path.
  Future<String> requestSeatAssignment() async {
    final targetSurfaceId =
        surfaceBloc.activeSurfaceIdValue ?? 'surf-seat-customization';
    Object? response;
    try {
      response = await surfaceBloc.callAgentFunction(
        targetSurfaceId,
        FunctionCall(
          call: 'assignPreferredSeat',
          args: <String, Object?>{
            'tier': value.selectedTier.label,
          },
        ),
      );
    } on Exception catch (_) {
      // Transient RPC timeout or network error falls back gracefully to
      // local tier-based seat selection below.
      response = null;
    }
    final seat =
        response?.toString() ?? _seatForTierLabel(value.selectedTier.label);
    if (!isClosed) {
      surfaceBloc.add(
        UpdateFormField(
          surfaceId: targetSurfaceId,
          path: '/booking/assignedSeat',
          value: 'Assigned Seat: $seat',
        ),
      );
      emit(value.copyWith(assignedSeat: seat));
    }
    return seat;
  }

  /// Operation generation ID tracking active asynchronous pipeline requests.
  int _activeOperationId = 0;

  /// Stream delay duration for mock responses.
  Duration streamDelay = const Duration(milliseconds: 10);

  /// Initiates the flight search discovery turn.
  ///
  /// Optionally accepts [streamOverride] for testing or custom stream sources.
  Future<void> startDiscoverySearch({
    String query = 'Find flights from San Francisco to Tokyo',
    Duration? delay,
    bool clearMessages = false,
    Stream<Map<String, dynamic>>? streamOverride,
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
        departureDate: clearMessages ? '2026-10-15' : value.departureDate,
        clearAssignedSeat: clearMessages,
        hasCheckedLuggage: clearMessages ? false : value.hasCheckedLuggage,
        hasPriorityBoarding: clearMessages ? false : value.hasPriorityBoarding,
        clearActiveSurfaceId: clearMessages,
      ),
    );

    // Stream the flight discovery surface while monitoring chunk arrival count
    var chunkCount = 0;
    final rawStream = streamOverride ??
        FlightMockStreamer.streamDiscoverySurface(delay: effectiveDelay);
    final stream = rawStream.transform(
      StreamTransformer<Map<String, dynamic>,
          Map<String, dynamic>>.fromHandlers(
        handleData: (chunk, sink) {
          chunkCount++;
          sink.add(chunk);
        },
        handleError: (error, stackTrace, sink) {
          sink.addError(error, stackTrace);
        },
      ),
    );
    surfaceBloc.add(IngestStream(stream));

    // Wait briefly for ingestion to settle
    await Future<void>.delayed(
        effectiveDelay * 3 + const Duration(milliseconds: 20));
    if (isClosed || _activeOperationId != operationId) return;

    // Defense against zero-chunk stream failure (SCAR-GENUI-3):
    // If the stream errored or terminated before delivering any chunks,
    // prune the optimistic user turn so subsequent retries do not trigger
    // "INVALID_ARGUMENT: Consecutive user turns are not allowed".
    if (surfaceBloc.stateValue is SurfaceError ||
        (chunkCount == 0 && surfaceBloc.stateValue is! SurfaceReady)) {
      emit(
        value.copyWith(
          messages: List<ChatMessage>.from(value.messages)..remove(userMsg),
          isStreaming: false,
        ),
      );
      return;
    }

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
      case 'requestSeatAssignment':
        surfaceBloc.add(
          CompleteAction(surfaceId: response.surfaceId),
        );
        await requestSeatAssignment();
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

    final rawFormTier = response.getFormValue<Object?>('/booking/tier') ??
        response.getFormValue<Object?>('booking.tier') ??
        response.getFormValue<Object?>('input_seat_tier');
    final parsedTier = _parseSeatTier(rawFormTier);
    if (parsedTier != null) {
      tier = parsedTier;
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
    _surfaceStateUnsubscribe?.call();
    _surfaceStateUnsubscribe = null;
    await _actionSubscription?.cancel();
    await _outboundRpcSubscription?.cancel();
    return super.close();
  }
}
