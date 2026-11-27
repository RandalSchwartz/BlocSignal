import 'package:blocsignal_website/src/models/pub_api_registry.dart';
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
          Component.text('Discover '),
          apiLink(DocSymbol.blocSignalBuilder),
          Component.text(', '),
          apiLink(DocSymbol.blocSignalListener),
          Component.text(', '),
          apiLink(DocSymbol.blocSignalConsumer),
          Component.text(', and '),
          apiLink(DocSymbol.blocSignalSelector),
          Component.text(' for efficient, surgical Flutter UI rebuilding.'),
        ]),
      ]),

      section(id: 'builder', classes: 'docs-section', [
        h2([Component.text('1. BlocSignalBuilder')]),
        p([
          apiLink(DocSymbol.blocSignalBuilder),
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
            ' condition to filter which state transitions trigger widget rebuilds. BlocSignalBuilder tracks _previousState independently from the last rendered state so buildWhen always receives consecutive state pairs even across suppressed rebuilds, while BlocSignalBuilder, BlocSignalListener, and BlocSignalSelector suppress initial-pass callbacks for non-reflexive equals comparators, guard callbacks with mounted, and detect container swaps via !identical():',
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
        p([
          Component.text('Use '),
          code([Component.text('BlocSignalBuilder.child')]),
          Component.text(
            ' when part of the subtree is static and should not be reconstructed '
            'across state-driven rebuilds. The parent constructs ',
          ),
          code([Component.text('child')]),
          Component.text(' once and passes it into '),
          code([Component.text('builder')]),
          Component.text(':'),
        ]),
        const DocsCodeBlock(
          title: 'Preserving a Static Subtree with .child',
          dart313Code: '''
BlocSignalBuilder<CounterCubit, int>.child(
  child: const Icon(Icons.add),
  builder: (context, count, child) {
    return Row(
      children: [
        if (child != null) child,
        Text('Count: \$count'),
      ],
    );
  },
)
''',
          dart35Code: '''
BlocSignalBuilder<CounterCubit, int>.child(
  child: const Icon(Icons.add),
  builder: (BuildContext context, int count, Widget? child) {
    return Row(
      children: <Widget>[
        if (child != null) child,
        Text('Count: \$count'),
      ],
    );
  },
)
''',
        ),
      ]),

      section(id: 'listener', classes: 'docs-section', [
        h2([Component.text('2. BlocSignalListener')]),
        p([
          apiLink(DocSymbol.blocSignalListener),
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
        h3([Component.text('Execution Quotas (take and takeWhile)')]),
        p([
          Component.text('Use '),
          code([Component.text('take')]),
          Component.text(' and '),
          code([Component.text('takeWhile')]),
          Component.text(' on '),
          apiLink(DocSymbol.blocSignalListener),
          Component.text(
            ' (default, .debounce, .throttle, and .transition) to cap listener execution automatically:',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            code([Component.text('listenWhen')]),
            Component.text(' and rate-limiting ('),
            code([Component.text('debounce')]),
            Component.text(' / '),
            code([Component.text('throttle')]),
            Component.text(') filter emissions before quota evaluation.'),
          ]),
          li([
            code([Component.text('takeWhile(current)')]),
            Component.text(
              ' is evaluated before incrementing the invocation count; returning ',
            ),
            code([Component.text('false')]),
            Component.text(' permanently detaches without calling '),
            code([Component.text('listener')]),
            Component.text('.'),
          ]),
          li([
            code([Component.text('take')]),
            Component.text(
              ' increments and detaches synchronously before invoking ',
            ),
            code([Component.text('listener')]),
            Component.text(' (preventing reentrant over-fires); '),
            code([Component.text('take: 0')]),
            Component.text(' skips effect registration.'),
          ]),
          li([
            Component.text('Swapping '),
            code([Component.text('bloc')]),
            Component.text(' resets counters; '),
            code([Component.text('takeWhile')]),
            Component.text(' detachment persists across rebuilds unless '),
            code([Component.text('takeWhile')]),
            Component.text(' becomes '),
            code([Component.text('null')]),
            Component.text(' or '),
            code([Component.text('bloc')]),
            Component.text(' swaps.'),
          ]),
        ]),
        const DocsCodeBlock(
          title: 'One-Shot Listener (take & listenWhen)',
          dart313Code: '''
class OnboardingBanner extends StatelessWidget {
  const OnboardingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<AuthBloc, AuthState>(
      take: 1,
      listenWhen: (_, current) => current is AuthSuccess,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome!')),
        );
      },
      child: const DashboardView(),
    );
  }
}
''',
          dart35Code: '''
class OnboardingBanner extends StatelessWidget {
  const OnboardingBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<AuthBloc, AuthState>(
      take: 1,
      listenWhen: (AuthState _, AuthState current) => current is AuthSuccess,
      listener: (BuildContext context, AuthState state) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome!')),
        );
      },
      child: const DashboardView(),
    );
  }
}
''',
        ),
        const DocsCodeBlock(
          title: 'Predicate-Bounded Listener (takeWhile)',
          dart313Code: '''
class SessionFeedbackListener extends StatelessWidget {
  const SessionFeedbackListener({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<AuthBloc, AuthState>(
      takeWhile: (current) => current is! AuthLoggedOut,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth update: \$state')),
        );
      },
      child: const DashboardView(),
    );
  }
}
''',
          dart35Code: '''
class SessionFeedbackListener extends StatelessWidget {
  const SessionFeedbackListener({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<AuthBloc, AuthState>(
      takeWhile: (AuthState current) => current is! AuthLoggedOut,
      listener: (BuildContext context, AuthState state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth update: \$state')),
        );
      },
      child: const DashboardView(),
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
          apiLink(DocSymbol.blocSignalConsumer),
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
        p([
          Component.text('Use '),
          code([Component.text('BlocSignalConsumer.child')]),
          Component.text(' to preserve a static '),
          code([Component.text('child')]),
          Component.text(
            ' subtree across state rebuilds while listening for side effects:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'BlocSignalConsumer.child Static Subtree',
          dart313Code: '''
BlocSignalConsumer<CartBloc, CartState>.child(
  listener: (context, state) {
    if (state is CartCheckoutSuccess) {
      Navigator.of(context).pushNamed('/order-confirmation');
    }
  },
  child: const CartHeaderBanner(),
  builder: (context, state, child) {
    return Column(
      children: [
        if (child != null) child,
        CartItemsList(items: state.items),
      ],
    );
  },
)
''',
          dart35Code: '''
BlocSignalConsumer<CartBloc, CartState>.child(
  listener: (BuildContext context, CartState state) {
    if (state is CartCheckoutSuccess) {
      Navigator.of(context).pushNamed('/order-confirmation');
    }
  },
  child: const CartHeaderBanner(),
  builder: (BuildContext context, CartState state, Widget? child) {
    return Column(
      children: <Widget>[
        if (child != null) child,
        CartItemsList(items: state.items),
      ],
    );
  },
)
''',
        ),
        p([
          apiLink(DocSymbol.blocSignalConsumer),
          Component.text(' (default, .transition, and .child) also supports '),
          code([Component.text('take')]),
          Component.text(' and '),
          code([Component.text('takeWhile')]),
          Component.text(
            ' with the same filtering, synchronous detachment, and ',
          ),
          code([Component.text('bloc')]),
          Component.text('-swap / rebuild semantics. Quotas cap only '),
          code([Component.text('listener')]),
          Component.text(' while '),
          code([Component.text('builder')]),
          Component.text(
            ' continues rebuilding on every state change (subject to ',
          ),
          code([Component.text('buildWhen')]),
          Component.text(').'),
        ]),
      ]),

      section(id: 'selector', classes: 'docs-section', [
        h2([Component.text('4. BlocSignalSelector')]),
        p([
          Component.text(
            'For complex, large state objects where only a small property is displayed, ',
          ),
          apiLink(DocSymbol.blocSignalSelector),
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
        p([
          Component.text('Use '),
          code([Component.text('BlocSignalSelector.child')]),
          Component.text(' to pass a pre-built static '),
          code([Component.text('child')]),
          Component.text(' widget into '),
          code([Component.text('builder')]),
          Component.text(
            ' without rebuilding it when the selected value changes:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'BlocSignalSelector.child Static Subtree',
          dart313Code: '''
BlocSignalSelector<UserBloc, UserState, String>.child(
  selector: (state) => state.username,
  child: const Icon(Icons.person),
  builder: (context, username, child) {
    return Row(
      children: [
        if (child != null) child,
        Text('Username: \$username'),
      ],
    );
  },
)
''',
          dart35Code: '''
BlocSignalSelector<UserBloc, UserState, String>.child(
  selector: (UserState state) => state.username,
  child: const Icon(Icons.person),
  builder: (BuildContext context, String username, Widget? child) {
    return Row(
      children: <Widget>[
        if (child != null) child,
        Text('Username: \$username'),
      ],
    );
  },
)
''',
        ),
      ]),
    ]);
  }
}
