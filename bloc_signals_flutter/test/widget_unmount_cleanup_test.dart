import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AsyncUnmountCubit extends CubitSignal<int> {
  AsyncUnmountCubit() : super(initialState: 0);

  Future<void> performSlowAsync() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!isClosed) {
      emit(stateValue + 1);
    }
  }
}

void main() {
  testWidgets(
    'BlocSignalProvider handles widget unmount midway through async operation',
    (tester) async {
      late AsyncUnmountCubit cubit;

      final widget = MaterialApp(
        home: BlocSignalProvider<AsyncUnmountCubit>(
          create: (context) => cubit = AsyncUnmountCubit(),
          child: BlocSignalBuilder<AsyncUnmountCubit, int>(
            builder: (context, count) {
              return Text('Count: $count');
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('Count: 0'), findsOneWidget);

      // Trigger async work
      final future = cubit.performSlowAsync();

      // Unmount widget tree before async finishes
      await tester.pumpWidget(const SizedBox());

      // Wait for async work to complete
      await tester.pump(const Duration(milliseconds: 60));
      await future;

      expect(cubit.isClosed, isTrue);
    },
  );
}
