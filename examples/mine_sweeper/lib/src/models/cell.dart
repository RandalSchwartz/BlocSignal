/// Represents the immutable state of a single cell on the Minesweeper board.
class Cell {
  /// Whether the cell is covered (hidden) or revealed.
  final bool isCovered;

  /// Whether the player has placed a flag on this cell.
  final bool isFlagged;

  /// Whether this cell contains a mine.
  final bool isMine;

  /// The number of adjacent mines surrounding this cell (0 to 8).
  final int adjacentMines;

  /// Creates an immutable [Cell].
  const Cell({
    this.isCovered = true,
    this.isFlagged = false,
    this.isMine = false,
    this.adjacentMines = 0,
  });

  /// Creates a copy of this cell with the given fields replaced with new values.
  Cell copyWith({
    bool? isCovered,
    bool? isFlagged,
    bool? isMine,
    int? adjacentMines,
  }) {
    return Cell(
      isCovered: isCovered ?? this.isCovered,
      isFlagged: isFlagged ?? this.isFlagged,
      isMine: isMine ?? this.isMine,
      adjacentMines: adjacentMines ?? this.adjacentMines,
    );
  }

  /// Serializes this cell to a JSON-compatible map for state hydration.
  Map<String, dynamic> toJson() => {
        'isCovered': isCovered,
        'isFlagged': isFlagged,
        'isMine': isMine,
        'adjacentMines': adjacentMines,
      };

  /// Deserializes a cell from a JSON map during state hydration.
  factory Cell.fromJson(dynamic json) => switch (json) {
        {
          'isCovered': bool isCovered,
          'isFlagged': bool isFlagged,
          'isMine': bool isMine,
          'adjacentMines': int adjacentMines,
        } =>
          Cell(
            isCovered: isCovered,
            isFlagged: isFlagged,
            isMine: isMine,
            adjacentMines: adjacentMines,
          ),
        _ => const Cell(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          runtimeType == other.runtimeType &&
          isCovered == other.isCovered &&
          isFlagged == other.isFlagged &&
          isMine == other.isMine &&
          adjacentMines == other.adjacentMines;

  @override
  int get hashCode => Object.hash(isCovered, isFlagged, isMine, adjacentMines);
}
