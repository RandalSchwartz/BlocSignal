import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:web/web.dart' as web;

@JS('trackMinesweeperEvent')
external void _trackMinesweeperEvent(
  JSString eventName,
  JSString difficulty,
  JSNumber val,
);

void _trackAnalytics(String eventName, String difficulty, [int val = 0]) {
  try {
    _trackMinesweeperEvent(eventName.toJS, difficulty.toJS, val.toJS);
  } catch (_) {}
}

enum Difficulty({
  required final int rows,
  required final int cols,
  required final int mines,
  required final String name,
}) {
  beginner(rows: 9, cols: 9, mines: 10, name: 'Beginner'),
  intermediate(rows: 12, cols: 12, mines: 20, name: 'Intermediate'),
  expert(rows: 16, cols: 16, mines: 40, name: 'Expert'),
}

enum GameStatus() {
  initial,
  playing,
  won,
  lost,
}

class const MinesweeperCell({
  required final int row,
  required final int col,
  final bool hasMine = false,
  final bool isRevealed = false,
  final bool isFlagged = false,
  final int adjacentMines = 0,
}) {
  MinesweeperCell copyWith({
    bool? hasMine,
    bool? isRevealed,
    bool? isFlagged,
    int? adjacentMines,
  }) {
    return MinesweeperCell(
      row: row,
      col: col,
      hasMine: hasMine ?? this.hasMine,
      isRevealed: isRevealed ?? this.isRevealed,
      isFlagged: isFlagged ?? this.isFlagged,
      adjacentMines: adjacentMines ?? this.adjacentMines,
    );
  }

  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'hasMine': hasMine,
    'isRevealed': isRevealed,
    'isFlagged': isFlagged,
    'adjacentMines': adjacentMines,
  };

  factory fromJson(Map<String, dynamic> json) {
    return MinesweeperCell(
      row: json['row'] as int,
      col: json['col'] as int,
      hasMine: json['hasMine'] as bool,
      isRevealed: json['isRevealed'] as bool,
      isFlagged: json['isFlagged'] as bool,
      adjacentMines: json['adjacentMines'] as int,
    );
  }
}

class const MinesweeperState({
  required final Difficulty difficulty,
  required final List<List<MinesweeperCell>> board,
  required final GameStatus status,
  required final int minesRemaining,
  required final int timerSeconds,
  required final int seed,
}) {
  MinesweeperState copyWith({
    Difficulty? difficulty,
    List<List<MinesweeperCell>>? board,
    GameStatus? status,
    int? minesRemaining,
    int? timerSeconds,
    int? seed,
  }) {
    return MinesweeperState(
      difficulty: difficulty ?? this.difficulty,
      board: board ?? this.board,
      status: status ?? this.status,
      minesRemaining: minesRemaining ?? this.minesRemaining,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      seed: seed ?? this.seed,
    );
  }

  Map<String, dynamic> toJson() => {
    'difficulty': difficulty.name,
    'board': board
        .map((row) => row.map((cell) => cell.toJson()).toList())
        .toList(),
    'status': status.name,
    'minesRemaining': minesRemaining,
    'timerSeconds': timerSeconds,
    'seed': seed,
  };

  factory fromJson(Map<String, dynamic> json) {
    final diff = Difficulty.values.firstWhere(
      (d) => d.name == json['difficulty'],
      orElse: () => Difficulty.beginner,
    );
    final boardJson = json['board'] as List<dynamic>;
    final board = boardJson
        .map(
          (rowJson) => (rowJson as List<dynamic>)
              .map(
                (cellJson) =>
                    MinesweeperCell.fromJson(cellJson as Map<String, dynamic>),
              )
              .toList(),
        )
        .toList();
    final status = GameStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => GameStatus.initial,
    );
    return MinesweeperState(
      difficulty: diff,
      board: board,
      status: status,
      minesRemaining: json['minesRemaining'] as int,
      timerSeconds: json['timerSeconds'] as int,
      seed: json['seed'] as int,
    );
  }
}

