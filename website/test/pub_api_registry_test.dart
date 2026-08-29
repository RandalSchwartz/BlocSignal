import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/jaspr.dart';
import 'package:test/test.dart';

void main() {
  group('PubApiRegistry & DocSymbol Tests', () {
    test('all DocSymbol entries produce valid pub.dev documentation URLs', () {
      expect(DocSymbol.values, isNotEmpty);

      for (final symbol in DocSymbol.values) {
        expect(symbol.symbolName, isNotEmpty);
        expect(symbol.package, isNotEmpty);
        expect(symbol.htmlFile, isNotEmpty);

        final expectedPrefix =
            'https://pub.dev/documentation/${symbol.package}/latest/${symbol.package}/';
        expect(
          symbol.url,
          startsWith(expectedPrefix),
          reason:
              'Symbol ${symbol.symbolName} has unexpected URL: ${symbol.url}',
        );
        expect(
          symbol.url.endsWith('.html'),
          isTrue,
          reason: 'URL must end with .html for dartdoc: ${symbol.url}',
        );
      }
    });

    test('apiLink and DocSymbol.link render valid anchor components', () {
      for (final symbol in DocSymbol.values) {
        final component = apiLink(symbol);
        expect(component, isA<Component>());

        final customLabeledComponent = symbol.link(label: 'CustomLabel');
        expect(customLabeledComponent, isA<Component>());
      }
    });

    test('key core and satellite symbols are present in DocSymbol enum', () {
      final names = DocSymbol.values.map((s) => s.symbolName).toSet();

      expect(names, contains('CubitSignal'));
      expect(names, contains('BlocSignal'));
      expect(names, contains('BlocSignalObserver'));
      expect(names, contains('droppable'));
      expect(names, contains('restartable'));
      expect(names, contains('sequential'));
      expect(names, contains('BlocSignalProvider'));
      expect(names, contains('BlocSignalBuilder'));
      expect(names, contains('BlocSignalListener'));
      expect(names, contains('BlocSignalConsumer'));
      expect(names, contains('BlocSignalSelector'));
      expect(names, contains('blocSignalTest'));
      expect(names, contains('HydratedCubitSignal'));
      expect(names, contains('HydratedBlocSignal'));
      expect(names, contains('ClassicBlocSignal'));
      expect(names, contains('ClassicCubitSignal'));
      expect(names, contains('ReplayCubit'));
      expect(names, contains('ReplayBloc'));
      expect(names, contains('on'));
      expect(names, contains('emit'));
      expect(names, contains('read'));
      expect(names, contains('watch'));
      expect(names, contains('select'));
    });
  });
}
