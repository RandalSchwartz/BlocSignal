import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_sweeper_example/src/models/difficulty.dart';
import 'package:mine_sweeper_example/src/state/game_state.dart';
import 'package:mine_sweeper_example/src/widgets/board_widget.dart';
import 'package:mine_sweeper_example/src/widgets/cell_widget.dart';

void main() {
  group('Step 3: Basic UI - Board Rendering', () {
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

    testWidgets('T3.1: BoardWidget renders the correct number of cells', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(const BoardWidget()));

      final beginner = GameDifficulty.beginner;
      expect(
        find.byType(CellWidget),
        findsNWidgets(beginner.rows * beginner.cols),
      );
      await bloc.close();
    });

    testWidgets('T3.2: Tapping a covered cell uncovers it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const BoardWidget()));

      expect(bloc.stateValue.grid[0][0].isCovered, isTrue);

      await tester.tap(find.byType(CellWidget).first);
      await tester.pump();

      expect(bloc.stateValue.grid[0][0].isCovered, isFalse);
      await bloc.close();
    });

    testWidgets('T3.3: Tapping a blank cell uncovers adjacent cells', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const BoardWidget()));

      await tester.tap(find.byType(CellWidget).first);
      await tester.pump();

      expect(bloc.stateValue.grid[0][0].isCovered, isFalse);
      await bloc.close();
    });

    testWidgets('T3.4: Tapping a mine reveals all mines', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const BoardWidget()));

      await tester.tap(find.byType(CellWidget).first);
      await tester.pump();

      final grid = bloc.stateValue.grid;
      int mineRow = -1;
      int mineCol = -1;
      for (int r = 0; r < grid.length; r++) {
        for (int c = 0; c < grid[r].length; c++) {
          if (grid[r][c].isMine) {
            mineRow = r;
            mineCol = c;
            break;
          }
        }
        if (mineRow != -1) break;
      }

      if (mineRow != -1) {
        bloc.add(UncoverCellEvent(mineRow, mineCol));
        await tester.pump();

        expect(bloc.stateValue.status, GameStatus.lost);
      }
      await bloc.close();
    });
  });
}
