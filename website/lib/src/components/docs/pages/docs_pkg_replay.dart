import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering undo/redo state history with bloc_signals_replay.
class const DocsPkgReplayPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'ReplayCubit', anchor: 'replay-cubit'),
    TocHeading(title: 'ReplayBloc', anchor: 'replay-bloc'),
    TocHeading(title: 'History Limits & Bounds', anchor: 'history-limits'),
    TocHeading(
      title: 'Filtering with shouldReplay',
      anchor: 'filtering-history',
    ),
    TocHeading(title: 'Mixins & Composition', anchor: 'mixins-composition'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_replay')]),
        p(classes: 'docs-lead', [
          Component.text(
            'High-performance undo and redo state history tracking for CubitSignal and BlocSignal with customizable capacity and transition filtering.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_replay package equips state containers with time-travel capabilities. '
            'It records state history stacks without copying heavyweight objects, exposing synchronous '
            'canUndo and canRedo signals that bind seamlessly to Flutter buttons and key shortcuts.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'flutter pub add bloc_signals_replay bloc_signals',
        ),
      ]),

      // 2. ReplayCubit
      section(id: 'replay-cubit', classes: 'docs-section', [
        h2([Component.text('ReplayCubit')]),
        p([
          Component.text('Extend '),
          apiLink(DocSymbol.replayCubit),
          Component.text(
            ' to automatically record emitted states in an undo history stack:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/drawing_cubit.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

class CanvasState {
  const CanvasState({required this.paths});
  final List<String> paths;
}

class DrawingCubit extends ReplayCubit<CanvasState> {
  DrawingCubit() : super(initialState: const CanvasState(paths: []));

  void addPath(String path) {
    emit(CanvasState(paths: [...stateValue.paths, path]));
  }
}''',
          dart313Code: '''
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

class CanvasState {
  const CanvasState({required this.paths});
  final List<String> paths;
}

class DrawingCubit() extends ReplayCubit<CanvasState> {
  this : super(initialState: const CanvasState(paths: []));

  void addPath(String path) {
    emit(CanvasState(paths: [...stateValue.paths, path]));
  }
}''',
        ),
        p([
          Component.text(
            'In your UI, bind undo and redo buttons directly to canUndo and canRedo signals:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/canvas_toolbar.dart',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'drawing_cubit.dart';

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DrawingCubit>();
    final canUndo = context.select<DrawingCubit, bool>((c) => c.canUndo);
    final canRedo = context.select<DrawingCubit, bool>((c) => c.canRedo);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: canUndo ? cubit.undo : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          onPressed: canRedo ? cubit.redo : null,
        ),
      ],
    );
  }
}''',
          dart35Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'drawing_cubit.dart';

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DrawingCubit>();
    final canUndo = context.select<DrawingCubit, bool>((c) => c.canUndo);
    final canRedo = context.select<DrawingCubit, bool>((c) => c.canRedo);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: canUndo ? cubit.undo : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          onPressed: canRedo ? cubit.redo : null,
        ),
      ],
    );
  }
}''',
        ),
      ]),

      // 3. ReplayBloc
      section(id: 'replay-bloc', classes: 'docs-section', [
        h2([Component.text('ReplayBloc')]),
        p([
          Component.text('For event-driven architectures, extend '),
          apiLink(DocSymbol.replayBloc),
          Component.text(
            '. ReplayBloc routes undo and redo commands through synthetic ReplayEvents, ensuring that '
            'BlocSignalObservers observe complete lifecycle transitions during time-travel operations.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/editor_bloc.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

sealed class EditorEvent {}
final class TextInserted extends EditorEvent {
  TextInserted(this.text);
  final String text;
}

class EditorBloc extends ReplayBloc<EditorEvent, String> {
  EditorBloc() : super(initialState: '') {
    on<TextInserted>((event, emit) => emit('\$stateValue\${event.text}'));
  }
}''',
        ),
      ]),

      // 4. History Limits & Bounds
      section(id: 'history-limits', classes: 'docs-section', [
        h2([Component.text('History Limits & Memory Bounds')]),
        p([
          Component.text(
            'To prevent unbounded memory consumption in long-running sessions, pass maxHistoryLength to the super constructor. '
            'When the stack exceeds this capacity, the oldest history entries are automatically discarded.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/limited_history_cubit.dart',
          language: 'dart',
          code: '''
class LimitedHistoryCubit extends ReplayCubit<int> {
  // Retains at most 20 historical states in the undo queue
  LimitedHistoryCubit() : super(initialState: 0, maxHistoryLength: 20);
}''',
        ),
      ]),

      // 5. Filtering with shouldReplay
      section(id: 'filtering-history', classes: 'docs-section', [
        h2([Component.text('Filtering with shouldReplay')]),
        p([
          Component.text(
            'Override shouldReplay to selectively record only meaningful user actions while ignoring transient intermediate states (like loading flags or hovered items):',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/filtered_replay_cubit.dart',
          language: 'dart',
          code: '''
class FormFieldState {
  const FormFieldState({required this.value, required this.isFocused});
  final String value;
  final bool isFocused;
}

class FormFieldCubit extends ReplayCubit<FormFieldState> {
  FormFieldCubit() : super(
    initialState: const FormFieldState(value: '', isFocused: false),
  );

  @override
  bool shouldReplay(FormFieldState state) {
    // Only record state history when the text value changes, ignoring focus shifts
    return state.value.isNotEmpty;
  }
}''',
        ),
      ]),

      // 6. Mixins & Composition
      section(id: 'mixins-composition', classes: 'docs-section', [
        h2([Component.text('Mixins & Composition')]),
        p([
          Component.text(
            'If your state container already extends a custom base class or another satellite container '
            '(such as HydratedCubitSignal), compose replay functionality using ReplayCubitMixin or ReplayBlocMixin:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/hydrated_replay_cubit.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

/// Combines persistent disk storage with in-memory undo/redo history.
class PersistentEditorCubit extends HydratedCubitSignal<String>
    with ReplayCubitMixin<String> {
  PersistentEditorCubit() : super(initialState: '');

  @override
  String fromJson(Object? json) => json as String? ?? '';

  @override
  Object? toJson(String state) => state;
}''',
        ),
      ]),
    ]);
  }
}
