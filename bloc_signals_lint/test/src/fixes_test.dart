import 'package:bloc_signals_lint/src/fixes/add_super_on_event_fix.dart';
import 'package:bloc_signals_lint/src/fixes/prefer_read_in_callbacks_fix.dart';
import 'package:test/test.dart';

void main() {
  group('IDE Quick Fix Metadata & Construction Assertions', () {
    test('AddSuperOnEventFix instantiates cleanly', () {
      final fix = AddSuperOnEventFix();
      expect(fix, isA<AddSuperOnEventFix>());
    });

    test('PreferReadInCallbacksFix instantiates cleanly', () {
      final fix = PreferReadInCallbacksFix();
      expect(fix, isA<PreferReadInCallbacksFix>());
    });
  });
}
