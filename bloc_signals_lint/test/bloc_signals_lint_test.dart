import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analysis_server_plugin/src/correction/fix_generators.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/bloc_signals_lint.dart';
import 'package:bloc_signals_lint/main.dart' as main_entrypoint;
import 'package:bloc_signals_lint/src/fixes/add_super_on_event_fix.dart';
import 'package:bloc_signals_lint/src/fixes/avoid_raw_signal_effects_in_bloc_fix.dart';
import 'package:bloc_signals_lint/src/fixes/prefer_read_in_callbacks_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_watch_with_read_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_positional_replay_constructor_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_cubit_signal_mixin_init_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_emit_in_helper_name_fix.dart';
import 'package:bloc_signals_lint/src/fixes/use_provider_value_fix.dart';
import 'package:bloc_signals_lint/src/rules/avoid_context_watch_for_bloc_state.dart';
import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_invalid_context_select_generics.dart';
import 'package:bloc_signals_lint/src/rules/avoid_manual_close_on_provided_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_multiple_synchronous_emits.dart';
import 'package:bloc_signals_lint/src/rules/avoid_primitive_event_types.dart';
import 'package:bloc_signals_lint/src/rules/avoid_providing_existing_instance_with_create.dart';
import 'package:bloc_signals_lint/src/rules/avoid_pseudo_events_in_telemetry.dart';
import 'package:bloc_signals_lint/src/rules/avoid_raw_signal_effects_in_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_stream_transformers_on_bloc_signal.dart';
import 'package:bloc_signals_lint/src/rules/avoid_top_level_bloc_signal_instances.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_effects.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unused_select_result.dart';
import 'package:bloc_signals_lint/src/rules/prefer_bloc_signal_provider_read_in_callbacks.dart';
import 'package:bloc_signals_lint/src/rules/prefer_named_replay_constructor.dart';
import 'package:bloc_signals_lint/src/rules/require_cubit_signal_mixin_init.dart';
import 'package:bloc_signals_lint/src/rules/require_emit_in_helper_name.dart';
import 'package:bloc_signals_lint/src/rules/require_super_on_event.dart';
import 'package:test/test.dart';

class _RecordingPluginRegistry implements PluginRegistry {
  final List<AbstractAnalysisRule> warningRules = [];
  final Map<DiagnosticCode, List<ProducerGenerator>> fixes = {};

  @override
  void registerWarningRule(AbstractAnalysisRule rule) {
    warningRules.add(rule);
  }

  @override
  void registerFixForRule(DiagnosticCode code, ProducerGenerator generator) {
    fixes.putIfAbsent(code, () => []).add(generator);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('bloc_signals_lint plugin entrypoint', () {
    test('plugin exposes BlocSignalsPlugin with 20 rules and 8 fixes', () {
      expect(plugin, isA<Plugin>());
      expect(plugin, isA<BlocSignalsPlugin>());
      expect(identical(main_entrypoint.plugin, plugin), isTrue);
      expect(plugin.name, equals('bloc_signals_lint'));

      final registry = _RecordingPluginRegistry();
      plugin.register(registry);

      final rules = registry.warningRules;
      expect(rules, hasLength(20));
      expect(rules, contains(isA<AvoidDuplicateEventHandlers>()));
      expect(rules, contains(isA<RequireSuperOnEvent>()));
      expect(rules, contains(isA<AvoidStreamTransformersOnBlocSignal>()));
      expect(rules, contains(isA<AvoidDirectSignalMutationOutsideBloc>()));
      expect(rules, contains(isA<AvoidEmitInBuild>()));
      expect(rules, contains(isA<AvoidUnmanagedSignalEffects>()));
      expect(rules, contains(isA<PreferBlocSignalProviderReadInCallbacks>()));
      expect(rules, contains(isA<AvoidTopLevelBlocSignalInstances>()));
      expect(rules, contains(isA<AvoidProvidingExistingInstanceWithCreate>()));
      expect(rules, contains(isA<AvoidManualCloseOnProvidedBloc>()));
      expect(rules, contains(isA<AvoidInvalidContextSelectGenerics>()));
      expect(rules, contains(isA<RequireCubitSignalMixinInit>()));
      expect(rules, contains(isA<AvoidContextWatchForBlocState>()));
      expect(rules, contains(isA<AvoidRawSignalEffectsInBloc>()));
      expect(rules, contains(isA<AvoidUnusedSelectResult>()));
      expect(rules, contains(isA<PreferNamedReplayConstructor>()));
      expect(rules, contains(isA<RequireEmitInHelperName>()));
      expect(rules, contains(isA<AvoidMultipleSynchronousEmits>()));
      expect(rules, contains(isA<AvoidPrimitiveEventTypes>()));
      expect(rules, contains(isA<AvoidPseudoEventsInTelemetry>()));

      expect(registry.fixes, hasLength(8));
    });
  });

  group('LintCode metadata assertions', () {
    test('AvoidDuplicateEventHandlers code is properly configured', () {
      final rule = AvoidDuplicateEventHandlers();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_duplicate_event_handlers'),
      );
    });

    test('RequireSuperOnEvent code is properly configured', () {
      final rule = RequireSuperOnEvent();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('require_super_on_event'),
      );
    });

    test('AvoidStreamTransformersOnBlocSignal code is properly configured', () {
      final rule = AvoidStreamTransformersOnBlocSignal();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_stream_transformers_on_bloc_signal'),
      );
    });

