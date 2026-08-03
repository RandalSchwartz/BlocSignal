import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_sweeper_example/main.dart';
import 'package:mine_sweeper_example/src/models/difficulty.dart';
import 'package:mine_sweeper_example/src/state/game_state.dart';
import 'package:mine_sweeper_example/src/widgets/cell_widget.dart';
import 'package:mine_sweeper_example/src/widgets/mine_counter_widget.dart';
import 'package:mine_sweeper_example/src/widgets/reset_button_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);
  });

  group('Step 4: UI - Header and Game Controls', () {
    late GameBlocSignal bloc;

    setUp(() {
      bloc = GameBlocSignal()
        ..add(const ResetGameEvent(GameDifficulty.beginner));
    });

    Widget createTestApp(Widget child) {
      return BlocSignalProvider<GameBlocSignal>.value(
        value: bloc,
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('T4.1: Timer starts and increments after first click', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        BlocSignalProvider<GameBlocSignal>.value(
          value: bloc,
          child: const MyApp(),
        ),
      );

      expect(find.text('000'), findsOneWidget);

      await tester.tap(find.byType(CellWidget).first);
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('003'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('008'), findsOneWidget);

      // Access the created GameBlocSignal from context to close timer before test exits
      final element = tester.element(find.byType(MyApp));
      await element.read<GameBlocSignal>().close();
    });

    testWidgets('T4.2: Mine counter displays correct initial value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const MineCounterWidget()));

      final expectedMines =
          GameDifficulty.beginner.mineCount.toString().padLeft(3, '0');
      expect(find.text(expectedMines), findsOneWidget);
      await bloc.close();
    });

    testWidgets('T4.3: Reset button starts a new game', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        BlocSignalProvider<GameBlocSignal>.value(
          value: bloc,
          child: const MyApp(),
        ),
      );

      bloc.add(const TickTimerEvent());
      bloc.add(const ToggleFlagEvent(0, 0));
      await tester.pump();

      expect(find.text('001'), findsOneWidget);

      await tester.tap(find.byType(ResetButtonWidget));
      await tester.pump();

      expect(find.text('000'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('T4.4: Smiley face icon reflects game state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const ResetButtonWidget()));

      expect(find.byIcon(Icons.sentiment_satisfied), findsOneWidget);

      bloc.emit(bloc.stateValue.copyWith(status: GameStatus.won));
      await tester.pump();
      expect(find.byIcon(Icons.sentiment_very_satisfied), findsOneWidget);

      bloc.emit(bloc.stateValue.copyWith(status: GameStatus.lost));
      await tester.pump();
      expect(find.byIcon(Icons.sentiment_very_dissatisfied), findsOneWidget);
      await bloc.close();
    });
  });
}
