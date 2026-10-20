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
  final disposeStateSub = bloc.state.subscribe((state) {
    stdout.writeln(TuiRenderer.renderState(state));
  });

  // Listen to action responses dispatched by components
  final responseCompleter = Completer<void>();
  final responseSub = bloc.actionResponses.listen((response) {
    stdout.writeln(
      '\x1B[1;32m🚀 [Agent Tool Callback Response Received]\x1B[0m',
    );
    stdout.writeln('   Action: ${response.actionName}');
    stdout.writeln('   Surface: ${response.surfaceId}');
    stdout.writeln('   Form Data: ${response.formData}');
    if (!responseCompleter.isCompleted) {
      responseCompleter.complete();
    }
  });

  // Simulate streaming A2UI v0.9 BasicCatalog chunks
  final streamController = StreamController<dynamic>();
  bloc.add(IngestStream(streamController.stream));

  // [PRODUCTION CONSIDERATION]: In production, this mock stream delay is
  // replaced by Server-Sent Events (SSE) arriving from an enterprise AI agent.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  streamController.add({
    'version': 'v0.9',
    'createSurface': {
      'surfaceId': 'flight_booking_surface',
      'catalogId':
          'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json',
    },
  });

  await Future<void>.delayed(const Duration(milliseconds: 50));
  streamController.add({
    'version': 'v0.9',
    'updateDataModel': {
      'surfaceId': 'flight_booking_surface',
      'path': '/',
      'value': {
        'passengerName': '',
        'cabinTier': ['Business'],
        'priorityBoarding': true,
        'extraLegroom': 50,
        'departureDate': '2026-11-15',
      },
    },
  });

  await Future<void>.delayed(const Duration(milliseconds: 50));
  streamController.add({
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': 'flight_booking_surface',
      'components': [
        {'id': 'root', 'component': 'Card', 'child': 'main_col'},
        {
          'id': 'main_col',
          'component': 'Column',
          'children': [
            'txt_title',
            'tabs_nav',
            'field_passenger',
            'picker_tier',
            'chk_priority',
            'slider_legroom',
            'input_date',
            'div_line',
            'btn_confirm',
          ],
        },
        {
          'id': 'txt_title',
          'component': 'Text',
          'variant': 'h1',
          'text': 'Book Your Flight to Tokyo (HND)',
        },
        {
          'id': 'tabs_nav',
          'component': 'Tabs',
          'tabs': [
            {'title': 'Flights', 'child': 'txt_title'},
            {'title': 'Seat Map', 'child': 'txt_title'},
          ],
        },
        {
          'id': 'field_passenger',
          'component': 'TextField',
          'label': 'Passenger Full Name',
          'value': {'path': '/passengerName'},
        },
        {
          'id': 'picker_tier',
          'component': 'ChoicePicker',
          'label': 'Cabin Tier',
          'variant': 'mutuallyExclusive',
          'options': [
            {'label': 'Economy', 'value': 'Economy'},
            {'label': 'Business', 'value': 'Business'},
          ],
          'value': {'path': '/cabinTier'},
        },
        {
          'id': 'chk_priority',
          'component': 'CheckBox',
          'label': 'Priority Boarding',
          'value': {'path': '/priorityBoarding'},
        },
        {
          'id': 'slider_legroom',
          'component': 'Slider',
          'label': 'Extra Legroom',
          'min': 0,
          'max': 100,
          'value': {'path': '/extraLegroom'},
        },
        {
          'id': 'input_date',
          'component': 'DateTimeInput',
          'label': 'Departure Date',
          'value': {'path': '/departureDate'},
        },
        {'id': 'div_line', 'component': 'Divider'},
        {
          'id': 'btn_confirm',
          'component': 'Button',
          'variant': 'primary',
          'child': 'txt_btn_label',
          'action': {
            'event': {'name': 'confirmBooking'},
          },
        },
        {'id': 'txt_btn_label', 'component': 'Text', 'text': 'Confirm Booking'},
      ],
    },
  });

  await streamController.close();
  await Future<void>.delayed(const Duration(milliseconds: 50));

  // Simulate 0ms user input into form
  stdout.writeln(
    '\x1B[35m⌨️  Simulating user typing "Randal L. Schwartz" into form...\x1B[0m',
  );
  bloc.add(
    const UpdateFormField(
      path: '/passengerName',
      value: 'Randal L. Schwartz',
      surfaceId: 'flight_booking_surface',
    ),
  );

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

  await responseCompleter.future;
  stdout.writeln(
    '\n\x1B[1;32m✅ Generative UI lifecycle demonstration complete!\x1B[0m',
  );
  disposeStateSub();
  await responseSub.cancel();
  await bloc.close();
}
