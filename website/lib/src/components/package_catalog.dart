import 'package:jaspr/jaspr.dart';

class PackageCatalog extends StatelessComponent {
  const PackageCatalog({super.key});

  @override
  Component build(BuildContext context) {
    final packages = [
      (
        name: 'bloc_signals',
        version: '0.9.0',
        desc:
            'Core pure Dart reactive state container bridging BLoC semantics with signals v7 primitives.',
        icon: '⚡',
        pubUrl: 'https://pub.dev/packages/bloc_signals',
      ),
      (
        name: 'bloc_signals_flutter',
        version: '0.9.0',
        desc:
            'Flutter UI bindings, InheritedWidget providers, builders, selectors, and Listenable interop.',
        icon: '💙',
        pubUrl: 'https://pub.dev/packages/bloc_signals_flutter',
      ),
      (
        name: 'bloc_signals_jaspr',
        version: '0.9.0',
        desc:
            'Jaspr web component integration, InheritedComponent providers, builders, listeners, and selectors.',
        icon: '🌐',
        pubUrl: 'https://pub.dev/packages/bloc_signals_jaspr',
      ),
      (
        name: 'bloc_signals_riverpod',
        version: '0.9.0',
        desc:
            'Bidirectional Riverpod 2 & 3 interop adapters (toBlocSignal / toProvider).',
        icon: '🌊',
        pubUrl: 'https://pub.dev/packages/bloc_signals_riverpod',
      ),
      (
        name: 'bloc_signals_hydrate',
        version: '0.9.0',
        desc:
            'Synchronous state persistence across app restarts with primitive and collection support.',
        icon: '💾',
        pubUrl: 'https://pub.dev/packages/bloc_signals_hydrate',
      ),
      (
        name: 'bloc_signals_replay',
        version: '0.9.0',
        desc:
            'Replay, undo, and redo state tracking utilities (ReplayCubit, ReplayBloc).',
        icon: '↩️',
        pubUrl: 'https://pub.dev/packages/bloc_signals_replay',
      ),
      (
        name: 'bloc_signals_otel',
        version: '0.9.0',
        desc:
            'OpenTelemetry lifecycle tracing, transition metrics, and distributed span correlation.',
        icon: '🔭',
        pubUrl: 'https://pub.dev/packages/bloc_signals_otel',
      ),
      (
        name: 'bloc_signals_devtools',
        version: '0.9.0',
        desc:
            'Custom Flutter DevTools extension for timeline tracing, state diffing, and leak detection.',
        icon: '🛠️',
        pubUrl: 'https://pub.dev/packages/bloc_signals_devtools',
      ),
      (
        name: 'bloc_signals_test',
        version: '0.9.0',
        desc:
            'Declarative unit testing utilities and test observers for BlocSignal and CubitSignal.',
        icon: '🧪',
        pubUrl: 'https://pub.dev/packages/bloc_signals_test',
      ),
      (
        name: 'bloc_signals_lint',
        version: '0.9.0',
        desc:
            'Custom analyzer lints and automated IDE quick-fixes for enforcing BlocSignal best practices.',
        icon: '🔍',
        pubUrl: 'https://pub.dev/packages/bloc_signals_lint',
      ),
    ];

    return Component.element(
      tag: 'section',
      id: 'packages',
      classes: 'packages-section',
      children: [
        Component.element(
          tag: 'div',
          classes: 'container',
          children: [
            Component.element(
              tag: 'h2',
              classes: 'section-title',
              children: [
                Component.text('The '),
                Component.element(
                  tag: 'span',
                  classes: 'gradient-text',
                  children: [Component.text('BlocSignal Ecosystem')],
                ),
              ],
            ),
            Component.element(
              tag: 'p',
              classes: 'section-subtitle',
              children: [
                Component.text(
                  'Modular, zero-dependency core with first-class interop packages.',
                ),
              ],
            ),
            Component.element(
              tag: 'div',
              classes: 'package-grid',
              children: [
                for (final pkg in packages)
                  Component.element(
                    tag: 'div',
                    classes: 'package-card',
                    children: [
                      Component.element(
                        tag: 'div',
                        classes: 'package-header',
                        children: [
                          Component.element(
                            tag: 'span',
                            classes: 'package-icon',
                            children: [Component.text(pkg.icon)],
                          ),
                          Component.element(
                            tag: 'span',
                            classes: 'package-version',
                            children: [Component.text('v${pkg.version}')],
                          ),
                        ],
                      ),
                      Component.element(
                        tag: 'h3',
                        classes: 'package-name',
                        children: [Component.text(pkg.name)],
                      ),
                      Component.element(
                        tag: 'p',
                        classes: 'package-desc',
                        children: [Component.text(pkg.desc)],
                      ),
                      Component.element(
                        tag: 'a',
                        classes: 'package-link',
                        attributes: {
                          'href': pkg.pubUrl,
                          'target': '_blank',
                          'rel': 'noopener',
                        },
                        children: [Component.text('View on pub.dev →')],
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
