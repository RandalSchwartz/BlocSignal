import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/rules/avoid_pseudo_events_in_telemetry.dart';
import 'package:test/test.dart';

void main() {
  group('AvoidPseudoEventsInTelemetry AST Detection', () {
    test('rule metadata is properly configured', () {
      const rule = AvoidPseudoEventsInTelemetry();
      expect(rule.code.name, equals('avoid_pseudo_events_in_telemetry'));
      expect(
        rule.code.problemMessage,
        equals(
          'Avoid using pseudo-event action names ("{0}") in "emitTelemetry" '
          'inside a CubitSignal.',
        ),
      );
      expect(
        rule.code.correctionMessage,
        equals(
          'Telemetry should record operational occurrences or domain '
          'milestones, not simulate user UI events inside a Cubit. '
          'If event modeling is needed, migrate to BlocSignal.',
        ),
      );
    });

    test('detects Pressed pseudo-events in CubitSignal', () {
      const badCode = '''
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
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPseudoEventsInTelemetry.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(2));
    });

    test(
        'detects Clicked, Submitted, and Requested '
        'pseudo-events in CubitSignal', () {
      const badCode = '''
class FormCubit extends CubitSignal<String> {
  FormCubit() : super(initialState: '');

  void submit() {
    emitTelemetry('SubmitClicked');
    emitTelemetry('form_submitted');
    emitTelemetry('RefreshRequested');
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPseudoEventsInTelemetry.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(3));
    });

    test('detects Tapped, Swiped, and Event pseudo-events in CubitSignal', () {
      const badCode = '''
class CardCubit extends CubitSignal<int> {
  CardCubit() : super(initialState: 0);

  void handleInteraction() {
    this.emitTelemetry('CardTapped');
    emitTelemetry('item_swiped');
    emitTelemetry('CounterEvent');
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPseudoEventsInTelemetry.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(3));
    });

    test('detects pseudo-events in CubitSignalMixin and ReplayCubit', () {
      const badCode = '''
class ServiceCubit extends BaseService with CubitSignalMixin<int> {
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
      final parseResult = parseString(content: badCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPseudoEventsInTelemetry.findViolations(declaration));
      }

      expect(flaggedNodes, hasLength(2));
    });

    test('accepts legitimate operational telemetry in CubitSignal', () {
      const goodCode = '''
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
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPseudoEventsInTelemetry.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts telemetry in BlocSignal', () {
      const goodCode = '''
class OrderBloc extends BlocSignal<OrderEvent, OrderState> {
  OrderBloc() : super(initialState: OrderState.initial()) {
    on<OrderEvent>((event, emit) {
      emitTelemetry('OrderRequested');
    });
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPseudoEventsInTelemetry.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });

    test('accepts non-cubit classes with emitTelemetry methods', () {
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
      final parseResult = parseString(content: goodCode);
      final flaggedNodes = <AstNode>[];

      for (final declaration
          in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
        flaggedNodes
            .addAll(AvoidPseudoEventsInTelemetry.findViolations(declaration));
      }

      expect(flaggedNodes, isEmpty);
    });
  });
}
