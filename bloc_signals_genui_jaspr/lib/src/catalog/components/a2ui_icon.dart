import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

const Map<String, String> _a2uiIconGlyphs = <String, String>{
  'accountCircle': 'account_circle',
  'add': '+',
  'arrowBack': '←',
  'arrowForward': '→',
  'attachFile': 'attach_file',
  'calendarToday': 'calendar_today',
  'call': 'call',
  'camera': 'camera_alt',
  'check': '✓',
  'close': '✕',
  'delete': 'delete',
  'download': '↓',
  'edit': '✎',
  'error': '!',
  'event': 'event',
  'fastForward': 'fast_forward',
  'favorite': '♥',
  'favoriteOff': '♡',
  'folder': 'folder',
  'help': '?',
  'home': 'home',
  'info': 'i',
  'locationOn': 'location_on',
  'lock': 'lock',
  'lockOpen': 'lock_open',
  'mail': 'mail',
  'menu': '☰',
  'moreHoriz': '⋯',
  'moreVert': '⋮',
  'notifications': 'notifications',
  'notificationsOff': 'notifications_off',
  'pause': '⏸',
  'payment': 'payment',
  'person': 'person',
  'phone': 'phone',
  'photo': 'photo',
  'play': '▶',
  'print': 'print',
  'refresh': '↻',
  'rewind': 'rewind',
  'search': 'search',
  'send': 'send',
  'settings': '⚙',
  'share': 'share',
  'shoppingCart': 'shopping_cart',
  'skipNext': 'skip_next',
  'skipPrevious': 'skip_previous',
  'star': '★',
  'starHalf': 'star_half',
  'starOff': '☆',
  'stop': '■',
  'upload': '↑',
  'visibility': 'visibility',
  'visibilityOff': 'visibility_off',
  'volumeDown': 'volume_down',
  'volumeMute': 'volume_mute',
  'volumeOff': 'volume_off',
  'volumeUp': 'volume_up',
  'warning': '⚠',
};

/// Renders an A2UI `Icon` component.
///
/// Supports standard A2UI icon names as well as custom `{"svgPath": "..."}`
/// payloads rendered as inline `<svg viewBox="0 0 24 24">` elements.
///
/// ```dart
/// final component = buildA2uiIcon(context, componentContext);
/// ```
Component buildA2uiIcon(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final rawName = unwrapBinding(props['name'] ?? props['icon']);
  final size = props['size'] != null ? asDouble(props['size'], 24) : 24.0;
  final semanticLabel = unwrapBinding(props['description'])?.toString();

  final a11yAttrs = <String, String>{
    if (semanticLabel != null && semanticLabel.isNotEmpty)
      'aria-label': semanticLabel
    else
      'aria-hidden': 'true',
  };

  if (rawName is Map && rawName['svgPath'] != null) {
    final svgPath = asString(rawName['svgPath']).trim();
    if (svgPath.isNotEmpty) {
      return span(
        classes: 'a2ui-icon a2ui-icon-svg',
        attributes: a11yAttrs,
        styles: Styles(
          display: Display.inlineFlex,
          alignItems: AlignItems.center,
          justifyContent: JustifyContent.center,
          width: Unit.pixels(size),
          height: Unit.pixels(size),
        ),
        [
          svg(
            viewBox: '0 0 24 24',
            width: Unit.pixels(size),
            height: Unit.pixels(size),
            [
              path(
                const [],
                d: svgPath,
                attributes: const {'fill': 'currentColor'},
              ),
            ],
          ),
        ],
      );
    }
  }

  final String iconName;
  if (rawName is Map) {
    iconName = asString(rawName['name']);
  } else {
    iconName = asString(rawName);
  }

  final glyph = _a2uiIconGlyphs[iconName] ?? '?';

  return span(
    classes: 'a2ui-icon',
    attributes: {
      ...a11yAttrs,
      if (iconName.isNotEmpty) 'data-icon': iconName,
    },
    styles: Styles(
      display: Display.inlineFlex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.center,
      fontSize: Unit.pixels(size),
      lineHeight: Unit.pixels(size),
    ),
    [Component.text(glyph)],
  );
}
