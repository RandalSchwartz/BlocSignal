import '../models/app_route.dart';

/// Platform browser bridge for [NavigationCubit] on non-browser (VM/SSR)
/// targets.
class NavigationBrowserBridge() {
  /// Resolves the current route, falling back to [AppRoute.home] on VM/SSR.
  AppRoute resolveCurrentRoute() => AppRoute.home;

  /// Registers browser navigation listeners (no-op on VM/SSR).
  void registerListeners(void Function() onSync) {}

  /// Unregisters browser navigation listeners (no-op on VM/SSR).
  void unregisterListeners() {}

  /// Pushes browser history state (no-op on VM/SSR).
  void pushState(String path) {}

  /// Tracks a page view in analytics (no-op on VM/SSR).
  void trackPageView(String path) {}
}
