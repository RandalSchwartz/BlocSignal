import 'dart:js_interop';

import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:web/web.dart' as web;

@JS('trackGaPageView')
external void _trackGaPageView(JSString path);

/// Cubit managing client-side navigation route state and browser history.
class NavigationCubit() extends CubitSignal<String> {
  /// Creates a [NavigationCubit] initialized to the current URL route.
  this : super(initialState: _resolveCurrentPath()) {
    _popStateListener = ((web.Event _) {
      _syncFromBrowser();
    }).toJS;
    _hashChangeListener = ((web.Event _) {
      _syncFromBrowser();
    }).toJS;

    web.window.addEventListener('popstate', _popStateListener);
    web.window.addEventListener('hashchange', _hashChangeListener);

    _trackPageView(stateValue);
  }

  late final JSFunction _popStateListener;
  late final JSFunction _hashChangeListener;

  static String _resolveCurrentPath() {
    try {
      final path = web.window.location.pathname;
      final rawHash = web.window.location.hash.toLowerCase();

      if (path == '/showcase' ||
          path.startsWith('/showcase') ||
          rawHash.contains('showcase')) {
        return '/showcase';
      } else if (path == '/ported-examples' ||
          path.startsWith('/ported-examples') ||
          rawHash.contains('ported-examples') ||
          rawHash.contains('ported')) {
        return '/ported-examples';
      } else if (path == '/minesweeper' ||
          path.startsWith('/minesweeper') ||
          rawHash.contains('minesweeper')) {
        return '/minesweeper';
      } else if (path == '/publications' ||
          path.startsWith('/publications') ||
          rawHash.contains('publications')) {
        return '/publications';
      }
      return '/';
    } catch (_) {
      return '/';
    }
  }

  void _syncFromBrowser() {
    final next = _resolveCurrentPath();
    if (next != stateValue) {
      emit(next);
      _trackPageView(next);
    }
  }

  /// Navigates to [targetRoute], pushing history state if in a browser.
  void navigate(String targetRoute) {
    if (stateValue == targetRoute) return;

    try {
      web.window.history.pushState(null, '', targetRoute);
    } catch (_) {
      // Fallback or non-browser context
    }

    emit(targetRoute);
    _trackPageView(targetRoute);
  }

  void _trackPageView(String route) {
    try {
      _trackGaPageView(route.toJS);
    } catch (_) {
      // Ignore if outside browser or JS binding is unavailable.
    }
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
