import 'dart:async';
import 'dart:math';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import '../models/cell.dart';
import '../models/difficulty.dart';
import '../models/mine_sweeper_state.dart';

export '../models/mine_sweeper_state.dart';

/// Sealed base class for all Minesweeper user and system actions.
///
/// Sealed class inheritance ensures compile-time exhaustive pattern matching
/// when processing events inside `GameBlocSignal.onEvent`.
sealed class GameEvent {
  const GameEvent();
}

/// Dispatched on the player's first click on the game board.
///
/// Guarantees that cell `(row, col)` and all its immediate neighbors are safe
/// from mines before placing mines across the rest of the board.
final class FirstClickEvent extends GameEvent {
  /// Zero-based row coordinate of the first clicked cell.
  final int row;

  /// Zero-based column coordinate of the first clicked cell.
  final int col;

  const FirstClickEvent(this.row, this.col);
}

/// Dispatched when a player clicks to reveal cell `(row, col)`.
final class UncoverCellEvent extends GameEvent {
  /// Zero-based row coordinate of the cell.
  final int row;

  /// Zero-based column coordinate of the cell.
  final int col;

  const UncoverCellEvent(this.row, this.col);
}

/// Dispatched when a player long-presses cell `(row, col)` to toggle a flag.
final class ToggleFlagEvent extends GameEvent {
  /// Zero-based row coordinate of the cell.
  final int row;

  /// Zero-based column coordinate of the cell.
  final int col;

  const ToggleFlagEvent(this.row, this.col);
}

/// Dispatched to reset the game board to a fresh state.
///
/// Optionally accepts a new [difficulty]; if omitted, resets using the current difficulty.
final class ResetGameEvent extends GameEvent {
  /// Optional target game difficulty for the new board.
  final GameDifficulty? difficulty;

  const ResetGameEvent([this.difficulty]);
}

/// Periodic heartbeat event dispatched every second to increment the game timer.
final class TickTimerEvent extends GameEvent {
  const TickTimerEvent();
}

/// Central state container for the Minesweeper game.
///
/// Extends [HydratedBlocSignal] to provide:
/// 1. **Synchronous State Propagation**: State changes trigger instant frame rebuilds.
/// 2. **Automated Local Persistence**: Automatically saves and restores game state
///    (difficulty, timer, grid, status) across app restarts via `HydratedStorage`.
/// 3. **Encapsulated Timer Loop**: Automatically starts, ticks, and cancels its internal
///    [Timer] based on game status, even after restoring a saved game state.
class GameBlocSignal extends HydratedBlocSignal<GameEvent, MineSweeperState> {
  Timer? _timer;

  /// Constructs a [GameBlocSignal] with initial state.
  ///
  /// Automatically resumes the timer ticker if a game state was hydrated in
  /// [GameStatus.playing] with elapsed time.
  GameBlocSignal() : super(initialState: MineSweeperState.initial()) {
    if (stateValue.status == GameStatus.playing && stateValue.timer > 0) {
      _startTimer();
    }
  }

