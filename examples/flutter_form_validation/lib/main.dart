import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Form Validation State.
@immutable
class FormValidationState {
  const FormValidationState({
    this.email = '',
    this.password = '',
    this.isSubmitting = false,
    this.isSuccess = false,
  });

  final String email;
  final String password;
  final bool isSubmitting;
  final bool isSuccess;

  FormValidationState copyWith({
    String? email,
    String? password,
    bool? isSubmitting,
    bool? isSuccess,
  }) {
    return FormValidationState(
      email: email ?? this.email,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormValidationState &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          password == other.password &&
          isSubmitting == other.isSubmitting &&
          isSuccess == other.isSuccess;

  @override
  int get hashCode =>
      email.hashCode ^
      password.hashCode ^
      isSubmitting.hashCode ^
      isSuccess.hashCode;
}

/// Events.
sealed class FormValidationEvent {
  const FormValidationEvent();
}

final class EmailChanged extends FormValidationEvent {
  const EmailChanged(this.email);
  final String email;
}

final class PasswordChanged extends FormValidationEvent {
  const PasswordChanged(this.password);
  final String password;
}

final class FormSubmitted extends FormValidationEvent {
  const FormSubmitted();
}

final class FormReset extends FormValidationEvent {
  const FormReset();
}

/// [FormValidationBlocSignal] handles real-time input validation & submission.
class FormValidationBlocSignal
    extends BlocSignal<FormValidationEvent, FormValidationState> {
  FormValidationBlocSignal()
      : super(initialState: const FormValidationState()) {
    on<EmailChanged>(_onEmailChanged);
    on<PasswordChanged>(_onPasswordChanged);
    on<FormSubmitted>(_onSubmitted);
    on<FormReset>(_onReset);

    // Validation computed signals
    emailError = computed(() {
      final email = stateValue.email;
      if (email.isEmpty) return null;
      if (!email.contains('@') || !email.contains('.')) {
        return 'Please enter a valid email address';
      }
      return null;
    });

    passwordError = computed(() {
      final pass = stateValue.password;
      if (pass.isEmpty) return null;
      if (pass.length < 6) {
        return 'Password must be at least 6 characters long';
      }
      return null;
    });

    isValid = computed(() {
      final s = stateValue;
      return s.email.isNotEmpty &&
          s.password.isNotEmpty &&
          emailError.value == null &&
          passwordError.value == null;
    });
  }

  late final ReadonlySignal<String?> emailError;
  late final ReadonlySignal<String?> passwordError;
  late final ReadonlySignal<bool> isValid;

  void _onEmailChanged(
      EmailChanged event, void Function(FormValidationState) emit) {
    emit(stateValue.copyWith(email: event.email, isSuccess: false));
  }

  void _onPasswordChanged(
      PasswordChanged event, void Function(FormValidationState) emit) {
    emit(stateValue.copyWith(password: event.password, isSuccess: false));
  }

  Future<void> _onSubmitted(
      FormSubmitted event, void Function(FormValidationState) emit) async {
    if (!isValid.value) return;
    emit(stateValue.copyWith(isSubmitting: true));
    await Future.delayed(const Duration(milliseconds: 500));
    emit(stateValue.copyWith(isSubmitting: false, isSuccess: true));
  }

  void _onReset(FormReset event, void Function(FormValidationState) emit) {
    emit(const FormValidationState());
  }
}

void main() {
  runApp(const FormValidationApp());
}

class FormValidationApp extends StatelessWidget {
  const FormValidationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Form Validation',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<FormValidationBlocSignal>(
        create: (_) => FormValidationBlocSignal(),
        child: const FormValidationPage(),
      ),
    );
  }
}

class FormValidationPage extends StatelessWidget {
  const FormValidationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FormValidationBlocSignal>();
    return Scaffold(
      appBar: AppBar(title: const Text('Real-Time Form Validation')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Input
            BlocSignalBuilder<FormValidationBlocSignal, FormValidationState>(
              builder: (context, state) {
                return TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: bloc.emailError.value,
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (val) => bloc.add(EmailChanged(val)),
                );
              },
            ),
            const SizedBox(height: 16),

            // Password Input
            BlocSignalBuilder<FormValidationBlocSignal, FormValidationState>(
              builder: (context, state) {
                return TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: bloc.passwordError.value,
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) => bloc.add(PasswordChanged(val)),
                );
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            BlocSignalBuilder<FormValidationBlocSignal, FormValidationState>(
              builder: (context, state) {
                if (state.isSubmitting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Submit'),
                  onPressed: bloc.isValid.value
                      ? () => bloc.add(const FormSubmitted())
                      : null,
                );
              },
            ),
            const SizedBox(height: 16),

            // Success Indicator
            BlocSignalBuilder<FormValidationBlocSignal, FormValidationState>(
              builder: (context, state) {
                if (state.isSuccess) {
                  return const Card(
                    color: Colors.greenAccent,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Form submitted successfully!'),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
