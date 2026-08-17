import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering handling one-shot presentation side-effects.
class const DocsRecipeOneShotPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'The Problem: Ephemeral Events', anchor: 'the-problem'),
    TocHeading(
      title: 'Pattern 1: Sealed Result States',
      anchor: 'sealed-result-states',
    ),
    TocHeading(
      title: 'Pattern 2: Event Streams vs Listeners',
      anchor: 'listeners-vs-streams',
    ),
    TocHeading(title: 'Complete Flutter Example', anchor: 'flutter-example'),
    TocHeading(title: 'Anti-Patterns to Avoid', anchor: 'anti-patterns'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('🛠️ Architecture Recipes'),
        ]),
        h1([Component.text('One-Shot Presentation Side Effects')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Clean, declarative patterns for triggering one-off UI actions like Navigation, SnackBars, and Alert Dialogs without anti-pattern event reset flags.',
          ),
        ]),
      ]),

      // 1. The Problem
      section(id: 'the-problem', classes: 'docs-section', [
        h2([Component.text('The Problem: Ephemeral Events')]),
        p([
          Component.text(
            'In declarative state management, representing one-time actions (like showing a SnackBar or navigating to a new screen) '
            'can be tricky. If an error message is stored as a persistent property on your state object, navigating away and returning '
            'or rotating the device could cause the SnackBar to trigger a second time.',
          ),
        ]),
      ]),

      // 2. Pattern 1: Sealed Result States
      section(id: 'sealed-result-states', classes: 'docs-section', [
        h2([
          Component.text(
            'Pattern 1: Sealed Result States with BlocSignalListener',
          ),
        ]),
        p([
          Component.text(
            'The recommended approach in BlocSignal is to model terminal outcomes using sealed state classes and react to them with BlocSignalListener:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/auth_state.dart',
          language: 'dart',
          code: '''
sealed class AuthState {}
final class AuthInitial extends AuthState {}
final class AuthSubmitting extends AuthState {}
final class AuthSuccess extends AuthState {
  AuthSuccess(this.user);
  final User user;
}
final class AuthFailure extends AuthState {
  AuthFailure(this.errorMessage);
  final String errorMessage;
}''',
        ),
      ]),

      // 3. Pattern 2: Listeners vs Streams
      section(id: 'listeners-vs-streams', classes: 'docs-section', [
        h2([
          Component.text('Pattern 2: Why BlocSignalListener Over Raw Streams'),
        ]),
        p([
          Component.text(
            'Unlike raw EventBus streams, BlocSignalListener participates in Flutter widget lifecycles. '
            'It registers and unregisters listeners automatically when the widget mounts and unmounts, preventing memory leaks '
            'and ensuring that dialogs are only shown when the widget is actively mounted in the element tree.',
          ),
        ]),
      ]),

      // 4. Complete Flutter Example
      section(id: 'flutter-example', classes: 'docs-section', [
        h2([Component.text('Complete Flutter Example')]),
        const DocsCodeBlock(
          title: 'lib/login_view.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSuccess || current is AuthFailure,
      listener: (context, state) {
        if (state is AuthSuccess) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: const LoginForm(),
    );
  }
}''',
        ),
      ]),

      // 5. Anti-Patterns to Avoid
      section(id: 'anti-patterns', classes: 'docs-section', [
        h2([Component.text('Anti-Patterns to Avoid')]),
        const DocsCallout(
          type: CalloutType.warning,
          title: 'Avoid Boolean Reset Flags',
          children: [
            p([
              Component.text(
                'Avoid adding fields like shouldShowSnackBar: true followed immediately by emit(state.copyWith(shouldShowSnackBar: false)). '
                'This generates double transitions and race conditions. Instead, model outcomes as distinct sealed states handled in listenWhen.',
              ),
            ]),
          ],
        ),
      ]),
    ]);
  }
}
