import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:genui_flight_booking/src/models/chat_message.dart';
import 'package:genui_flight_booking/src/models/flight_models.dart';
import 'package:genui_flight_booking/src/state/flight_assistant_cubit.dart';

/// The primary flight booking interactive reference screen.
class FlightBookingScreen extends StatelessWidget {
  /// Creates a [FlightBookingScreen].
  const FlightBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FlightAssistantCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A2UI Generative Flight Booking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'BlocSignal + Google A2UI Declarative Stream',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          BlocSignalBuilder<FlightAssistantCubit, FlightAssistantState>(
            builder: (context, state) {
              final isMock = state.mode == ExecutionMode.mockSimulation;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilterChip(
                  avatar: Icon(
                    isMock ? Icons.offline_bolt : Icons.cloud_done,
                    size: 16,
                  ),
                  label: Text(isMock ? 'Mock Offline' : 'Live Gemini'),
                  selected: isMock,
                  onSelected: (val) {
                    cubit.toggleMode(
                      val
                          ? ExecutionMode.mockSimulation
                          : ExecutionMode.liveGemini,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Reactive Price Banner
          const _PriceBanner(),

          // Chat message list
          Expanded(
            child:
                BlocSignalBuilder<FlightAssistantCubit, FlightAssistantState>(
              builder: (context, state) {
                if (state.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flight_takeoff,
                          size: 64,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ready to book your flight to Tokyo?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap below to stream the generative UI discovery card.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => cubit.startDiscoverySearch(),
                          icon: const Icon(Icons.search),
                          label: const Text('Search Flights (SFO ➔ HND)'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.messages.length +
                      (state.activeSurfaceId != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < state.messages.length) {
                      final msg = state.messages[index];
                      return _ChatMessageBubble(message: msg);
                    }

                    // Render active A2UI surface container
                    return const _ActiveSurfaceCard();
                  },
                );
              },
            ),
          ),

          // Customization add-ons bar (reactive controls)
          const _AddonsControlBar(),
        ],
      ),
    );
  }
}

class _PriceBanner extends StatelessWidget {
  const _PriceBanner();

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<FlightAssistantCubit, FlightAssistantState>(
      builder: (context, state) {
        final total = state.calculatedTotal;
        final tier = state.selectedTier.label;

        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.airplane_ticket, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Selected: $tier',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                'Live Reactive Total: \$$total USD',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ActiveSurfaceCard extends StatelessWidget {
  const _ActiveSurfaceCard();

  @override
  Widget build(BuildContext context) {
    final surfaceBloc = context.read<A2uiSurfaceBloc>();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: A2uiSurfaceView(
          bloc: surfaceBloc,
          placeholderBuilder: (ctx) => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Initializing surface...')),
          ),
          streamingBuilder: (ctx, streaming) => Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: 0.5,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Streaming A2UI surface (${streaming.messageCount} chunks)...',
                ),
              ],
            ),
          ),
          submittingBuilder: (ctx, submitting) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Submitting ${submitting.actionName}...'),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddonsControlBar extends StatelessWidget {
  const _AddonsControlBar();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FlightAssistantCubit>();

    return BlocSignalBuilder<FlightAssistantCubit, FlightAssistantState>(
      builder: (context, state) {
        if (state.activeSurfaceId != 'surf-seat-customization') {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Checked Bag (+\$45)'),
                    value: state.hasCheckedLuggage,
                    onChanged: (val) => cubit.toggleLuggage(val ?? false),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Priority Boarding (+\$30)'),
                    value: state.hasPriorityBoarding,
                    onChanged: (val) =>
                        cubit.togglePriorityBoarding(val ?? false),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
