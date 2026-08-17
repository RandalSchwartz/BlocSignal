import 'dart:js_interop';

import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:web/web.dart' as web;

import '../models/docs_models.dart';
import '../models/docs_registry.dart';

@JS('trackGaPageView')
external void _trackGaPageView(JSString path);

/// Cubit managing documentation hub state, active article, search filters, and mobile drawer.
class DocsCubit({String? initialSectionId}) extends CubitSignal<DocsState> {
  this
    : super(
        initialState: DocsState(
          activeSectionId:
              initialSectionId ?? _resolveInitialSectionFromBrowser(),
          searchQuery: '',
          expandedCategories: {
            'Getting Started',
            'Core Concepts',
            'Flutter Integration',
          },
          isMobileDrawerOpen: false,
          selectedDartVersion: '3.13',
        ),
      ) {
    _popStateListener = ((web.Event _) {
      _syncFromBrowser();
    }).toJS;
    _hashChangeListener = ((web.Event _) {
      _syncFromBrowser();
    }).toJS;

    try {
      web.window.addEventListener('popstate', _popStateListener);
      web.window.addEventListener('hashchange', _hashChangeListener);
    } catch (_) {}

    _trackDocsPageView(stateValue.activeSectionId);
  }

  late final JSFunction _popStateListener;
  late final JSFunction _hashChangeListener;

  static String _resolveInitialSectionFromBrowser() {
    try {
      final path = web.window.location.pathname;
      final hash = web.window.location.hash;

      final pathSlug = _cleanSlug(path);
      if (pathSlug.isNotEmpty && pathSlug != 'docs') {
        return DocsRegistry.resolveSection(pathSlug).id;
      }

      final hashSlug = _cleanSlug(hash.replaceFirst('#', ''));
      if (hashSlug.isNotEmpty && hashSlug != 'docs') {
        return DocsRegistry.resolveSection(hashSlug).id;
      }
    } catch (_) {}
    return 'overview';
  }

  static String _cleanSlug(String raw) {
    var s = raw.trim();
    if (s.startsWith('/')) s = s.substring(1);
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (s.endsWith('/index.html')) {
      s = s.substring(0, s.length - '/index.html'.length);
    } else if (s.endsWith('index.html')) {
      s = s.substring(0, s.length - 'index.html'.length);
    }
    if (s.startsWith('docs/')) {
      s = s.substring('docs/'.length);
    } else if (s == 'docs') {
      s = '';
    }
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.trim();
  }

  void _syncFromBrowser() {
    final nextId = _resolveInitialSectionFromBrowser();
    if (nextId != stateValue.activeSectionId) {
      emit(stateValue.copyWith(activeSectionId: nextId));
      _trackDocsPageView(nextId);
    }
  }

  /// Selects a new active documentation section.
  void selectSection(String sectionId, {bool pushHistory = true}) {
    final targetSection = DocsRegistry.resolveSection(sectionId);

    if (stateValue.activeSectionId == targetSection.id) {
      if (stateValue.isMobileDrawerOpen) {
        closeMobileDrawer();
      }
      return;
    }

    if (pushHistory) {
      try {
        web.window.history.pushState(null, '', targetSection.path);
      } catch (_) {}
    }

    // Ensure category of target section is expanded
    final updatedCategories = Set<String>.from(stateValue.expandedCategories)
      ..add(targetSection.category);

    emit(
      stateValue.copyWith(
        activeSectionId: targetSection.id,
        expandedCategories: updatedCategories,
        isMobileDrawerOpen: false,
      ),
    );

    _trackDocsPageView(targetSection.id);

    // Scroll to top of article
    try {
      web.window.scrollTo(web.ScrollToOptions(top: 0, left: 0));
    } catch (_) {}
  }

  /// Updates navigation search query.
  void updateSearch(String query) {
    emit(stateValue.copyWith(searchQuery: query));
  }

  /// Toggles expansion of a navigation category.
  void toggleCategory(String categoryTitle) {
    final updated = Set<String>.from(stateValue.expandedCategories);
    if (updated.contains(categoryTitle)) {
      updated.remove(categoryTitle);
    } else {
      updated.add(categoryTitle);
    }
    emit(stateValue.copyWith(expandedCategories: updated));
  }

  /// Toggles mobile docs navigation drawer.
  void toggleMobileDrawer() {
    emit(
      stateValue.copyWith(isMobileDrawerOpen: !stateValue.isMobileDrawerOpen),
    );
  }

  /// Closes mobile docs navigation drawer.
  void closeMobileDrawer() {
    if (stateValue.isMobileDrawerOpen) {
      emit(stateValue.copyWith(isMobileDrawerOpen: false));
    }
  }

  /// Changes the globally preferred Dart code version ('3.13' or '3.5').
  void setDartVersion(String version) {
    if (version != stateValue.selectedDartVersion) {
      emit(stateValue.copyWith(selectedDartVersion: version));
    }
  }

  void _trackDocsPageView(String sectionId) {
    try {
      _trackGaPageView('/docs/$sectionId'.toJS);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    try {
      web.window.removeEventListener('popstate', _popStateListener);
      web.window.removeEventListener('hashchange', _hashChangeListener);
    } catch (_) {}
    await super.close();
  }
}