    test(
      'AvoidDirectSignalMutationOutsideBloc code is properly configured',
      () {
        final rule = AvoidDirectSignalMutationOutsideBloc();
        expect(
          rule.diagnosticCode.lowerCaseName,
          equals('avoid_direct_signal_mutation_outside_bloc'),
        );
      },
    );

    test('AvoidEmitInBuild code is properly configured', () {
      final rule = AvoidEmitInBuild();
      expect(rule.diagnosticCode.lowerCaseName, equals('avoid_emit_in_build'));
    });

    test('AvoidUnmanagedSignalEffects code is properly configured', () {
      final rule = AvoidUnmanagedSignalEffects();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_unmanaged_signal_effects'),
      );
    });

    test(
      'PreferBlocSignalProviderReadInCallbacks code is properly configured',
      () {
        final rule = PreferBlocSignalProviderReadInCallbacks();
        expect(
          rule.diagnosticCode.lowerCaseName,
          equals('prefer_bloc_signal_provider_read_in_callbacks'),
        );
      },
    );

    test('AvoidTopLevelBlocSignalInstances code is properly configured', () {
      final rule = AvoidTopLevelBlocSignalInstances();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_top_level_bloc_signal_instances'),
      );
    });

    test(
      'AvoidProvidingExistingInstanceWithCreate code is properly configured',
      () {
        final rule = AvoidProvidingExistingInstanceWithCreate();
        expect(
          rule.diagnosticCode.lowerCaseName,
          equals('avoid_providing_existing_instance_with_create'),
        );
      },
    );

    test('AvoidManualCloseOnProvidedBloc code is properly configured', () {
      final rule = AvoidManualCloseOnProvidedBloc();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_manual_close_on_provided_bloc'),
      );
    });

    test('AvoidInvalidContextSelectGenerics code is properly configured', () {
      final rule = AvoidInvalidContextSelectGenerics();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_invalid_context_select_generics'),
      );
    });

    test('RequireCubitSignalMixinInit code is properly configured', () {
      final rule = RequireCubitSignalMixinInit();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('require_cubit_signal_mixin_init'),
      );
    });

    test('AvoidContextWatchForBlocState code is properly configured', () {
      final rule = AvoidContextWatchForBlocState();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_context_watch_for_bloc_state'),
      );
    });

    test('AvoidRawSignalEffectsInBloc code is properly configured', () {
      final rule = AvoidRawSignalEffectsInBloc();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_raw_signal_effects_in_bloc'),
      );
    });

    test('AvoidUnusedSelectResult code is properly configured', () {
      final rule = AvoidUnusedSelectResult();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_unused_select_result'),
      );
    });

    test('PreferNamedReplayConstructor code is properly configured', () {
      final rule = PreferNamedReplayConstructor();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('prefer_named_replay_constructor'),
      );
    });

    test('RequireEmitInHelperName code is properly configured', () {
      final rule = RequireEmitInHelperName();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('require_emit_in_helper_name'),
      );
    });

    test('AvoidMultipleSynchronousEmits code is properly configured', () {
      final rule = AvoidMultipleSynchronousEmits();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_multiple_synchronous_emits'),
      );
    });

    test('AvoidPrimitiveEventTypes code is properly configured', () {
      final rule = AvoidPrimitiveEventTypes();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_primitive_event_types'),
      );
    });

    test('AvoidPseudoEventsInTelemetry code is properly configured', () {
      final rule = AvoidPseudoEventsInTelemetry();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_pseudo_events_in_telemetry'),
      );
    });
  });

  group('Rule Fix Association assertions', () {
    test(
      'rules with automated quick-fixes register expected Fix producers',
      () {
        final registry = _RecordingPluginRegistry();
        plugin.register(registry);

        expect(
          registry.fixes[PreferNamedReplayConstructor.code],
          contains(equals(ReplacePositionalReplayConstructorFix.new)),
        );
        expect(
          registry.fixes[RequireSuperOnEvent.code],
          contains(equals(AddSuperOnEventFix.new)),
        );
        expect(
          registry.fixes[PreferBlocSignalProviderReadInCallbacks.code],
          contains(equals(PreferReadInCallbacksFix.new)),
        );
        expect(
          registry.fixes[AvoidProvidingExistingInstanceWithCreate.code],
          contains(equals(UseProviderValueFix.new)),
        );
        expect(
          registry.fixes[RequireCubitSignalMixinInit.code],
          contains(equals(RequireCubitSignalMixinInitFix.new)),
        );
        expect(
          registry.fixes[AvoidContextWatchForBlocState.code],
          contains(equals(ReplaceContextWatchWithReadFix.new)),
        );
        expect(
          registry.fixes[AvoidRawSignalEffectsInBloc.code],
          contains(equals(AvoidRawSignalEffectsInBlocFix.new)),
        );
        expect(
          registry.fixes[RequireEmitInHelperName.code],
          contains(equals(RequireEmitInHelperNameFix.new)),
        );
      },
    );
  });
}
