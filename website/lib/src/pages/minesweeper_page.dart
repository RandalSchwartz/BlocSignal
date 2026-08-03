import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/footer.dart';
import '../components/minesweeper/minesweeper_component.dart';
import '../components/navbar.dart';

class MinesweeperPage extends StatelessComponent {
  const MinesweeperPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentPath: '/minesweeper'),
      main_([
        section(classes: 'minesweeper-hero-section', [
          div(classes: 'container', [
            div(classes: 'hero-badge-tag', [
              Component.text('🎮 Interactive Case Study & Live Web Demo'),
            ]),
            h1(classes: 'section-title ms-landing-title', [
              Component.text('Minesweeper in Dart & Web'),
            ]),
            p(classes: 'section-subtitle ms-landing-subtitle', [
              Component.text(
                'Built with BlocSignal — The state management library for Dart & Flutter bridging Business Logic Component (BLoC) discipline with 0ms microtask-free Signals reactivity.',
              ),
            ]),

            // Prominent CTAs
            div(classes: 'ms-hero-ctas', [
              a(
                href:
                    'https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/mine_sweeper',
                target: Target.blank,
                classes: 'btn-primary btn-github-source',
                [Component.text('⭐ View Live Source Code on GitHub ↗')],
              ),
              a(
                href: 'https://pub.dev/packages/bloc_signals',
                target: Target.blank,
                classes: 'btn-secondary btn-pub',
                [Component.text('📦 View on pub.dev ↗')],
              ),
              a(
                href: '/',
                classes: 'btn-secondary',
                [Component.text('📖 Framework Overview')],
              ),
            ]),

            // Live Game Board Component
            const MinesweeperComponent(),

            // Feature Cards Grid
            div(classes: 'ms-feature-grid', [
              div(classes: 'ms-feature-card', [
                div(classes: 'feature-icon', [Component.text('⚡')]),
                h3([Component.text('0ms Synchronous Flood Fill')]),
                p([
                  Component.text(
                    'Uncovering a blank cell recursively opens neighboring regions synchronously in the exact same frame, eliminating microtask queue latency.',
                  ),
                ]),
              ]),
              div(classes: 'ms-feature-card', [
                div(classes: 'feature-icon', [Component.text('🌐')]),
                h3([Component.text('100% Shared Business Logic')]),
                p([
                  Component.text(
                    'Because BlocSignal core has zero Flutter dependencies, the exact same game engine runs in Flutter desktop/mobile apps AND Jaspr web apps with 0 logic changes.',
                  ),
                ]),
              ]),
              div(classes: 'ms-feature-card', [
                div(classes: 'feature-icon', [Component.text('💾')]),
                h3([Component.text('Zero-Backend Persistence')]),
                p([
                  Component.text(
                    'Active game progress (grid, flags, timer) is saved synchronously to local storage on every move, restoring your board state across browser tab refreshes.',
                  ),
                ]),
              ]),
              div(classes: 'ms-feature-card', [
                div(classes: 'feature-icon', [Component.text('🔑')]),
                h3([Component.text('Shareable Challenge Seeds')]),
                p([
                  Component.text(
                    'Export and import Base64-encoded game seeds to challenge friends or audience members to clear identical minefield layouts.',
                  ),
                ]),
              ]),
            ]),

            // Code Preview Section
            div(classes: 'ms-code-preview', [
              h3([Component.text('💻 Game Engine Source Preview (MinesweeperCubit)')]),
              p([
                Component.text(
                  'Below is a snippet of the MinesweeperCubit running live on this page, demonstrating synchronous state updates and recursive flood fill:',
                ),
              ]),
              div(classes: 'ms-code-box', [
                pre([
                  code([
                    Component.text('''
class MinesweeperCubit extends CubitSignal<MinesweeperState> {
  void revealCell(int row, int col) {
    if (stateValue.status == GameStatus.won ||
        stateValue.status == GameStatus.lost) return;

    final cell = stateValue.board[row][col];
    if (cell.isRevealed || cell.isFlagged) return;

    final newBoard = stateValue.board
        .map((r) => r.map((c) => c).toList())
        .toList();

    // 0ms Synchronous Flood Fill Recursion
    void floodFill(int r, int c) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return;
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

    // Synchronous state emission -> UI updates in exact same frame!
    emit(stateValue.copyWith(board: newBoard));
    _persistState(stateValue);
  }
}'''),
                  ]),
                ]),
              ]),
              div(classes: 'ms-code-links', [
                a(
                  href:
                      'https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/mine_sweeper',
                  target: Target.blank,
                  classes: 'card-link',
                  [Component.text('View Full Flutter Example Repository ↗')],
                ),
                span([Component.text(' • ')]),
                a(
                  href:
                      'https://github.com/RandalSchwartz/BlocSignal/tree/main/website/lib/src/components/minesweeper',
                  target: Target.blank,
                  classes: 'card-link',
                  [Component.text('View Web Jaspr Component Source ↗')],
                ),
              ]),
            ]),
          ]),
        ]),
      ]),
      const Footer(),
    ]);
  }
}
