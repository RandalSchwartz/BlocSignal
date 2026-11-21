import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('(Issue #424) safe_prop_parser non-finite and finite numeric guards',
      () {
    test('(Issue #424) asDouble handles finite numbers and strings', () {
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

    test('(Issue #424) asInt handles finite numbers and strings', () {
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
}
