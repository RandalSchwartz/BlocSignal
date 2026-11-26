import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering analyzer lints and IDE fixes with bloc_signals_lint.
class const DocsPkgLintPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'Core Framework Rules', anchor: 'core-rules'),
    TocHeading(title: 'Flutter UI Rules', anchor: 'flutter-rules'),
    TocHeading(title: 'Configuration & Severities', anchor: 'configuration'),
    TocHeading(title: 'Automated Quick-Fixes', anchor: 'quick-fixes'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_lint')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Static analysis rules and automated IDE quick-fixes enforcing best practices, reactive correctness, and architectural invariants across BlocSignal projects.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_lint package is an official Dart analyzer plugin (built on analysis_server_plugin) providing 28 specialized analyzer rules. '
            'It detects dangerous runtime pitfalls—such as emitting states during widget build cycles, omitting mixin initializers, or unmanaged signal effects—directly in VS Code, Android Studio, and dart analyze with one-click automated quick-fixes.',
          ),
        ]),

        p([
          Component.text(
            'Enable bloc_signals_lint solely under plugins: in your root analysis_options.yaml file (no dev_dependencies entry is needed; use path: for local unreleased workspaces):',
          ),
        ]),
        const DocsCodeBlock(
          title: 'analysis_options.yaml',
          language: 'yaml',
          code: 'plugins:\n  bloc_signals_lint: ^2.0.0',
        ),
      ]),

      // 2. Core Framework Rules
      section(id: 'core-rules', classes: 'docs-section', [
        h2([Component.text('Core Framework Rules')]),
        p([
          Component.text(
            'These rules enforce immutability, lifecycle integrity, and event handling discipline within state containers:',
          ),
        ]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Rule')]),
                th([Component.text('Default')]),
                th([Component.text('Description & Invariant')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  code([Component.text('avoid_duplicate_event_handlers')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags duplicate on<E>() registrations for the exact same event type within a BlocSignal or BlocSignalMixin class or mixin declaration.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('require_super_on_event')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Enforces calling super.onEvent(event) inside onEvent overrides to preserve Zone event tracking and observer telemetry.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_stream_transformers_on_bloc_signal'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags stream transformer calls (such as .transform(), .debounce(), .switchMap()) directly on synchronous BlocSignalBase instances.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_direct_signal_mutation_outside_bloc'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Prevents external code outside the state container class from calling protected emit() or mutating internal signal state.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_top_level_bloc_signal_instances'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags top-level variables and static fields declared directly as BlocSignal or CubitSignal instances.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('require_cubit_signal_mixin_init')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Enforces calling initCubitSignal(initialState: ...) in constructors of classes adopting mixins.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_raw_signal_effects_in_bloc')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags unmanaged top-level effect() calls inside BlocSignalBase containers, recommending container-owned createEffect().',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('prefer_named_replay_constructor')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags deprecated super.positional(...) constructor calls on ReplayCubit and ReplayBloc subclasses, recommending super(initialState: ...).',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('require_emit_in_helper_name')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags private helper methods calling emit() whose names do not indicate state emission, recommending renaming to ...AndEmit.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_multiple_synchronous_emits')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags multiple synchronous emit() calls along the same linear execution path without an intervening await (treating catch clauses after an await-containing try body, outside nested closures including await for, as starting after a suspension boundary) to preserve state atomicity.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_primitive_event_types')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags BlocSignal<Event, State> or BlocSignalMixin declarations using primitive or untyped types (such as int, String, bool, or dynamic) as event types.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_pseudo_events_in_telemetry')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    "Flags emitTelemetry('...') calls inside CubitSignal containers whose names match UI event action patterns (such as Pressed, Clicked, or Submitted).",
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_emit_or_add_in_computed')]),
                ]),
                td([
                  span(classes: 'badge badge-error', [Component.text('ERROR')]),
                ]),
                td([
                  Component.text(
                    'Flags emit() or add() calls on state containers inside computed() callbacks to keep derived signals pure.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('require_hydrated_storage_prefix')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Requires concrete HydratedCubitSignal, HydratedBlocSignal, and HydratedMixin classes to override storagePrefix.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('require_hydrated_mixin_init')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Requires classes mixing in HydratedMixin with CubitSignalMixin or BlocSignalMixin to call hydrate() in constructors.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_unmanaged_signal_subscription')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags discarded ReadonlySignal.subscribe(...) calls whose cleanup closure is not retained.',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 3. Flutter UI Rules
      section(id: 'flutter-rules', classes: 'docs-section', [
        h2([Component.text('Flutter UI Rules')]),
        p([
          Component.text(
            'These rules safeguard widget lifecycles, eliminate unnecessary rebuilds, and ensure optimal reactive subscriptions:',
          ),
        ]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Rule')]),
                th([Component.text('Default')]),
                th([Component.text('Description & Invariant')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  code([Component.text('avoid_emit_in_build')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags direct emit() or add() mutations inside Widget.build() methods. Mutating state during layout causes Flutter frame assertion errors.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_unmanaged_signal_effects')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags unmanaged effect() calls inside Flutter Widget/HookWidget/State or Jaspr Component/State methods outside build() without lifecycle cleanup.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text(
                      'prefer_bloc_signal_provider_read_in_callbacks',
                    ),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Warns when context.watch<T>() is used inside event callback closures (for example onPressed), suggesting context.read<T>().',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text(
                      'avoid_providing_existing_instance_with_create',
                    ),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags passing existing variable references to BlocSignalProvider(create: ...) instead of BlocSignalProvider.value(value: ...).',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_manual_close_on_provided_bloc')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags calling .close() manually on state containers retrieved via context.read<T>() or BlocSignalProvider.of(context).',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_invalid_context_select_generics'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags context.select<B, R> invocations where generic parameters B (container) or R (slice) are omitted or invalid.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_context_watch_for_bloc_state')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags context.watch<T>() on state containers inside build() methods to prevent missed state emissions (tracks container swaps only).',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_unused_select_result')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags calling context.select(...) as an unused expression statement where the returned value is discarded.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_bridging_in_build')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags .toBlocSignal(), .toAsyncBlocSignal(), .toValueListenable(), and ListenableBlocSignal calls directly inside UI build() methods.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('require_child_outside_multi_bloc_signal'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags BlocSignalProvider, BlocSignalProvider.value, and BlocSignalListener omitting child: outside MultiBlocSignalProvider or MultiBlocSignalListener.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_signal_creation_in_build')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags direct signal(), computed(), and effect() allocations inside build() methods.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_context_select_outside_build')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags context.select(...) and context.value(...) calls outside build(), including callbacks, closures, and non-build lifecycle methods.',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 4. Configuration & Severities
      section(id: 'configuration', classes: 'docs-section', [
        h2([Component.text('Configuration & Severities')]),
        p([
          Component.text(
            'You can enable or disable specific diagnostics under diagnostics: in your analysis_options.yaml file:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'analysis_options.yaml',
          language: 'yaml',
          code: '''plugins:
  bloc_signals_lint:
    version: ^2.0.0
    diagnostics:
      # Disable a specific rule if needed
      avoid_duplicate_event_handlers: false''',
        ),
        p([
          Component.text(
            'To ignore a rule on a specific line or throughout an entire file, use standard Dart analyzer comment directives:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/example.dart',
          language: 'dart',
          code: '''// ignore_for_file: bloc_signals_lint/avoid_stream_transformers_on_bloc_signal

void example(BuildContext context, CounterBloc bloc) {
  // ignore: bloc_signals_lint/avoid_emit_in_build
  bloc.add(const Increment());
}''',
        ),
      ]),

      // 5. Automated Quick-Fixes
      section(id: 'quick-fixes', classes: 'docs-section', [
        h2([Component.text('Automated Quick-Fixes')]),
        p([
          Component.text(
            'Most rules in bloc_signals_lint come with automated IDE quick-fixes. When a diagnostic is flagged, press ',
          ),
          code([Component.text('Cmd + .')]),
          Component.text(' (macOS) or '),
          code([Component.text('Alt + Enter')]),
          Component.text(
            ' (Windows/Linux) to preview and apply surgical code transformations instantly:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('AddSuperOnEventFix')]),
            Component.text(
              ': Inserts super.onEvent(event); into onEvent overrides.',
            ),
          ]),
          li([
            strong([Component.text('AvoidRawSignalEffectsInBlocFix')]),
            Component.text(
              ': Converts unmanaged top-level effect(...) calls to createEffect(...).',
            ),
          ]),
          li([
            strong([Component.text('PreferReadInCallbacksFix')]),
            Component.text(
              ': Replaces context.watch<T>() with context.read<T>() inside event callback closures.',
            ),
          ]),
          li([
            strong([Component.text('ReplaceContextWatchWithReadFix')]),
            Component.text(
              ': Replaces context.watch<T>() with context.read<T>() inside widget build methods.',
            ),
          ]),
          li([
            strong([Component.text('RequireCubitSignalMixinInitFix')]),
            Component.text(
              ': Inserts missing initCubitSignal(initialState: ...) directly into the constructor body.',
            ),
          ]),
          li([
            strong([Component.text('UseProviderValueFix')]),
            Component.text(
              ': Replaces BlocSignalProvider(create: (_) => existing) with BlocSignalProvider.value(value: existing).',
            ),
          ]),
          li([
            strong([Component.text('ReplacePositionalReplayConstructorFix')]),
            Component.text(
              ': Rewrites super.positional(...) to super(initialState: ...), preserving trailing named parameters.',
            ),
          ]),
          li([
            strong([Component.text('RequireEmitInHelperNameFix')]),
            Component.text(
              ': Renames private helper methods calling emit() and their call sites by appending AndEmit.',
            ),
          ]),
          li([
            strong([Component.text('AddHydratedStoragePrefixFix')]),
            Component.text(
              ': Inserts @override String get storagePrefix => ...; on concrete hydrated containers.',
            ),
          ]),
          li([
            strong([Component.text('AddHydratedMixinInitFix')]),
            Component.text(
              ': Inserts hydrate(); into uninitialized HydratedMixin constructor bodies.',
            ),
          ]),
          li([
            strong([Component.text('ReplaceContextSelectOutsideBuildFix')]),
            Component.text(
              ': Rewrites context.select<B, R>(...) or context.value<B, S>() outside build() to context.read<B>().',
            ),
          ]),
          li([
            strong([Component.text('FixContextSelectGenericsFix')]),
            Component.text(
              ': Reduces invalid context.select<B, S, R> type arguments to <B, R>.',
            ),
          ]),
          li([
            strong([Component.text('InsertToStreamForTransformerFix')]),
            Component.text(
              ': Inserts .toStream() before stream transformer calls on BlocSignalBase containers.',
            ),
          ]),
          li([
            strong([Component.text('BindUnusedSelectResultFix')]),
            Component.text(
              ': Binds discarded context.select(...) statements to final value = ....',
            ),
          ]),
          li([
            strong([Component.text('RemoveManualCloseOnProvidedBlocFix')]),
            Component.text(
              ': Removes manual close() calls on provider-managed containers.',
            ),
          ]),
          li([
            strong([Component.text('RemoveDuplicateEventHandlerFix')]),
            Component.text(
              ': Removes duplicate on<Event>(...) handler registrations.',
            ),
          ]),
          li([
            strong([Component.text('ReplaceContextWatchWithValueFix')]),
            Component.text(
              ': Alternative fix rewriting context.watch<B>() to context.value<B, S>().',
            ),
          ]),
        ]),
      ]),
    ]);
  }
}
