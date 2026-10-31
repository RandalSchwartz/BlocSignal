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
  });
}
