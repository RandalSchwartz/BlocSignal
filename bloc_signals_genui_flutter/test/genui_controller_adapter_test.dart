import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('GenUiControllerAdapter', () {
    test('forwards messages to A2uiSurfaceBloc', () async {
      final bloc = A2uiSurfaceBloc();
      final adapter = GenUiControllerAdapter(bloc);

      expect(adapter.surfaceBloc, equals(bloc));

      adapter.processJson({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 'surf-adapter',
          'catalogId': minimalCatalogId,
        },
      });

      expect(adapter.state, isA<SurfaceReady>());
      final ready = adapter.state as SurfaceReady;
      expect(ready.surfaceId, equals('surf-adapter'));

      await bloc.close();
    });

    test('ingests message stream via ingestStream', () async {
      final bloc = A2uiSurfaceBloc();
      final adapter = bloc.toGenUiController();

      final controller = StreamController<Map<String, dynamic>>();
      adapter.ingestStream(controller.stream);

      controller.add({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 'surf-stream',
          'catalogId': minimalCatalogId,
        },
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(adapter.state, isA<SurfaceStreaming>());
      expect(
        (adapter.state as SurfaceStreaming).surfaceId,
        equals('surf-stream'),
      );

      await controller.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(adapter.state, isA<SurfaceReady>());
      expect((adapter.state as SurfaceReady).surfaceId, equals('surf-stream'));

      await bloc.close();
    });

    test('exposes actionResponses stream and delegates submitAction & reset',
        () async {
      final bloc = A2uiSurfaceBloc();
      final adapter = bloc.toGenUiController();

      final actions = <A2uiActionResponse>[];
      final sub = adapter.actionResponses.listen(actions.add);

      adapter
        ..processJson({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf-act',
            'catalogId': minimalCatalogId,
          },
        })
        ..submitAction(
          'checkout',
          surfaceId: 'surf-act',
          sourceComponentId: 'btn-chk',
          context: {'total': 99},
        );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(actions.length, equals(1));
      expect(actions.first.actionName, equals('checkout'));
      expect(actions.first.surfaceId, equals('surf-act'));
      expect(actions.first.context['total'], equals(99));

      adapter.reset('surf-act');
      expect(adapter.state, isA<SurfaceInitial>());

      await sub.cancel();
      await bloc.close();
    });
  });
}
