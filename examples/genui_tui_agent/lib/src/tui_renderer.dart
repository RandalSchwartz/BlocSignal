import 'package:bloc_signals_genui/bloc_signals_genui.dart';

/// ANSI terminal renderer that formats A2UI component trees into
/// visual terminal boxes matching `agy-cli` styling.
class TuiRenderer {
  /// Formats an [A2uiSurfaceState] into an ANSI terminal representation.
  static String renderState(A2uiSurfaceState state) {
    return switch (state) {
      SurfaceInitial() => _renderInitial(),
      SurfaceStreaming(:final surfaceId, :final messageCount) =>
        _renderStreaming(surfaceId, messageCount),
      SurfaceReady(:final surfaceId, :final surface, :final formValues) =>
        _renderSurface(surfaceId, surface, formValues),
      SurfaceSubmitting(:final surfaceId, :final actionName) =>
        _renderSubmitting(surfaceId, actionName),
      SurfaceError(:final error, :final surfaceId) => _renderError(
        error,
        surfaceId,
      ),
    };
  }

  static String _renderInitial() {
    return '''
\x1B[1;36m┌────────────────────────────────────────────────────────────┐
│                    A2UI Terminal Client                    │
│             Awaiting Generative UI stream...               │
└────────────────────────────────────────────────────────────┘\x1B[0m
''';
  }

  static String _renderStreaming(String? surfaceId, int count) {
    return '''
\x1B[1;33m┌────────────────────────────────────────────────────────────┐
│ [STREAMING] Processing A2UI chunk stream...                │
│ Surface ID: ${surfaceId ?? 'Initializing...'}
│ Messages Received: $count                                   │
└────────────────────────────────────────────────────────────┘\x1B[0m
''';
  }

  static String _renderSubmitting(String surfaceId, String action) {
    return '''
\x1B[1;35m┌────────────────────────────────────────────────────────────┐
│ [SUBMITTING] Dispatching client tool response...           │
│ Surface ID: $surfaceId                                      │
│ Action: $action                                            │
└────────────────────────────────────────────────────────────┘\x1B[0m
''';
  }

  static String _renderError(Object error, String? surfaceId) {
    return '''
\x1B[1;31m┌────────────────────────────────────────────────────────────┐
│ [ERROR] Surface Exception Encountered                      │
│ Surface: ${surfaceId ?? 'unknown'}
│ Message: $error
└────────────────────────────────────────────────────────────┘\x1B[0m
''';
  }

  static String _renderSurface(
    String surfaceId,
    SurfaceModel<ComponentApi> surface,
    Map<String, dynamic> formValues,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      '\x1B[1;32m┌── Surface: $surfaceId ────────────────────────────────────┐\x1B[0m',
    );

    final components = surface.componentsModel.all.toList();
    if (components.isEmpty) {
      buffer.writeln(
        '│  (Empty surface hierarchy)                                 │',
      );
    } else {
      for (final comp in components) {
        final rendered = _renderComponent(comp, formValues, surface: surface);
        for (final line in rendered) {
          buffer.writeln('│  $line');
        }
      }
    }

    if (formValues.isNotEmpty) {
      buffer.writeln(
        '\x1B[1;34m├─ Form Model ──────────────────────────────────────────────┤\x1B[0m',
      );
      formValues.forEach((key, value) {
        buffer.writeln('│  • \x1B[33m$key\x1B[0m: $value');
      });
    }

