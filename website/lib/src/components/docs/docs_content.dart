import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../cubits/docs_cubit.dart';
import '../../models/docs_models.dart';
import '../../models/docs_registry.dart';
import 'docs_toc.dart';
import 'pages/docs_installation.dart';
import 'pages/docs_overview.dart';
import 'pages/docs_quickstart.dart';

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

        // Extract TOC headings based on active section
        final headings = _getHeadingsForSection(state.activeSectionId);
        final sourcePath = _getSourcePathForSection(state.activeSectionId);

        return div(classes: 'docs-content-layout', [
          // Mobile Docs Navigation Bar
          div(classes: 'docs-mobile-bar', [
            button(
              classes: 'docs-mobile-menu-btn',
              onClick: () => cubit.toggleMobileDrawer(),
              attributes: {'aria-label': 'Open documentation menu'},
              [
                span(classes: 'mobile-menu-icon', [Component.text('☰')]),
                span(classes: 'mobile-menu-text', [Component.text('Menu')]),
              ],
            ),
            div(classes: 'docs-mobile-breadcrumbs', [
              span(classes: 'crumb-category', [
                Component.text(currentSection.category),
              ]),
              span(classes: 'crumb-separator', [Component.text(' / ')]),
              span(classes: 'crumb-title', [
                Component.text(currentSection.title),
              ]),
            ]),
          ]),

          // Main Article Container
          main_(classes: 'docs-main-container', [
            currentSection.builder(),

            // Footer Pagination (Previous / Next Article)
            div(classes: 'docs-pagination', [
              if (prevSection != null)
                a(
                  href: prevSection.path,
                  classes: 'docs-pager-btn prev',
                  onClick: () => cubit.selectSection(prevSection.id),
                  [
                    span(classes: 'pager-direction', [
                      Component.text('← Previous'),
                    ]),
                    span(classes: 'pager-title', [
                      Component.text(prevSection.title),
                    ]),
                  ],
                )
              else
                div(classes: 'docs-pager-spacer', []),

              if (nextSection != null)
                a(
                  href: nextSection.path,
                  classes: 'docs-pager-btn next',
                  onClick: () => cubit.selectSection(nextSection.id),
                  [
                    span(classes: 'pager-direction', [
                      Component.text('Next →'),
                    ]),
                    span(classes: 'pager-title', [
                      Component.text(nextSection.title),
                    ]),
                  ],
                ),
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

  static List<TocHeading> _getHeadingsForSection(String sectionId) {
    switch (sectionId) {
      case 'overview':
        return DocsOverviewPage.headings;
      case 'installation':
        return DocsInstallationPage.headings;
      case 'quickstart':
        return DocsQuickstartPage.headings;
      default:
        return const [];
    }
  }

  static String _getSourcePathForSection(String sectionId) {
    switch (sectionId) {
      case 'overview':
        return 'website/lib/src/components/docs/pages/docs_overview.dart';
      case 'installation':
        return 'website/lib/src/components/docs/pages/docs_installation.dart';
      case 'quickstart':
        return 'website/lib/src/components/docs/pages/docs_quickstart.dart';
      default:
        return 'website/lib/src/models/docs_registry.dart';
    }
  }
}
