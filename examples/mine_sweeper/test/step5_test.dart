import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_sweeper_example/src/models/difficulty.dart';
import 'package:mine_sweeper_example/src/state/game_state.dart';
import 'package:mine_sweeper_example/src/widgets/board_widget.dart';
import 'package:mine_sweeper_example/src/widgets/cell_widget.dart';
import 'package:mine_sweeper_example/src/widgets/mine_counter_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);
  });

  group('Step 5: User Interaction - Flagging', () {
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

    testWidgets('T5.1: Long press on a covered cell adds a flag', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const BoardWidget()));

      expect(bloc.stateValue.grid[0][0].isFlagged, isFalse);
      expect(find.byIcon(Icons.flag), findsNothing);

      await tester.longPress(find.byType(CellWidget).first);
      await tester.pump();

      expect(bloc.stateValue.grid[0][0].isFlagged, isTrue);
      expect(find.byIcon(Icons.flag), findsOneWidget);
      await bloc.close();
    });

    testWidgets('T5.2: A second long press removes the flag', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const BoardWidget()));

      await tester.longPress(find.byType(CellWidget).first);
      await tester.pump();
      expect(bloc.stateValue.grid[0][0].isFlagged, isTrue);

      await tester.longPress(find.byType(CellWidget).first);
      await tester.pump();
      expect(bloc.stateValue.grid[0][0].isFlagged, isFalse);
      await bloc.close();
    });

    testWidgets('T5.3: Flagging a cell decreases the mine counter', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestApp(
          const SingleChildScrollView(
            child: Column(children: [MineCounterWidget(), BoardWidget()]),
          ),
        ),
      );

      final initialMines = GameDifficulty.beginner.mineCount.toString().padLeft(
            3,
            '0',
          );
      final decrementedMines =
          (GameDifficulty.beginner.mineCount - 1).toString().padLeft(3, '0');

      expect(find.text(initialMines), findsOneWidget);

      await tester.longPress(find.byType(CellWidget).first);
      await tester.pump();

      expect(find.text(decrementedMines), findsOneWidget);
      await bloc.close();
    });

    testWidgets('T5.4: A simple tap on a flagged cell does nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const BoardWidget()));

      await tester.longPress(find.byType(CellWidget).first);
      await tester.pump();
      expect(bloc.stateValue.grid[0][0].isFlagged, isTrue);

      await tester.tap(find.byType(CellWidget).first);
      await tester.pump();

      expect(bloc.stateValue.grid[0][0].isCovered, isTrue);
      expect(bloc.stateValue.grid[0][0].isFlagged, isTrue);
      await bloc.close();
    });
  });
}