class MinesweeperCubit({Difficulty difficulty = Difficulty.beginner})
    extends CubitSignal<MinesweeperState> {
  static const _storageKey = 'blocsignal_minesweeper_state';

  this : super(initialState: _loadInitialState(difficulty));

  static MinesweeperState _loadInitialState(Difficulty difficulty) {
    try {
      final saved = web.window.localStorage.getItem(_storageKey);
      if (saved != null && saved.isNotEmpty) {
        final decoded = jsonDecode(saved) as Map<String, dynamic>;
        return MinesweeperState.fromJson(decoded);
      }
    } catch (_) {}
    return _generateNewGame(difficulty: difficulty);
  }

  static MinesweeperState _generateNewGame({
    required Difficulty difficulty,
    int? seed,
  }) {
    final currentSeed = seed ?? Random().nextInt(1000000);
    final rand = Random(currentSeed);

    final board = List.generate(
      difficulty.rows,
      (r) => List.generate(
        difficulty.cols,
        (c) => MinesweeperCell(row: r, col: c),
      ),
    );

    int placed = 0;
    while (placed < difficulty.mines) {
      final r = rand.nextInt(difficulty.rows);
      final c = rand.nextInt(difficulty.cols);
      if (!board[r][c].hasMine) {
        board[r][c] = board[r][c].copyWith(hasMine: true);
        placed++;
      }
    }

    for (int r = 0; r < difficulty.rows; r++) {
      for (int c = 0; c < difficulty.cols; c++) {
        if (!board[r][c].hasMine) {
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              final nr = r + dr;
              final nc = c + dc;
              if (nr >= 0 &&
                  nr < difficulty.rows &&
                  nc >= 0 &&
                  nc < difficulty.cols &&
                  board[nr][nc].hasMine) {
                count++;
              }
            }
          }
          board[r][c] = board[r][c].copyWith(adjacentMines: count);
        }
      }
    }

    return MinesweeperState(
      difficulty: difficulty,
      board: board,
      status: GameStatus.initial,
      minesRemaining: difficulty.mines,
      timerSeconds: 0,
      seed: currentSeed,
    );
  }

  void _persistState(MinesweeperState state) {
    try {
      web.window.localStorage.setItem(_storageKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void resetGame({Difficulty? difficulty, int? seed}) {
    final diff = difficulty ?? stateValue.difficulty;
    final newState = _generateNewGame(difficulty: diff, seed: seed);
    emit(newState);
    _persistState(newState);
    _trackAnalytics('minesweeper_new_game', diff.name);
  }

  void revealCell(int row, int col) {
    if (stateValue.status == GameStatus.won ||
        stateValue.status == GameStatus.lost) {
      return;
    }

    final cell = stateValue.board[row][col];
    final newBoard = stateValue.board
        .map((r) => r.map((c) => c).toList())
        .toList();

    // 1. Chording support for already revealed cells with adjacent mines
    if (cell.isRevealed && cell.adjacentMines > 0) {
      int flaggedCount = 0;
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = row + dr;
          final nc = col + dc;
          if (nr >= 0 &&
              nr < stateValue.difficulty.rows &&
              nc >= 0 &&
              nc < stateValue.difficulty.cols) {
            if (newBoard[nr][nc].isFlagged) flaggedCount++;
          }
        }
      }

      if (flaggedCount == cell.adjacentMines) {
        bool hitMine = false;
        void floodFill(int r, int c) {
          if (r < 0 ||
              r >= stateValue.difficulty.rows ||
              c < 0 ||
              c >= stateValue.difficulty.cols)
            return;
          final target = newBoard[r][c];
          if (target.isRevealed || target.isFlagged) return;

          newBoard[r][c] = target.copyWith(isRevealed: true);

          if (target.hasMine) {
            hitMine = true;
            return;
          }

          if (target.adjacentMines == 0) {
            for (int dr = -1; dr <= 1; dr++) {
              for (int dc = -1; dc <= 1; dc++) {
                if (dr == 0 && dc == 0) continue;
                floodFill(r + dr, c + dc);
              }
            }
          }
        }

        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = row + dr;
            final nc = col + dc;
            if (nr >= 0 &&
                nr < stateValue.difficulty.rows &&
                nc >= 0 &&
                nc < stateValue.difficulty.cols) {
              if (!newBoard[nr][nc].isFlagged && !newBoard[nr][nc].isRevealed) {
                floodFill(nr, nc);
              }
            }
          }
        }

        if (hitMine) {
          for (int r = 0; r < stateValue.difficulty.rows; r++) {
            for (int c = 0; c < stateValue.difficulty.cols; c++) {
              if (newBoard[r][c].hasMine) {
                newBoard[r][c] = newBoard[r][c].copyWith(isRevealed: true);
              }
            }
          }
        }

        bool hasWon = true;
        for (int r = 0; r < stateValue.difficulty.rows; r++) {
          for (int c = 0; c < stateValue.difficulty.cols; c++) {
            if (!newBoard[r][c].hasMine && !newBoard[r][c].isRevealed) {
              hasWon = false;
              break;
            }
          }
        }

        final nextStatus = hitMine
            ? GameStatus.lost
            : (hasWon ? GameStatus.won : GameStatus.playing);
        final newState = stateValue.copyWith(
          board: newBoard,
          status: nextStatus,
        );
        emit(newState);
        _persistState(newState);

        if (nextStatus == GameStatus.lost) {
          _trackAnalytics(
            'minesweeper_loss',
            stateValue.difficulty.name,
            stateValue.timerSeconds,
          );
        } else if (nextStatus == GameStatus.won) {
          _trackAnalytics(
            'minesweeper_win',
            stateValue.difficulty.name,
            stateValue.timerSeconds,
          );
        }
      }
      return;
    }

    if (cell.isRevealed || cell.isFlagged) return;

    // 2. First-click Mine Safety: Move mine if click #1 lands on a mine
    if (stateValue.status == GameStatus.initial && cell.hasMine) {
      newBoard[row][col] = cell.copyWith(hasMine: false);
      // Move mine to first non-mine cell
      outerLoop:
      for (int r = 0; r < stateValue.difficulty.rows; r++) {
        for (int c = 0; c < stateValue.difficulty.cols; c++) {
          if ((r != row || c != col) && !newBoard[r][c].hasMine) {
            newBoard[r][c] = newBoard[r][c].copyWith(hasMine: true);
            break outerLoop;
          }
        }
      }
      // Recalculate adjacent mines for all cells
      for (int r = 0; r < stateValue.difficulty.rows; r++) {
        for (int c = 0; c < stateValue.difficulty.cols; c++) {
          if (!newBoard[r][c].hasMine) {
            int count = 0;
            for (int dr = -1; dr <= 1; dr++) {
              for (int dc = -1; dc <= 1; dc++) {
                if (dr == 0 && dc == 0) continue;
                final nr = r + dr;
                final nc = c + dc;
                if (nr >= 0 &&
                    nr < stateValue.difficulty.rows &&
                    nc >= 0 &&
                    nc < stateValue.difficulty.cols &&
                    newBoard[nr][nc].hasMine) {
                  count++;
                }
              }
            }
            newBoard[r][c] = newBoard[r][c].copyWith(adjacentMines: count);
          }
        }
      }
    }

    // 3. Normal Cell Reveal
    final targetCell = newBoard[row][col];
    if (targetCell.hasMine) {
      for (int r = 0; r < stateValue.difficulty.rows; r++) {
        for (int c = 0; c < stateValue.difficulty.cols; c++) {
          if (newBoard[r][c].hasMine) {
            newBoard[r][c] = newBoard[r][c].copyWith(isRevealed: true);
          }
        }
      }
      final newState = stateValue.copyWith(
        board: newBoard,
        status: GameStatus.lost,
      );
      emit(newState);
      _persistState(newState);
      _trackAnalytics(
        'minesweeper_loss',
        stateValue.difficulty.name,
        stateValue.timerSeconds,
      );
      return;
    }

    void floodFill(int r, int c) {
      if (r < 0 ||
          r >= stateValue.difficulty.rows ||
          c < 0 ||
          c >= stateValue.difficulty.cols)
        return;
      final target = newBoard[r][c];
      if (target.isRevealed || target.isFlagged || target.hasMine) return;

      newBoard[r][c] = target.copyWith(isRevealed: true);

      if (target.adjacentMines == 0) {
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            floodFill(r + dr, c + dc);
          }
        }
      }
    }

    floodFill(row, col);

    bool hasWon = true;
    for (int r = 0; r < stateValue.difficulty.rows; r++) {
      for (int c = 0; c < stateValue.difficulty.cols; c++) {
        if (!newBoard[r][c].hasMine && !newBoard[r][c].isRevealed) {
          hasWon = false;
          break;
        }
      }
    }

    final nextStatus = hasWon ? GameStatus.won : GameStatus.playing;
    final newState = stateValue.copyWith(board: newBoard, status: nextStatus);
    emit(newState);
    _persistState(newState);

    if (nextStatus == GameStatus.won) {
      _trackAnalytics(
        'minesweeper_win',
        stateValue.difficulty.name,
        stateValue.timerSeconds,
      );
    }
  }

  void toggleFlag(int row, int col) {
    if (stateValue.status == GameStatus.won ||
        stateValue.status == GameStatus.lost) {
      return;
    }

    final cell = stateValue.board[row][col];
    if (cell.isRevealed) return;

    final newBoard = stateValue.board
        .map((r) => r.map((c) => c).toList())
        .toList();
    final newFlagged = !cell.isFlagged;
    newBoard[row][col] = cell.copyWith(isFlagged: newFlagged);

    final delta = newFlagged ? -1 : 1;
    final newState = stateValue.copyWith(
      board: newBoard,
      minesRemaining: stateValue.minesRemaining + delta,
      status: GameStatus.playing,
    );
    emit(newState);
    _persistState(newState);
  }

  String generatePasscode() {
    _trackAnalytics('minesweeper_share_seed', stateValue.difficulty.name);
    final payload = '${stateValue.difficulty.name}:${stateValue.seed}';
    return base64Url.encode(utf8.encode(payload));
  }

  bool loadPasscode(String code) {
    try {
      final decoded = utf8.decode(base64Url.decode(code.trim()));
      final parts = decoded.split(':');
      if (parts.length != 2) return false;
      final diffName = parts[0];
      final seed = int.parse(parts[1]);
      final diff = Difficulty.values.firstWhere(
        (d) => d.name == diffName,
        orElse: () => Difficulty.beginner,
      );
      _trackAnalytics('minesweeper_load_seed', diff.name);
      resetGame(difficulty: diff, seed: seed);
      return true;
    } catch (_) {
      return false;
    }
  }
}
