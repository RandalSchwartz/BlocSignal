/// Defines client-side application routes for blocsignal.dev.
enum AppRoute(final String path, final String label) {
  home('/', 'Home'),
  docs('/docs', 'Docs'),
  showcase('/showcase', 'Showcase'),
  portedExamples('/ported-examples', 'Ported Examples'),
  minesweeper('/minesweeper', '🎮 Minesweeper'),
  publications('/publications', '📚 Publications'),
  playground('/playground', '⚡ Playground');

  /// Parses the browser's current [path] and [hash] into a type-safe
  /// [AppRoute].
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
    } else if (p == '/playground' ||
        p.startsWith('/playground') ||
        h.contains('playground')) {
      return playground;
    }
    return home;
  }
}
