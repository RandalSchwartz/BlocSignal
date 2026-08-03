import 'package:flutter/material.dart';
import '../models/cell.dart';

/// Renders a single cell tile on the Minesweeper board.
class CellWidget extends StatelessWidget {
  /// The immutable state data for this cell.
  final Cell cell;

  /// Callback executed when the cell is tapped.
  final VoidCallback onTap;

  /// Callback executed when the cell is long-pressed (for flagging).
  final VoidCallback onLongPress;

  const CellWidget({
    super.key,
    required this.cell,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700, width: 0.5),
          color:
              cell.isCovered ? Colors.blueGrey.shade400 : Colors.grey.shade300,
        ),
        child: Center(child: _buildChild()),
      ),
    );
  }

  Widget? _buildChild() {
    if (cell.isCovered) {
      return cell.isFlagged ? const Icon(Icons.flag, color: Colors.red) : null;
    }

    if (cell.isMine) {
      return const Icon(
        Icons.brightness_7_rounded,
        color: Colors.black,
      );
    }

    if (cell.adjacentMines > 0) {
      return Text(
        '${cell.adjacentMines}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _getColorForNumber(cell.adjacentMines),
        ),
      );
    }

    return null;
  }

  Color _getColorForNumber(int number) {
    switch (number) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.orange;
      case 6:
        return Colors.teal;
      case 7:
        return Colors.brown;
      case 8:
        return Colors.black;
      default:
        return Colors.black;
    }
  }
}
