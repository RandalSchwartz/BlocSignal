import 'dart:js_interop';

import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:web/web.dart' as web;

import '../models/app_route.dart';

@JS('trackGaPageView')
external void _trackGaPageView(JSString path);

/// Cubit managing client-side navigation route state and browser history.
class NavigationCubit() extends CubitSignal<AppRoute> {
  /// Creates a [NavigationCubit] initialized to the current URL route.
  this : super(initialState: _resolveCurrentRoute()) {
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

  static AppRoute _resolveCurrentRoute() {
    try {
      return AppRoute.fromLocation(
        path: web.window.location.pathname,
        hash: web.window.location.hash,
      );
    } catch (_) {
      return AppRoute.home;
    }
  }

  void _syncFromBrowser() {
    final next = _resolveCurrentRoute();
    if (next != stateValue) {
      emit(next);
      _trackPageView(next);
    }
  }

  /// Navigates to [targetRoute], pushing history state if in a browser.
  void navigate(AppRoute targetRoute) {
    if (stateValue == targetRoute) return;

    try {
      web.window.history.pushState(null, '', targetRoute.path);
    } catch (_) {
      // Fallback or non-browser context
    }

    emit(targetRoute);
    _trackPageView(targetRoute);
  }

  void _trackPageView(AppRoute route) {
    try {
      _trackGaPageView(route.path.toJS);
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
