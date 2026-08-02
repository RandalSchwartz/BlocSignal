import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class PackageCatalog extends StatelessComponent {
  const PackageCatalog({super.key});

  @override
  Component build(BuildContext context) {
    final packages = [
      (
        name: 'bloc_signals',
        version: '1.0.0',
        desc: 'Core pure Dart reactive state container bridging BLoC semantics with signals v7 primitives.',
        icon: '⚡',
        pubUrl: 'https://pub.dev/packages/bloc_signals',
      ),
      (
        name: 'bloc_signals_flutter',
        version: '1.0.0',
        desc: 'Flutter UI bindings, InheritedWidget providers, builders, selectors, and Listenable interop.',
        icon: '💙',
        pubUrl: 'https://pub.dev/packages/bloc_signals_flutter',
      ),
      (
        name: 'bloc_signals_riverpod',
        version: '1.0.0',
        desc: 'Bidirectional Riverpod 2 & 3 interop adapters (toBlocSignal / toProvider).',
        icon: '🌊',
        pubUrl: 'https://pub.dev/packages/bloc_signals_riverpod',
      ),
      (
        name: 'bloc_signals_hydrate',
        version: '1.0.0',
        desc: 'Synchronous state persistence across app restarts with primitive and collection support.',
        icon: '💾',
        pubUrl: 'https://pub.dev/packages/bloc_signals_hydrate',
      ),
      (
        name: 'bloc_signals_otel',
        version: '1.0.0',
        desc: 'OpenTelemetry lifecycle tracing, transition metrics, and distributed span correlation.',
        icon: '🔭',
        pubUrl: 'https://pub.dev/packages/bloc_signals_otel',
      ),
      (
        name: 'bloc_signals_devtools',
        version: '1.0.0',
        desc: 'Custom Flutter DevTools extension for timeline tracing, state diffing, and leak detection.',
        icon: '🛠️',
        pubUrl: 'https://pub.dev/packages/bloc_signals_devtools',
      ),
      (
        name: 'bloc_signals_test',
        version: '1.0.0',
        desc: 'Declarative unit testing utilities (`blocSignalTest`) for BLoC and Cubit containers.',
        icon: '🧪',
        pubUrl: 'https://pub.dev/packages/bloc_signals_test',
      ),
      (
        name: 'bloc_signals_lint',
        version: '1.0.0',
        desc: 'Static analysis lints, AST rule enforcement, and automated IDE quick-fixes.',
        icon: '🔍',
        pubUrl: 'https://pub.dev/packages/bloc_signals_lint',
      ),
    ];

    return section(id: 'packages', classes: 'catalog-section', [
      div(classes: 'container', [
        h2(classes: 'section-title', [Component.text('Workspace Package Ecosystem')]),
        p(classes: 'section-subtitle', [
          Component.text('Modular, zero-bloat packages designed to work together seamlessly or independently.'),
        ]),
        div(classes: 'package-grid', [
          for (final pkg in packages)
            div(classes: 'package-card', [
              div(classes: 'card-header', [
                span(classes: 'card-icon', [Component.text(pkg.icon)]),
                span(classes: 'card-version', [Component.text('v${pkg.version}')]),
              ]),
              h3(classes: 'card-title', [Component.text(pkg.name)]),
              p(classes: 'card-desc', [Component.text(pkg.desc)]),
              a(
                href: pkg.pubUrl,
                target: Target.blank,
                classes: 'card-link',
                [Component.text('pub.dev →')],
              ),
            ]),
        ]),
      ]),
    ]);
  }
}
