import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';

import '../models/app_route.dart';
import 'navigation_browser_stub.dart'
    if (dart.library.js_interop) 'navigation_browser_web.dart';

/// Cubit managing client-side navigation route state and browser history.
class NavigationCubit._(final NavigationBrowserBridge _browser)
    extends CubitSignal<AppRoute> {
  /// Creates a [NavigationCubit] initialized to the current URL route.
  factory() => NavigationCubit._(NavigationBrowserBridge());

  this : super(initialState: _browser.resolveCurrentRoute()) {
    _browser.registerListeners(_syncFromBrowser);
    _browser.trackPageView(stateValue.path);
  }

  void _syncFromBrowser() {
    final next = _browser.resolveCurrentRoute();
    if (next != stateValue) {
      emit(next);
      _browser.trackPageView(next.path);
    }
  }

  /// Navigates to [targetRoute], pushing history state if in a browser.
  void navigate(AppRoute targetRoute) {
    if (stateValue == targetRoute) return;

    _browser.pushState(targetRoute.path);
    emit(targetRoute);
    _browser.trackPageView(targetRoute.path);
  }

  @override
  Future<void> close() async {
    _browser.unregisterListeners();
    await super.close();
  }
}
