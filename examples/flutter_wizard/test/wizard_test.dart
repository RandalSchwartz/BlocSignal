import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wizard_example/main.dart';

void main() {
  group('WizardBlocSignal', () {
    late WizardBlocSignal bloc;

    setUp(() {
      bloc = WizardBlocSignal();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is invalid for step 1 and step 2', () {
      expect(bloc.isStep1Valid.value, isFalse);
      expect(bloc.isStep2Valid.value, isFalse);
      expect(bloc.canSubmit.value, isFalse);
    });

    test('valid account info makes step 1 valid', () {
      bloc.add(const AccountInfoUpdated(
          username: 'merlyn', email: 'merlyn@example.com'));
      expect(bloc.isStep1Valid.value, isTrue);
      expect(bloc.isStep2Valid.value, isFalse);
    });

    test('valid profile info makes step 2 valid and enables submit', () {
      bloc.add(const AccountInfoUpdated(
          username: 'merlyn', email: 'merlyn@example.com'));
      bloc.add(const ProfileInfoUpdated(
          fullName: 'Merlyn', bio: 'Software Developer'));
      expect(bloc.isStep2Valid.value, isTrue);
      expect(bloc.canSubmit.value, isTrue);
    });

    test('WizardSubmitted sets isSubmitted to true when valid', () {
      bloc.add(const AccountInfoUpdated(
          username: 'merlyn', email: 'merlyn@example.com'));
      bloc.add(const ProfileInfoUpdated(
          fullName: 'Merlyn', bio: 'Software Developer'));
      bloc.add(const WizardSubmitted());
      expect(bloc.stateValue.isSubmitted, isTrue);
    });
  });

  group('WizardApp Widget Test', () {
    testWidgets('renders wizard stepper', (widgetTester) async {
      await widgetTester.pumpWidget(const WizardApp());
      expect(find.text('Account Details'), findsOneWidget);
      expect(find.text('Personal Profile'), findsOneWidget);
    });
  });
}
