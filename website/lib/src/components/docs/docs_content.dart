import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../cubits/docs_cubit.dart';
import '../../models/docs_models.dart';
import '../../models/docs_registry.dart';
import 'docs_toc.dart';

/// The central content viewer for the documentation hub.
class const DocsContent({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<DocsCubit, DocsState>(
      builder: (context, state) {
        final currentSection = DocsRegistry.resolveSection(
          state.activeSectionId,
        );
        final (prevSection, nextSection) = DocsRegistry.getAdjacentSections(
          state.activeSectionId,
        );
        final cubit = context.read<DocsCubit>();

        final headings = currentSection.headings;
        final sourcePath = currentSection.sourcePath;

        return div(classes: 'docs-content-layout', [
          div(classes: 'docs-main-wrapper', [
            // Mobile Docs Navigation Bar
            div(classes: 'docs-mobile-bar', [
              button(
                classes: 'docs-mobile-menu-btn',
                onClick: () => cubit.toggleMobileDrawer(),
                attributes: {'aria-label': 'Open documentation menu'},
                [
                  span(classes: 'docs-mobile-menu-icon', [Component.text('☰')]),
                  span(classes: 'docs-mobile-menu-text', [
                    Component.text('Menu'),
                  ]),
                ],
              ),
              div(classes: 'docs-mobile-breadcrumbs', [
                span(classes: 'docs-crumb-category', [
                  Component.text(currentSection.category),
                ]),
                span(classes: 'docs-crumb-separator', [Component.text(' / ')]),
                span(classes: 'docs-crumb-title', [
                  Component.text(currentSection.title),
                ]),
              ]),
            ]),

            // Main Documentation Article
            main_(classes: 'docs-main-container', [
              currentSection.builder(),

              // Footer Pagination (Previous / Next Article)
              div(classes: 'docs-pagination', [
                if (prevSection != null)
                  button(
                    classes: 'docs-pager-btn prev',
                    onClick: () => cubit.selectSection(prevSection.id),
                    [
                      span(classes: 'docs-pager-direction', [
                        Component.text('← Previous'),
                      ]),
                      span(classes: 'docs-pager-title', [
                        Component.text(prevSection.title),
                      ]),
                    ],
                  )
                else
                  div(classes: 'docs-pager-spacer', []),

                if (nextSection != null)
                  button(
                    classes: 'docs-pager-btn next',
                    onClick: () => cubit.selectSection(nextSection.id),
                    [
                      span(classes: 'docs-pager-direction', [
                        Component.text('Next →'),
                      ]),
                      span(classes: 'docs-pager-title', [
                        Component.text(nextSection.title),
                      ]),
                    ],
                  ),
              ]),
            ]),
          ]),

          // Right Table of Contents (TOC)
          aside(classes: 'docs-toc-container', [
            DocsToc(headings: headings, sourcePath: sourcePath),
          ]),
        ]);
      },
    );
  }

  /// Resolves the Table of Contents anchor headings for a given [sectionId].
  @visibleForTesting
  static List<TocHeading> getHeadingsForSection(String sectionId) {
    return DocsRegistry.maybeResolveSection(sectionId)?.headings ?? const [];
  }

  /// Resolves the GitHub repository source file path for a given [sectionId].
  @visibleForTesting
  static String getSourcePathForSection(String sectionId) {
    return DocsRegistry.maybeResolveSection(sectionId)?.sourcePath ??
        'website/lib/src/models/docs_registry.dart';
  }
}
