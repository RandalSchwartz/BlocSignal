import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Tabs` component with selectable tab headers and child
/// views.
///
/// ```dart
/// final component = A2uiTabs(componentContext: componentContext);
/// ```
class A2uiTabs extends StatefulComponent {
  /// Creates an [A2uiTabs] component.
  ///
  /// ```dart
  /// final tabs = A2uiTabs(componentContext: componentContext);
  /// ```
  const A2uiTabs({
    required this.componentContext,
    super.key,
  });

  /// The component context holding properties and child builders.
  final A2uiComponentContext componentContext;

  @override
  State<A2uiTabs> createState() => _A2uiTabsState();
}

class _A2uiTabsState extends State<A2uiTabs> {
  int _selectedIndex = 0;

  List<({String title, String childId})> _parseTabs(dynamic rawTabs) {
    final unwrapped = unwrapBinding(rawTabs);
    if (unwrapped is! Iterable) return const [];
    final parsed = <({String title, String childId})>[];
    for (final item in unwrapped) {
      final map = unwrapBinding(item);
      if (map is Map) {
        final title = asString(map['title'], 'Tab');
        final childId = extractChildId(map['child']);
        if (childId != null && childId.isNotEmpty) {
          parsed.add((title: title, childId: childId));
        }
      }
    }
    return parsed;
  }

  @override
  Component build(BuildContext context) {
    final tabs = _parseTabs(
      component.componentContext.props['tabs'] ??
          component.componentContext.props['tabItems'],
    );
    if (tabs.isEmpty) {
      return const Component.empty();
    }

    final activeIndex = _selectedIndex.clamp(0, tabs.length - 1);
    final activeTab = tabs[activeIndex];

    return div(
      classes: 'a2ui-tabs',
      styles: const Styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
      ),
      [
        div(
          classes: 'a2ui-tabs-header',
          attributes: const {'role': 'tablist'},
          styles: const Styles(
            display: Display.flex,
            flexDirection: FlexDirection.row,
            overflow: Overflow.only(x: Overflow.auto),
            margin: Spacing.only(bottom: Unit.pixels(8)),
          ),
          [
            for (var index = 0; index < tabs.length; index++)
              button(
                classes: index == activeIndex
                    ? 'a2ui-tab a2ui-tab-active'
                    : 'a2ui-tab',
                attributes: {
                  'role': 'tab',
                  'aria-selected': (index == activeIndex).toString(),
                },
                onClick: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                styles: Styles(
                  margin: const Spacing.only(right: Unit.pixels(8)),
                  padding: const Spacing.symmetric(
                    vertical: Unit.pixels(6),
                    horizontal: Unit.pixels(12),
                  ),
                  radius: const BorderRadius.circular(Unit.pixels(16)),
                  border: Border.all(
                    color: index == activeIndex
                        ? const Color('#2563eb')
                        : const Color('#d1d5db'),
                    width: const Unit.pixels(1),
                  ),
                  backgroundColor: index == activeIndex
                      ? const Color('#dbeafe')
                      : Colors.white,
                  color: index == activeIndex
                      ? const Color('#1d4ed8')
                      : const Color('#374151'),
                  cursor: Cursor.pointer,
                ),
                [Component.text(tabs[index].title)],
              ),
          ],
        ),
        div(
          classes: 'a2ui-tabs-panel',
          attributes: const {'role': 'tabpanel'},
          [component.componentContext.buildChild(activeTab.childId)],
        ),
      ],
    );
  }
}

/// Builder function for registering [A2uiTabs] in an A2UI Jaspr catalog.
///
/// ```dart
/// catalog.register('Tabs', buildA2uiTabs);
/// ```
Component buildA2uiTabs(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  return A2uiTabs(componentContext: componentContext);
}
