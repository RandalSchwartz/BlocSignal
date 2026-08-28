import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

class const PackageItem({
  required final String name,
  required final String version,
  required final String desc,
  required final String icon,
  required final String category,
  required final String pubUrl,
  required final String installCmd,
}) {}

const List<PackageItem> _allPackages = [
  PackageItem(
    name: 'bloc_signals',
    version: '1.1.0',
    desc: 'Core pure Dart reactive state container bridging BLoC semantics with Preact Signals v7 primitives.',
    icon: '⚡',
    category: 'Core & UI',
    pubUrl: 'https://pub.dev/packages/bloc_signals',
    installCmd: 'dart pub add bloc_signals',
  ),
  PackageItem(
    name: 'bloc_signals_flutter',
    version: '1.2.0',
    desc: 'Flutter UI bindings, InheritedWidget providers, builders, listeners, selectors, and Listenable interop.',
    icon: '💙',
    category: 'Core & UI',
    pubUrl: 'https://pub.dev/packages/bloc_signals_flutter',
    installCmd: 'flutter pub add bloc_signals_flutter',
  ),
  PackageItem(
    name: 'bloc_signals_jaspr',
    version: '1.0.0+1',
    desc: 'Jaspr web component integration, InheritedComponent providers, builders, listeners, and selectors.',
    icon: '🌐',
    category: 'Core & UI',
    pubUrl: 'https://pub.dev/packages/bloc_signals_jaspr',
    installCmd: 'dart pub add bloc_signals_jaspr',
  ),
  PackageItem(
    name: 'bloc_signals_riverpod',
    version: '1.0.0+1',
    desc: 'Bidirectional Riverpod 2 & 3 interop adapters (toBlocSignal / toProvider / ProviderListenable).',
    icon: '🌊',
    category: 'State & Interop',
    pubUrl: 'https://pub.dev/packages/bloc_signals_riverpod',
    installCmd: 'dart pub add bloc_signals_riverpod',
  ),
  PackageItem(
    name: 'bloc_signals_hydrate',
    version: '1.0.1',
    desc: 'Synchronous state persistence across app restarts with primitive and collection storage support.',
    icon: '💾',
    category: 'State & Interop',
    pubUrl: 'https://pub.dev/packages/bloc_signals_hydrate',
    installCmd: 'dart pub add bloc_signals_hydrate',
  ),
  PackageItem(
    name: 'bloc_signals_replay',
    version: '1.0.0',
    desc: 'Replay, undo, and redo state tracking utilities (ReplayCubit, ReplayBloc, ReplayEvent).',
    icon: '↩️',
    category: 'State & Interop',
    pubUrl: 'https://pub.dev/packages/bloc_signals_replay',
    installCmd: 'dart pub add bloc_signals_replay',
  ),
  PackageItem(
    name: 'bloc_signals_otel',
    version: '1.0.0+1',
    desc: 'OpenTelemetry lifecycle tracing, transition metrics, and distributed span correlation.',
    icon: '🔭',
    category: 'DevTools & Tooling',
    pubUrl: 'https://pub.dev/packages/bloc_signals_otel',
    installCmd: 'dart pub add bloc_signals_otel',
  ),
  PackageItem(
    name: 'bloc_signals_devtools',
    version: '1.0.0',
    desc: 'Custom Flutter DevTools extension for timeline tracing, state diffing, and memory leak detection.',
    icon: '🛠️',
    category: 'DevTools & Tooling',
    pubUrl: 'https://pub.dev/packages/bloc_signals_devtools',
    installCmd: 'dart pub add bloc_signals_devtools',
  ),
  PackageItem(
    name: 'bloc_signals_test',
    version: '1.0.0',
    desc: 'Declarative unit testing utilities and test observers for BlocSignal and CubitSignal.',
    icon: '🧪',
    category: 'DevTools & Tooling',
    pubUrl: 'https://pub.dev/packages/bloc_signals_test',
    installCmd: 'dart pub add --dev bloc_signals_test',
  ),
  PackageItem(
    name: 'bloc_signals_lint',
    version: '1.0.0',
    desc: 'Custom analyzer lints and automated IDE quick-fixes for enforcing BlocSignal best practices.',
    icon: '🔍',
    category: 'DevTools & Tooling',
    pubUrl: 'https://pub.dev/packages/bloc_signals_lint',
    installCmd: 'dart pub add --dev bloc_signals_lint',
  ),
];

class const PackageCatalog({super.key}) extends StatefulComponent {
  @override
  State<PackageCatalog> createState() => _PackageCatalogState();
}

