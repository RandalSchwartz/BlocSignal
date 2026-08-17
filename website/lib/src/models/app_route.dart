import 'package:jaspr/jaspr.dart';

import '../pages/docs_page.dart';
import '../pages/home_page.dart';
import '../pages/minesweeper_page.dart';
import '../pages/ported_examples_page.dart';
import '../pages/publications_page.dart';
import '../pages/showcase_page.dart';

/// Defines client-side application routes for blocsignal.dev.
enum AppRoute(
  final String path,
  final String label,
  final Component Function() builder,
) {
  home('/', 'Home', HomePage.new),
  docs('/docs', 'Docs', DocsPage.new),
  showcase('/showcase', 'Showcase', ShowcasePage.new),
  portedExamples('/ported-examples', 'Ported Examples', PortedExamplesPage.new),
  minesweeper('/minesweeper', '🎮 Minesweeper', MinesweeperPage.new),
  publications('/publications', '📚 Publications', PublicationsPage.new);

  /// Parses the browser's current [path] and [hash] into a type-safe [AppRoute].
  static AppRoute fromLocation({String? path, String? hash}) {
    final p = path ?? '';
    final h = (hash ?? '').toLowerCase();

    if (p == '/docs' || p.startsWith('/docs/') || h.contains('docs')) {
      return docs;
    } else if (p == '/showcase' ||
        p.startsWith('/showcase') ||
        h.contains('showcase')) {
      return showcase;
    } else if (p == '/ported-examples' ||
        p.startsWith('/ported-examples') ||
        h.contains('ported-examples') ||
        h.contains('ported')) {
      return portedExamples;
    } else if (p == '/minesweeper' ||
        p.startsWith('/minesweeper') ||
        h.contains('minesweeper')) {
      return minesweeper;
    } else if (p == '/publications' ||
        p.startsWith('/publications') ||
        h.contains('publications')) {
      return publications;
    }
    return home;
  }
}
