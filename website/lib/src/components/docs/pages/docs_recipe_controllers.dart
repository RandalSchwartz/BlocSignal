import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering coordinating TextEditingControllers with BlocSignal.
class const DocsRecipeControllersPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'The Challenge: Mutable vs Immutable',
      anchor: 'the-challenge',
    ),
    TocHeading(title: 'The Build-Phase Pitfall', anchor: 'build-pitfall'),
    TocHeading(title: 'Safe Synchronization Pattern', anchor: 'sync-pattern'),
    TocHeading(
      title: 'Preserving Cursor Selection',
      anchor: 'cursor-preservation',
    ),
    TocHeading(
      title: 'Complete Stateful Implementation',
      anchor: 'complete-example',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('🛠️ Architecture Recipes'),
        ]),
        h1([Component.text('Coordinating TextEditingControllers')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Safely synchronize Flutter mutable TextEditingControllers with immutable Cubit and Bloc state without cursor jump glitches or infinite rebuild loops.',
          ),
        ]),
      ]),

      // 1. The Challenge
      section(id: 'the-challenge', classes: 'docs-section', [
        h2([Component.text('The Challenge: Mutable vs Immutable')]),
        p([
          Component.text(
            'Flutter TextEditingController is a mutable Listenable that manages text value and cursor selection offset. '
            'In contrast, BlocSignal relies on immutable state transitions. Coordinating both directions—user typing in the UI '
            'and external state updates from network or storage—requires care.',
          ),
        ]),
      ]),

      // 2. The Build-Phase Pitfall
      section(id: 'build-pitfall', classes: 'docs-section', [
        h2([Component.text('The Build-Phase Pitfall')]),
        const DocsCallout(
          type: CalloutType.warning,
          title: 'Never Update Controllers Inside build()',
          children: [
            p([
              Component.text(
                'Assigning controller.text = state.value inside a build() method triggers listener notifications while the framework '
                'is actively building the widget tree, causing "setState() or markNeedsBuild() called during build" errors or resetting the cursor to position 0.',
              ),
            ]),
          ],
        ),
      ]),

      // 3. Safe Synchronization Pattern
      section(id: 'sync-pattern', classes: 'docs-section', [
        h2([Component.text('Safe Synchronization Pattern')]),
        p([
          Component.text(
            'Use BlocSignalListener to synchronize external state updates to the controller only when the state value diverges from the current controller text:',
          ),
        ]),
      ]),

      // 4. Preserving Cursor Selection
      section(id: 'cursor-preservation', classes: 'docs-section', [
        h2([Component.text('Preserving Cursor Selection')]),
        p([
          Component.text(
            'When setting controller text programmatically, update controller.value rather than controller.text '
            'so you can retain or adjust TextSelection:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/text_sync_helper.dart',
          language: 'dart',
          code: '''
void syncControllerSafely(TextEditingController controller, String newText) {
  if (controller.text == newText) return;

  final oldSelection = controller.selection;
  final newOffset = oldSelection.baseOffset.clamp(0, newText.length);

  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newOffset),
  );
}''',
        ),
      ]),

      // 5. Complete Stateful Implementation
      section(id: 'complete-example', classes: 'docs-section', [
        h2([Component.text('Complete Stateful Implementation')]),
        const DocsCodeBlock(
          title: 'lib/search_bar_widget.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

class SearchInputWidget extends StatefulWidget {
  const SearchInputWidget({super.key});

  @override
  State<SearchInputWidget> createState() => _SearchInputWidgetState();
}

class _SearchInputWidgetState extends State<SearchInputWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize controller with initial cubit value
    final initialQuery = context.read<SearchCubit>().stateValue.query;
    _controller = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<SearchCubit, SearchState>(
      listenWhen: (prev, current) => prev.query != current.query,
      listener: (context, state) {
        // Sync external query resets (for example from a clear filters button)
        if (_controller.text != state.query) {
          _controller.value = TextEditingValue(
            text: state.query,
            selection: TextSelection.collapsed(offset: state.query.length),
          );
        }
      },
      child: TextField(
        controller: _controller,
        onChanged: (text) => context.read<SearchCubit>().queryChanged(text),
        decoration: const InputDecoration(
          hintText: 'Search packages...',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }
}''',
        ),
      ]),
    ]);
  }
}
