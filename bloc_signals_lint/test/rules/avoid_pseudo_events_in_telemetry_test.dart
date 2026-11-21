import 'package:bloc_signals_lint/src/rules/avoid_pseudo_events_in_telemetry.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('AvoidPseudoEventsInTelemetry Semantic Detection', () {
    test('rule metadata is properly configured', () {
      final rule = AvoidPseudoEventsInTelemetry();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_pseudo_events_in_telemetry'),
      );
      expect(
        rule.diagnosticCode.problemMessage,
        equals(
          'Avoid using pseudo-event action names ("{0}") in "emitTelemetry" '
          'inside a CubitSignal.',
        ),
      );
      expect(
        rule.diagnosticCode.correctionMessage,
        equals(
          'Telemetry should record operational occurrences or domain '
          'milestones, not simulate user UI events inside a Cubit. '
          'If event modeling is needed, migrate to BlocSignal.',
        ),
      );
    });

    test('detects Pressed pseudo-events in CubitSignal', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() {
    emitTelemetry('IncrementPressed');
    emit(stateValue + 1);
  }

  void decrement() {
    emitTelemetry('button_pressed');
    emit(stateValue - 1);
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPseudoEventsInTelemetry(),
        badCode,
      );
      expect(diagnostics, hasLength(2));
    });

    test('detects Clicked, Submitted, and Requested '
        'pseudo-events in CubitSignal', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class FormCubit extends CubitSignal<String> {
  FormCubit() : super(initialState: '');

  void submit() {
    emitTelemetry('SubmitClicked');
    emitTelemetry('form_submitted');
    emitTelemetry('RefreshRequested');
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPseudoEventsInTelemetry(),
        badCode,
      );
      expect(diagnostics, hasLength(3));
    });

    test(
      'detects Tapped, Swiped, and Event pseudo-events in CubitSignal',
      () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CardCubit extends CubitSignal<int> {
  CardCubit() : super(initialState: 0);

  void handleInteraction() {
    this.emitTelemetry('CardTapped');
    emitTelemetry('item_swiped');
    emitTelemetry('CounterEvent');
  }
}
''';
        final diagnostics = await runLintRule(
          AvoidPseudoEventsInTelemetry(),
          badCode,
        );
        expect(diagnostics, hasLength(3));
      },
    );

    test('detects pseudo-events in CubitSignalMixin and ReplayCubit', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

class BaseService {}

class ServiceCubit extends BaseService with CubitSignalMixin<int> {
  ServiceCubit() {
    initCubitSignal(initialState: 0);
  }

  void track() {
    emitTelemetry('SavePressed');
  }
}

class ReplayItemCubit extends ReplayCubit<int> {
  ReplayItemCubit() : super(initialState: 0);

  void act() {
    emitTelemetry('ActionRequested');
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPseudoEventsInTelemetry(),
        badCode,
      );
      expect(diagnostics, hasLength(2));
    });

    test('accepts legitimate operational telemetry in CubitSignal', () async {
      const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class OrderState {
  const OrderState._();
  factory OrderState.initial() => const OrderState._();
  factory OrderState.success() => const OrderState._();
}

class OrderCubit extends CubitSignal<OrderState> {
  OrderCubit() : super(initialState: OrderState.initial());

  void processOrder() {
    emitTelemetry('cache_hit', metadata: {'duration_ms': 12});
    emitTelemetry('sync_completed');
    emitTelemetry('token_expired');
    emitTelemetry('quota_warning');
    emitTelemetry('fraud_prevent');
    emit(OrderState.success());
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPseudoEventsInTelemetry(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });

    test('accepts telemetry in BlocSignal', () async {
      const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class OrderEvent {}
class OrderState {
  const OrderState._();
  factory OrderState.initial() => const OrderState._();
}

class OrderBloc extends BlocSignal<OrderEvent, OrderState> {
  OrderBloc() : super(initialState: OrderState.initial()) {
    on<OrderEvent>((event, emit) {
      emitTelemetry('OrderRequested');
    });
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPseudoEventsInTelemetry(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });

    test('accepts non-cubit classes with emitTelemetry methods', () async {
      const goodCode = '''
class TelemetryEmitter {
  void emitTelemetry(String name) {}
}

class Client {
  void run(TelemetryEmitter emitter) {
    emitter.emitTelemetry('ButtonPressed');
  }
}
''';
      final diagnostics = await runLintRule(
        AvoidPseudoEventsInTelemetry(),
        goodCode,
      );
      expect(diagnostics, isEmpty);
    });
  });
}
