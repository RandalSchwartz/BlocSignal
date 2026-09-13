import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:flutter/material.dart';
import 'package:genui_flight_booking/src/state/flight_assistant_cubit.dart';
import 'package:genui_flight_booking/src/ui/flight_booking_screen.dart';

void main() {
  runApp(const GenUiFlightBookingApp());
}

/// The root application widget for the Generative UI Flight Booking showcase.
class GenUiFlightBookingApp extends StatelessWidget {
  /// Creates a [GenUiFlightBookingApp].
  const GenUiFlightBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlocSignal Generative Flight Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
      ),
      home: BlocSignalProvider(
        create: (context) => A2uiSurfaceBloc(),
        child: Builder(
          builder: (context) {
            final surfaceBloc = context.read<A2uiSurfaceBloc>();
            return BlocSignalProvider(
              create: (context) => FlightAssistantCubit(
                surfaceBloc: surfaceBloc,
                geminiApiKey: const String.fromEnvironment('GEMINI_API_KEY'),
              ),
              child: const FlightBookingScreen(),
            );
          },
        ),
      ),
    );
  }
}
