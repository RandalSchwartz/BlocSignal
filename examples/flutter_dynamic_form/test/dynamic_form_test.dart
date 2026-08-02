import 'package:flutter_dynamic_form_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DynamicFormBlocSignal', () {
    late DynamicFormBlocSignal bloc;

    setUp(() {
      bloc = DynamicFormBlocSignal();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state has empty models and trims', () {
      expect(bloc.stateValue.brand, isNull);
      expect(bloc.availableModels.value, isEmpty);
      expect(bloc.availableTrims.value, isEmpty);
      expect(bloc.isFormComplete.value, isFalse);
    });

    test('selecting brand updates available models', () {
      bloc.add(const BrandSelected('Toyota'));
      expect(bloc.stateValue.brand, equals('Toyota'));
      expect(bloc.availableModels.value,
          containsAll(['Camry', 'Corolla', 'RAV4']));
      expect(bloc.stateValue.model, isNull);
    });

    test('selecting model updates available trims', () {
      bloc.add(const BrandSelected('Toyota'));
      bloc.add(const ModelSelected('Camry'));
      expect(bloc.stateValue.model, equals('Camry'));
      expect(
          bloc.availableTrims.value, containsAll(['LE', 'SE', 'XLE', 'TRD']));
    });

    test('selecting trim completes form', () {
      bloc.add(const BrandSelected('Toyota'));
      bloc.add(const ModelSelected('Camry'));
      bloc.add(const TrimSelected('TRD'));
      expect(bloc.isFormComplete.value, isTrue);
    });

    test('changing brand clears model and trim', () {
      bloc.add(const BrandSelected('Toyota'));
      bloc.add(const ModelSelected('Camry'));
      bloc.add(const TrimSelected('TRD'));

      bloc.add(const BrandSelected('Tesla'));
      expect(bloc.stateValue.brand, equals('Tesla'));
      expect(bloc.stateValue.model, isNull);
      expect(bloc.stateValue.trim, isNull);
      expect(bloc.isFormComplete.value, isFalse);
    });
  });

  group('DynamicFormApp Widget Test', () {
    testWidgets('renders brand dropdown and submit button initially disabled',
        (widgetTester) async {
      await widgetTester.pumpWidget(const DynamicFormApp());
      expect(find.text('Vehicle Brand'), findsOneWidget);
      expect(find.text('Submit Selection'), findsOneWidget);
    });
  });
}
