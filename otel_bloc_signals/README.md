# otel_bloc_signals

OpenTelemetry tracing instrumentation for `BlocSignal` state containers.

This package provides a custom `BlocSignalObserver` that maps BLoC events, transitions, and errors into OpenTelemetry spans for end-to-end distributed tracing.

---

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  otel_bloc_signals: ^0.1.0
```

---

## Usage

Register the `OtelBlocSignalObserver` globally:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:otel_bloc_signals/otel_bloc_signals.dart';
import 'package:opentelemetry/api.dart' as otel;

void main() {
  // Setup your OpenTelemetry tracer provider...
  final tracer = otel.globalTracerProvider.getTracer('my_app');

  // Register the observer
  BlocSignalObserver.observer = OtelBlocSignalObserver(tracer: tracer);
}
```

---

## AI Coding Assistant Skills

This repository includes a pre-packaged [AI Coding Skill](https://context7.com/skills) representing all the best practices, lifecycle structures, and FAQs for using `BlocSignal`. If you develop with AI code assistants (like Gemini, Claude Code, or Cursor), you can install this skill globally or locally to guide your assistant's code generation:

```bash
npx ctx7@latest skills install RandalSchwartz/BlocSignal bloc-signals
```