  /// Internal helper to start the 1-second periodic timer loop.
  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const TickTimerEvent());
    });
  }

  /// Internal helper to cancel the periodic timer loop.
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() async {
    _stopTimer();
    return super.close();
  }

  @override
  FutureOr<void> onEvent(GameEvent event) {
    switch (event) {
      case FirstClickEvent(:final row, :final col):
        _handleFirstClick(row, col);
      case UncoverCellEvent(:final row, :final col):
        _uncoverCell(row, col);
      case ToggleFlagEvent(:final row, :final col):
        _toggleFlag(row, col);
      case ResetGameEvent(:final difficulty):
        _reset(difficulty);
      case TickTimerEvent():
        _tickTimer();
    }
    return super.onEvent(event);
  }

  @override
  MineSweeperState? fromJson(dynamic json) => switch (json) {
        Map<String, dynamic>() => MineSweeperState.fromJson(json),
        _ => null,
      };

  @override
  dynamic toJson(MineSweeperState state) => state.toJson();

  void _reset(GameDifficulty? newDifficulty) {
    _stopTimer();
    emit(
      MineSweeperState.initial(
        difficulty: newDifficulty ?? stateValue.difficulty,
      ),
    );
  }

  void _tickTimer() {
    if (stateValue.status == GameStatus.playing) {
      emit(stateValue.copyWith(timer: stateValue.timer + 1));
    } else {
      _stopTimer();
    }
  }

  void _handleFirstClick(int row, int col) {
    final difficulty = stateValue.difficulty;
    final grid = _createEmptyGrid(difficulty);

    _placeMines(grid, difficulty, row, col);
    _calculateAdjacentMines(grid, difficulty);

    emit(stateValue.copyWith(grid: grid, status: GameStatus.playing));
    _startTimer();

    _uncoverCell(row, col);
  }

  void _uncoverCell(int row, int col) {
    final grid = _deepCopyGrid(stateValue.grid);
    final cell = grid[row][col];

    if (!cell.isCovered || cell.isFlagged) {
      return;
    }

    grid[row][col] = cell.copyWith(isCovered: false);

    if (cell.isMine) {
      _revealAllMines(grid);
      _stopTimer();
      emit(stateValue.copyWith(grid: grid, status: GameStatus.lost));
      return;
    }

    if (cell.adjacentMines == 0) {
      _floodFillUncover(grid, row, col);
    }

    final isWon = _checkWinCondition(grid);
    if (isWon) {
      _stopTimer();
    }
    emit(
      stateValue.copyWith(
        grid: grid,
        status: isWon ? GameStatus.won : stateValue.status,
      ),
    );
  }

  void _toggleFlag(int row, int col) {
    final grid = _deepCopyGrid(stateValue.grid);
    final cell = grid[row][col];

    if (cell.isCovered) {
      grid[row][col] = cell.copyWith(isFlagged: !cell.isFlagged);
      emit(stateValue.copyWith(grid: grid));
    }
  }

  List<List<Cell>> _createEmptyGrid(GameDifficulty difficulty) {
    return List.generate(
      difficulty.rows,
      (_) => List.generate(difficulty.cols, (_) => const Cell()),
    );
  }

  List<List<Cell>> _deepCopyGrid(List<List<Cell>> source) {
    return source.map((row) => List<Cell>.from(row)).toList();
  }

  void _placeMines(
    List<List<Cell>> grid,
    GameDifficulty difficulty,
    int initialRow,
    int initialCol,
  ) {
    int minesToPlace = difficulty.mineCount;
    final random = Random();

    final Set<Point<int>> forbiddenSpots = {};
    for (int r = -1; r <= 1; r++) {
      for (int c = -1; c <= 1; c++) {
        int newRow = initialRow + r;
        int newCol = initialCol + c;
        if (_isValidCell(newRow, newCol, difficulty)) {
          forbiddenSpots.add(Point(newRow, newCol));
        }
      }
    }

    while (minesToPlace > 0) {
      int r = random.nextInt(difficulty.rows);
      int c = random.nextInt(difficulty.cols);

      if (!grid[r][c].isMine && !forbiddenSpots.contains(Point(r, c))) {
        grid[r][c] = grid[r][c].copyWith(isMine: true);
        minesToPlace--;
      }
    }
  }

  void _calculateAdjacentMines(
    List<List<Cell>> grid,
    GameDifficulty difficulty,
  ) {
    for (int r = 0; r < difficulty.rows; r++) {
      for (int c = 0; c < difficulty.cols; c++) {
        if (!grid[r][c].isMine) {
          int count = 0;
          for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
              if (i == 0 && j == 0) continue;
              int newRow = r + i;
              int newCol = c + j;
              if (_isValidCell(newRow, newCol, difficulty) &&
                  grid[newRow][newCol].isMine) {
                count++;
              }
            }
          }
          grid[r][c] = grid[r][c].copyWith(adjacentMines: count);
        }
      }
    }
  }

  void _floodFillUncover(List<List<Cell>> grid, int row, int col) {
    final difficulty = stateValue.difficulty;
    final queue = [
      [row, col],
    ];

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final r = curr[0];
      final c = curr[1];

      for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
          if (i == 0 && j == 0) continue;
          int nr = r + i;
          int nc = c + j;
          if (_isValidCell(nr, nc, difficulty)) {
            final neighbor = grid[nr][nc];
            if (neighbor.isCovered && !neighbor.isFlagged) {
              grid[nr][nc] = neighbor.copyWith(isCovered: false);
              if (neighbor.adjacentMines == 0) {
                queue.add([nr, nc]);
              }
            }
          }
        }
      }
    }
  }

  void _revealAllMines(List<List<Cell>> grid) {
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        if (grid[r][c].isMine) {
          grid[r][c] = grid[r][c].copyWith(isCovered: false);
        }
      }
    }
  }

  bool _checkWinCondition(List<List<Cell>> grid) {
    for (var row in grid) {
      for (var cell in row) {
        if (cell.isCovered && !cell.isMine) {
          return false;
        }
      }
    }
    return true;
  }

  bool _isValidCell(int row, int col, GameDifficulty difficulty) {
    return row >= 0 &&
        row < difficulty.rows &&
        col >= 0 &&
        col < difficulty.cols;
  }
}
