import 'dart:async';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

/// Sensor Data Model.
@immutable
class SensorReading {
  const SensorReading({required this.timestamp, required this.value});
  final DateTime timestamp;
  final double value;
}

/// Simulated external stream service.
class SensorStreamService {
  const SensorStreamService();

  Stream<double> createSensorStream() {
    return Stream.periodic(
      const Duration(milliseconds: 500),
      (i) => 20.0 + (i % 10) * 1.5,
    );
  }
}

/// Instructive Example: [SensorCubitSignal]
///
/// Demonstrates wrapping external Dart `Stream` sources into a `CubitSignal` container,
/// and exporting `BlocSignal` states back to external consumers using the `.toStream()` extension.
///
/// **Educational Key Takeaways**:
/// - **Ingesting Streams**: Listen to external streams in container constructors and call `emit()`.
/// - **Exporting Streams**: Use `cubit.toStream()` to produce a broadcast `Stream<State>` for legacyRx stream components.
class SensorCubitSignal extends CubitSignal<SensorReading> {
  SensorCubitSignal({SensorStreamService service = const SensorStreamService()})
      : super(
            initialState:
                SensorReading(timestamp: DateTime.now(), value: 0.0)) {
    _subscription = service.createSensorStream().listen((val) {
      emit(SensorReading(timestamp: DateTime.now(), value: val));
    });
  }

  StreamSubscription<double>? _subscription;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

void main() {
  runApp(const StreamInteropApp());
}

class StreamInteropApp extends StatelessWidget {
  const StreamInteropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlocSignal Stream Interop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<SensorCubitSignal>(
        create: (_) => SensorCubitSignal(),
        child: const StreamInteropPage(),
      ),
    );
  }
}

class StreamInteropPage extends StatefulWidget {
  const StreamInteropPage({super.key});

  @override
  State<StreamInteropPage> createState() => _StreamInteropPageState();
}

class _StreamInteropPageState extends State<StreamInteropPage> {
  StreamSubscription<SensorReading>? _streamSub;
  double _lastStreamVal = 0.0;

  @override
  void initState() {
    super.initState();
    // Educational API Note: Demonstrates cubit.toStream() extension directly on BlocSignalBase
    final cubit = context.read<SensorCubitSignal>();
    _streamSub = cubit.toStream().listen((reading) {
      if (mounted) {
        setState(() => _lastStreamVal = reading.value);
      }
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stream Interop Example')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Demonstrates wrapping external Dart streams into BlocSignal containers, and exporting BlocSignal states via .toStream() extension.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Reactive Signal View
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Reactive Signal View (BlocSignalBuilder)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    BlocSignalBuilder<SensorCubitSignal, SensorReading>(
                      builder: (context, state) {
                        return Text(
                          '${state.value.toStringAsFixed(1)} °C',
                          style: Theme.of(context).textTheme.displaySmall,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Broadcast Stream Listener View
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Broadcast Stream Consumer (.toStream())',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '${_lastStreamVal.toStringAsFixed(1)} °C',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
