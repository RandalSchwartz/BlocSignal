import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginBloc Unit Tests', () {
    late LoginBloc loginBloc;

    setUp(() {
      loginBloc = LoginBloc();
    });

    tearDown(() {
      loginBloc.close();
    });

    test('initial state has empty credentials and is not logged in', () {
      expect(loginBloc.stateValue.username, isEmpty);
      expect(loginBloc.stateValue.password, isEmpty);
      expect(loginBloc.stateValue.isLoading, isFalse);
      expect(loginBloc.stateValue.isLoggedIn, isFalse);
      expect(loginBloc.stateValue.error, null);
    });

    test('UsernameChanged updates username in state', () {
      loginBloc.add(UsernameChanged('alice'));
      expect(loginBloc.stateValue.username, 'alice');
    });

    test('PasswordChanged updates password in state', () {
      loginBloc.add(PasswordChanged('secret'));
      expect(loginBloc.stateValue.password, 'secret');
    });

    test('SubmitLogin with empty username sets error', () async {
      loginBloc.add(SubmitLogin());
      expect(loginBloc.stateValue.error, 'Username cannot be empty');
    });

    test('SubmitLogin with short password sets error', () async {
      loginBloc.add(UsernameChanged('alice'));
      loginBloc.add(PasswordChanged('123'));
      loginBloc.add(SubmitLogin());
      expect(
        loginBloc.stateValue.error,
        'Password must be at least 4 characters',
      );
    });

    test('SubmitLogin with incorrect password sets error', () async {
      loginBloc.add(UsernameChanged('alice'));
      loginBloc.add(PasswordChanged('wrongpass'));
      loginBloc.add(SubmitLogin());
      expect(loginBloc.stateValue.isLoading, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(loginBloc.stateValue.isLoading, isFalse);
      expect(loginBloc.stateValue.isLoggedIn, isFalse);
      expect(
        loginBloc.stateValue.error,
        'Incorrect password! (Hint: use "password")',
      );
    });

    test('SubmitLogin with correct password logs in successfully', () async {
      loginBloc.add(UsernameChanged('alice'));
      loginBloc.add(PasswordChanged('password'));
      loginBloc.add(SubmitLogin());
      expect(loginBloc.stateValue.isLoading, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(loginBloc.stateValue.isLoading, isFalse);
      expect(loginBloc.stateValue.isLoggedIn, isTrue);
      expect(loginBloc.stateValue.error, null);
    });

    test('Logout resets state to initial', () async {
      loginBloc.add(UsernameChanged('alice'));
      loginBloc.add(PasswordChanged('password'));
      loginBloc.add(SubmitLogin());
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(loginBloc.stateValue.isLoggedIn, isTrue);

      loginBloc.add(Logout());
      expect(loginBloc.stateValue.username, isEmpty);
      expect(loginBloc.stateValue.password, isEmpty);
      expect(loginBloc.stateValue.isLoggedIn, isFalse);
    });
  });

  group('TimerBloc Unit Tests', () {
    late TimerBloc timerBloc;

    setUp(() {
      timerBloc = TimerBloc(ticker: const Ticker());
    });

    tearDown(() {
      timerBloc.close();
    });

    test('initial state is TimerInitial with duration 60', () {
      expect(timerBloc.stateValue, isA<TimerInitial>());
      expect(timerBloc.stateValue.duration, 60);
    });

    test('TimerStarted transitions to TimerRunInProgress', () {
      timerBloc.add(TimerStarted(duration: 10));
      expect(timerBloc.stateValue, isA<TimerRunInProgress>());
      expect(timerBloc.stateValue.duration, 10);
    });

    test('TimerPaused transitions from TimerRunInProgress to TimerRunPause',
        () {
      timerBloc.add(TimerStarted(duration: 10));
      timerBloc.add(TimerPaused());
      expect(timerBloc.stateValue, isA<TimerRunPause>());
      expect(timerBloc.stateValue.duration, 10);
    });

    test('TimerResumed transitions from TimerRunPause to TimerRunInProgress',
        () {
      timerBloc.add(TimerStarted(duration: 10));
      timerBloc.add(TimerPaused());
      timerBloc.add(TimerResumed());
      expect(timerBloc.stateValue, isA<TimerRunInProgress>());
      expect(timerBloc.stateValue.duration, 10);
    });

    test('TimerReset resets to TimerInitial', () {
      timerBloc.add(TimerStarted(duration: 10));
      timerBloc.add(TimerReset());
      expect(timerBloc.stateValue, isA<TimerInitial>());
      expect(timerBloc.stateValue.duration, 60);
    });
  });
}
