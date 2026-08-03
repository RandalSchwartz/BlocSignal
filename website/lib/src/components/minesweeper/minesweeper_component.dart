import 'dart:async';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'minesweeper_cubit.dart';

class MinesweeperComponent extends StatefulComponent {
  const MinesweeperComponent({super.key});

  @override
  State<MinesweeperComponent> createState() => _MinesweeperComponentState();
}

class _MinesweeperComponentState extends State<MinesweeperComponent> {
  late final MinesweeperCubit _cubit;
  String _passcodeNotice = '';
  String _passcodeInput = '';
  Timer? _longPressTimer;
  bool _didLongPress = false;

  @override
  void initState() {
    super.initState();
    _cubit = MinesweeperCubit();
    _cubit.state.subscribe((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _cubit.close();
    super.dispose();
  }

  void _onCellClick(int r, int c) {
    if (_didLongPress) {
      _didLongPress = false;
      return;
    }
    _cubit.revealCell(r, c);
  }

  void _onCellRightClick(int r, int c) {
    _cubit.toggleFlag(r, c);
  }

  void _startPressTimer(int r, int c) {
    _didLongPress = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 350), () {
      _didLongPress = true;
      _onCellRightClick(r, c);
    });
  }

  void _cancelPressTimer() {
    _longPressTimer?.cancel();
  }

  @override
  Component build(BuildContext context) {
    final state = _cubit.stateValue;
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
                _cubit.resetGame(difficulty: diff);
              },
              [Component.text(diff.name)],
            ),
        ]),
        div(classes: 'ms-status-bar', [
          div(classes: 'ms-counter', [
            span(classes: 'ms-label', [Component.text('Mines: ')]),
            span(classes: 'ms-val', [Component.text('${state.minesRemaining}')]),
          ]),
          button(
            classes: 'ms-btn ms-btn-reset',
            onClick: () {
              _passcodeNotice = '';
              _cubit.resetGame();
            },
            [
              Component.text(state.status == GameStatus.lost
                  ? '💥 Retry'
                  : state.status == GameStatus.won
                      ? '😎 Winner!'
                      : '🙂 New Game')
            ],
          ),
          button(
            classes: 'ms-btn ms-btn-share',
            onClick: () {
              final code = _cubit.generatePasscode();
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
                  _buildCell(board[r][c]),
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
              final ok = _cubit.loadPasscode(_passcodeInput);
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
  }

  Component _buildCell(MinesweeperCell cell) {
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
        'click': (e) => _onCellClick(cell.row, cell.col),
        'contextmenu': (e) {
          e.preventDefault();
          _didLongPress = true;
          _onCellRightClick(cell.row, cell.col);
        },
        'mousedown': (e) => _startPressTimer(cell.row, cell.col),
        'mouseup': (e) => _cancelPressTimer(),
        'mouseleave': (e) => _cancelPressTimer(),
        'touchstart': (e) => _startPressTimer(cell.row, cell.col),
        'touchend': (e) => _cancelPressTimer(),
        'touchcancel': (e) => _cancelPressTimer(),
      },
      [Component.text(cellText)],
    );
  }
}
