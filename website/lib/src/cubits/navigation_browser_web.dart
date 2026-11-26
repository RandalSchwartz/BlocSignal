import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/app_route.dart';

@JS('trackGaPageView')
external void _trackGaPageView(JSString path);

/// Platform browser bridge for [NavigationCubit] on `dart:js_interop` targets.
class NavigationBrowserBridge() {
  JSFunction? _popStateListener;
  JSFunction? _hashChangeListener;

  /// Resolves the current route from `window.location`.
  AppRoute resolveCurrentRoute() {
    // Intentional on Object catch (SCAR-ERR-02): web.window throws
    // UnsupportedError during Jaspr SSR pre-rendering.
    try {
      return AppRoute.fromLocation(
        path: web.window.location.pathname,
        hash: web.window.location.hash,
      );
    } on Object catch (_) {
      return AppRoute.home;
    }
  }

  /// Registers `popstate` and `hashchange` listeners on `window`.
  void registerListeners(void Function() onSync) {
    // Intentional on Object catch (SCAR-ERR-02): web.window and Function.toJS
    // throw UnsupportedError during Jaspr SSR pre-rendering.
    try {
      final popListener = ((web.Event _) {
        onSync();
      }).toJS;
      final hashListener = ((web.Event _) {
        onSync();
      }).toJS;
      web.window.addEventListener('popstate', popListener);
      web.window.addEventListener('hashchange', hashListener);
      _popStateListener = popListener;
      _hashChangeListener = hashListener;
    } on Object catch (_) {
      // Ignore in SSR or non-browser environments.
    }
  }

  /// Unregisters `popstate` and `hashchange` listeners from `window`.
  void unregisterListeners() {
    // Intentional on Object catch (SCAR-ERR-02): web.window throws
    // UnsupportedError during Jaspr SSR pre-rendering.
    try {
      final popListener = _popStateListener;
      if (popListener != null) {
        web.window.removeEventListener('popstate', popListener);
      }
      final hashListener = _hashChangeListener;
      if (hashListener != null) {
        web.window.removeEventListener('hashchange', hashListener);
      }
    } on Object catch (_) {}
  }

  /// Pushes a new browser history entry for [path].
  void pushState(String path) {
    // Intentional on Object catch (SCAR-ERR-02): web.window throws
    // UnsupportedError during Jaspr SSR pre-rendering.
    try {
      web.window.history.pushState(null, '', path);
    } on Object catch (_) {
      // Fallback or non-browser context.
    }
  }

  /// Tracks a page view via `window.trackGaPageView`.
  void trackPageView(String path) {
    // Intentional on Object catch (SCAR-ERR-02): JS interop binding throws
    // when invoked outside a browser or during Jaspr SSR pre-rendering.
    try {
      _trackGaPageView(path.toJS);
    } on Object catch (_) {
      // Ignore if outside browser or JS binding is unavailable.
    }
  }
}
