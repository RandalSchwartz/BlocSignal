import 'package:flutter_form_validation_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormValidationBlocSignal', () {
    late FormValidationBlocSignal bloc;

    setUp(() {
      bloc = FormValidationBlocSignal();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is invalid with no errors', () {
      expect(bloc.emailError.value, isNull);
      expect(bloc.passwordError.value, isNull);
      expect(bloc.isValid.value, isFalse);
    });

    test('invalid email returns error', () {
      bloc.add(const EmailChanged('invalid-email'));
      expect(
          bloc.emailError.value, equals('Please enter a valid email address'));
      expect(bloc.isValid.value, isFalse);
    });

    test('short password returns error', () {
      bloc.add(const PasswordChanged('123'));
      expect(bloc.passwordError.value,
          equals('Password must be at least 6 characters long'));
      expect(bloc.isValid.value, isFalse);
    });

    test('valid email and password enables isValid', () {
      bloc.add(const EmailChanged('user@test.com'));
      bloc.add(const PasswordChanged('secret123'));

      expect(bloc.emailError.value, isNull);
      expect(bloc.passwordError.value, isNull);
      expect(bloc.isValid.value, isTrue);
    });

    test('FormSubmitted updates isSuccess', () async {
      bloc.add(const EmailChanged('user@test.com'));
      bloc.add(const PasswordChanged('secret123'));
      bloc.add(const FormSubmitted());

      await Future.delayed(const Duration(milliseconds: 600));
      expect(bloc.stateValue.isSuccess, isTrue);
    });
  });

  group('FormValidationApp Widget Test', () {
    testWidgets('renders input fields and submit button', (widgetTester) async {
      await widgetTester.pumpWidget(const FormValidationApp());
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });
  });
}
