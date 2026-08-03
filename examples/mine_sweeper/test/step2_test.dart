import 'package:flutter_test/flutter_test.dart';
import 'package:mine_sweeper_example/src/models/difficulty.dart';
import 'package:mine_sweeper_example/src/state/game_state.dart';

void main() {
  group('Step 2: Game Logic Implementation', () {
    late GameBlocSignal bloc;

    setUp(() {
      bloc = GameBlocSignal()
        ..add(const ResetGameEvent(GameDifficulty.beginner));
    });

    test('T2.1: handleFirstClick places the correct number of mines', () {
      bloc.add(const FirstClickEvent(0, 0));
      final grid = bloc.stateValue.grid;
      final mineCount =
          grid.expand((row) => row).where((cell) => cell.isMine).length;
      expect(mineCount, GameDifficulty.beginner.mineCount);
    });

    test('T2.2: The first clicked cell is never a mine', () {
      for (int i = 0; i < 100; i++) {
        bloc.add(const ResetGameEvent(GameDifficulty.beginner));
        bloc.add(const FirstClickEvent(4, 4));
        final clickedCell = bloc.stateValue.grid[4][4];
        expect(clickedCell.isMine, isFalse, reason: "Failed on iteration $i");
      }
    });

    test('T2.2b: Neighbors of first clicked cell are never mines', () {
      for (int i = 0; i < 100; i++) {
        bloc.add(const ResetGameEvent(GameDifficulty.beginner));
        bloc.add(const FirstClickEvent(4, 4));

        for (int r = -1; r <= 1; r++) {
          for (int c = -1; c <= 1; c++) {
            final cell = bloc.stateValue.grid[4 + r][4 + c];
            expect(
              cell.isMine,
              isFalse,
              reason:
                  "Neighbor at (${4 + r}, ${4 + c}) was a mine on iteration $i",
            );
          }
        }
      }
    });

    test('T2.4: Uncovering a mine sets the game status to lost', () {
      bloc.add(const FirstClickEvent(0, 0));
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

      bloc.add(UncoverCellEvent(mineRow, mineCol));
      expect(bloc.stateValue.status, GameStatus.lost);
    });

    test('T2.5: Uncovering a blank cell reveals adjacent area', () {
      bloc.add(const FirstClickEvent(0, 0));
      expect(bloc.stateValue.grid[0][0].isCovered, isFalse);
    });

    test('T2.6: Uncovering all non-mine cells sets status to won', () {
      bloc.add(const FirstClickEvent(0, 0));
      final grid = bloc.stateValue.grid;

      for (int r = 0; r < bloc.stateValue.difficulty.rows; r++) {
        for (int c = 0; c < bloc.stateValue.difficulty.cols; c++) {
          if (!grid[r][c].isMine && bloc.stateValue.grid[r][c].isCovered) {
            bloc.add(UncoverCellEvent(r, c));
          }
        }
      }

      expect(bloc.stateValue.status, GameStatus.won);
    });
  });
}
