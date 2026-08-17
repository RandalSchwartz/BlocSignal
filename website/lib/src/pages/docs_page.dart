import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/docs/docs_content.dart';
import '../components/docs/docs_sidebar.dart';
import '../components/footer.dart';
import '../components/navbar.dart';
import '../cubits/docs_cubit.dart';
import '../models/app_route.dart';
import '../models/docs_models.dart';

/// The top-level documentation hub page.
class const DocsPage({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root docs-page-root', [
      const Navbar(currentRoute: AppRoute.docs),
      BlocSignalProvider<DocsCubit>(
        create: (_) => DocsCubit(),
        child: const _DocsLayout(),
      ),
      const Footer(),
    ]);
  }
}

class const _DocsLayout() extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<DocsCubit, DocsState>(
      builder: (context, state) {
        final cubit = context.read<DocsCubit>();

        return div(classes: 'docs-wrapper', [
          // Mobile Drawer Backdrop
          if (state.isMobileDrawerOpen)
            div(
              classes: 'docs-drawer-backdrop',
              events: {'click': (_) => cubit.closeMobileDrawer()},
              [],
            ),

          div(classes: 'container docs-shell', [
            // Left Navigation Sidebar
            div(
              classes:
                  'docs-sidebar-wrapper ${state.isMobileDrawerOpen ? "open" : ""}',
              [const DocsSidebar()],
            ),

            // Center Content + Right TOC
            const DocsContent(),
          ]),
        ]);
      },
    );
  }
}