class _PackageCatalogState() extends State<PackageCatalog> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String? _copiedPackage;
  Timer? _copyTimer;

  static const List<String> _categories = [
    'All',
    'Core & UI',
    'State & Interop',
    'DevTools & Tooling',
  ];

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _selectCategory(String category) {
    if (_selectedCategory != category) {
      setState(() {
        _selectedCategory = category;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All';
      _searchQuery = '';
    });
  }

  void _copyCommand(PackageItem pkg) {
    try {
      web.window.navigator.clipboard.writeText(pkg.installCmd);
    } catch (_) {
      // Ignore if clipboard API is restricted in headless/iframe contexts.
    }
    setState(() {
      _copiedPackage = pkg.name;
    });
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (_copiedPackage == pkg.name) {
            _copiedPackage = null;
          }
        });
      }
    });
  }

  int _countForCategory(String category) {
    if (category == 'All') return _allPackages.length;
    return _allPackages.where((p) => p.category == category).length;
  }

  @override
  Component build(BuildContext context) {
    final filtered = _allPackages.where((pkg) {
      final matchesCat =
          _selectedCategory == 'All' || pkg.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          pkg.name.toLowerCase().contains(q) ||
          pkg.desc.toLowerCase().contains(q) ||
          pkg.category.toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();

    return section(id: 'packages', classes: 'packages-section', [
      div(classes: 'container', [
        h2(classes: 'section-title', [
          Component.text('The '),
          span(classes: 'gradient-text', [
            Component.text('BlocSignal Ecosystem'),
          ]),
        ]),
        p(classes: 'section-subtitle', [
          Component.text(
            'Modular, zero-dependency core with first-class interop packages.',
          ),
        ]),

        // Search Bar & Filter Controls
        div(classes: 'catalog-controls', [
          div(classes: 'catalog-search-wrapper', [
            span(classes: 'search-icon', [Component.text('🔍')]),
            input(
              type: InputType.text,
              classes: 'catalog-search-input',
              value: _searchQuery,
              onInput: _onSearchChanged,
              attributes: {
                'placeholder': 'Search packages (e.g. hydrate, flutter, riverpod, otel)...',
                'aria-label': 'Search packages',
              },
            ),
            if (_searchQuery.isNotEmpty)
              button(
                classes: 'search-clear-btn',
                onClick: () => _onSearchChanged(''),
                attributes: {'aria-label': 'Clear search'},
                [Component.text('✕')],
              ),
          ]),
          div(classes: 'category-pills-list', [
            for (final cat in _categories)
              button(
                classes:
                    'category-pill-btn ${_selectedCategory == cat ? "active" : ""}',
                onClick: () => _selectCategory(cat),
                [
                  span(classes: 'pill-label', [Component.text(cat)]),
                  span(classes: 'pill-badge', [
                    Component.text('${_countForCategory(cat)}'),
                  ]),
                ],
              ),
          ]),
        ]),

        // Package Grid or Empty State
        if (filtered.isNotEmpty)
          div(classes: 'package-grid', [
            for (final pkg in filtered)
              div(classes: 'package-card', [
                div(classes: 'package-header', [
                  div(classes: 'pkg-header-left', [
                    span(classes: 'package-icon', [Component.text(pkg.icon)]),
                    span(classes: 'package-category-tag', [
                      Component.text(pkg.category),
                    ]),
                  ]),
                  span(classes: 'package-version', [
                    Component.text('v${pkg.version}'),
                  ]),
                ]),
                h3(classes: 'package-name', [Component.text(pkg.name)]),
                p(classes: 'package-desc', [Component.text(pkg.desc)]),
                div(classes: 'package-card-footer', [
                  button(
                    classes:
                        'btn-pkg-copy ${_copiedPackage == pkg.name ? "copied" : ""}',
                    onClick: () => _copyCommand(pkg),
                    attributes: {
                      'aria-label': 'Copy install command for ${pkg.name}',
                    },
                    [
                      span(classes: 'copy-icon', [
                        Component.text(_copiedPackage == pkg.name ? '✓' : '📋'),
                      ]),
                      span(classes: 'copy-text', [
                        Component.text(
                          _copiedPackage == pkg.name ? 'Copied' : 'Add',
                        ),
                      ]),
                    ],
                  ),
                  a(
                    href: pkg.pubUrl,
                    target: Target.blank,
                    classes: 'package-link',
                    [Component.text('pub.dev ↗')],
                  ),
                ]),
              ]),
          ])
        else
          div(classes: 'catalog-empty-state', [
            span(classes: 'empty-icon', [Component.text('📦')]),
            h3(classes: 'empty-title', [
              Component.text('No packages found matching "$_searchQuery"'),
            ]),
            p(classes: 'empty-desc', [
              Component.text(
                'Try searching with different keywords or resetting filters.',
              ),
            ]),
            button(classes: 'btn-reset-filters', onClick: _clearFilters, [
              Component.text('Reset Filters 🔄'),
            ]),
          ]),
      ]),
    ]);
  }
}
