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
  final size = props['size'] != null
      ? asBoundedDouble(props['size'], min: 1, max: 256, defaultValue: 24)
      : 24.0;
  final semanticLabel = unwrapBinding(props['description'])?.toString();

  final a11yAttrs = <String, String>{
    if (semanticLabel != null && semanticLabel.isNotEmpty)
      'aria-label': semanticLabel
    else
      'aria-hidden': 'true',
  };

  if (rawName is Map && rawName['svgPath'] != null) {
    final svgPath = asString(rawName['svgPath']).trim();
    if (_isValidSvgPath(svgPath)) {
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

const int _kMaxSvgPathLength = 8192;
const int _kMaxSvgCommandCount = 512;
const double _kMaxSvgCoordMagnitude = 100000;

bool _isValidSvgPath(String pathData) {
  if (pathData.isEmpty || pathData.length > _kMaxSvgPathLength) return false;
  return _SvgPathValidator(pathData).validate();
}

class _SvgPathValidator {
  _SvgPathValidator(this.source);

  final String source;
  int index = 0;
  double curX = 0;
  double curY = 0;
  double startX = 0;
  double startY = 0;
  int commandCount = 0;
  bool hasCommands = false;

  void _skipSeparators() {
    while (index < source.length) {
      final code = source.codeUnitAt(index);
      if (code == 0x20 ||
          code == 0x09 ||
          code == 0x0A ||
          code == 0x0D ||
          code == 0x2C) {
        index++;
      } else {
        break;
      }
    }
  }

  bool _isCommandChar(int code) {
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  }

  bool _isValidCoord(double value) =>
      value.isFinite && value.abs() <= _kMaxSvgCoordMagnitude;

  bool _consumeCommandQuota() {
    commandCount++;
    return commandCount <= _kMaxSvgCommandCount;
  }

  double? _readNumber() {
    _skipSeparators();
    if (index >= source.length) return null;

    final start = index;
    var code = source.codeUnitAt(index);
    if (code == 0x2B || code == 0x2D) {
      index++;
    }

    var hasDigits = false;
    while (index < source.length) {
      code = source.codeUnitAt(index);
      if (code >= 0x30 && code <= 0x39) {
        hasDigits = true;
        index++;
      } else {
        break;
      }
    }

    if (index < source.length && source.codeUnitAt(index) == 0x2E) {
      index++;
      while (index < source.length) {
        code = source.codeUnitAt(index);
        if (code >= 0x30 && code <= 0x39) {
          hasDigits = true;
          index++;
        } else {
          break;
        }
      }
    }

    if (!hasDigits) return null;

    if (index < source.length) {
      code = source.codeUnitAt(index);
      if (code == 0x65 || code == 0x45) {
        index++;
        if (index < source.length) {
          final sign = source.codeUnitAt(index);
          if (sign == 0x2B || sign == 0x2D) {
            index++;
          }
        }
        var expDigits = false;
        while (index < source.length) {
          final c = source.codeUnitAt(index);
          if (c >= 0x30 && c <= 0x39) {
            expDigits = true;
            index++;
          } else {
            break;
          }
        }
        if (!expDigits) return null;
      }
    }

    final parsed = double.tryParse(source.substring(start, index));
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  int? _readFlag() {
    _skipSeparators();
    if (index >= source.length) return null;
    final code = source.codeUnitAt(index);
    if (code == 0x30 || code == 0x31) {
      index++;
      return code - 0x30;
    }
    return null;
  }

  bool _hasMoreNumbers() {
    _skipSeparators();
    if (index >= source.length) return false;
    return !_isCommandChar(source.codeUnitAt(index));
  }

  bool validate() {
    String? command;

    while (true) {
      _skipSeparators();
      if (index >= source.length) break;

      final code = source.codeUnitAt(index);
      if (_isCommandChar(code)) {
        command = String.fromCharCode(code);
        index++;
      } else if (command == null) {
        return false;
      }

      if (command == 'Z' || command == 'z') {
        if (!_consumeCommandQuota()) return false;
        curX = startX;
        curY = startY;
        hasCommands = true;
        command = null;
        continue;
      }

      if (!_hasMoreNumbers()) return false;

      while (_hasMoreNumbers()) {
        if (!_consumeCommandQuota()) return false;
        final isRel = command == command!.toLowerCase();
        switch (command) {
          case 'M':
          case 'm':
            final x = _readNumber();
            final y = _readNumber();
            if (x == null || y == null) return false;
            final nextX = isRel ? curX + x : x;
            final nextY = isRel ? curY + y : y;
            if (!_isValidCoord(nextX) || !_isValidCoord(nextY)) return false;
            curX = nextX;
            curY = nextY;
            startX = curX;
            startY = curY;
            command = isRel ? 'l' : 'L';
            hasCommands = true;
          case 'L':
          case 'l':
          case 'T':
          case 't':
            final x = _readNumber();
            final y = _readNumber();
            if (x == null || y == null) return false;
            final nextX = isRel ? curX + x : x;
            final nextY = isRel ? curY + y : y;
            if (!_isValidCoord(nextX) || !_isValidCoord(nextY)) return false;
            curX = nextX;
            curY = nextY;
            hasCommands = true;
          case 'H':
          case 'h':
            final x = _readNumber();
            if (x == null) return false;
            final nextX = isRel ? curX + x : x;
            if (!_isValidCoord(nextX)) return false;
            curX = nextX;
            hasCommands = true;
          case 'V':
          case 'v':
            final y = _readNumber();
            if (y == null) return false;
            final nextY = isRel ? curY + y : y;
            if (!_isValidCoord(nextY)) return false;
            curY = nextY;
            hasCommands = true;
          case 'C':
          case 'c':
            final x1 = _readNumber();
            final y1 = _readNumber();
            final x2 = _readNumber();
            final y2 = _readNumber();
            final x = _readNumber();
            final y = _readNumber();
            if (x1 == null ||
                y1 == null ||
                x2 == null ||
                y2 == null ||
                x == null ||
                y == null) {
              return false;
            }
            final ax1 = isRel ? curX + x1 : x1;
            final ay1 = isRel ? curY + y1 : y1;
            final ax2 = isRel ? curX + x2 : x2;
            final ay2 = isRel ? curY + y2 : y2;
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            if (!_isValidCoord(ax1) ||
                !_isValidCoord(ay1) ||
                !_isValidCoord(ax2) ||
                !_isValidCoord(ay2) ||
                !_isValidCoord(ax) ||
                !_isValidCoord(ay)) {
              return false;
            }
            curX = ax;
            curY = ay;
            hasCommands = true;
          case 'S':
          case 's':
          case 'Q':
          case 'q':
            final x1 = _readNumber();
            final y1 = _readNumber();
            final x = _readNumber();
            final y = _readNumber();
            if (x1 == null || y1 == null || x == null || y == null) {
              return false;
            }
            final ax1 = isRel ? curX + x1 : x1;
            final ay1 = isRel ? curY + y1 : y1;
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            if (!_isValidCoord(ax1) ||
                !_isValidCoord(ay1) ||
                !_isValidCoord(ax) ||
                !_isValidCoord(ay)) {
              return false;
            }
            curX = ax;
            curY = ay;
            hasCommands = true;
          case 'A':
          case 'a':
            final rx = _readNumber();
            final ry = _readNumber();
            final rot = _readNumber();
            final largeArc = _readFlag();
            final sweep = _readFlag();
            final x = _readNumber();
            final y = _readNumber();
            if (rx == null ||
                ry == null ||
                rot == null ||
                largeArc == null ||
                sweep == null ||
                x == null ||
                y == null) {
              return false;
            }
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            if (!_isValidCoord(rx) ||
                !_isValidCoord(ry) ||
                !_isValidCoord(rot) ||
                !_isValidCoord(ax) ||
                !_isValidCoord(ay)) {
              return false;
            }
            curX = ax;
            curY = ay;
            hasCommands = true;
          default:
            return false;
        }
      }
    }

    return hasCommands;
  }
}
