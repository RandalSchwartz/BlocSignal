import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
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
    TocHeading(title: 'Scoped Provider Setup', anchor: 'provider-setup'),
    TocHeading(
      title: 'Fine-Grained Rebuilds with context.select',
      anchor: 'fine-grained-select',
    ),
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
          dart313Code: '''
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
      final email = stateValue.email;
      if (email.isEmpty) return null;
      if (!email.contains('@') || !email.contains('.')) {
        return 'Please enter a valid email address';
      }
      return null;
    });

    // Derived password validation error
    passwordError = computed(() {
      final password = stateValue.password;
      if (password.isEmpty) return null;
      if (password.length < 8) {
        return 'Password must be at least 8 characters';
      }
      return null;
    });

    // Combined form validity signal
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

  void emailChanged(String email) => emit(stateValue.copyWith(email: email));
  void passwordChanged(String password) => emit(stateValue.copyWith(password: password));
}''',
          dart35Code: '''
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
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class LoginFormCubit extends CubitSignal<LoginFormState> {
  LoginFormCubit() : super(initialState: const LoginFormState()) {
    emailError = computed(() {
      final email = stateValue.email;
      if (email.isEmpty) return null;
      if (!email.contains('@') || !email.contains('.')) {
        return 'Please enter a valid email address';
      }
      return null;
    });

    passwordError = computed(() {
      final password = stateValue.password;
      if (password.isEmpty) return null;
      if (password.length < 8) {
        return 'Password must be at least 8 characters';
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
            'They are derived signals created via computed(). They track stateValue automatically and only notify '
            'listeners when their evaluated validation result changes.',
          ),
        ]),
      ]),

      // 4. Flutter UI Integration
      section(id: 'ui-integration', classes: 'docs-section', [
        h2([Component.text('Flutter UI Integration')]),
        p([
          Component.text('In the UI layer, retrieve the cubit via '),
          apiLink(
            DocSymbol.contextRead,
            label: 'context.read<LoginFormCubit>()',
          ),
          Component.text(
            ' for calling methods in event handlers. To ensure the widget rebuilds reactively when input state updates, '
            'wrap the form in ',
          ),
          apiLink(DocSymbol.blocSignalBuilder),
          Component.text(':'),
        ]),
        DocsCallout(
          type: CalloutType.warning,
          title: 'context.watch vs. State-Driven Rebuilds',
          children: [
            p([
              Component.text('Do not use '),
              apiLink(
                DocSymbol.contextWatch,
                label: 'context.watch<LoginFormCubit>()',
              ),
              Component.text(
                ' expecting widget rebuilds on state emissions. In BlocSignal, context.watch listens strictly to '
                'provider instance replacement (for dynamic dependency injection swapping), avoiding coarse whole-tree '
                'rebuild cascades. Use ',
              ),
              apiLink(DocSymbol.blocSignalBuilder),
              Component.text(' or '),
              apiLink(DocSymbol.contextSelect, label: 'context.select'),
              Component.text(
                ' to subscribe to state and computed signal changes.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'lib/login_form_view.dart',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'login_form_cubit.dart';

class LoginFormView extends StatelessWidget {
  const LoginFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginFormCubit>();

    return BlocSignalBuilder<LoginFormCubit, LoginFormState>(
      builder: (context, state) {
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
      },
    );
  }

  void _submit(BuildContext context) {
    // Handle form submission logic
  }
}''',
          dart35Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'login_form_cubit.dart';

class LoginFormView extends StatelessWidget {
  const LoginFormView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginFormCubit>();

    return BlocSignalBuilder<LoginFormCubit, LoginFormState>(
      builder: (context, state) {
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
      },
    );
  }

  void _submit(BuildContext context) {
    // Handle form submission logic
  }
}''',
        ),
      ]),

      // 5. Scoped Provider Setup
      section(id: 'provider-setup', classes: 'docs-section', [
        h2([Component.text('Scoped Provider Setup')]),
        p([
          Component.text('Provide the '),
          code([Component.text('LoginFormCubit')]),
          Component.text(' to the widget subtree using '),
          apiLink(DocSymbol.blocSignalProvider),
          Component.text(' (or '),
          apiLink(DocSymbol.multiBlocSignalProvider),
          Component.text(' when combining multiple providers):'),
        ]),
        const DocsCodeBlock(
          title: 'lib/login_form_page.dart',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'login_form_cubit.dart';
import 'login_form_view.dart';

class LoginFormPage extends StatelessWidget {
  const LoginFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: BlocSignalProvider<LoginFormCubit>(
        create: (context) => LoginFormCubit(),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: LoginFormView(),
        ),
      ),
    );
  }
}''',
          dart35Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'login_form_cubit.dart';
import 'login_form_view.dart';

class LoginFormPage extends StatelessWidget {
  const LoginFormPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: BlocSignalProvider<LoginFormCubit>(
        create: (context) => LoginFormCubit(),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: LoginFormView(),
        ),
      ),
    );
  }
}''',
        ),
      ]),

      // 6. Fine-Grained Rebuilds with context.select
      section(id: 'fine-grained-select', classes: 'docs-section', [
        h2([Component.text('Fine-Grained Rebuilds with context.select')]),
        p([
          Component.text(
            'For optimal performance in complex forms, you can also use ',
          ),
          apiLink(DocSymbol.contextSelect, label: 'context.select<B, R>()'),
          Component.text(
            ' to subscribe individual widgets exclusively to their specific computed validation signal. '
            'With this approach, typing in the password field will not rebuild the email text field at all:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/fine_grained_login_view.dart',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'login_form_cubit.dart';

class FineGrainedLoginFormView extends StatelessWidget {
  const FineGrainedLoginFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginFormCubit>();
    final emailError = context.select<LoginFormCubit, String?>(
      (c) => c.emailError.value,
    );
    final passwordError = context.select<LoginFormCubit, String?>(
      (c) => c.passwordError.value,
    );
    final isValid = context.select<LoginFormCubit, bool>(
      (c) => c.isValid.value,
    );

    return Column(
      children: [
        TextField(
          onChanged: cubit.emailChanged,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: emailError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: true,
          onChanged: cubit.passwordChanged,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: passwordError,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isValid ? () => _submit(context) : null,
          child: const Text('Log In'),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    // Handle submission logic
  }
}''',
          dart35Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'login_form_cubit.dart';

class FineGrainedLoginFormView extends StatelessWidget {
  const FineGrainedLoginFormView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginFormCubit>();
    final emailError = context.select<LoginFormCubit, String?>(
      (c) => c.emailError.value,
    );
    final passwordError = context.select<LoginFormCubit, String?>(
      (c) => c.passwordError.value,
    );
    final isValid = context.select<LoginFormCubit, bool>(
      (c) => c.isValid.value,
    );

    return Column(
      children: [
        TextField(
          onChanged: cubit.emailChanged,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: emailError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: true,
          onChanged: cubit.passwordChanged,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: passwordError,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isValid ? () => _submit(context) : null,
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

      // 7. Performance & Debouncing
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
