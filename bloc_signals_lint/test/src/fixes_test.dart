import 'package:bloc_signals_lint/src/fixes/add_super_on_event_fix.dart';
import 'package:bloc_signals_lint/src/fixes/avoid_raw_signal_effects_in_bloc_fix.dart';
import 'package:bloc_signals_lint/src/fixes/prefer_read_in_callbacks_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_watch_with_read_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_cubit_signal_mixin_init_fix.dart';
import 'package:bloc_signals_lint/src/fixes/use_provider_value_fix.dart';
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

    test('RequireCubitSignalMixinInitFix instantiates cleanly', () {
      final fix = RequireCubitSignalMixinInitFix();
      expect(fix, isA<RequireCubitSignalMixinInitFix>());
    });

    test('ReplaceContextWatchWithReadFix instantiates cleanly', () {
      final fix = ReplaceContextWatchWithReadFix();
      expect(fix, isA<ReplaceContextWatchWithReadFix>());
    });

    test('AvoidRawSignalEffectsInBlocFix instantiates cleanly', () {
      final fix = AvoidRawSignalEffectsInBlocFix();
      expect(fix, isA<AvoidRawSignalEffectsInBlocFix>());
    });

    test('UseProviderValueFix instantiates cleanly', () {
      final fix = UseProviderValueFix();
      expect(fix, isA<UseProviderValueFix>());
    });
  });
}
