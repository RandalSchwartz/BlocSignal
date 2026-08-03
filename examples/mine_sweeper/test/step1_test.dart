import 'package:flutter_test/flutter_test.dart';
import 'package:mine_sweeper_example/src/models/cell.dart';
import 'package:mine_sweeper_example/src/models/difficulty.dart';
import 'package:mine_sweeper_example/src/state/game_state.dart';

void main() {
  group('Step 1: Core Data Models and Game State', () {
    test('T1.1: Cell model can be created and serialized', () {
      const cell = Cell();
      expect(cell.isCovered, isTrue);
      expect(cell.isFlagged, isFalse);
      expect(cell.isMine, isFalse);
      expect(cell.adjacentMines, 0);

      final updatedCell = cell.copyWith(
        isCovered: false,
        isFlagged: true,
        isMine: true,
        adjacentMines: 5,
      );

      expect(updatedCell.isCovered, isFalse);
      expect(updatedCell.isFlagged, isTrue);
      expect(updatedCell.isMine, isTrue);
      expect(updatedCell.adjacentMines, 5);

      final json = updatedCell.toJson();
      final restored = Cell.fromJson(json);
      expect(restored, equals(updatedCell));
    });

    test(
      'T1.2: GameBlocSignal can be initialized with a specific difficulty',
      () {
        final bloc = GameBlocSignal()
          ..add(const ResetGameEvent(GameDifficulty.intermediate));
        expect(bloc.stateValue.difficulty, GameDifficulty.intermediate);
        expect(bloc.stateValue.status, GameStatus.playing);
      },
    );

    test(
      'T1.3: GameBlocSignal grid is populated correctly based on difficulty',
      () {
        final bloc = GameBlocSignal()
          ..add(const ResetGameEvent(GameDifficulty.beginner));
        final grid = bloc.stateValue.grid;

        expect(grid.length, GameDifficulty.beginner.rows);
        expect(grid[0].length, GameDifficulty.beginner.cols);
        expect(grid.expand((row) => row).isNotEmpty, isTrue);
      },
    );

    test('T1.4: Derived properties derive their initial values correctly', () {
      final bloc = GameBlocSignal()
        ..add(const ResetGameEvent(GameDifficulty.expert));

      expect(bloc.stateValue.mineCount, GameDifficulty.expert.mineCount);
      expect(bloc.stateValue.flagCount, 0);

      bloc.add(const ToggleFlagEvent(0, 0));
      expect(bloc.stateValue.flagCount, 1);
    });

    test('GameBlocSignal reset method works correctly', () {
      final bloc = GameBlocSignal();
      bloc.add(const FirstClickEvent(0, 0));
      bloc.add(const ResetGameEvent(GameDifficulty.intermediate));

      expect(bloc.stateValue.difficulty, GameDifficulty.intermediate);
      expect(bloc.stateValue.grid.length, GameDifficulty.intermediate.rows);
      expect(bloc.stateValue.flagCount, 0);
      expect(bloc.stateValue.timer, 0);
      expect(bloc.stateValue.status, GameStatus.playing);
    });
  });
}
