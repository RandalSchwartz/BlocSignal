import 'dart:async';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

class HeroBanner extends StatefulComponent {
  const HeroBanner({super.key});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  String _selectedTab = 'Flutter';
  bool _isCopied = false;
  Timer? _copyTimer;

  static const Map<String, String> _installCommands = {
    'Flutter': 'flutter pub add bloc_signals_flutter',
    'Dart': 'dart pub add bloc_signals',
    'Jaspr': 'dart pub add bloc_signals_jaspr',
    'Riverpod': 'dart pub add bloc_signals_riverpod',
  };

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _selectTab(String tab) {
    if (_selectedTab != tab) {
      setState(() {
        _selectedTab = tab;
      });
    }
  }

  void _copyCommand() {
    final cmd = _installCommands[_selectedTab] ?? 'dart pub add bloc_signals';
    try {
      web.window.navigator.clipboard.writeText(cmd);
    } catch (_) {
      // Ignore if clipboard API is restricted in headless/iframe contexts.
    }
    setState(() {
      _isCopied = true;
    });
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Component build(BuildContext context) {
    final activeCommand =
        _installCommands[_selectedTab] ?? 'dart pub add bloc_signals';

    return section(classes: 'hero-section', [
      div(classes: 'container hero-container', [
        div(classes: 'hero-logo-wrapper', [
          img(
            src: '/assets/logo.png',
            alt: 'BlocSignal Official Logo',
            classes: 'hero-branding-logo',
            width: 140,
            height: 140,
          ),
        ]),
        div(classes: 'hero-badge-tag', [
          span(classes: 'hero-badge-dot', []),
          Component.text(
              '⚡ v1.1.0 Released — 0ms Latency State Management for Dart & Flutter'),
        ]),
        h1(classes: 'hero-title', [
          Component.text('The Rigor of BLoC.'),
          br(),
          span(
              classes: 'highlight-text',
              [Component.text('The Flex & Speed of Signal.')]),
        ]),
        p(classes: 'hero-motto', [
          Component.text(
            'Enterprise-grade state management for Dart & Flutter with 0ms microtask latency, 100% docstring coverage, OpenTelemetry tracing, and universal ecosystem bridges.',
          ),
        ]),
        div(classes: 'hero-actions', [
          a(
            href: '#visualizer',
            classes: 'btn-primary',
            [Component.text('Try Live Visualizer ⚡')],
          ),
          a(
            href: 'https://pub.dev/packages/bloc_signals',
            target: Target.blank,
            classes: 'btn-secondary',
            [Component.text('View on pub.dev ↗')],
          ),
        ]),

        // Interactive Tabbed Install Terminal
        div(classes: 'install-terminal-box', [
          div(classes: 'install-terminal-header', [
            div(classes: 'install-tabs-list', [
              for (final tab in _installCommands.keys)
                button(
                  classes:
                      'install-tab-btn ${_selectedTab == tab ? "active" : ""}',
                  onClick: () => _selectTab(tab),
                  [Component.text(tab)],
                ),
            ]),
            button(
              classes: 'btn-copy-install ${_isCopied ? "copied" : ""}',
              onClick: _copyCommand,
              attributes: {'aria-label': 'Copy installation command'},
              [
                span(classes: 'copy-icon', [
                  Component.text(_isCopied ? '✓' : '📋'),
                ]),
                span(classes: 'copy-label', [
                  Component.text(_isCopied ? 'Copied!' : 'Copy'),
                ]),
              ],
            ),
          ]),
          div(classes: 'install-terminal-body', [
            span(classes: 'terminal-prompt', [Component.text('\$ ')]),
            code(classes: 'terminal-command', [Component.text(activeCommand)]),
          ]),
        ]),

        // Side-by-Side "Before & After" Architecture Comparison
        div(classes: 'hero-comparison-wrapper', [
          h3(classes: 'comparison-headline', [
            Component.text('Why Bridge BLoC with Signals?'),
          ]),
          p(classes: 'comparison-subheadline', [
            Component.text(
              'Classic BLoC couples state to asynchronous Stream microtask queues. BlocSignal retains the exact same event machine while swapping the reactive engine for Preact Signals v7.',
            ),
          ]),
          div(classes: 'comparison-grid', [
            // Left Card: Classic BLoC
            div(classes: 'comparison-card comparison-card-classic', [
              div(classes: 'comp-card-header', [
                div(classes: 'comp-header-left', [
                  span(classes: 'comp-icon', [Component.text('⏳')]),
                  h4(classes: 'comp-title', [Component.text('Classic BLoC')]),
                ]),
                span(classes: 'comp-badge comp-badge-classic', [
                  Component.text('Async Streams'),
                ]),
              ]),
              div(classes: 'comp-code-box', [
                pre([
                  code([
                    Component.text('''
// Classic BLoC: Emits via StreamController
emit(LoadingState()); // Queued in Microtask 1 ⏳
emit(LoadedState());  // Queued in Microtask 2 ⏳
// UI frame rendering delayed across microtasks'''),
                  ]),
                ]),
              ]),
              ul(classes: 'comp-features-list', [
                li(classes: 'comp-feature-item negative', [
                  span(classes: 'feature-bullet', [Component.text('⚠️')]),
                  span([
                    Component.text(
                        'Asynchronous microtask lag & intermediate frame tearing'),
                  ]),
                ]),
                li(classes: 'comp-feature-item negative', [
                  span(classes: 'feature-bullet', [Component.text('⚠️')]),
                  span([
                    Component.text(
                        'Heavy StreamController heap allocations on every event'),
                  ]),
                ]),
                li(classes: 'comp-feature-item negative', [
                  span(classes: 'feature-bullet', [Component.text('⚠️')]),
                  span([
                    Component.text(
                        'Complex async Rx streams required for simple state reads'),
                  ]),
                ]),
              ]),
            ]),

            // Right Card: BlocSignal
            div(classes: 'comparison-card comparison-card-signal', [
              div(classes: 'comp-card-header', [
                div(classes: 'comp-header-left', [
                  span(classes: 'comp-icon', [Component.text('⚡')]),
                  h4(classes: 'comp-title', [Component.text('BlocSignal')]),
                ]),
                span(classes: 'comp-badge comp-badge-signal', [
                  Component.text('0ms Signals v7'),
                ]),
              ]),
              div(classes: 'comp-code-box', [
                pre([
                  code([
                    Component.text('''
// BlocSignal: Emits via Synchronous Signal
emit(LoadingState()); // 0ms Synchronous emission! ⚡
emit(LoadedState());  // Instant UI frame settling!
// Exact same call stack — 0 microtask delay'''),
                  ]),
                ]),
              ]),
              ul(classes: 'comp-features-list', [
                li(classes: 'comp-feature-item positive', [
                  span(classes: 'feature-bullet', [Component.text('✅')]),
                  span([
                    Component.text(
                        '0ms latency: emits and settles in the exact same call stack'),
                  ]),
                ]),
                li(classes: 'comp-feature-item positive', [
                  span(classes: 'feature-bullet', [Component.text('✅')]),
                  span([
                    Component.text(
                        'Automatic == equality de-duplication drops redundant builds'),
                  ]),
                ]),
                li(classes: 'comp-feature-item positive', [
                  span(classes: 'feature-bullet', [Component.text('✅')]),
                  span([
                    Component.text(
                        '100% BLoC API parity: onEvent, onTransition, and OpenTelemetry'),
                  ]),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
