import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:genui_tui_agent/src/tui_renderer.dart';
import 'package:test/test.dart';

void main() {
  group('TuiRenderer', () {
    test('renders all states without throwing', () {
      expect(
        TuiRenderer.renderState(const SurfaceInitial()),
        contains('A2UI Terminal Client'),
      );
      expect(
        TuiRenderer.renderState(
          const SurfaceStreaming(surfaceId: 's1', messageCount: 3),
        ),
        contains('s1'),
      );
      expect(
        TuiRenderer.renderState(
          const SurfaceSubmitting(
            surfaceId: 's1',
            actionName: 'submit',
            sourceComponentId: 'btn1',
          ),
        ),
        contains('submit'),
      );
      expect(
        TuiRenderer.renderState(
          const SurfaceError(error: 'test error', surfaceId: 's1'),
        ),
        contains('test error'),
      );
    });

    test('renders surface model with components and forms', () {
      final surface = SurfaceModel<ComponentApi>(
        'test_surf',
        catalog: MinimalCatalog(),
      );
      surface.componentsModel.addComponent(
        ComponentModel('t1', 'Text', {'text': 'Header', 'variant': 'h1'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('tf1', 'TextField', {'label': 'Name'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('b1', 'Button', {
          'action': {'name': 'doWork'},
        }),
      );
      surface.componentsModel.addComponent(ComponentModel('c1', 'Column', {}));
      surface.componentsModel.addComponent(ComponentModel('r1', 'Row', {}));
      surface.componentsModel.addComponent(
        ComponentModel('u1', 'UnknownCustom', {}),
      );

      final output = TuiRenderer.renderState(
        SurfaceReady(
          surfaceId: 'test_surf',
          surface: surface,
          formValues: const {'name': 'Merlyn'},
        ),
      );

      expect(output, contains('Header'));
      expect(output, contains('Name'));
      expect(output, contains('doWork'));
      expect(output, contains('Merlyn'));
    });
  });
}
