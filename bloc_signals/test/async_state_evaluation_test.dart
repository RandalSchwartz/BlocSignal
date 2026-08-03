import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

// Async Data Repository
class AsyncDataRepository {
  AsyncDataRepository({this.shouldFail = false});

  final bool shouldFail;

  Future<String> fetchData(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (shouldFail) {
      throw Exception('Network error for $id');
    }
    return 'Data for $id';
  }
}

// Cubit handling AsyncState
class AsyncDataCubit extends CubitSignal<AsyncState<String>> {
  AsyncDataCubit(this.repository)
      : super(initialState: const AsyncLoading<String>());

  final AsyncDataRepository repository;

  Future<void> loadData(String id) async {
    emit(const AsyncLoading<String>());
    try {
      final result = await repository.fetchData(id);
      emit(AsyncData<String>(result));
    } catch (e, st) {
      emit(AsyncError<String>(e, st));
    }
  }
}

// Async Events for BlocSignal
sealed class AsyncFetchEvent {}

final class FetchUserEvent extends AsyncFetchEvent {
  FetchUserEvent(this.userId);
  final String userId;
}

// Bloc handling AsyncState with restartable transformer
class AsyncFetchBloc extends BlocSignal<AsyncFetchEvent, AsyncState<String>> {
  AsyncFetchBloc(this.repository)
      : super(initialState: const AsyncLoading<String>()) {
    on<FetchUserEvent>(
      (event, emit) async {
        emit(const AsyncLoading<String>());
        try {
          final data = await repository.fetchData(event.userId);
          emit(AsyncData<String>(data));
        } catch (e, st) {
          emit(AsyncError<String>(e, st));
        }
      },
      transformer: restartable(),
    );
  }

  final AsyncDataRepository repository;
}

void main() {
  group('AsyncState & Async Evaluation Testing', () {
    test('AsyncDataCubit transitions through Loading -> Data successfully',
        () async {
      final repository = AsyncDataRepository();
      final cubit = AsyncDataCubit(repository);

      expect(cubit.stateValue, isA<AsyncLoading<String>>());

      final loadFuture = cubit.loadData('123');
      expect(cubit.stateValue, isA<AsyncLoading<String>>());

      await loadFuture;

      expect(cubit.stateValue, isA<AsyncData<String>>());
      final dataState = cubit.stateValue as AsyncData<String>;
      expect(dataState.value, equals('Data for 123'));

      await cubit.close();
    });

    test('AsyncDataCubit transitions to AsyncError on repository failure',
        () async {
      final repository = AsyncDataRepository(shouldFail: true);
      final cubit = AsyncDataCubit(repository);

      await cubit.loadData('456');

      expect(cubit.stateValue, isA<AsyncError<String>>());
      final errorState = cubit.stateValue as AsyncError<String>;
      expect(errorState.error.toString(), contains('Network error for 456'));

      await cubit.close();
    });

    test('AsyncFetchBloc evaluates async events with restartable transformer',
        () async {
      final repository = AsyncDataRepository();
      final bloc = AsyncFetchBloc(repository);

      bloc.add(FetchUserEvent('user_1'));
      bloc.add(FetchUserEvent('user_2')); // Cancels user_1 request

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.stateValue, isA<AsyncData<String>>());
      final dataState = bloc.stateValue as AsyncData<String>;
      expect(dataState.value, equals('Data for user_2'));

      await bloc.close();
    });
  });
}
