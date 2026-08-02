/// # Colorband Example — Dynamic Signal Derivations with CubitSignal
///
/// This example demonstrates how [CubitSignal] manages dynamic UI state derivations
/// (RGB color sliders, HSL transformations, complementary color computations).
///
/// In standard Flutter, updating RGB sliders causes full widget subtree rebuilds.
/// With `BlocSignal`, state changes propagate synchronously and de-duplicate identical colors,
/// keeping rendering smooth and performant.
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

// =============================================================================
// 1. Color State Model
// =============================================================================

/// Immutable state model representing RGBA values and derived color properties.
///
/// Note: This state class could also use `package:equatable` (extending `Equatable` with `props`) for concise equality.
@immutable
class ColorState {
  const ColorState({
    required this.red,
    required this.green,
    required this.blue,
  });

  final int red;
  final int green;
  final int blue;

  Color get color => Color.fromRGBO(red, green, blue, 1.0);
  Color get complementary =>
      Color.fromRGBO(255 - red, 255 - green, 255 - blue, 1.0);

  ColorState copyWith({int? red, int? green, int? blue}) {
    return ColorState(
      red: red ?? this.red,
      green: green ?? this.green,
      blue: blue ?? this.blue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorState &&
          runtimeType == other.runtimeType &&
          red == other.red &&
          green == other.green &&
          blue == other.blue;

  @override
  int get hashCode => Object.hash(red, green, blue);
}

// =============================================================================
// 2. ColorCubit Implementation
// =============================================================================

/// Manages interactive color channel states.
class ColorCubit extends CubitSignal<ColorState> {
  ColorCubit()
      : super(initialState: const ColorState(red: 106, green: 27, blue: 154));

  void updateRed(double value) => emit(stateValue.copyWith(red: value.round()));
  void updateGreen(double value) =>
      emit(stateValue.copyWith(green: value.round()));
  void updateBlue(double value) =>
      emit(stateValue.copyWith(blue: value.round()));
  void reset() => emit(const ColorState(red: 106, green: 27, blue: 154));
}

// =============================================================================
// 3. Application Entrypoint & UI Layout
// =============================================================================

void main() {
  runApp(const ColorbandApp());
}

/// Root application widget.
class ColorbandApp extends StatelessWidget {
  const ColorbandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<ColorCubit>(
      lazy: false,
      create: (context) => ColorCubit(),
      child: MaterialApp(
        title: 'BlocSignal Colorband',
        theme: ThemeData(useMaterial3: true),
        home: const ColorbandHomePage(),
      ),
    );
  }
}

/// Main colorband page with live color preview and channel sliders.
class ColorbandHomePage extends StatelessWidget {
  const ColorbandHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Colorband Signals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ColorCubit>().reset(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Color Banner
          Expanded(
            child: BlocSignalBuilder<ColorCubit, ColorState>(
              builder: (context, state) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  color: state.color,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: state.complementary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${state.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                        style: TextStyle(
                          color: state.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Channel Sliders
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _ChannelSlider(
                  label: 'Red',
                  color: Colors.red,
                  selector: (state) => state.red,
                  onChanged: (val) => context.read<ColorCubit>().updateRed(val),
                ),
                _ChannelSlider(
                  label: 'Green',
                  color: Colors.green,
                  selector: (state) => state.green,
                  onChanged: (val) =>
                      context.read<ColorCubit>().updateGreen(val),
                ),
                _ChannelSlider(
                  label: 'Blue',
                  color: Colors.blue,
                  selector: (state) => state.blue,
                  onChanged: (val) =>
                      context.read<ColorCubit>().updateBlue(val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.color,
    required this.selector,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final int Function(ColorState state) selector;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return BlocSignalSelector<ColorCubit, ColorState, int>(
      selector: selector,
      builder: (context, channelValue) {
        return Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Slider(
                value: channelValue.toDouble(),
                min: 0,
                max: 255,
                activeColor: color,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$channelValue',
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      },
    );
  }
}
