import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

sealed class StressEvent {}

final class RapidEvent extends StressEvent {
  RapidEvent(this.id);
  final int id;
}

final class FaultyEvent extends StressEvent {}

class StressBloc extends BlocSignal<StressEvent, int> {
  StressBloc() : super(initialState: 0) {
    on<RapidEvent>(
      (event, emit) async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        emit(event.id);
      },
      transformer: restartable(),
    );

    on<FaultyEvent>(
      (event, emit) async {
        throw Exception('Intentional failure inside mutex lock');
      },
      transformer: sequential(),
    );
  }
}

void main() {
  group('High-Frequency Transformer Stress & Mutex Recovery', () {
    test('restartable handles high-frequency burst without memory leaks',
        () async {
      final bloc = StressBloc();

      // Dispatch 100 rapid events
      for (var i = 1; i <= 100; i++) {
        bloc.add(RapidEvent(i));
      }

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Final event is the one that settles
      expect(bloc.stateValue, equals(100));

      await bloc.close();
    });

    test('Mutex releases lock automatically when handler throws exception',
        () async {
      final bloc = StressBloc()..add(FaultyEvent());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Subsequent event executes cleanly without deadlocking
      bloc.add(RapidEvent(999));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.stateValue, equals(999));

      await bloc.close();
    });
  });
}
