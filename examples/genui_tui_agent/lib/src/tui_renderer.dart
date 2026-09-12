import 'package:a2ui_core/a2ui_core.dart';
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
        final rendered = _renderComponent(comp, formValues);
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

  static List<String> _renderComponent(
    ComponentModel comp,
    Map<String, dynamic> formValues,
  ) {
    switch (comp.type) {
      case 'Text':
        final text = comp.properties['text'] ?? '';
        final variant = comp.properties['variant'] ?? 'body';
        if (variant == 'h1' || variant == 'h2') {
          return ['\x1B[1;37m### $text\x1B[0m'];
        }
        return ['$text'];
      case 'Button':
        final action = comp.properties['action'] as Map<String, dynamic>?;
        final actionName = action?['name'] ?? 'submit';
        return ['[\x1B[1;32m 🔘 Action: $actionName \x1B[0m]'];
      case 'TextField':
        final label = comp.properties['label'] ?? 'Input';
        return ['[\x1B[1;36m ✏️  $label \x1B[0m]'];
      case 'Column':
        return ['\x1B[2m[Column Layout]\x1B[0m'];
      case 'Row':
        return ['\x1B[2m[Row Layout]\x1B[0m'];
      default:
        return ['[Component: ${comp.type} (id: ${comp.id})]'];
    }
  }
}
