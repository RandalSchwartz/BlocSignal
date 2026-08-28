import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

enum CalloutType(
  final String icon,
  final String defaultTitle,
  final String cssClass,
) {
  note('📝', 'Note', 'callout-note'),
  tip('💡', 'Tip', 'callout-tip'),
  important('⚡', 'Important', 'callout-important'),
  warning('⚠️', 'Warning', 'callout-warning'),
  caution('🛑', 'Caution', 'callout-caution'),
}

/// A styled GitHub-like callout box for documentation.
class const DocsCallout({
  required final CalloutType type,
  final String? title,
  required final List<Component> children,
  super.key,
}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'docs-callout ${type.cssClass}', [
      div(classes: 'docs-callout-header', [
        span(classes: 'docs-callout-icon', [Component.text(type.icon)]),
        span(classes: 'docs-callout-title', [
          Component.text(title ?? type.defaultTitle),
        ]),
      ]),
      div(classes: 'docs-callout-body', children),
    ]);
  }
}
