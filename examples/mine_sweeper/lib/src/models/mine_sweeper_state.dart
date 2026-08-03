import 'cell.dart';
import 'difficulty.dart';

/// Current status of the Minesweeper game session.
enum GameStatus {
  /// Game is active and in progress.
  playing,

  /// Player successfully revealed all non-mine cells.
  won,

  /// Player uncovered a mine.
  lost,
}

/// Immutable state container representing the entire Minesweeper game session.
class MineSweeperState {
  /// Target board difficulty settings.
  final GameDifficulty difficulty;

  /// 2D grid matrix of cells ([difficulty.rows] x [difficulty.cols]).
  final List<List<Cell>> grid;

  /// Current game lifecycle status.
  final GameStatus status;

  /// Elapsed time in seconds since the first cell click.
  final int timer;

  /// Constructs an immutable [MineSweeperState].
  const MineSweeperState({
    required this.difficulty,
    required this.grid,
    required this.status,
    required this.timer,
  });

  /// Factory constructor to initialize a fresh game session for the given [difficulty].
  factory MineSweeperState.initial({
    GameDifficulty difficulty = GameDifficulty.beginner,
  }) {
    return MineSweeperState(
      difficulty: difficulty,
      grid: List.generate(
        difficulty.rows,
        (_) => List.generate(difficulty.cols, (_) => const Cell()),
      ),
      status: GameStatus.playing,
      timer: 0,
    );
  }

  /// Total number of mines hidden on the board.
  int get mineCount => difficulty.mineCount;

  /// Total number of flags currently placed by the player.
  int get flagCount =>
      grid.expand((row) => row).where((cell) => cell.isFlagged).length;

  /// Creates a copy of this state with specified fields updated.
  MineSweeperState copyWith({
    GameDifficulty? difficulty,
    List<List<Cell>>? grid,
    GameStatus? status,
    int? timer,
  }) {
    return MineSweeperState(
      difficulty: difficulty ?? this.difficulty,
      grid: grid ?? this.grid,
      status: status ?? this.status,
      timer: timer ?? this.timer,
    );
  }

  /// Serializes game state to a JSON-compatible map for persistence.
  Map<String, dynamic> toJson() => {
        'difficulty': difficulty.toJson(),
        'grid': grid
            .map((row) => row.map((cell) => cell.toJson()).toList())
            .toList(),
        'status': status.name,
        'timer': timer,
      };

  /// Deserializes game state from JSON during storage hydration.
  factory MineSweeperState.fromJson(dynamic json) => switch (json) {
        {
          'difficulty': dynamic difficultyJson,
          'grid': List rawGrid,
          'status': String statusName,
          'timer': int timer,
        } =>
          MineSweeperState(
            difficulty: GameDifficulty.fromJson(difficultyJson),
            grid: rawGrid
                .map(
                  (row) =>
                      (row as List).map((cell) => Cell.fromJson(cell)).toList(),
                )
                .toList(),
            status: GameStatus.values.firstWhere(
              (e) => e.name == statusName,
              orElse: () => GameStatus.playing,
            ),
            timer: timer,
          ),
        _ => MineSweeperState.initial(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MineSweeperState) return false;
    if (difficulty != other.difficulty ||
        status != other.status ||
        timer != other.timer ||
        grid.length != other.grid.length) {
      return false;
    }
    for (int i = 0; i < grid.length; i++) {
      if (grid[i].length != other.grid[i].length) return false;
      for (int j = 0; j < grid[i].length; j++) {
        if (grid[i][j] != other.grid[i][j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        difficulty,
        status,
        timer,
        Object.hashAll(grid.expand((row) => row)),
      );
}
