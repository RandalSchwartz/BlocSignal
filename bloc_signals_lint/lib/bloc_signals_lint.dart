import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_in_build.dart';
import 'package:bloc_signals_lint/src/rules/avoid_stream_transformers_on_bloc_signal.dart';
import 'package:bloc_signals_lint/src/rules/avoid_unmanaged_signal_effects.dart';
import 'package:bloc_signals_lint/src/rules/prefer_bloc_signal_provider_read_in_callbacks.dart';
import 'package:bloc_signals_lint/src/rules/require_super_on_event.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Entrypoint for the `bloc_signals_lint` custom linter plugin.
PluginBase createPlugin() => _BlocSignalsLinter();

class _BlocSignalsLinter extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const AvoidDuplicateEventHandlers(),
        const RequireSuperOnEvent(),
        const AvoidStreamTransformersOnBlocSignal(),
        const AvoidDirectSignalMutationOutsideBloc(),
        const AvoidEmitInBuild(),
        const AvoidUnmanagedSignalEffects(),
        const PreferBlocSignalProviderReadInCallbacks(),
      ];
}
