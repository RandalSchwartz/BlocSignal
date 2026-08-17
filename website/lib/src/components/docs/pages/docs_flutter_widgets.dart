import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Flutter Integration: Reactive Widgets guide.
class const DocsFlutterWidgetsPage({super.key}) extends StatelessComponent {
  /// Table of contents headings for this article.
  static const List<TocHeading> headings = [
    TocHeading(title: '1. BlocSignalBuilder', anchor: 'builder'),
    TocHeading(title: '2. BlocSignalListener', anchor: 'listener'),
    TocHeading(title: '3. BlocSignalConsumer', anchor: 'consumer'),
    TocHeading(title: '4. BlocSignalSelector', anchor: 'selector'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('Flutter Bindings & UI')]),
        h1([Component.text('Flutter Reactive Widgets')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Discover BlocSignalBuilder, BlocSignalListener, BlocSignalConsumer, '
            'and BlocSignalSelector for efficient, surgical Flutter UI rebuilding.',
          ),
        ]),
      ]),

      section(id: 'builder', classes: 'docs-section', [
        h2([Component.text('1. BlocSignalBuilder')]),
        p([
          code([Component.text('BlocSignalBuilder<B, S>')]),
          Component.text(
            ' subscribes to a BlocSignal or CubitSignal and rebuilds its child subtree '
            'whenever the container emits a new state value. By default, duplicate states '
            'are automatically suppressed by signal equality check.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'BlocSignalBuilder Example',
          dart313Code: '''
class CounterDisplay extends StatelessWidget {
  const CounterDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<CounterCubit, int>(
      builder: (context, count) {
        return Text(
          'Count: \$count',
          style: Theme.of(context).textTheme.headlineMedium,
        );
      },
    );
  }
}
''',
          dart35Code: '''
class CounterDisplay extends StatelessWidget {
  const CounterDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<CounterCubit, int>(
      builder: (BuildContext context, int count) {
        return Text(
          'Count: \$count',
          style: Theme.of(context).textTheme.headlineMedium,
        );
      },
    );
  }
}
''',
        ),
        p([
          Component.text('You can provide an optional '),
          code([Component.text('buildWhen')]),
          Component.text(
            ' condition to filter which state transitions trigger widget rebuilds:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'Conditional Rebuilding with buildWhen',
          dart313Code: '''
BlocSignalBuilder<CounterCubit, int>(
  buildWhen: (previous, current) => current.isEven,
  builder: (context, count) => Text('Even Count: \$count'),
)
''',
          dart35Code: '''
BlocSignalBuilder<CounterCubit, int>(
  buildWhen: (int previous, int current) => current.isEven,
  builder: (BuildContext context, int count) {
    return Text('Even Count: \$count');
  },
)
''',
        ),
      ]),

      section(id: 'listener', classes: 'docs-section', [
        h2([Component.text('2. BlocSignalListener')]),
        p([
          code([Component.text('BlocSignalListener<B, S>')]),
          Component.text(
            ' is designed exclusively for executing one-off side effects in response '
            'to state changes, such as showing SnackBars, pushing routes, popping sheets, '
            'or presenting alert dialogs.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'Zero Widget Rebuilds',
          children: [
            p([
              Component.text(
                'BlocSignalListener returns its child widget directly without wrapping it '
                'in a rebuild boundary. The listener callback executes synchronously on emission.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'BlocSignalListener Navigation & Feedback',
          dart313Code: '''
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous != current,
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is AuthSuccess) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      },
      child: const LoginForm(),
    );
  }
}
''',
          dart35Code: '''
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<AuthBloc, AuthState>(
      listenWhen: (AuthState previous, AuthState current) => previous != current,
      listener: (BuildContext context, AuthState state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is AuthSuccess) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      },
      child: const LoginForm(),
    );
  }
}
''',
        ),
      ]),

      section(id: 'consumer', classes: 'docs-section', [
        h2([Component.text('3. BlocSignalConsumer')]),
        p([
          Component.text(
            'When a widget needs both to rebuild UI and to trigger side-effect actions '
            '(such as showing a loading spinner while listening for errors), ',
          ),
          code([Component.text('BlocSignalConsumer<B, S>')]),
          Component.text(
            ' combines builder and listener into a single widget without nesting.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'BlocSignalConsumer Example',
          dart313Code: '''
BlocSignalConsumer<CartBloc, CartState>(
  listenWhen: (prev, curr) => curr is CartCheckoutSuccess,
  listener: (context, state) {
    Navigator.of(context).pushNamed('/order-confirmation');
  },
  builder: (context, state) {
    if (state is CartLoading) {
      return const CircularProgressIndicator();
    }
    return CartItemsList(items: state.items);
  },
)
''',
          dart35Code: '''
BlocSignalConsumer<CartBloc, CartState>(
  listenWhen: (CartState prev, CartState curr) => curr is CartCheckoutSuccess,
  listener: (BuildContext context, CartState state) {
    Navigator.of(context).pushNamed('/order-confirmation');
  },
  builder: (BuildContext context, CartState state) {
    if (state is CartLoading) {
      return const CircularProgressIndicator();
    }
    return CartItemsList(items: state.items);
  },
)
''',
        ),
      ]),

      section(id: 'selector', classes: 'docs-section', [
        h2([Component.text('4. BlocSignalSelector')]),
        p([
          Component.text(
            'For complex, large state objects where only a small property is displayed, ',
          ),
          code([Component.text('BlocSignalSelector<B, S, T>')]),
          Component.text(
            ' extracts a derived value via a selector function. The widget rebuilds ',
          ),
          strong([
            Component.text('only when the selected property value changes'),
          ]),
          Component.text(', completely ignoring all other state emissions.'),
        ]),
        const DocsCodeBlock(
          title: 'BlocSignalSelector Sub-State Extraction',
          dart313Code: '''
class UserAvatarHeader extends StatelessWidget {
  const UserAvatarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalSelector<UserBloc, UserState, String>(
      selector: (state) => state.avatarUrl,
      builder: (context, avatarUrl) {
        return CircleAvatar(
          backgroundImage: NetworkImage(avatarUrl),
        );
      },
    );
  }
}
''',
          dart35Code: '''
class UserAvatarHeader extends StatelessWidget {
  const UserAvatarHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocSignalSelector<UserBloc, UserState, String>(
      selector: (UserState state) => state.avatarUrl,
      builder: (BuildContext context, String avatarUrl) {
        return CircleAvatar(
          backgroundImage: NetworkImage(avatarUrl),
        );
      },
    );
  }
}
''',
        ),
      ]),
    ]);
  }
}
