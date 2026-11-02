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
      expect(names, contains('CubitSignalMixin'));
      expect(names, contains('BlocSignalMixin'));
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
      expect(names, contains('HydratedMixin'));
      expect(names, contains('HydratedCubitSignal'));
      expect(names, contains('HydratedBlocSignal'));
      expect(names, contains('ClassicBlocSignal'));
      expect(names, contains('ClassicCubitSignal'));
      expect(names, contains('ReplayMixin'));
      expect(names, contains('ReplayCubit'));
      expect(names, contains('ReplayBloc'));
      expect(names, contains('on'));
      expect(names, contains('emit'));
      expect(names, contains('emitError'));
      expect(names, contains('emitTelemetry'));
      expect(names, contains('onTelemetry'));
      expect(names, contains('BlocTelemetryKeys'));
      expect(names, contains('read'));
      expect(names, contains('watch'));
      expect(names, contains('select'));
      expect(names, contains('value'));
      expect(names, contains('state'));
      expect(names, contains('createPlugin'));
    });

    test('(Issue #330: R16) devToolsBlocSignalObserver maps to bloc_signals package', () {
      expect(
        DocSymbol.devToolsBlocSignalObserver.package,
        equals('bloc_signals'),
      );
      expect(
        DocSymbol.devToolsBlocSignalObserver.url,
        equals(
          'https://pub.dev/documentation/bloc_signals/latest/bloc_signals/DevToolsBlocSignalObserver-class.html',
        ),
      );
    });

    test('(Issue #294) GenUI DocSymbol entries map to bloc_signals_genui and bloc_signals_genui_flutter', () {
      final expectedGenUiSymbols = <DocSymbol, (String, String, String)>{
        DocSymbol.a2uiSurfaceBloc: (
          'A2uiSurfaceBloc',
          'bloc_signals_genui',
          'A2uiSurfaceBloc-class.html',
        ),
        DocSymbol.a2uiSurfaceState: (
          'A2uiSurfaceState',
          'bloc_signals_genui',
          'A2uiSurfaceState-class.html',
        ),
        DocSymbol.a2uiSurfaceEvent: (
          'A2uiSurfaceEvent',
          'bloc_signals_genui',
          'A2uiSurfaceEvent-class.html',
        ),
        DocSymbol.a2uiActionResponse: (
          'A2uiActionResponse',
          'bloc_signals_genui',
          'A2uiActionResponse-class.html',
        ),
        DocSymbol.standardCatalog: (
          'StandardCatalog',
          'bloc_signals_genui',
          'StandardCatalog-class.html',
        ),
        DocSymbol.a2uiSurfaceView: (
          'A2uiSurfaceView',
          'bloc_signals_genui_flutter',
          'A2uiSurfaceView-class.html',
        ),
        DocSymbol.a2uiFlutterCatalog: (
          'A2uiFlutterCatalog',
          'bloc_signals_genui_flutter',
          'A2uiFlutterCatalog-class.html',
        ),
        DocSymbol.a2uiComponentContext: (
          'A2uiComponentContext',
          'bloc_signals_genui_flutter',
          'A2uiComponentContext-class.html',
        ),
        DocSymbol.genUiControllerAdapter: (
          'GenUiControllerAdapter',
          'bloc_signals_genui_flutter',
          'GenUiControllerAdapter-class.html',
        ),
        DocSymbol.a2uiJasprCatalog: (
          'A2uiJasprCatalog',
          'bloc_signals_genui_jaspr',
          'A2uiJasprCatalog-class.html',
        ),
        DocSymbol.a2uiJasprSurfaceView: (
          'A2uiSurfaceView (Jaspr)',
          'bloc_signals_genui_jaspr',
          'A2uiSurfaceView-class.html',
        ),
        DocSymbol.a2uiJasprComponentContext: (
          'A2uiComponentContext (Jaspr)',
          'bloc_signals_genui_jaspr',
          'A2uiComponentContext-class.html',
        ),
      };

      for (final entry in expectedGenUiSymbols.entries) {
        final symbol = entry.key;
        final (expectedName, expectedPkg, expectedHtml) = entry.value;
        expect(symbol.symbolName, equals(expectedName));
        expect(symbol.package, equals(expectedPkg));
        expect(symbol.htmlFile, equals(expectedHtml));
        expect(
          symbol.url,
          equals(
            'https://pub.dev/documentation/$expectedPkg/latest/$expectedPkg/$expectedHtml',
          ),
        );
      }
    });
  });
}
