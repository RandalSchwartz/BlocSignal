import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../cubits/docs_cubit.dart';
import '../../models/docs_models.dart';
import '../../models/docs_registry.dart';
import 'docs_toc.dart';
import 'pages/docs_cubit_vs_bloc.dart';
import 'pages/docs_decision_matrix.dart';
import 'pages/docs_event_transformers.dart';
import 'pages/docs_events_and_handlers.dart';
import 'pages/docs_flutter_context.dart';
import 'pages/docs_flutter_providers.dart';
import 'pages/docs_flutter_widgets.dart';
import 'pages/docs_installation.dart';
import 'pages/docs_lifecycle_and_observers.dart';
import 'pages/docs_migration_bloc.dart';
import 'pages/docs_migration_riverpod.dart';
import 'pages/docs_overview.dart';
import 'pages/docs_pkg_bloc.dart';
import 'pages/docs_pkg_devtools.dart';
import 'pages/docs_pkg_hydrate.dart';
import 'pages/docs_pkg_jaspr.dart';
import 'pages/docs_pkg_lint.dart';
import 'pages/docs_pkg_otel.dart';
import 'pages/docs_pkg_replay.dart';
import 'pages/docs_pkg_riverpod.dart';
import 'pages/docs_quickstart.dart';
import 'pages/docs_recipe_batching.dart';
import 'pages/docs_recipe_caching.dart';
import 'pages/docs_recipe_controllers.dart';
import 'pages/docs_recipe_form_validation.dart';
import 'pages/docs_recipe_one_shot.dart';
import 'pages/docs_signals_reactivity.dart';
import 'pages/docs_state_modeling.dart';
import 'pages/docs_testing_guide.dart';

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

        final headings = _getHeadingsForSection(currentSection.id);
        final sourcePath = _getSourcePathForSection(currentSection.id);

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

  static List<TocHeading> _getHeadingsForSection(String sectionId) {
    switch (sectionId) {
      case 'overview':
        return DocsOverviewPage.headings;
      case 'installation':
        return DocsInstallationPage.headings;
      case 'quickstart':
        return DocsQuickstartPage.headings;
      case 'decision-matrix':
        return DocsDecisionMatrixPage.headings;
      case 'cubit-vs-bloc':
        return DocsCubitVsBlocPage.headings;
      case 'state-modeling':
        return DocsStateModelingPage.headings;
      case 'events-and-handlers':
        return DocsEventsAndHandlersPage.headings;
      case 'event-transformers':
        return DocsEventTransformersPage.headings;
      case 'lifecycle-and-observers':
        return DocsLifecycleAndObserversPage.headings;
      case 'signals-reactivity':
        return DocsSignalsReactivityPage.headings;
      case 'flutter-providers':
        return DocsFlutterProvidersPage.headings;
      case 'flutter-widgets':
        return DocsFlutterWidgetsPage.headings;
      case 'flutter-context':
        return DocsFlutterContextPage.headings;
      case 'testing-guide':
        return DocsTestingGuidePage.headings;
      case 'pkg-hydrate':
        return DocsPkgHydratePage.headings;
      case 'pkg-replay':
        return DocsPkgReplayPage.headings;
      case 'pkg-riverpod':
        return DocsPkgRiverpodPage.headings;
      case 'pkg-bloc':
        return DocsPkgBlocPage.headings;
      case 'pkg-otel':
        return DocsPkgOtelPage.headings;
      case 'pkg-devtools':
        return DocsPkgDevtoolsPage.headings;
      case 'pkg-lint':
        return DocsPkgLintPage.headings;
      case 'pkg-jaspr':
        return DocsPkgJasprPage.headings;
      case 'recipe-one-shot':
        return DocsRecipeOneShotPage.headings;
      case 'recipe-form-validation':
        return DocsRecipeFormValidationPage.headings;
      case 'recipe-controllers':
        return DocsRecipeControllersPage.headings;
      case 'recipe-caching':
        return DocsRecipeCachingPage.headings;
      case 'recipe-batching':
        return DocsRecipeBatchingPage.headings;
      case 'migration-bloc':
        return DocsMigrationBlocPage.headings;
      case 'migration-riverpod':
        return DocsMigrationRiverpodPage.headings;
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
      case 'decision-matrix':
        return 'website/lib/src/components/docs/pages/docs_decision_matrix.dart';
      case 'cubit-vs-bloc':
        return 'website/lib/src/components/docs/pages/docs_cubit_vs_bloc.dart';
      case 'state-modeling':
        return 'website/lib/src/components/docs/pages/docs_state_modeling.dart';
      case 'events-and-handlers':
        return 'website/lib/src/components/docs/pages/docs_events_and_handlers.dart';
      case 'event-transformers':
        return 'website/lib/src/components/docs/pages/docs_event_transformers.dart';
      case 'lifecycle-and-observers':
        return 'website/lib/src/components/docs/pages/docs_lifecycle_and_observers.dart';
      case 'signals-reactivity':
        return 'website/lib/src/components/docs/pages/docs_signals_reactivity.dart';
      case 'flutter-providers':
        return 'website/lib/src/components/docs/pages/docs_flutter_providers.dart';
      case 'flutter-widgets':
        return 'website/lib/src/components/docs/pages/docs_flutter_widgets.dart';
      case 'flutter-context':
        return 'website/lib/src/components/docs/pages/docs_flutter_context.dart';
      case 'testing-guide':
        return 'website/lib/src/components/docs/pages/docs_testing_guide.dart';
      case 'pkg-hydrate':
        return 'website/lib/src/components/docs/pages/docs_pkg_hydrate.dart';
      case 'pkg-replay':
        return 'website/lib/src/components/docs/pages/docs_pkg_replay.dart';
      case 'pkg-riverpod':
        return 'website/lib/src/components/docs/pages/docs_pkg_riverpod.dart';
      case 'pkg-bloc':
        return 'website/lib/src/components/docs/pages/docs_pkg_bloc.dart';
      case 'pkg-otel':
        return 'website/lib/src/components/docs/pages/docs_pkg_otel.dart';
      case 'pkg-devtools':
        return 'website/lib/src/components/docs/pages/docs_pkg_devtools.dart';
      case 'pkg-lint':
        return 'website/lib/src/components/docs/pages/docs_pkg_lint.dart';
      case 'pkg-jaspr':
        return 'website/lib/src/components/docs/pages/docs_pkg_jaspr.dart';
      case 'recipe-one-shot':
        return 'website/lib/src/components/docs/pages/docs_recipe_one_shot.dart';
      case 'recipe-form-validation':
        return 'website/lib/src/components/docs/pages/docs_recipe_form_validation.dart';
      case 'recipe-controllers':
        return 'website/lib/src/components/docs/pages/docs_recipe_controllers.dart';
      case 'recipe-caching':
        return 'website/lib/src/components/docs/pages/docs_recipe_caching.dart';
      case 'recipe-batching':
        return 'website/lib/src/components/docs/pages/docs_recipe_batching.dart';
      case 'migration-bloc':
        return 'website/lib/src/components/docs/pages/docs_migration_bloc.dart';
      case 'migration-riverpod':
        return 'website/lib/src/components/docs/pages/docs_migration_riverpod.dart';
      default:
        return 'website/lib/src/models/docs_registry.dart';
    }
  }
}
