import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// A CounterCubit for the Jaspr web example.
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}

/// Root Jaspr web component providing CounterCubit.
class CounterApp extends StatelessComponent {
  const CounterApp({super.key});

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider(
      create: (context) => CounterCubit(),
      child: const CounterView(),
    );
  }
}

/// View component consuming CounterCubit via BlocSignalBuilder.
class CounterView extends StatelessComponent {
  const CounterView({super.key});

  @override
  Component build(BuildContext context) {
    return div([
      BlocSignalBuilder<CounterCubit, int>(
        builder: (context, count) {
          return h1([Component.text('Count: $count')]);
        },
      ),
      button(
        onClick: () => context.read<CounterCubit>().increment(),
        [Component.text('Increment')],
      ),
    ]);
  }
}
