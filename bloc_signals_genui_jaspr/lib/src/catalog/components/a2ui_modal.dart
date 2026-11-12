import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Modal` component that opens a dialog overlay containing
/// the `content` child when the `trigger` child is clicked.
///
/// Supports both v0.9/v1.0 `trigger` and `content` properties and legacy
/// `entryPointChild` and `contentChild` aliases.
///
/// ```dart
/// final component = A2uiModal(componentContext: componentContext);
/// ```
class A2uiModal extends StatefulComponent {
  /// Creates an [A2uiModal] component.
  ///
  /// ```dart
  /// final modal = A2uiModal(componentContext: componentContext);
  /// ```
  const A2uiModal({
    required this.componentContext,
    super.key,
  });

  /// The component context holding properties and child builders.
  final A2uiComponentContext componentContext;

  @override
  State<A2uiModal> createState() => _A2uiModalState();
}

class _A2uiModalState extends State<A2uiModal> {
  bool _isOpen = false;

  @override
  Component build(BuildContext context) {
    final props = component.componentContext.props;
    final triggerId = extractChildId(
      props['trigger'] ?? props['entryPointChild'],
    );
    final contentId = extractChildId(
      props['content'] ?? props['contentChild'],
    );

    if (triggerId == null || triggerId.isEmpty) {
      return const Component.empty();
    }

    final hasContent = contentId != null && contentId.isNotEmpty;

    return div(
      classes: 'a2ui-modal',
      [
        div(
          classes: 'a2ui-modal-trigger',
          events: hasContent
              ? {
                  'click': (_) {
                    setState(() {
                      _isOpen = true;
                    });
                  },
                }
              : null,
          styles: Styles(
            display: Display.inlineBlock,
            cursor: hasContent ? Cursor.pointer : Cursor.defaultCursor,
          ),
          [component.componentContext.buildChild(triggerId)],
        ),
        if (_isOpen && hasContent)
          div(
            classes: 'a2ui-modal-backdrop',
            attributes: const {
              'role': 'dialog',
              'aria-modal': 'true',
            },
            styles: const Styles(
              position: Position.fixed(
                top: Unit.zero,
                right: Unit.zero,
                bottom: Unit.zero,
                left: Unit.zero,
              ),
              display: Display.flex,
              justifyContent: JustifyContent.center,
              alignItems: AlignItems.center,
              backgroundColor: Color.rgba(0, 0, 0, 0.5),
            ),
            [
              div(
                classes: 'a2ui-modal-dialog',
                styles: const Styles(
                  backgroundColor: Colors.white,
                  padding: Spacing.all(Unit.pixels(16)),
                  radius: BorderRadius.circular(Unit.pixels(8)),
                  maxWidth: Unit.percent(90),
                ),
                [
                  div(
                    classes: 'a2ui-modal-actions',
                    styles: const Styles(
                      display: Display.flex,
                      justifyContent: JustifyContent.end,
                      margin: Spacing.only(bottom: Unit.pixels(8)),
                    ),
                    [
                      button(
                        classes: 'a2ui-modal-close',
                        attributes: const {'aria-label': 'Close modal'},
                        onClick: () {
                          setState(() {
                            _isOpen = false;
                          });
                        },
                        styles: const Styles(
                          backgroundColor: Colors.transparent,
                          border: Border.all(style: BorderStyle.none),
                          cursor: Cursor.pointer,
                        ),
                        const [Component.text('×')],
                      ),
                    ],
                  ),
                  div(
                    classes: 'a2ui-modal-content',
                    [component.componentContext.buildChild(contentId)],
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

/// Builder function for registering [A2uiModal] in an A2UI Jaspr catalog.
///
/// ```dart
/// catalog.register('Modal', buildA2uiModal);
/// ```
Component buildA2uiModal(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  return A2uiModal(componentContext: componentContext);
}
