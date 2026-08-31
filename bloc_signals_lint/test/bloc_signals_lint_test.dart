import 'package:bloc_signals_lint/bloc_signals_lint.dart';
import 'package:bloc_signals_lint/src/rules/avoid_context_watch_for_bloc_state.dart';
import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_invalid_context_select_generics.dart';
import 'package:bloc_signals_lint/src/rules/avoid_manual_close_on_provided_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_providing_existing_instance_with_create.dart';
import 'package:bloc_signals_lint/src/rules/avoid_raw_signal_effects_in_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_stream_transformers_on_bloc_signal.dart';
import 'package:bloc_signals_lint/src/rules/avoid_top_level_bloc_signal_instances.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_effects.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unused_select_result.dart';
import 'package:bloc_signals_lint/src/rules/prefer_bloc_signal_provider_read_in_callbacks.dart';
import 'package:bloc_signals_lint/src/rules/require_cubit_signal_mixin_init.dart';
import 'package:bloc_signals_lint/src/rules/require_super_on_event.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  group('bloc_signals_lint plugin entrypoint', () {
    test('createPlugin returns PluginBase with 15 core and UI rules', () {
      final plugin = createPlugin();
      expect(plugin, isA<PluginBase>());

      /// Ignore internal member usage for testing.
      // ignore: invalid_use_of_internal_member
      final rules = plugin.getLintRules(CustomLintConfigs.empty);
      expect(rules, hasLength(15));
      expect(rules, contains(isA<AvoidDuplicateEventHandlers>()));
      expect(rules, contains(isA<RequireSuperOnEvent>()));
      expect(rules, contains(isA<AvoidStreamTransformersOnBlocSignal>()));
      expect(rules, contains(isA<AvoidDirectSignalMutationOutsideBloc>()));
      expect(rules, contains(isA<AvoidEmitInBuild>()));
      expect(rules, contains(isA<AvoidUnmanagedSignalEffects>()));
      expect(
        rules,
        contains(isA<PreferBlocSignalProviderReadInCallbacks>()),
      );
      expect(rules, contains(isA<AvoidTopLevelBlocSignalInstances>()));
      expect(rules, contains(isA<AvoidProvidingExistingInstanceWithCreate>()));
      expect(rules, contains(isA<AvoidManualCloseOnProvidedBloc>()));
      expect(rules, contains(isA<AvoidInvalidContextSelectGenerics>()));
      expect(rules, contains(isA<RequireCubitSignalMixinInit>()));
      expect(rules, contains(isA<AvoidContextWatchForBlocState>()));
      expect(rules, contains(isA<AvoidRawSignalEffectsInBloc>()));
      expect(rules, contains(isA<AvoidUnusedSelectResult>()));
    });
  });

  group('LintCode metadata assertions', () {
    test('AvoidDuplicateEventHandlers code is properly configured', () {
      const rule = AvoidDuplicateEventHandlers();
      expect(rule.code.name, equals('avoid_duplicate_event_handlers'));
    });

    test('RequireSuperOnEvent code is properly configured', () {
      const rule = RequireSuperOnEvent();
      expect(rule.code.name, equals('require_super_on_event'));
    });

    test('AvoidStreamTransformersOnBlocSignal code is properly configured', () {
      const rule = AvoidStreamTransformersOnBlocSignal();
      expect(
        rule.code.name,
        equals('avoid_stream_transformers_on_bloc_signal'),
      );
    });

    test('AvoidDirectSignalMutationOutsideBloc code is properly configured',
        () {
      const rule = AvoidDirectSignalMutationOutsideBloc();
      expect(
        rule.code.name,
        equals('avoid_direct_signal_mutation_outside_bloc'),
      );
    });

    test('AvoidEmitInBuild code is properly configured', () {
      const rule = AvoidEmitInBuild();
      expect(rule.code.name, equals('avoid_emit_in_build'));
    });

    test('AvoidUnmanagedSignalEffects code is properly configured', () {
      const rule = AvoidUnmanagedSignalEffects();
      expect(rule.code.name, equals('avoid_unmanaged_signal_effects'));
    });

    test('PreferBlocSignalProviderReadInCallbacks code is properly configured',
        () {
      const rule = PreferBlocSignalProviderReadInCallbacks();
      expect(
        rule.code.name,
        equals('prefer_bloc_signal_provider_read_in_callbacks'),
      );
    });

    test('AvoidTopLevelBlocSignalInstances code is properly configured', () {
      const rule = AvoidTopLevelBlocSignalInstances();
      expect(
        rule.code.name,
        equals('avoid_top_level_bloc_signal_instances'),
      );
    });

    test('AvoidProvidingExistingInstanceWithCreate code is properly configured',
        () {
      const rule = AvoidProvidingExistingInstanceWithCreate();
      expect(
        rule.code.name,
        equals('avoid_providing_existing_instance_with_create'),
      );
    });

    test('AvoidManualCloseOnProvidedBloc code is properly configured', () {
      const rule = AvoidManualCloseOnProvidedBloc();
      expect(
        rule.code.name,
        equals('avoid_manual_close_on_provided_bloc'),
      );
    });

    test('AvoidInvalidContextSelectGenerics code is properly configured', () {
      const rule = AvoidInvalidContextSelectGenerics();
      expect(
        rule.code.name,
        equals('avoid_invalid_context_select_generics'),
      );
    });

    test('RequireCubitSignalMixinInit code is properly configured', () {
      const rule = RequireCubitSignalMixinInit();
      expect(
        rule.code.name,
        equals('require_cubit_signal_mixin_init'),
      );
    });

    test('AvoidContextWatchForBlocState code is properly configured', () {
      const rule = AvoidContextWatchForBlocState();
      expect(
        rule.code.name,
        equals('avoid_context_watch_for_bloc_state'),
      );
    });

    test('AvoidRawSignalEffectsInBloc code is properly configured', () {
      const rule = AvoidRawSignalEffectsInBloc();
      expect(
        rule.code.name,
        equals('avoid_raw_signal_effects_in_bloc'),
      );
    });

    test('AvoidUnusedSelectResult code is properly configured', () {
      const rule = AvoidUnusedSelectResult();
      expect(
        rule.code.name,
        equals('avoid_unused_select_result'),
      );
    });
  });
}
