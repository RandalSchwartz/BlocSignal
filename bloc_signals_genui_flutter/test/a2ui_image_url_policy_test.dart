import 'package:bloc_signals_genui/bloc_signals_genui.dart' as genui;
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('(Issue #423 / #463) A2uiImageUrlPolicy re-export parity', () {
    test('re-exports the identical A2uiImageUrlPolicy type from genui', () {
      const flutterPolicy = A2uiImageUrlPolicy();
      const corePolicy = genui.A2uiImageUrlPolicy();

      expect(identical(A2uiImageUrlPolicy, genui.A2uiImageUrlPolicy), isTrue);
      expect(flutterPolicy.runtimeType, corePolicy.runtimeType);
      expect(flutterPolicy.isAllowed('https://example.com/a.png'), isTrue);
      expect(flutterPolicy.isAllowed('https://10.0.0.1/a.png'), isFalse);
      expect(flutterPolicy.isAllowed('https://0177.0.0.1/a.png'), isFalse);
    });
  });
}
