import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../state/game_state.dart';
import 'cell_widget.dart';

/// Renders the 2D grid of Minesweeper cells.
///
/// Uses [BlocSignalBuilder] to rebuild the grid dynamically when cell states change.
class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBlocSignal>();

    return BlocSignalBuilder<GameBlocSignal, MineSweeperState>(
      builder: (context, state) {
        final grid = state.grid;
        final difficulty = state.difficulty;
        final status = state.status;
        final isFirstClick = status == GameStatus.playing && state.timer == 0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: difficulty.cols,
          ),
          itemCount: difficulty.rows * difficulty.cols,
          itemBuilder: (context, index) {
            final row = index ~/ difficulty.cols;
            final col = index % difficulty.cols;
            final cell = grid[row][col];

            return CellWidget(
              cell: cell,
              onTap: () {
                if (status != GameStatus.playing || cell.isFlagged) return;

                if (isFirstClick) {
                  bloc.add(FirstClickEvent(row, col));
                } else {
                  bloc.add(UncoverCellEvent(row, col));
                }
              },
              onLongPress: () {
                if (status == GameStatus.playing) {
                  bloc.add(ToggleFlagEvent(row, col));
                }
              },
            );
          },
        );
      },
    );
  }
}
