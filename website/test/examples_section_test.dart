import 'package:blocsignal_website/src/components/examples_section.dart';
import 'package:jaspr/jaspr.dart';
import 'package:test/test.dart';

void _collectDomTextAndLinks(
  Component component,
  StringBuffer textBuffer,
  List<Map<String, String>> anchorAttributes,
) {
  if (component is Text) {
    textBuffer.write(component.text);
    return;
  }
  if (component is StatelessComponent) {
    final element = component.createElement();
    // ignore: invalid_use_of_protected_member
    final built = component.build(element);
    _collectDomTextAndLinks(built, textBuffer, anchorAttributes);
  } else if (component is DomComponent) {
    if (component.tag == 'a') {
      anchorAttributes.add(component.attributes ?? const {});
    }
    final children = component.children;
    if (children != null) {
      for (final child in children) {
        _collectDomTextAndLinks(child, textBuffer, anchorAttributes);
      }
    }
  }
}

void main() {
  group('(Issue #263) ExamplesSection Community Showcase', () {
    test('renders Community Showcase with dog_ceo_signals_app and secure link attributes', () {
      const component = ExamplesSection();
      final element = component.createElement();
      // ignore: invalid_use_of_protected_member
      final built = component.build(element);

      final textBuffer = StringBuffer();
      final anchorAttributes = <Map<String, String>>[];
      _collectDomTextAndLinks(built, textBuffer, anchorAttributes);

      final renderedText = textBuffer.toString();
      expect(renderedText, contains('Community Showcase'));
      expect(renderedText, contains('dog_ceo_signals_app'));
      expect(renderedText, contains('@tataDan'));

      final dogCeoLink = anchorAttributes.firstWhere(
        (attrs) =>
            attrs['href'] == 'https://github.com/tataDan/dog_ceo_signals_app',
      );
      expect(dogCeoLink['rel'], equals('noopener noreferrer'));
    });
  });
}
