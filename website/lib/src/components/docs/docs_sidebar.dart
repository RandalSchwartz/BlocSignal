import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../cubits/docs_cubit.dart';
import '../../models/docs_models.dart';
import '../../models/docs_registry.dart';

/// The reactive navigation sidebar for the documentation hub.
class const DocsSidebar({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<DocsCubit, DocsState>(
      builder: (context, state) {
        final query = state.searchQuery.trim().toLowerCase();
        final cubit = context.read<DocsCubit>();

        // Filter categories & sections based on search
        final displayedCategories = <DocCategory>[];
        for (final cat in DocsRegistry.categories) {
          final matchingSections = query.isEmpty
              ? cat.sections
              : cat.sections.where((sec) {
                  return sec.title.toLowerCase().contains(query) ||
                      sec.description.toLowerCase().contains(query);
                }).toList();

          if (matchingSections.isNotEmpty) {
            displayedCategories.add(
              DocCategory(
                title: cat.title,
                icon: cat.icon,
                sections: matchingSections,
              ),
            );
          }
        }

        return aside(classes: 'docs-sidebar', [
          // Search Input
          div(classes: 'docs-search-box', [
            span(classes: 'docs-search-icon', [Component.text('🔍')]),
            input(
              type: InputType.text,
              classes: 'docs-search-input',
              value: state.searchQuery,
              onInput: cubit.updateSearch,
              attributes: {
                'placeholder': 'Search documentation...',
                'aria-label': 'Search documentation',
              },
            ),
            if (state.searchQuery.isNotEmpty)
              button(
                classes: 'docs-search-clear',
                onClick: () => cubit.updateSearch(''),
                [Component.text('✕')],
              ),
          ]),

          // Category Navigation Tree
          nav(classes: 'docs-nav-tree', [
            if (displayedCategories.isEmpty) ...[
              div(classes: 'docs-nav-empty', [
                p([Component.text('No matching topics found for "$query"')]),
                button(
                  classes: 'btn-clear-search',
                  onClick: () => cubit.updateSearch(''),
                  [Component.text('Clear search')],
                ),
              ]),
            ] else ...[
              for (final cat in displayedCategories) ...[
                () {
                  final isExpanded =
                      query.isNotEmpty ||
                      state.expandedCategories.contains(cat.title);
                  return div(classes: 'docs-category-group', [
                    button(
                      classes:
                          'docs-category-header ${isExpanded ? "expanded" : ""}',
                      onClick: () => cubit.toggleCategory(cat.title),
                      [
                        span(classes: 'docs-category-icon', [
                          Component.text(cat.icon),
                        ]),
                        span(classes: 'docs-category-title', [
                          Component.text(cat.title),
                        ]),
                        span(classes: 'docs-category-chevron', [
                          Component.text(isExpanded ? '▾' : '▸'),
                        ]),
                      ],
                    ),
                    if (isExpanded)
                      ul(classes: 'docs-section-list', [
                        for (final sec in cat.sections)
                          li(classes: 'docs-section-item', [
                            button(
                              classes:
                                  'docs-section-link ${state.activeSectionId == sec.id ? "active" : ""}',
                              onClick: () => cubit.selectSection(sec.id),
                              [
                                span(classes: 'docs-nav-link-title', [
                                  Component.text(sec.title),
                                ]),
                                if (sec.badge != null)
                                  span(classes: 'docs-nav-link-badge', [
                                    Component.text(sec.badge!),
                                  ]),
                              ],
                            ),
                          ]),
                      ]),
                  ]);
                }(),
              ],
            ],
          ]),

          // Sidebar Footer Quick Links
          div(classes: 'docs-sidebar-footer', [
            a(
              href: 'https://pub.dev/packages/bloc_signals',
              target: Target.blank,
              classes: 'docs-footer-link',
              [
                span([Component.text('📦 pub.dev ↗')]),
              ],
            ),
            a(
              href: 'https://github.com/RandalSchwartz/BlocSignal',
              target: Target.blank,
              classes: 'docs-footer-link',
              [
                span([Component.text('⭐️ GitHub ↗')]),
              ],
            ),
          ]),
        ]);
      },
    );
  }
}
