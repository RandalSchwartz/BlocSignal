import 'package:blocsignal_website/src/cubits/navigation_cubit.dart';
import 'package:blocsignal_website/src/models/app_route.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// Captures the current browser `window.location.href`.
String captureBrowserHref() => web.window.location.href;

/// Restores a previously captured browser URL via `history.replaceState`.
void restoreBrowserHref(String href) {
  web.window.history.replaceState(null, '', href);
}

/// Registers Chrome-only `popstate`/`hashchange` synchronization and
/// post-`close()` detachment tests for [NavigationCubit].
void registerBrowserNavigationTests() {
  group(
    '(Issue #478) NavigationCubit Browser History & Listener Detachment',
    () {
      late String originalHref;

      setUp(() {
        originalHref = captureBrowserHref();
      });

      tearDown(() {
        restoreBrowserHref(originalHref);
      });

      test(
        '(Issue #478) syncs from popstate and hashchange events and detaches '
        'listeners on close()',
        () async {
          web.window.history.replaceState(null, '', '/');
          final cubit = NavigationCubit();
          addTearDown(cubit.close);
          expect(cubit.stateValue, equals(AppRoute.home));

          // Simulate browser history navigation via replaceState + popstate.
          web.window.history.replaceState(null, '', '/docs');
          web.window.dispatchEvent(web.PopStateEvent('popstate'));
          expect(cubit.stateValue, equals(AppRoute.docs));

          // Simulate hashchange navigation.
          web.window.history.replaceState(null, '', '/playground');
          web.window.dispatchEvent(web.HashChangeEvent('hashchange'));
          expect(cubit.stateValue, equals(AppRoute.playground));

          // Close cubit and verify listeners are detached.
          await cubit.close();
          web.window.history.replaceState(null, '', '/showcase');
          web.window.dispatchEvent(web.PopStateEvent('popstate'));
          web.window.dispatchEvent(web.HashChangeEvent('hashchange'));
          expect(cubit.stateValue, equals(AppRoute.playground));
        },
      );
    },
  );
}
