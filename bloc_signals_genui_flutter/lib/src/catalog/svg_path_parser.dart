import 'package:flutter/rendering.dart';

/// Zero-dependency [CustomPainter] that scales a parsed `24x24` viewBox SVG
/// [Path] to the widget's painted [Size] and fills it with [color].
class SvgPathPainter extends CustomPainter {
  /// Creates an [SvgPathPainter].
  const SvgPathPainter({
    required this.path,
    required this.color,
  });

  /// The parsed SVG [Path] defined in a `24x24` coordinate space.
  final Path path;

  /// The fill color used to paint [path].
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas
      ..save()
      ..scale(size.width / 24.0, size.height / 24.0)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(SvgPathPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}

/// Zero-dependency parser for SVG `d` path strings into Flutter [Path] objects.
///
/// Supports `M/m`, `L/l`, `H/h`, `V/v`, `C/c`, `S/s`, `Q/q`, `T/t`, `A/a`,
/// and `Z/z` commands. Returns `null` when the path string is empty or
/// malformed.
///
/// ```dart
/// final path = SvgPathParser.parse('M 2 2 L 22 2 L 12 22 Z');
/// ```
abstract final class SvgPathParser {
  /// Parses an SVG path data string [data] into a [Path], or returns `null` if
  /// [data] is empty or contains invalid syntax.
  static Path? parse(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return null;

    final parser = _SvgPathCursor(trimmed);
    return parser.parsePath();
  }
}

class _SvgPathCursor {
  _SvgPathCursor(this.source);

  final String source;
  int index = 0;

  double curX = 0;
  double curY = 0;
  double startX = 0;
  double startY = 0;
  double lastCtrlX = 0;
  double lastCtrlY = 0;
  String? prevCommand;
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

  Path? parsePath() {
    final path = Path();
    String? command;

    while (true) {
      _skipSeparators();
      if (index >= source.length) break;

      final code = source.codeUnitAt(index);
      if (_isCommandChar(code)) {
        command = String.fromCharCode(code);
        index++;
      } else if (command == null) {
        return null;
      }

      if (command == 'Z' || command == 'z') {
        path.close();
        curX = startX;
        curY = startY;
        prevCommand = command;
        hasCommands = true;
        command = null;
        continue;
      }

      if (!_hasMoreNumbers()) return null;

      while (_hasMoreNumbers()) {
        final isRel = command == command!.toLowerCase();
        switch (command) {
          case 'M':
          case 'm':
            final x = _readNumber();
            final y = _readNumber();
            if (x == null || y == null) return null;
            curX = isRel ? curX + x : x;
            curY = isRel ? curY + y : y;
            startX = curX;
            startY = curY;
            path.moveTo(curX, curY);
            prevCommand = command;
            command = isRel ? 'l' : 'L';
            hasCommands = true;
          case 'L':
          case 'l':
            final x = _readNumber();
            final y = _readNumber();
            if (x == null || y == null) return null;
            curX = isRel ? curX + x : x;
            curY = isRel ? curY + y : y;
            path.lineTo(curX, curY);
            prevCommand = command;
            hasCommands = true;
          case 'H':
          case 'h':
            final x = _readNumber();
            if (x == null) return null;
            curX = isRel ? curX + x : x;
            path.lineTo(curX, curY);
            prevCommand = command;
            hasCommands = true;
          case 'V':
          case 'v':
            final y = _readNumber();
            if (y == null) return null;
            curY = isRel ? curY + y : y;
            path.lineTo(curX, curY);
            prevCommand = command;
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
              return null;
            }
            final ax1 = isRel ? curX + x1 : x1;
            final ay1 = isRel ? curY + y1 : y1;
            final ax2 = isRel ? curX + x2 : x2;
            final ay2 = isRel ? curY + y2 : y2;
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            path.cubicTo(ax1, ay1, ax2, ay2, ax, ay);
            lastCtrlX = ax2;
            lastCtrlY = ay2;
            curX = ax;
            curY = ay;
            prevCommand = command;
            hasCommands = true;
          case 'S':
          case 's':
            final x2 = _readNumber();
            final y2 = _readNumber();
            final x = _readNumber();
            final y = _readNumber();
            if (x2 == null || y2 == null || x == null || y == null) {
              return null;
            }
            final isPrevCubic =
                const {'C', 'c', 'S', 's'}.contains(prevCommand);
            final ax1 = isPrevCubic ? 2 * curX - lastCtrlX : curX;
            final ay1 = isPrevCubic ? 2 * curY - lastCtrlY : curY;
            final ax2 = isRel ? curX + x2 : x2;
            final ay2 = isRel ? curY + y2 : y2;
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            path.cubicTo(ax1, ay1, ax2, ay2, ax, ay);
            lastCtrlX = ax2;
            lastCtrlY = ay2;
            curX = ax;
            curY = ay;
            prevCommand = command;
            hasCommands = true;
          case 'Q':
          case 'q':
            final x1 = _readNumber();
            final y1 = _readNumber();
            final x = _readNumber();
            final y = _readNumber();
            if (x1 == null || y1 == null || x == null || y == null) {
              return null;
            }
            final ax1 = isRel ? curX + x1 : x1;
            final ay1 = isRel ? curY + y1 : y1;
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            path.quadraticBezierTo(ax1, ay1, ax, ay);
            lastCtrlX = ax1;
            lastCtrlY = ay1;
            curX = ax;
            curY = ay;
            prevCommand = command;
            hasCommands = true;
          case 'T':
          case 't':
            final x = _readNumber();
            final y = _readNumber();
            if (x == null || y == null) return null;
            final isPrevQuad = const {'Q', 'q', 'T', 't'}.contains(prevCommand);
            final ax1 = isPrevQuad ? 2 * curX - lastCtrlX : curX;
            final ay1 = isPrevQuad ? 2 * curY - lastCtrlY : curY;
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            path.quadraticBezierTo(ax1, ay1, ax, ay);
            lastCtrlX = ax1;
            lastCtrlY = ay1;
            curX = ax;
            curY = ay;
            prevCommand = command;
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
              return null;
            }
            final ax = isRel ? curX + x : x;
            final ay = isRel ? curY + y : y;
            path.arcToPoint(
              Offset(ax, ay),
              radius: Radius.elliptical(rx.abs(), ry.abs()),
              rotation: rot,
              largeArc: largeArc != 0,
              clockwise: sweep != 0,
            );
            curX = ax;
            curY = ay;
            prevCommand = command;
            hasCommands = true;
          default:
            return null;
        }
      }
    }

    return hasCommands ? path : null;
  }
}
