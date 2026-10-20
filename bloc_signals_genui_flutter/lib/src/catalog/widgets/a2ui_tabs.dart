import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Tabs` component with selectable tab headers and child
/// views.
///
/// ```dart
/// final widget = A2uiTabs(componentContext: componentContext);
/// ```
class A2uiTabs extends StatefulWidget {
  /// Creates an [A2uiTabs] widget.
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
  Widget build(BuildContext context) {
    final tabs = _parseTabs(
      widget.componentContext.props['tabs'] ??
          widget.componentContext.props['tabItems'],
    );
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeIndex = _selectedIndex.clamp(0, tabs.length - 1);
    final activeTab = tabs[activeIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tabs[i].title),
                    selected: i == activeIndex,
                    onSelected: (_) {
                      setState(() {
                        _selectedIndex = i;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        widget.componentContext.buildChild(activeTab.childId),
      ],
    );
  }
}

/// Builder function for registering [A2uiTabs] in an A2UI catalog.
///
/// ```dart
/// catalog.register('Tabs', buildA2uiTabs);
/// ```
Widget buildA2uiTabs(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  return A2uiTabs(componentContext: componentContext);
}
