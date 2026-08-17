import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering form validation using computed signals.
class const DocsRecipeFormValidationPage({super.key})
    extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Reactive Forms', anchor: 'overview-forms'),
    TocHeading(title: 'Designing the Form Cubit', anchor: 'form-cubit'),
    TocHeading(
      title: 'Derived Validation with computed()',
      anchor: 'computed-validation',
    ),
    TocHeading(title: 'Flutter UI Integration', anchor: 'ui-integration'),
    TocHeading(
      title: 'Performance & Debouncing',
      anchor: 'performance-debouncing',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('🛠️ Architecture Recipes'),
        ]),
        h1([Component.text('Form Validation with Reactive Signals')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Build ultra-responsive, zero-boilerplate forms by separating raw user inputs from derived validation rules using computed() signals.',
          ),
        ]),
      ]),

      // 1. Overview & Reactive Forms
      section(id: 'overview-forms', classes: 'docs-section', [
        h2([Component.text('Overview & Reactive Forms')]),
        p([
          Component.text(
            'Traditional form validation in Flutter often mixes raw text values, error strings, and submission flags '
            'inside large state objects with complex copyWith() logic. With BlocSignal and computed() signals, '
            'validation rules are defined as pure functions of input signals, automatically recalculating with 0ms latency '
            'and memoizing results.',
          ),
        ]),
      ]),

      // 2. Designing the Form Cubit
      section(id: 'form-cubit', classes: 'docs-section', [
        h2([Component.text('Designing the Form Cubit')]),
        const DocsCodeBlock(
          title: 'lib/login_form_cubit.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';

class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.isSubmitting = false,
  });

  final String email;
  final String password;
  final bool isSubmitting;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? isSubmitting,
  }) => LoginFormState(
    email: email ?? this.email,
    password: password ?? this.password,
    isSubmitting: isSubmitting ?? this.isSubmitting,
  );
}

class LoginFormCubit extends CubitSignal<LoginFormState> {
  LoginFormCubit() : super(initialState: const LoginFormState()) {
    // Derived email validation error
    emailError = computed(() {
      final email = state.value.email;
      if (email.isEmpty) return null;
      if (!email.contains('@') || !email.contains('.')) {
        return 'Please enter a valid email address';
      }
      return null;
    });

    // Derived password validation error
    passwordError = computed(() {
      final password = state.value.password;
      if (password.isEmpty) return null;
      if (password.length < 8) {
        return 'Password must be at least 8 characters';
      }
      return null;
    });

    // Combined form validity signal
    isValid = computed(() {
      final s = state.value;
      return s.email.isNotEmpty &&
          s.password.isNotEmpty &&
          emailError.value == null &&
          passwordError.value == null;
    });
  }

  late final ReadonlySignal<String?> emailError;
  late final ReadonlySignal<String?> passwordError;
  late final ReadonlySignal<bool> isValid;

  void emailChanged(String email) => emit(stateValue.copyWith(email: email));
  void passwordChanged(String password) => emit(stateValue.copyWith(password: password));
}''',
        ),
      ]),

      // 3. Derived Validation with computed()
      section(id: 'computed-validation', classes: 'docs-section', [
        h2([Component.text('Derived Validation with computed()')]),
        p([
          Component.text(
            'Notice that emailError, passwordError, and isValid are not stored fields in LoginFormState. '
            'They are derived signals created via computed(). They track state.value automatically and only notify '
            'listeners when their evaluated validation result changes.',
          ),
        ]),
      ]),

      // 4. Flutter UI Integration
      section(id: 'ui-integration', classes: 'docs-section', [
        h2([Component.text('Flutter UI Integration')]),
        const DocsCodeBlock(
          title: 'lib/login_form_view.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

class LoginFormView extends StatelessWidget {
  const LoginFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<LoginFormCubit>();

    return Column(
      children: [
        TextField(
          onChanged: cubit.emailChanged,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: cubit.emailError.value,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: true,
          onChanged: cubit.passwordChanged,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: cubit.passwordError.value,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: cubit.isValid.value ? () => _submit(context) : null,
          child: const Text('Log In'),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    // Handle submission logic
  }
}''',
        ),
      ]),

      // 5. Performance & Debouncing
      section(id: 'performance-debouncing', classes: 'docs-section', [
        h2([Component.text('Performance & Debouncing')]),
        p([
          Component.text(
            'Because computed signals automatically de-duplicate equal outputs, typing in the password field will never '
            're-evaluate or rebuild the email error widget unless the email validation state actually changes.',
          ),
        ]),
      ]),
    ]);
  }
}
