import 'package:flutter_complex_list_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComplexListBlocSignal', () {
    late ComplexListBlocSignal bloc;

    setUp(() {
      bloc = ComplexListBlocSignal(
        initialItems: const [
          Item(id: '1', value: 'Item Alpha'),
          Item(id: '2', value: 'Item Beta'),
        ],
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state and computed properties work', () {
      expect(bloc.stateValue.items.length, equals(2));
      expect(bloc.selectedCount.value, equals(0));
      expect(bloc.isAllSelected.value, isFalse);
    });

    test('ItemToggled toggles selection', () {
      bloc.add(const ItemToggled('1'));
      expect(bloc.selectedCount.value, equals(1));
      expect(bloc.isAllSelected.value, isFalse);
    });

    test('SelectAllToggled selects all items', () {
      bloc.add(const SelectAllToggled());
      expect(bloc.selectedCount.value, equals(2));
      expect(bloc.isAllSelected.value, isTrue);
    });

    test('BatchDeleted removes selected items', () {
      bloc.add(const ItemToggled('1'));
      bloc.add(const BatchDeleted());
      expect(bloc.stateValue.items.length, equals(1));
      expect(bloc.stateValue.items.first.id, equals('2'));
    });
  });

  group('ComplexListApp Widget Test', () {
    testWidgets('renders item list', (widgetTester) async {
      await widgetTester.pumpWidget(const ComplexListApp());
      expect(find.text('Item Alpha'), findsOneWidget);
      expect(find.text('Item Beta'), findsOneWidget);
    });
  });
}
