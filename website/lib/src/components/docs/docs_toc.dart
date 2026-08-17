import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class const TocHeading({
  required final String title,
  required final String anchor,
  final int level = 2,
});

/// Renders the On-This-Page table of contents on the right sidebar.
class const DocsToc({
  required final List<TocHeading> headings,
  required final String sourcePath,
  super.key,
}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    if (headings.isEmpty) {
      return div(classes: 'docs-toc-empty', []);
    }

    return nav(classes: 'docs-toc-panel', [
      div(classes: 'docs-toc-header', [
        span(classes: 'docs-toc-icon', [Component.text('📑')]),
        span(classes: 'docs-toc-title', [Component.text('On This Page')]),
      ]),
      ul(classes: 'docs-toc-list', [
        for (final h in headings)
          li(classes: 'docs-toc-item level-${h.level}', [
            a(href: '#${h.anchor}', classes: 'docs-toc-link', [
              Component.text(h.title),
            ]),
          ]),
      ]),
      div(classes: 'docs-toc-community', [
        div(classes: 'docs-toc-divider', []),
        a(
          href:
              'https://github.com/RandalSchwartz/BlocSignal/tree/main/$sourcePath',
          target: Target.blank,
          classes: 'docs-toc-meta-link',
          [
            span(classes: 'docs-toc-meta-icon', [Component.text('✏️')]),
            span([Component.text('Edit this page on GitHub')]),
          ],
        ),
        a(
          href: 'https://github.com/RandalSchwartz/BlocSignal/issues/new',
          target: Target.blank,
          classes: 'docs-toc-meta-link',
          [
            span(classes: 'docs-toc-meta-icon', [Component.text('💬')]),
            span([Component.text('Give feedback / Open issue')]),
          ],
        ),
      ]),
    ]);
  }
}
