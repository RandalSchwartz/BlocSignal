import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Navbar extends StatelessComponent {
  const Navbar({super.key});

  @override
  Component build(BuildContext context) {
    return header(classes: 'navbar', [
      div(classes: 'container nav-content', [
        a(href: '/', classes: 'brand', [
          img(src: '/assets/logo.png', alt: 'BlocSignal Logo', width: 36, height: 36),
          span(classes: 'brand-title', [Component.text('BlocSignal')]),
          span(classes: 'brand-badge', [Component.text('v1.0.0')]),
        ]),
        nav(classes: 'nav-links', [
          a(href: '#packages', [Component.text('Packages')]),
          a(href: '#visualizer', [Component.text('Live Visualizer')]),
          a(href: '#examples', [Component.text('Examples')]),
          a(href: 'https://pub.dev/packages/bloc_signals', target: Target.blank, [Component.text('pub.dev')]),
          a(
            href: 'https://github.com/RandalSchwartz/BlocSignal',
            target: Target.blank,
            classes: 'btn-github',
            [Component.text('GitHub ⭐️')],
          ),
        ]),
      ]),
    ]);
  }
}
