import 'dart:async';
import 'dart:io';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:genui_tui_agent/src/tui_renderer.dart';

Future<void> main(List<String> args) async {
  stdout.writeln(
    '\x1B[1;36m🤖 BlocSignal A2UI TUI Showcase (agy-cli style)\x1B[0m\n',
  );

  // Check auth tier
  final geminiKey = Platform.environment['GEMINI_API_KEY'];
  final useMock =
      args.contains('--mock') || (geminiKey == null || geminiKey.isEmpty);

  if (useMock) {
    stdout.writeln(
      '\x1B[33mℹ️  Running in Tier 3 (Zero-Key Offline Simulation)\x1B[0m',
    );
  } else {
    stdout.writeln(
      '\x1B[32m🔑 Found GEMINI_API_KEY in environment (Tier 2 Execution)\x1B[0m',
    );
  }

  final bloc = A2uiSurfaceBloc();

  // Print state changes via TUI renderer
  bloc.state.subscribe((state) {
    stdout.writeln(TuiRenderer.renderState(state));
  });

  // Listen to action responses dispatched by components
  bloc.actionResponses.listen((response) {
    stdout.writeln(
      '\x1B[1;32m🚀 [Agent Tool Callback Response Received]\x1B[0m',
    );
    stdout.writeln('   Action: ${response.actionName}');
    stdout.writeln('   Surface: ${response.surfaceId}');
    stdout.writeln('   Form Data: ${response.formData}');
  });

  // Simulate streaming A2UI chunks
  final streamController = StreamController<dynamic>();
  bloc.add(IngestStream(streamController.stream));

  await Future<void>.delayed(const Duration(milliseconds: 300));
  streamController.add({
    'version': 'v0.9',
    'createSurface': {
      'surfaceId': 'flight_booking_surface',
      'catalogId': 'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json',
    },
  });

  await Future<void>.delayed(const Duration(milliseconds: 300));
  streamController.add({
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': 'flight_booking_surface',
      'components': [
        {
          'id': 'txt_title',
          'component': 'Text',
          'variant': 'h1',
          'text': 'Book Your Flight to Tokyo (HND)',
        },
        {
          'id': 'field_passenger',
          'component': 'TextField',
          'label': 'Passenger Full Name',
        },
        {
          'id': 'btn_confirm',
          'component': 'Button',
          'variant': 'primary',
          'child': 'txt_title',
          'action': {'name': 'confirmBooking'},
        },
      ],
    },
  });

  await streamController.close();
  await Future<void>.delayed(const Duration(milliseconds: 400));

  // Simulate 0ms user input into form
  stdout.writeln(
    '\x1B[35m⌨️  Simulating user typing "Merlyn Schwartz" into form...\x1B[0m',
  );
  bloc.add(
    const UpdateFormField(
      path: '/passengerName',
      value: 'Merlyn Schwartz',
      surfaceId: 'flight_booking_surface',
    ),
  );

  await Future<void>.delayed(const Duration(milliseconds: 400));

  // Simulate user clicking submit button
  stdout.writeln(
    '\x1B[35m👆 Simulating user clicking "Confirm Booking" button...\x1B[0m',
  );
  bloc.add(
    const SubmitAction(
      actionName: 'confirmBooking',
      sourceComponentId: 'btn_confirm',
      surfaceId: 'flight_booking_surface',
    ),
  );

  await Future<void>.delayed(const Duration(milliseconds: 400));
  stdout.writeln(
    '\n\x1B[1;32m✅ Generative UI lifecycle demonstration complete!\x1B[0m',
  );
  await bloc.close();
}
