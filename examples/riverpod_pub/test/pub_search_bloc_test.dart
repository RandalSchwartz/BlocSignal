import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_pub_example/blocs/pub_search_bloc.dart';
import 'package:riverpod_pub_example/services/pub_repository.dart';

void main() {
  group('PubSearchBloc (Riverpod Port)', () {
    late PubSearchBloc bloc;

    setUp(() {
      bloc = PubSearchBloc(repository: PubRepository());
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is PubSearchInitial', () {
      expect(bloc.stateValue, isA<PubSearchInitial>());
    });

    test('SearchQueryChanged empty string emits PubSearchInitial', () async {
      bloc.add(const SearchQueryChanged(''));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.stateValue, isA<PubSearchInitial>());
    });

    test('SearchQueryChanged non-empty emits loading then success', () async {
      bloc.add(const SearchQueryChanged('signal'));
      expect(bloc.stateValue, isA<PubSearchLoading>());

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.stateValue, isA<PubSearchSuccess>());
      final successState = bloc.stateValue as PubSearchSuccess;
      expect(
          successState.packages.any((p) => p.name.contains('signal')), isTrue);
    });
  });
}
