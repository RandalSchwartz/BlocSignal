/// Defines board dimensions and mine counts for Minesweeper difficulty levels.
class GameDifficulty {
  /// Number of grid rows.
  final int rows;

  /// Number of grid columns.
  final int cols;

  /// Total number of mines hidden on the board.
  final int mineCount;

  /// Creates a custom [GameDifficulty].
  const GameDifficulty({
    required this.rows,
    required this.cols,
    required this.mineCount,
  });

  /// Standard Beginner level: 9x9 grid with 10 mines.
  static const beginner = GameDifficulty(rows: 9, cols: 9, mineCount: 10);

  /// Standard Intermediate level: 16x16 grid with 40 mines.
  static const intermediate = GameDifficulty(rows: 16, cols: 16, mineCount: 40);

  /// Standard Expert level: 16x30 grid with 99 mines.
  static const expert = GameDifficulty(rows: 16, cols: 30, mineCount: 99);

  /// Serializes this difficulty settings object to JSON for state hydration.
  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'mineCount': mineCount,
      };

  /// Deserializes a difficulty settings object from JSON.
  factory GameDifficulty.fromJson(dynamic json) => switch (json) {
        {'rows': int rows, 'cols': int cols, 'mineCount': int mineCount} =>
          switch ((rows, cols)) {
            (16, 16) => GameDifficulty.intermediate,
            (16, 30) => GameDifficulty.expert,
            (9, 9) => GameDifficulty.beginner,
            _ => GameDifficulty(rows: rows, cols: cols, mineCount: mineCount),
          },
        _ => GameDifficulty.beginner,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameDifficulty &&
          runtimeType == other.runtimeType &&
          rows == other.rows &&
          cols == other.cols &&
          mineCount == other.mineCount;

  @override
  int get hashCode => Object.hash(rows, cols, mineCount);
}
