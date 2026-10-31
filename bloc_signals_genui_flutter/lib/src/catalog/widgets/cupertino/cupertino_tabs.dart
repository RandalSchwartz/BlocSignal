import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Tabs` component using [CupertinoSlidingSegmentedControl] to
/// switch between child tab views.
class A2uiCupertinoTabs extends StatefulWidget {
  /// Creates an [A2uiCupertinoTabs] widget.
  const A2uiCupertinoTabs({
    required this.componentContext,
    super.key,
  });

  /// The component context holding properties and child builders.
  final A2uiComponentContext componentContext;

  @override
  State<A2uiCupertinoTabs> createState() => _A2uiCupertinoTabsState();
}

class _A2uiCupertinoTabsState extends State<A2uiCupertinoTabs> {
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

    final segmentedChildren = <int, Widget>{
      for (var i = 0; i < tabs.length; i++)
        i: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            tabs[i].title,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 13,
                ),
          ),
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoSlidingSegmentedControl<int>(
          groupValue: activeIndex,
          children: segmentedChildren,
          onValueChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedIndex = val;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        widget.componentContext.buildChild(activeTab.childId),
      ],
    );
  }
}

/// Builder function for registering [A2uiCupertinoTabs] in an A2UI catalog.
Widget buildCupertinoTabs(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  return A2uiCupertinoTabs(componentContext: componentContext);
}
