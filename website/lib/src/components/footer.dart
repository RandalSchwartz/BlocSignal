import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class const Footer({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return footer(classes: 'site-footer', [
      div(classes: 'container footer-content', [
        p([
          Component.text(
            'Released under the MIT License. Managed by Randal L. Schwartz & Open-Source Contributors.',
          ),
        ]),
        p(classes: 'footer-links', [
          a(
            href: 'https://pub.dev/packages/bloc_signals',
            target: Target.blank,
            [Component.text('pub.dev')],
          ),
          Component.text(' • '),
          a(
            href: 'https://github.com/RandalSchwartz/BlocSignal',
            target: Target.blank,
            [Component.text('GitHub')],
          ),
          Component.text(' • '),
          a(href: 'https://blocsignal.dev', [Component.text('blocsignal.dev')]),
        ]),
      ]),
    ]);
  }
}
