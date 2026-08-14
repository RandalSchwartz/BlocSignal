import 'dart:async';

import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'minesweeper_cubit.dart';

class const MinesweeperComponent({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<MinesweeperCubit>(
      create: (_) => MinesweeperCubit(),
      child: const _MinesweeperBoard(),
    );
  }
}

class const _MinesweeperBoard() extends StatefulComponent {
  @override
  State<_MinesweeperBoard> createState() => _MinesweeperBoardState();
}

class _MinesweeperBoardState() extends State<_MinesweeperBoard> {
  String _passcodeNotice = '';
  String _passcodeInput = '';
  Timer? _longPressTimer;
  bool _didLongPress = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onCellClick(BuildContext context, int r, int c) {
    if (_didLongPress) {
      _didLongPress = false;
      return;
    }
    context.read<MinesweeperCubit>().revealCell(r, c);
  }

  void _onCellRightClick(BuildContext context, int r, int c) {
    context.read<MinesweeperCubit>().toggleFlag(r, c);
  }

  void _startPressTimer(BuildContext context, int r, int c) {
    _didLongPress = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 350), () {
      _didLongPress = true;
      _onCellRightClick(context, r, c);
    });
  }

  void _cancelPressTimer() {
    _longPressTimer?.cancel();
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<MinesweeperCubit, MinesweeperState>(
      builder: (context, state) {
        final board = state.board;

        return div(classes: 'minesweeper-wrapper', [
          // Control Header
          div(classes: 'ms-header', [
            div(classes: 'ms-difficulty-selector', [
              for (final diff in Difficulty.values)
                button(
                  classes: diff == state.difficulty
                      ? 'ms-btn ms-btn-diff active'
                      : 'ms-btn ms-btn-diff',
                  onClick: () {
                    _passcodeNotice = '';
                    context.read<MinesweeperCubit>().resetGame(
                      difficulty: diff,
                    );
                  },
                  [Component.text(diff.name)],
                ),
            ]),
            div(classes: 'ms-status-bar', [
              div(classes: 'ms-counter', [
                span(classes: 'ms-label', [Component.text('Mines: ')]),
                span(classes: 'ms-val', [
                  Component.text('${state.minesRemaining}'),
                ]),
              ]),
              button(
                classes: 'ms-btn ms-btn-reset',
                onClick: () {
                  _passcodeNotice = '';
                  context.read<MinesweeperCubit>().resetGame();
                },
                [
                  Component.text(
                    state.status == GameStatus.lost
                        ? '💥 Retry'
                        : state.status == GameStatus.won
                        ? '😎 Winner!'
                        : '🙂 New Game',
                  ),
                ],
              ),
              button(
                classes: 'ms-btn ms-btn-share',
                onClick: () {
                  final code = context
                      .read<MinesweeperCubit>()
                      .generatePasscode();
                  setState(() {
                    _passcodeNotice = 'Passcode: $code';
                  });
                },
                [Component.text('🔑 Share Seed')],
              ),
            ]),
          ]),

          if (_passcodeNotice.isNotEmpty)
            div(classes: 'ms-passcode-banner', [
              Component.text(_passcodeNotice),
            ]),

          // Grid Container
          div(classes: 'ms-board-container', [
            div(
              classes: 'ms-grid',
              attributes: {'style': 'width: ${state.difficulty.cols * 32}px'},
              [
                for (int r = 0; r < state.difficulty.rows; r++)
                  div(classes: 'ms-row', [
                    for (int c = 0; c < state.difficulty.cols; c++)
                      _buildCell(context, board[r][c]),
                  ]),
              ],
            ),
          ]),

          // Passcode Import Box
          div(classes: 'ms-import-box', [
            input(
              type: InputType.text,
              value: _passcodeInput,
              attributes: {'placeholder': 'Paste challenge passcode...'},
              onInput: (val) {
                _passcodeInput = val.toString();
              },
            ),
            button(
              classes: 'ms-btn ms-btn-import',
              onClick: () {
                if (_passcodeInput.isNotEmpty) {
                  final ok = context.read<MinesweeperCubit>().loadPasscode(
                    _passcodeInput,
                  );
                  setState(() {
                    _passcodeNotice = ok
                        ? 'Loaded challenge seed!'
                        : 'Invalid passcode!';
                  });
                }
              },
              [Component.text('Load Challenge')],
            ),
          ]),
        ]);
      },
    );
  }

  Component _buildCell(BuildContext context, MinesweeperCell cell) {
    String cellText = '';
    String cellClass = 'ms-cell';

    if (cell.isRevealed) {
      cellClass += ' revealed';
      if (cell.hasMine) {
        cellText = '💣';
        cellClass += ' mine';
      } else if (cell.adjacentMines > 0) {
        cellText = '${cell.adjacentMines}';
        cellClass += ' num-${cell.adjacentMines}';
      }
    } else if (cell.isFlagged) {
      cellClass += ' flagged';
      cellText = '🚩';
    }

    return div(
      classes: cellClass,
      events: {
        'click': (e) => _onCellClick(context, cell.row, cell.col),
        'contextmenu': (e) {
          e.preventDefault();
          _didLongPress = true;
          _onCellRightClick(context, cell.row, cell.col);
        },
        'mousedown': (e) => _startPressTimer(context, cell.row, cell.col),
        'mouseup': (e) => _cancelPressTimer(),
        'mouseleave': (e) => _cancelPressTimer(),
        'touchstart': (e) => _startPressTimer(context, cell.row, cell.col),
        'touchend': (e) => _cancelPressTimer(),
        'touchcancel': (e) => _cancelPressTimer(),
      },
      [Component.text(cellText)],
    );
  }
}
