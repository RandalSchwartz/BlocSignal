import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_sweeper_example/main.dart';
import 'package:mine_sweeper_example/src/models/difficulty.dart';
import 'package:mine_sweeper_example/src/screens/settings_screen.dart';
import 'package:mine_sweeper_example/src/state/game_state.dart';
import 'package:mine_sweeper_example/src/widgets/cell_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameBlocSignal bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);
    bloc = GameBlocSignal();
  });

  Widget createTestApp(Widget child) {
    return BlocSignalProvider<GameBlocSignal>.value(
      value: bloc,
      child: MaterialApp(home: child),
    );
  }

  group('Step 6: Settings and Difficulty Selection', () {
    testWidgets('T6.1: Settings screen can be opened from the game screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const GameScreen()));

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SettingsScreen), findsOneWidget);
      await bloc.close();
    });

    testWidgets('T6.2: Selecting a new difficulty changes the board size', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(const GameScreen()));

      expect(
        find.byType(CellWidget),
        findsNWidgets(
          GameDifficulty.beginner.rows * GameDifficulty.beginner.cols,
        ),
      );

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile &&
              widget.title is Text &&
              (widget.title as Text).data == 'Intermediate',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(
        find.byType(CellWidget),
        findsNWidgets(
          GameDifficulty.intermediate.rows * GameDifficulty.intermediate.cols,
        ),
      );
      await bloc.close();
    });

    testWidgets('T6.3: Mine counter updates after changing difficulty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const GameScreen()));

      expect(find.text('010'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile &&
              widget.title is Text &&
              (widget.title as Text).data == 'Expert',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('099'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('T6.4: Correct radio button is selected by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const GameScreen()));

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump();

      final radioGroup = tester.widget<RadioGroup<GameDifficulty>>(
        find.byType(RadioGroup<GameDifficulty>),
      );
      expect(radioGroup.groupValue, GameDifficulty.beginner);
      await bloc.close();
    });
  });
}
