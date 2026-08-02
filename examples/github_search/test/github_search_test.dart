import 'package:flutter_test/flutter_test.dart';
import 'package:github_search_example/main.dart';

void main() {
  group('GithubSearchBlocSignal', () {
    late GithubSearchBlocSignal bloc;

    setUp(() {
      bloc = GithubSearchBlocSignal();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is SearchEmpty', () {
      expect(bloc.stateValue, isA<SearchEmpty>());
    });

    test('SearchQueryChanged empty string emits SearchEmpty', () async {
      bloc.add(const SearchQueryChanged(''));
      expect(bloc.stateValue, isA<SearchEmpty>());
    });

    test('SearchQueryChanged fetches matching repositories', () async {
      bloc.add(const SearchQueryChanged('bloc'));
      await Future.delayed(const Duration(milliseconds: 400));
      expect(bloc.stateValue, isA<SearchSuccess>());
      final s = bloc.stateValue as SearchSuccess;
      expect(s.items.length, greaterThanOrEqualTo(1));
    });

    test('SearchQueryChanged error query emits SearchError', () async {
      bloc.add(const SearchQueryChanged('error'));
      await Future.delayed(const Duration(milliseconds: 400));
      expect(bloc.stateValue, isA<SearchError>());
    });
  });

  group('GithubSearchApp Widget Test', () {
    testWidgets('renders search textfield and empty placeholder',
        (widgetTester) async {
      await widgetTester.pumpWidget(const GithubSearchApp());
      expect(find.text('Search Repositories'), findsOneWidget);
      expect(find.text('Type a query to search GitHub.'), findsOneWidget);
    });
  });
}
