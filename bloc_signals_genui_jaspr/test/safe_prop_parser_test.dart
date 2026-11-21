import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:test/test.dart';

void main() {
  group('safe_prop_parser tests', () {
    test('unwrapBinding unwraps nested ResolvedBinding instances', () {
      const inner = 'hello';
      const bound1 = ResolvedBinding<Object?>(inner);
      const bound2 = ResolvedBinding<Object?>(bound1);

      expect(unwrapBinding(bound2), equals('hello'));
      expect(unwrapBinding('plain'), equals('plain'));
      expect(unwrapBinding(null), isNull);
    });

    test('asDouble coerces various types and falls back to default', () {
      expect(asDouble(3.14), equals(3.14));
      expect(asDouble(42), equals(42.0));
      expect(asDouble('3.14'), equals(3.14));
      expect(asDouble('invalid', 1.5), equals(1.5));
      expect(asDouble(null, 2), equals(2.0));
      expect(
        asDouble(const ResolvedBinding<Object?>('9.99')),
        equals(9.99),
      );
    });

    test('asInt coerces various types and falls back to default', () {
      expect(asInt(42), equals(42));
      expect(asInt(42.9), equals(42));
      expect(asInt('123'), equals(123));
      expect(asInt('invalid', 5), equals(5));
      expect(asInt(null, 10), equals(10));
      expect(
        asInt(const ResolvedBinding<Object?>('99')),
        equals(99),
      );
    });

    test('asString coerces various types and falls back to default', () {
      expect(asString('hello'), equals('hello'));
      expect(asString(123), equals('123'));
      expect(asString(null, 'default'), equals('default'));
      expect(
        asString(const ResolvedBinding<Object?>('wrapped')),
        equals('wrapped'),
      );
    });

    test('asBool parses booleans and strings correctly', () {
      expect(asBool(true), isTrue);
      expect(asBool(false), isFalse);
      expect(asBool('true'), isTrue);
      expect(asBool('TRUE'), isTrue);
      expect(asBool('  true  '), isTrue);
      expect(asBool('false'), isFalse);
      expect(asBool('FALSE'), isFalse);
      expect(asBool('other', defaultValue: true), isTrue);
      expect(asBool('other'), isFalse);
      expect(asBool(null, defaultValue: true), isTrue);
      expect(
        asBool(const ResolvedBinding<Object?>('true')),
        isTrue,
      );
      expect(
        asBool(const ValidationResult(valid: true, message: '')),
        isTrue,
      );
      expect(
        asBool(const ValidationResult(valid: false, message: 'Bad')),
        isFalse,
      );
      expect(asBool(const {'valid': true}), isTrue);
      expect(asBool(const {'valid': false}), isFalse);
      expect(asBool(1), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool(double.nan), isFalse);
    });

    test('extractChildId extracts ID from various formats', () {
      expect(extractChildId(null), isNull);
      expect(extractChildId('btn_1'), equals('btn_1'));
      expect(
        extractChildId(ChildNode('child_node_1', '/')),
        equals('child_node_1'),
      );
      expect(extractChildId({'id': 'map_id_1'}), equals('map_id_1'));
      expect(extractChildId({'id': null}), isNull);
      expect(
        extractChildId(const ResolvedBinding<Object?>('bound_id')),
        equals('bound_id'),
      );
      expect(
        extractChildId({'id': const ResolvedBinding<Object?>('nested_id')}),
        equals('nested_id'),
      );
    });

    test('extractChildIds handles lists, bindings, and non-iterables', () {
      expect(extractChildIds(null), isEmpty);
      expect(extractChildIds('not_a_list'), isEmpty);
      expect(extractChildIds(<dynamic>[]), isEmpty);

      final result = extractChildIds([
        'item_1',
        ChildNode('item_2', '/'),
        {'id': 'item_3'},
        {'id': ''},
        null,
      ]);

      expect(result, equals(['item_1', 'item_2', 'item_3']));
      expect(
        extractChildIds(const ResolvedBinding<Object?>(['a', 'b'])),
        equals(['a', 'b']),
      );
    });

    group('(Issue #424) non-finite numeric guards', () {
      test(
          '(Issue #424) asDouble returns defaultValue for non-finite num and '
          'String inputs', () {
        expect(asDouble(double.nan, 7.5), equals(7.5));
        expect(asDouble(double.infinity, 7.5), equals(7.5));
        expect(asDouble(double.negativeInfinity, 7.5), equals(7.5));
        expect(asDouble('NaN', 7.5), equals(7.5));
        expect(asDouble('Infinity', 7.5), equals(7.5));
        expect(asDouble('-Infinity', 7.5), equals(7.5));
        expect(
          asDouble(const ResolvedBinding<Object?>(double.nan), 7.5),
          equals(7.5),
        );
        expect(
          asDouble(const ResolvedBinding<Object?>('Infinity'), 7.5),
          equals(7.5),
        );
      });

      test(
          '(Issue #424) asInt returns defaultValue for non-finite num and '
          'String inputs', () {
        expect(asInt(double.nan, 11), equals(11));
        expect(asInt(double.infinity, 11), equals(11));
        expect(asInt(double.negativeInfinity, 11), equals(11));
        expect(asInt('NaN', 11), equals(11));
        expect(asInt('Infinity', 11), equals(11));
        expect(asInt('-Infinity', 11), equals(11));
        expect(
          asInt(const ResolvedBinding<Object?>(double.nan), 11),
          equals(11),
        );
        expect(
          asInt(const ResolvedBinding<Object?>('Infinity'), 11),
          equals(11),
        );
      });
    });

    group('(Issue #472) parseSliderRange', () {
      test(
          '(Issue #472) clamps bounds, falls back on invalid spans, and caps '
          'steps/divisions', () {
        expect(
          parseSliderRange(const {'min': 0, 'max': 10, 'steps': 0}),
          equals((min: 0.0, max: 10.0, value: 0.0, divisions: null)),
        );
        expect(
          parseSliderRange(const {'min': 0, 'max': 10, 'steps': -1}),
          equals((min: 0.0, max: 10.0, value: 0.0, divisions: null)),
        );
        expect(
          parseSliderRange(const {'min': 0, 'max': 10, 'steps': 500}),
          equals((min: 0.0, max: 10.0, value: 0.0, divisions: 500)),
        );
        expect(
          parseSliderRange(const {'min': 0, 'max': 10, 'steps': 1000}),
          equals((min: 0.0, max: 10.0, value: 0.0, divisions: 1000)),
        );
        expect(
          parseSliderRange(const {'min': 0, 'max': 10, 'steps': 1001}),
          equals((min: 0.0, max: 10.0, value: 0.0, divisions: 1000)),
        );
        expect(
          parseSliderRange(const {'min': 0, 'max': 10, 'divisions': 25}),
          equals((min: 0.0, max: 10.0, value: 0.0, divisions: 25)),
        );
        expect(
          parseSliderRange(
            const {
              'min': -1e308,
              'max': 1e308,
              'value': 50,
              'steps': 1000000000,
            },
          ),
          equals(
            (
              min: -kMaxSliderBound,
              max: kMaxSliderBound,
              value: 50.0,
              divisions: kMaxSliderDivisions,
            ),
          ),
        );
        expect(
          parseSliderRange(
            const {'min': 1e20, 'max': 1e20, 'value': 1e20, 'steps': 10},
          ),
          equals((min: 0.0, max: 100.0, value: 100.0, divisions: 10)),
        );
        expect(
          parseSliderRange(const {'min': 50, 'max': 10, 'value': 25}),
          equals((min: 0.0, max: 100.0, value: 25.0, divisions: null)),
        );
        expect(
          parseSliderRange(
            const {
              'min': double.nan,
              'max': double.infinity,
              'value': double.negativeInfinity,
            },
          ),
          equals((min: 0.0, max: 100.0, value: 0.0, divisions: null)),
        );
      });
    });
  });
}
