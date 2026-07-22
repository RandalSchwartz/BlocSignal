import 'package:bloc_signals_lint/bloc_signals_lint.dart';
import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/avoid_duplicate_event_handlers.dart';
import 'package:bloc_signals_lint/src/rules/avoid_stream_transformers_on_bloc_signal.dart';
import 'package:bloc_signals_lint/src/rules/require_super_on_event.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  group('bloc_signals_lint plugin entrypoint', () {
    test('createPlugin returns PluginBase with 4 core rules', () {
      final plugin = createPlugin();
      expect(plugin, isA<PluginBase>());

      /// Ignore internal member usage for testing.
      // ignore: invalid_use_of_internal_member
      final rules = plugin.getLintRules(CustomLintConfigs.empty);
      expect(rules, hasLength(4));
      expect(rules, contains(isA<AvoidDuplicateEventHandlers>()));
      expect(rules, contains(isA<RequireSuperOnEvent>()));
      expect(rules, contains(isA<AvoidStreamTransformersOnBlocSignal>()));
      expect(rules, contains(isA<AvoidDirectSignalMutationOutsideBloc>()));
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
  });
}
