import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Vehicle Data Catalog.
class VehicleData {
  static const Map<String, Map<String, List<String>>> data = {
    'Toyota': {
      'Camry': ['LE', 'SE', 'XLE', 'TRD'],
      'Corolla': ['L', 'LE', 'SE', 'Apex'],
      'RAV4': ['LE', 'XLE', 'Adventure', 'TRD Off-Road'],
    },
    'Tesla': {
      'Model 3': ['Rear-Wheel Drive', 'Long Range', 'Performance'],
      'Model Y': ['Long Range', 'Performance'],
      'Model S': ['Dual Motor', 'Plaid'],
    },
    'Ford': {
      'Mustang': ['EcoBoost', 'GT', 'Dark Horse'],
      'F-150': ['XL', 'XLT', 'Lariat', 'Raptor'],
    },
  };
}

/// Dynamic Form Selection State.
@immutable
class DynamicFormState {
  const DynamicFormState({
    this.brand,
    this.model,
    this.trim,
  });

  final String? brand;
  final String? model;
  final String? trim;

  DynamicFormState copyWith({
    Object? brand = _sentinel,
    Object? model = _sentinel,
    Object? trim = _sentinel,
  }) {
    return DynamicFormState(
      brand: brand == _sentinel ? this.brand : brand as String?,
      model: model == _sentinel ? this.model : model as String?,
      trim: trim == _sentinel ? this.trim : trim as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicFormState &&
          runtimeType == other.runtimeType &&
          brand == other.brand &&
          model == other.model &&
          trim == other.trim;

  @override
  int get hashCode => brand.hashCode ^ model.hashCode ^ trim.hashCode;
}

const Object _sentinel = Object();

/// Sealed class representing all dynamic form events.
sealed class DynamicFormEvent {
  const DynamicFormEvent();
}

final class BrandSelected extends DynamicFormEvent {
  const BrandSelected(this.brand);
  final String? brand;
}

final class ModelSelected extends DynamicFormEvent {
  const ModelSelected(this.model);
  final String? model;
}

final class TrimSelected extends DynamicFormEvent {
  const TrimSelected(this.trim);
  final String? trim;
}

final class FormReset extends DynamicFormEvent {
  const FormReset();
}

/// Instructive Example: [DynamicFormBlocSignal]
///
/// Demonstrates cascading dynamic form selections using `computed()` option derivations.
///
/// **Educational Key Takeaway**:
/// - As the user picks a vehicle brand, `availableModels` computes the valid options instantly.
/// - Selecting a model derives `availableTrims` and updates `isFormComplete` on the same frame.
class DynamicFormBlocSignal
    extends BlocSignal<DynamicFormEvent, DynamicFormState> {
  DynamicFormBlocSignal() : super(initialState: const DynamicFormState()) {
    on<BrandSelected>(_onBrandSelected);
    on<ModelSelected>(_onModelSelected);
    on<TrimSelected>(_onTrimSelected);
    on<FormReset>(_onReset);
  }

  /// Reactive computed list of available vehicle brand names.
  late final ReadonlySignal<List<String>> availableBrands =
      computed(() => VehicleData.data.keys.toList());

  /// Reactive computed list of available models for the currently selected brand.
  late final ReadonlySignal<List<String>> availableModels = computed(() {
    final brand = stateValue.brand;
    if (brand == null || !VehicleData.data.containsKey(brand)) return const [];
    return VehicleData.data[brand]!.keys.toList();
  });

  /// Reactive computed list of available trims for the currently selected brand and model.
  late final ReadonlySignal<List<String>> availableTrims = computed(() {
    final brand = stateValue.brand;
    final model = stateValue.model;
    if (brand == null || model == null) return const [];
    final models = VehicleData.data[brand];
    if (models == null || !models.containsKey(model)) return const [];
    return models[model]!;
  });

  /// Reactive computed boolean indicating whether all 3 dropdown selections are complete.
  late final ReadonlySignal<bool> isFormComplete = computed(() {
    final s = stateValue;
    return s.brand != null && s.model != null && s.trim != null;
  });

  void _onBrandSelected(
      BrandSelected event, void Function(DynamicFormState) emit) {
    emit(DynamicFormState(brand: event.brand));
  }

  void _onModelSelected(
      ModelSelected event, void Function(DynamicFormState) emit) {
    emit(stateValue.copyWith(model: event.model, trim: null));
  }

  void _onTrimSelected(
      TrimSelected event, void Function(DynamicFormState) emit) {
    emit(stateValue.copyWith(trim: event.trim));
  }

  void _onReset(FormReset event, void Function(DynamicFormState) emit) {
    emit(const DynamicFormState());
  }
}

void main() {
  runApp(const DynamicFormApp());
}

class DynamicFormApp extends StatelessWidget {
  const DynamicFormApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dynamic Form',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<DynamicFormBlocSignal>(
        create: (_) => DynamicFormBlocSignal(),
        child: const DynamicFormPage(),
      ),
    );
  }
}

class DynamicFormPage extends StatelessWidget {
  const DynamicFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DynamicFormBlocSignal>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Form Selection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => bloc.add(const FormReset()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand Selection Dropdown
            BlocSignalBuilder<DynamicFormBlocSignal, DynamicFormState>(
              builder: (context, state) {
                final brands = bloc.availableBrands.value;
                final selectedBrand = state.brand;
                return DropdownButtonFormField<String>(
                  initialValue: selectedBrand,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Brand',
                    border: OutlineInputBorder(),
                  ),
                  items: brands
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (val) => bloc.add(BrandSelected(val)),
                );
              },
            ),
            const SizedBox(height: 16),

            // Model Selection Dropdown
            BlocSignalBuilder<DynamicFormBlocSignal, DynamicFormState>(
              builder: (context, state) {
                final models = bloc.availableModels.value;
                final selectedModel = state.model;
                return DropdownButtonFormField<String>(
                  initialValue: selectedModel,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Model',
                    border: const OutlineInputBorder(),
                    enabled: models.isNotEmpty,
                  ),
                  items: models
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: models.isNotEmpty
                      ? (val) => bloc.add(ModelSelected(val))
                      : null,
                );
              },
            ),
            const SizedBox(height: 16),

            // Trim Selection Dropdown
            BlocSignalBuilder<DynamicFormBlocSignal, DynamicFormState>(
              builder: (context, state) {
                final trims = bloc.availableTrims.value;
                final selectedTrim = state.trim;
                return DropdownButtonFormField<String>(
                  initialValue: selectedTrim,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Trim',
                    border: const OutlineInputBorder(),
                    enabled: trims.isNotEmpty,
                  ),
                  items: trims
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: trims.isNotEmpty
                      ? (val) => bloc.add(TrimSelected(val))
                      : null,
                );
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            BlocSignalBuilder<DynamicFormBlocSignal, DynamicFormState>(
              builder: (context, state) {
                final isComplete = bloc.isFormComplete.value;
                return ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Submit Selection'),
                  onPressed: isComplete
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Selected: ${state.brand} ${state.model} (${state.trim})'),
                            ),
                          );
                        }
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
