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
            'Master context.read, context.watch, and context.select on ',
          ),
          apiLink(DocSymbol.blocSignalProviderExtension, label: 'BuildContext'),
          Component.text(
            ' for clean, expressive state access throughout your Flutter widget tree.',
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
                'the widget will not update when state mutates. Use context.watch() or BlocSignalBuilder instead.',
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
            'as a listener on the InheritedWidget. Whenever the container emits a new state, '
            'the widget marks itself dirty and rebuilds on the next frame.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'context.watch in Widget Build Methods',
          dart313Code: '''
class ThemeIconHeader extends StatelessWidget {
  const ThemeIconHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCubit = context.watch<ThemeCubit>();
    final isDark = themeCubit.stateValue.isDarkMode;

    return Icon(
      isDark ? Icons.dark_mode : Icons.light_mode,
      color: isDark ? Colors.amber : Colors.blue,
    );
  }
}
''',
          dart35Code: '''
class ThemeIconHeader extends StatelessWidget {
  const ThemeIconHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeCubit themeCubit = context.watch<ThemeCubit>();
    final bool isDark = themeCubit.stateValue.isDarkMode;

    return Icon(
      isDark ? Icons.dark_mode : Icons.light_mode,
      color: isDark ? Colors.amber : Colors.blue,
    );
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
    ]);
  }
}