    buffer.writeln(
      '\x1B[1;32m└───────────────────────────────────────────────────────────┘\x1B[0m',
    );
    return buffer.toString();
  }

  static Object? _resolveProp(
    Object? rawVal,
    Map<String, dynamic> formValues,
    SurfaceModel<ComponentApi>? surface,
  ) {
    if (rawVal is Map &&
        (rawVal.containsKey('path') || rawVal.containsKey('@path'))) {
      final path = (rawVal['path'] ?? rawVal['@path'])?.toString() ?? '';
      if (path.isNotEmpty) {
        if (surface != null) {
          final modelVal = surface.dataModel.get(path);
          if (modelVal != null) return modelVal;
        }
        final cleanKey = path.startsWith('/') ? path.substring(1) : path;
        if (formValues.containsKey(path)) return formValues[path];
        if (formValues.containsKey(cleanKey)) return formValues[cleanKey];
      }
      return null;
    }
    return rawVal;
  }

  static List<String> _renderComponent(
    ComponentModel comp,
    Map<String, dynamic> formValues, {
    SurfaceModel<ComponentApi>? surface,
  }) {
    final props = comp.properties;
    switch (comp.type) {
      case 'Text':
        final text = _resolveProp(props['text'], formValues, surface) ?? '';
        final variant = props['variant'] ?? 'body';
        if (variant == 'h1' || variant == 'h2') {
          return ['\x1B[1;37m### $text\x1B[0m'];
        }
        return ['$text'];
      case 'Button':
        final action = props['action'];
        var actionName = 'submit';
        if (action is Map) {
          final eventMap = action['event'];
          if (eventMap is Map && eventMap['name'] != null) {
            actionName = eventMap['name'].toString();
          } else if (action['name'] != null) {
            actionName = action['name'].toString();
          }
        } else if (action is String) {
          actionName = action;
        }
        return ['[\x1B[1;32m 🔘 Action: $actionName \x1B[0m]'];
      case 'TextField':
        final label = props['label'] ?? 'Input';
        final currentVal = _resolveProp(props['value'], formValues, surface);
        final valSuffix = currentVal != null ? ': $currentVal' : '';
        return ['[\x1B[1;36m ✏️  $label$valSuffix \x1B[0m]'];
      case 'CheckBox':
        final label = props['label'] ?? 'CheckBox';
        final rawVal = _resolveProp(props['value'], formValues, surface);
        final checked = rawVal == true || rawVal?.toString() == 'true';
        final mark = checked ? '[x]' : '[ ]';
        return ['[\x1B[1;32m $mark $label \x1B[0m]'];
      case 'ChoicePicker':
        final label = props['label'] ?? 'ChoicePicker';
        final rawVal = _resolveProp(props['value'], formValues, surface);
        final selectedStr = rawVal is Iterable
            ? rawVal.join(', ')
            : (rawVal?.toString() ?? '');
        final suffix = selectedStr.isNotEmpty ? ' ($selectedStr)' : '';
        return ['[\x1B[1;35m 🎯 ChoicePicker: $label$suffix \x1B[0m]'];
      case 'Slider':
        final label = props['label'] ?? 'Slider';
        final val = _resolveProp(props['value'], formValues, surface) ?? 0;
        final min = props['min'] ?? 0;
        final max = props['max'] ?? 100;
        return ['[\x1B[1;33m 🎚️  $label: $val ($min..$max) \x1B[0m]'];
      case 'DateTimeInput':
        final label = props['label'] ?? 'Date';
        final val = _resolveProp(props['value'], formValues, surface) ?? '';
        return ['[\x1B[1;36m 📅 $label: $val \x1B[0m]'];
      case 'Icon':
        final rawName = props['name'] ?? props['icon'] ?? 'icon';
        final name = rawName is Map
            ? (rawName['name'] ?? rawName['svgPath'] ?? 'icon')
            : rawName;
        return ['[\x1B[1;34m 🔹 Icon: $name \x1B[0m]'];
      case 'Image':
        final desc = props['description'] ?? 'Image';
        final url = props['url'] ?? '';
        return ['[\x1B[1;34m 🖼️  Image: $desc ($url) \x1B[0m]'];
      case 'Video':
        final url = props['url'] ?? '';
        return ['[\x1B[1;34m 🎬 Video: $url \x1B[0m]'];
      case 'AudioPlayer':
        final desc = props['description'] ?? 'Audio';
        final url = props['url'] ?? '';
        return ['[\x1B[1;34m 🔊 AudioPlayer: $desc ($url) \x1B[0m]'];
      case 'Card':
        return ['\x1B[2m[Card]\x1B[0m'];
      case 'Divider':
        return ['\x1B[2m────────────────────────────────────────\x1B[0m'];
      case 'List':
        final direction = props['direction'] ?? props['axis'] ?? 'vertical';
        final children = props['children'];
        if (children is Map && children.containsKey('path')) {
          final path = children['path']?.toString() ?? '';
          final tplId = children['componentId']?.toString() ?? '';
          return [
            '\x1B[2m[List ($direction, template: $tplId @ $path)]\x1B[0m',
          ];
        }
        return ['\x1B[2m[List ($direction)]\x1B[0m'];
      case 'Tabs':
        final rawTabs = props['tabs'] ?? props['tabItems'];
        final titles = <String>[];
        if (rawTabs is Iterable) {
          for (final item in rawTabs) {
            if (item is Map && item['title'] != null) {
              titles.add(item['title'].toString());
            }
          }
        }
        final joined = titles.isEmpty ? 'Tabs' : titles.join(' | ');
        return ['[\x1B[1;36m 🗂️  Tabs: $joined \x1B[0m]'];
      case 'Modal':
        final trigger = props['trigger'] ?? props['entryPointChild'] ?? '';
        return ['\x1B[2m[Modal (trigger: $trigger)]\x1B[0m'];
      case 'Column':
        return ['\x1B[2m[Column Layout]\x1B[0m'];
      case 'Row':
        return ['\x1B[2m[Row Layout]\x1B[0m'];
      default:
        return ['[Component: ${comp.type} (id: ${comp.id})]'];
    }
  }
}
