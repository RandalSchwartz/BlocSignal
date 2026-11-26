@TestOn('vm || chrome')
import 'package:blocsignal_website/src/cubits/navigation_cubit.dart';
import 'package:blocsignal_website/src/models/app_route.dart';
import 'package:test/test.dart';

import 'navigation_browser_test_stub.dart'
    if (dart.library.js_interop) 'navigation_browser_test_web.dart';

void main() {
  group('(Issue #478) NavigationCubit Lifecycle & SSR Guard', () {
    late String originalHref;

    setUp(() {
      originalHref = captureBrowserHref();
    });

    tearDown(() {
      restoreBrowserHref(originalHref);
    });

    test('(Issue #478) constructs, navigates, ignores duplicate routes, and '
        'closes cleanly', () async {
      final cubit = NavigationCubit();
      addTearDown(cubit.close);
      expect(cubit.stateValue, equals(AppRoute.home));

      cubit.navigate(AppRoute.docs);
      expect(cubit.stateValue, equals(AppRoute.docs));

      // Navigating to the already active route is a no-op.
      cubit.navigate(AppRoute.docs);
      expect(cubit.stateValue, equals(AppRoute.docs));

      await cubit.close();
    });
  });

  registerBrowserNavigationTests();
}
