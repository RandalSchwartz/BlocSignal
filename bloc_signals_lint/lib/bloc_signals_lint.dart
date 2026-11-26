import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:bloc_signals_lint/src/fixes/add_super_on_event_fix.dart';
import 'package:bloc_signals_lint/src/fixes/avoid_raw_signal_effects_in_bloc_fix.dart';
import 'package:bloc_signals_lint/src/fixes/prefer_read_in_callbacks_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_watch_with_read_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_positional_replay_constructor_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_cubit_signal_mixin_init_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_emit_in_helper_name_fix.dart';
import 'package:bloc_signals_lint/src/fixes/use_provider_value_fix.dart';
import 'package:bloc_signals_lint/src/rules/avoid_bridging_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_context_watch_for_bloc_state.dart';
import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_or_add_in_computed.dart';
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

/// Top-level plugin instance discovered by the Dart Analysis Server.
final plugin = BlocSignalsPlugin();

/// Analyzer plugin providing `BlocSignal` and `CubitSignal` rules and fixes.
class BlocSignalsPlugin extends Plugin {
  /// Creates a [BlocSignalsPlugin] instance.
  new();

  @override
  String get name => 'bloc_signals_lint';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(AvoidDuplicateEventHandlers())
      ..registerWarningRule(RequireSuperOnEvent())
      ..registerWarningRule(AvoidStreamTransformersOnBlocSignal())
      ..registerWarningRule(AvoidDirectSignalMutationOutsideBloc())
      ..registerWarningRule(AvoidEmitInBuild())
      ..registerWarningRule(AvoidUnmanagedSignalEffects())
      ..registerWarningRule(PreferBlocSignalProviderReadInCallbacks())
      ..registerWarningRule(AvoidTopLevelBlocSignalInstances())
      ..registerWarningRule(AvoidProvidingExistingInstanceWithCreate())
      ..registerWarningRule(AvoidManualCloseOnProvidedBloc())
      ..registerWarningRule(AvoidInvalidContextSelectGenerics())
      ..registerWarningRule(RequireCubitSignalMixinInit())
      ..registerWarningRule(AvoidContextWatchForBlocState())
      ..registerWarningRule(AvoidRawSignalEffectsInBloc())
      ..registerWarningRule(AvoidUnusedSelectResult())
      ..registerWarningRule(PreferNamedReplayConstructor())
      ..registerWarningRule(RequireEmitInHelperName())
      ..registerWarningRule(AvoidMultipleSynchronousEmits())
      ..registerWarningRule(AvoidPrimitiveEventTypes())
      ..registerWarningRule(AvoidPseudoEventsInTelemetry())
      ..registerWarningRule(AvoidBridgingInBuild())
      ..registerWarningRule(AvoidEmitOrAddInComputed())
      ..registerFixForRule(RequireSuperOnEvent.code, AddSuperOnEventFix.new)
      ..registerFixForRule(
        AvoidRawSignalEffectsInBloc.code,
        AvoidRawSignalEffectsInBlocFix.new,
      )
      ..registerFixForRule(
        PreferBlocSignalProviderReadInCallbacks.code,
        PreferReadInCallbacksFix.new,
      )
      ..registerFixForRule(
        AvoidContextWatchForBlocState.code,
        ReplaceContextWatchWithReadFix.new,
      )
      ..registerFixForRule(
        PreferNamedReplayConstructor.code,
        ReplacePositionalReplayConstructorFix.new,
      )
      ..registerFixForRule(
        RequireCubitSignalMixinInit.code,
        RequireCubitSignalMixinInitFix.new,
      )
      ..registerFixForRule(
        RequireEmitInHelperName.code,
        RequireEmitInHelperNameFix.new,
      )
      ..registerFixForRule(
        AvoidProvidingExistingInstanceWithCreate.code,
        UseProviderValueFix.new,
      );
  }
}
