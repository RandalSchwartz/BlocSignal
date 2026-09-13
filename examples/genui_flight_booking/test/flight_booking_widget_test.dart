import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flight_booking/src/models/flight_models.dart';
import 'package:genui_flight_booking/src/state/flight_assistant_cubit.dart';
import 'package:genui_flight_booking/src/ui/flight_booking_screen.dart';

void main() {
  group('FlightBookingScreen Widget Tests', () {
    late A2uiSurfaceBloc surfaceBloc;
    late FlightAssistantCubit cubit;

    setUp(() {
      surfaceBloc = A2uiSurfaceBloc();
      cubit = FlightAssistantCubit(surfaceBloc: surfaceBloc)
        ..streamDelay = Duration.zero;
    });

    tearDown(() async {
      await cubit.close();
      await surfaceBloc.close();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: BlocSignalProvider.value(
          value: surfaceBloc,
          child: BlocSignalProvider.value(
            value: cubit,
            child: const FlightBookingScreen(),
          ),
        ),
      );
    }

    testWidgets('renders initial search prompt and price banner',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('A2UI Generative Flight Booking'), findsOneWidget);
      expect(
        find.text('Ready to book your flight to Tokyo?'),
        findsOneWidget,
      );
      expect(find.text('Live Reactive Total: \$420 USD'), findsOneWidget);
      expect(find.text('Selected: Economy'), findsOneWidget);
    });

    testWidgets('tapping search button streams discovery flight card',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      final searchBtn = find.text('Search Flights (SFO ➔ HND)');
      expect(searchBtn, findsOneWidget);
      await tester.tap(searchBtn);
      await tester.pump();

      // Ingest stream takes a moment to process chunks
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Chat bubble from user and assistant
      expect(
        find.text('Find flights from San Francisco to Tokyo'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Here is the best flight match I found for SFO ➔ HND on Pacific Rim Airways:',
        ),
        findsOneWidget,
      );

      // Verify A2UI surface components rendered
      expect(find.text('Pacific Rim Airways (Nonstop)'), findsOneWidget);
      expect(find.text('SFO 11:20 AM'), findsOneWidget);
      expect(find.text('HND 3:05 PM +1'), findsOneWidget);
      expect(find.text('From \$420 USD'), findsOneWidget);
      expect(find.text('Select This Flight'), findsOneWidget);
    });

    testWidgets(
        'selecting flight navigates to customization surface and updates price',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());

      final searchBtn = find.text('Search Flights (SFO ➔ HND)');
      expect(searchBtn, findsOneWidget);
      await tester.tap(searchBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Tap "Select This Flight" button inside A2uiSurfaceView
      final selectFlightBtn = find.text('Select This Flight');
      expect(selectFlightBtn, findsOneWidget);
      await tester.tap(selectFlightBtn);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      // Customization surface should now be active
      expect(
        find.text('Passenger & Cabin Customization'),
        findsOneWidget,
      );
      expect(
        find.text('Primary Passenger Full Name'),
        findsOneWidget,
      );

      // Verify Addons Control Bar is visible
      expect(find.text('Checked Bag (+\$45)'), findsOneWidget);
      expect(find.text('Priority Boarding (+\$30)'), findsOneWidget);

      // Toggle luggage checkbox
      final luggageFinder = find.byType(CheckboxListTile).first;
      await tester.tap(luggageFinder);
      await tester.pump();

      // Price banner immediately updates via synchronous signal reaction
      expect(find.text('Live Reactive Total: \$465 USD'), findsOneWidget);

      // Enter passenger name in text field
      final tfFinder = find.byType(TextField).first;
      await tester.enterText(tfFinder, 'Wilhelm & Randal');
      await tester.pump();

      // Continue to confirmation
      final continueBtn = find.text('Continue to Confirmation');
      expect(continueBtn, findsOneWidget);
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      // Confirmation surface should be rendered
      expect(find.text('🎉 Booking Confirmed!'), findsOneWidget);
      expect(find.text('PNR Reference: PR-9942XJ'), findsOneWidget);
      expect(find.text('Passenger: Wilhelm & Randal'), findsOneWidget);
      expect(find.text('Total Paid: \$465 USD'), findsOneWidget);
      expect(find.text('Book Another Flight'), findsOneWidget);
    });

    testWidgets('mode filter chip toggles between Mock and Live modes',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      final chipFinder = find.byType(FilterChip);
      expect(chipFinder, findsOneWidget);
      expect(find.text('Mock Offline'), findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(cubit.value.mode, equals(ExecutionMode.liveGemini));
    });
  });
}
