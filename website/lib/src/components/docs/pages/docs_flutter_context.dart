import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Flutter Integration: BuildContext Extensions guide.
class const DocsFlutterContextPage({super.key}) extends StatelessComponent {
  /// Table of contents headings for this article.
  static const List<TocHeading> headings = [
    TocHeading(title: '1. context.read<B>()', anchor: 'read'),
    TocHeading(title: '2. context.watch<B>()', anchor: 'watch'),
    TocHeading(title: '3. context.select<B, R>()', anchor: 'select'),
    TocHeading(title: '4. context.value<B, S>()', anchor: 'value'),
    TocHeading(title: '5. context.state<B, S>()', anchor: 'state'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('Flutter Bindings & Extensions'),
        ]),
        h1([Component.text('BuildContext Extensions')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Master context.read, context.watch, context.select, context.value, and context.state on ',
          ),
          apiLink(DocSymbol.blocSignalProviderExtension, label: 'BuildContext'),
          Component.text(
            ' for clean, expressive state access and reactive signal composition throughout your Flutter widget tree.',
          ),
        ]),
      ]),

      section(id: 'read', classes: 'docs-section', [
        h2([Component.text('1. context.read<B>()')]),
        p([
          Component.text(
            'Retrieves the nearest ancestor state container without registering a rebuild dependency. '
            'Always use ',
          ),
          apiLink(DocSymbol.contextRead, label: 'context.read<B>()'),
          Component.text(
            ' inside event handlers, callback closures, button presses, and gestures '
            'where you want to dispatch an action or read a one-off value without causing the enclosing '
            'build method to rebuild.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.caution,
          title: 'Do Not Use context.read in build()',
          children: [
            p([
              Component.text(
                'Calling context.read() inside a widget build() method is an anti-pattern because '
                'the widget will not update when state mutates. Use context.select() or BlocSignalBuilder instead.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'context.read in Button Callbacks',
          dart313Code: '''
class IncrementButton extends StatelessWidget {
  const IncrementButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        // O(1) non-listening retrieval
        context.read<CounterCubit>().increment();
      },
      child: const Icon(Icons.add),
    );
  }
}
''',
          dart35Code: '''
class IncrementButton extends StatelessWidget {
  const IncrementButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        context.read<CounterCubit>().increment();
      },
      child: const Icon(Icons.add),
    );
  }
}
''',
        ),
      ]),

      section(id: 'watch', classes: 'docs-section', [
        h2([Component.text('2. context.watch<B>()')]),
        p([
          apiLink(DocSymbol.contextWatch, label: 'context.watch<B>()'),
          Component.text(
            ' resolves the container and registers the current widget’s Element '
            'as a listener on the InheritedWidget provider. It triggers a rebuild '
            'if the provided container instance itself is replaced in the widget tree.',
          ),
        ]),
        DocsCallout(
          type: CalloutType.warning,
          title: 'context.watch Tracks Provider Instance, Not State',
          children: [
            p([
              Component.text(
                'Unlike classic flutter_bloc, context.watch in BlocSignal does NOT rebuild on state changes. '
                'To reactively rebuild when state values mutate, use ',
              ),
              apiLink(DocSymbol.contextSelect, label: 'context.select<B, R>()'),
              Component.text(' or '),
              apiLink(
                DocSymbol.blocSignalBuilder,
                label: 'BlocSignalBuilder<B, S>',
              ),
              Component.text('.'),
            ]),
          ],
        ),
        h3([Component.text('Primary Use Cases for context.watch<B>()')]),
        ul([
          li([
            strong([Component.text('Dynamic Instance Swapping: ')]),
            Component.text(
              'When a parent widget dynamically injects different container instances via ',
            ),
            code([Component.text('BlocSignalProvider.value')]),
            Component.text(
              ' (for example, switching the active chat room, document, or workspace in a master-detail view).',
            ),
          ]),
          li([
            strong([Component.text('Passing Instance to Child Delegates: ')]),
            Component.text(
              'When a widget extracts the container in build() to pass into child component constructors or delegates, '
              'ensuring children stay synchronized if the parent replaces the container.',
            ),
          ]),
        ]),
        const DocsCodeBlock(
          title: 'context.watch for Dynamic Instance Swapping',
          dart313Code: '''
class ActiveRoomHeader extends StatelessWidget {
  const ActiveRoomHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the parent provider swaps the RoomBloc instance
    final roomBloc = context.watch<RoomBloc>();
    return Text('Active Room: \${roomBloc.roomId}');
  }
}
''',
          dart35Code: '''
class ActiveRoomHeader extends StatelessWidget {
  const ActiveRoomHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the parent provider swaps the RoomBloc instance
    final RoomBloc roomBloc = context.watch<RoomBloc>();
    return Text('Active Room: \${roomBloc.roomId}');
  }
}
''',
        ),
      ]),

      section(id: 'select', classes: 'docs-section', [
        h2([Component.text('3. context.select<B, R>()')]),
        p([
          apiLink(
            DocSymbol.contextSelect,
            label: 'context.select<B, R>((bloc) => ...)',
          ),
          Component.text(
            ' listens to a specific derived property of a state container. '
            'The calling widget rebuilds ',
          ),
          strong([
            Component.text('only when the selected return value R changes'),
          ]),
          Component.text(
            '. This provides fine-grained selector ergonomics directly from BuildContext.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'context.select Fine-Grained Filtering',
          dart313Code: '''
class UsernameDisplay extends StatelessWidget {
  const UsernameDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    // Only rebuilds when state.username string changes
    final username = context.select<UserBloc, String>(
      (bloc) => bloc.stateValue.username,
    );

    return Text('Logged in as: \$username');
  }
}
''',
          dart35Code: '''
class UsernameDisplay extends StatelessWidget {
  const UsernameDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String username = context.select<UserBloc, String>(
      (UserBloc bloc) => bloc.stateValue.username,
    );

    return Text('Logged in as: \$username');
  }
}
''',
        ),
      ]),

      section(id: 'value', classes: 'docs-section', [
        h2([Component.text('4. context.value<B, S>()')]),
        p([
          code([Component.text('context.value<B, S>()')]),
          Component.text(
            ' subscribes the current BuildContext Element to state emissions on ',
          ),
          code([Component.text('B')]),
          Component.text(' and returns the current state value '),
          code([Component.text('S')]),
          Component.text('. It delegates directly to '),
          code([Component.text('context.select<B, S>((b) => b.stateValue)')]),
          Component.text(
            ' while providing clean single-line state access without writing an explicit selector closure.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Ideal for build() Methods & Scoped Builders',
          children: [
            p([
              Component.text(
                'Use context.value<B, S>() when the widget itself must rebuild on state updates. '
                'When wrapped inside a Builder(builder: (ctx) => ...), calling ctx.value<B, S>() '
                'scopes the rebuild exclusively to that inner subtree.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'context.value in build() Methods',
          dart313Code: '''
class CounterDisplay extends StatelessWidget {
  const CounterDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds this element whenever CounterCubit emits a new state:
    final count = context.value<CounterCubit, int>();

    return Text('Count: \$count');
  }
}
''',
          dart35Code: '''
class CounterDisplay extends StatelessWidget {
  const CounterDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Rebuilds this element whenever CounterCubit emits a new state:
    final int count = context.value<CounterCubit, int>();

    return Text('Count: \$count');
  }
}
''',
        ),
      ]),

      section(id: 'state', classes: 'docs-section', [
        h2([Component.text('5. context.state<B, S>()')]),
        p([
          code([Component.text('context.state<B, S>()')]),
          Component.text(' looks up the container and returns its underlying '),
          code([Component.text('ReadonlySignal<S>')]),
          Component.text(
            ' without registering a rebuild dependency on the calling BuildContext. '
            'It is designed specifically for reactive signal graph composition.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'Signal Graph Composition (computed & effect)',
          children: [
            p([
              Component.text(
                'In computed(() => ...) or effect(() => ...), always use context.state<B, S>() '
                'rather than context.value<B, S>(). Using context.value inside a computed signal would '
                'inappropriately attach Flutter Element rebuild subscriptions to pure reactive signal evaluations.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'context.state in computed Signals',
          dart313Code: '''
class OrderSummaryBadge extends StatelessWidget {
  const OrderSummaryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Look up signals for composition without context rebuilds:
    final cartSignal = context.state<CartCubit, CartState>();
    final promoSignal = context.state<PromoCubit, PromoState>();

    // 2. Reactively evaluate inside Watch without allocating unmanaged computed signals:
    return Watch((context) {
      final total = cartSignal.value.subtotal - promoSignal.value.discountAmount;
      return Text('Total: \$total');
    });
  }
}
''',
          dart35Code: '''
class OrderSummaryBadge extends StatelessWidget {
  const OrderSummaryBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. Look up signals for composition without context rebuilds:
    final ReadonlySignal<CartState> cartSignal =
        context.state<CartCubit, CartState>();
    final ReadonlySignal<PromoState> promoSignal =
        context.state<PromoCubit, PromoState>();

    // 2. Reactively evaluate inside Watch without allocating unmanaged computed signals:
    return Watch((context) {
      final double total =
          cartSignal.value.subtotal - promoSignal.value.discountAmount;
      return Text('Total: \$total');
    });
  }
}
''',
        ),
      ]),
    ]);
  }
}
