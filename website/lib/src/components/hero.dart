import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class HeroBanner extends StatelessComponent {
  const HeroBanner({super.key});

  @override
  Component build(BuildContext context) {
    return section(classes: 'hero-section', [
      div(classes: 'container hero-container', [
        div(classes: 'hero-logo-wrapper', [
          img(
            src: '/assets/logo.png',
            alt: 'BlocSignal Official Logo',
            classes: 'hero-branding-logo',
            width: 140,
            height: 140,
          ),
        ]),
        div(classes: 'hero-badge-tag', [
          Component.text(
              '🚀 Powerful & Synchronous State Management for Dart & Flutter'),
        ]),
        h1(classes: 'hero-title', [
          Component.text('The Rigor of BLoC.'),
          br(),
          span(
              classes: 'highlight-text',
              [Component.text('The Flex & Speed of Signal.')]),
        ]),
        p(classes: 'hero-motto', [
          Component.text(
            'Enterprise-grade state management for Dart & Flutter with 0ms microtask latency, 100% docstring coverage, OpenTelemetry tracing, and universal ecosystem bridges.',
          ),
        ]),
        div(classes: 'hero-actions', [
          a(
            href: '#visualizer',
            classes: 'btn-primary',
            [Component.text('Try Live Visualizer')],
          ),
          a(
            href: 'https://pub.dev/packages/bloc_signals',
            target: Target.blank,
            classes: 'btn-secondary',
            [Component.text('View on pub.dev')],
          ),
        ]),
        div(classes: 'code-snippet-box', [
          pre([
            code([
              Component.text('''
dependencies:
  bloc_signals: ^1.0.0
  bloc_signals_flutter: ^1.0.0'''),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
