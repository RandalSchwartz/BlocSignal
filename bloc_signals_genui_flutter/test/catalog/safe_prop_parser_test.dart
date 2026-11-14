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
}
