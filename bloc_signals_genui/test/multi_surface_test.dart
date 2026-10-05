import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:test/test.dart';

const _minimalCatalogId =
    'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

typedef _TwoSurfaces = ({
  A2uiSurfaceBloc bloc,
  List<A2uiSurfaceState> states,
});

_TwoSurfaces _createTwoSurfaces() {
  final bloc = A2uiSurfaceBloc();
  addTearDown(bloc.close);

  bloc
    ..add(
      ProcessMessage(
        CreateSurfaceMessage(
          surfaceId: 'A',
          catalogId: _minimalCatalogId,
        ),
      ),
    )
    ..add(
      ProcessMessage(
        UpdateComponentsMessage(
          surfaceId: 'A',
          components: const [
            {
              'id': 'a1',
              'component': 'Text',
              'text': 'on A',
            },
          ],
        ),
      ),
    )
    ..add(
      ProcessMessage(
        CreateSurfaceMessage(
          surfaceId: 'B',
          catalogId: _minimalCatalogId,
        ),
      ),
    )
    ..add(
      ProcessMessage(
        UpdateComponentsMessage(
          surfaceId: 'B',
          components: const [
            {
              'id': 'b1',
              'component': 'Text',
              'text': 'on B',
            },
          ],
        ),
      ),
    );

  final states = <A2uiSurfaceState>[];
  final unsubscribe = bloc.state.subscribe(states.add);
  addTearDown(unsubscribe);
  states.clear();

  return (bloc: bloc, states: states);
}

List<String> _surfaceIds(A2uiSurfaceBloc bloc) =>
    bloc.processor.groupModel.allSurfaces.map((s) => s.id).toList();

Future<List<A2uiActionResponse>> _replayedResponses(
  A2uiSurfaceBloc bloc,
) async {
  final replayed = <A2uiActionResponse>[];
  final subscription = bloc.actionResponses.listen(replayed.add);
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  return replayed;
}

void main() {
  group('ResetSurface Triad (Issue #299: F1, F17, F20, C1)', () {
    test(
        '(Issue #299: F1) named reset deletes targeted surface and preserves '
        'survivor state and history', () async {
      final session = _createTwoSurfaces();

      session.bloc
        ..add(
          const SubmitAction(
            actionName: 'action_a',
            sourceComponentId: 'a1',
            surfaceId: 'A',
          ),
        )
        ..add(
          const SubmitAction(
            actionName: 'action_b',
            sourceComponentId: 'b1',
            surfaceId: 'B',
          ),
        );

      final initialResponses = await _replayedResponses(session.bloc);
      expect(initialResponses, hasLength(2));

      session.states.clear();

      // Reset active surface B
      session.bloc.add(const ResetSurface(surfaceId: 'B'));

      // B is deleted, A survives
      expect(_surfaceIds(session.bloc), ['A']);
      // Active surface is promoted to survivor A
      expect(session.bloc.activeSurfaceId, 'A');

      // State is SurfaceReady for A, NOT SurfaceInitial
      expect(session.states, hasLength(1));
      final ready = session.states.single as SurfaceReady;
      expect(ready.surfaceId, 'A');
      expect(ready.availableSurfaceIds, ['A']);

      // Only B's history is pruned; A's history survives
      final replayed = await _replayedResponses(session.bloc);
      expect(replayed, hasLength(1));
      expect(replayed.single.surfaceId, 'A');
      expect(replayed.single.actionName, 'action_a');
    });

    test(
        '(Issue #299: F1) resetting inactive surface preserves active surface '
        'and its history', () async {
      final session = _createTwoSurfaces();

      session.bloc
        ..add(
          const SubmitAction(
            actionName: 'action_a',
            sourceComponentId: 'a1',
            surfaceId: 'A',
          ),
        )
        ..add(
          const SubmitAction(
            actionName: 'action_b',
            sourceComponentId: 'b1',
            surfaceId: 'B',
          ),
        );

      session.states.clear();

      // Reset inactive surface A while B is active
      session.bloc.add(const ResetSurface(surfaceId: 'A'));

      // A is deleted, B survives
      expect(_surfaceIds(session.bloc), ['B']);
      // Active surface remains B
      expect(session.bloc.activeSurfaceId, 'B');

      // State is SurfaceReady for B with updated availableSurfaceIds
      expect(session.states, hasLength(1));
      final ready = session.states.single as SurfaceReady;
      expect(ready.surfaceId, 'B');
      expect(ready.availableSurfaceIds, ['B']);

      // Only A's history is pruned; B's history survives
      final replayed = await _replayedResponses(session.bloc);
      expect(replayed, hasLength(1));
      expect(replayed.single.surfaceId, 'B');
      expect(replayed.single.actionName, 'action_b');
    });

    test(
        '(Issue #299: F17) id-less reset deletes all surfaces and clears all '
        'history', () async {
      final session = _createTwoSurfaces();

      session.bloc
        ..add(
          const SubmitAction(
            actionName: 'action_a',
            sourceComponentId: 'a1',
            surfaceId: 'A',
          ),
        )
        ..add(
          const SubmitAction(
            actionName: 'action_b',
            sourceComponentId: 'b1',
            surfaceId: 'B',
          ),
        );

      session.states.clear();

      // ID-less reset (null for all)
      session.bloc.add(const ResetSurface());

      // All surfaces are deleted
      expect(_surfaceIds(session.bloc), isEmpty);
      expect(session.bloc.activeSurfaceId, isNull);
      expect(session.states.single, const SurfaceInitial());

      // All history is cleared
      final replayed = await _replayedResponses(session.bloc);
      expect(replayed, isEmpty);
    });

    test(
        '(Issue #299: F20) naming an unknown surface safely no-ops and '
        'preserves history', () async {
      final session = _createTwoSurfaces();

      session.bloc.add(
        const SubmitAction(
          actionName: 'action_a',
          sourceComponentId: 'a1',
          surfaceId: 'A',
        ),
      );

      session.states.clear();

      // Attempt to reset a non-existent surface
      session.bloc.add(const ResetSurface(surfaceId: 'unknown_surface'));

      // Both surfaces survive
      expect(_surfaceIds(session.bloc), ['A', 'B']);
      expect(session.bloc.activeSurfaceId, 'A');
      // No SurfaceInitial emitted; state is untouched
      expect(session.states, isEmpty);

      // History is completely preserved
      final replayed = await _replayedResponses(session.bloc);
      expect(replayed, hasLength(1));
      expect(replayed.single.actionName, 'action_a');
    });

    test(
        '(Issue #299: C1) id-less reset recovers gracefully when active '
        'surface is already deleted externally', () async {
      final session = _createTwoSurfaces();

      // Stale active surface: delete B directly from groupModel
      session.bloc.processor.groupModel.deleteSurface('B');
      session.states.clear();

      // ID-less reset should not wedge; it should delete remaining surfaces (A)
      session.bloc.add(const ResetSurface());

      expect(_surfaceIds(session.bloc), isEmpty);
      expect(session.bloc.activeSurfaceId, isNull);
      expect(session.states.single, const SurfaceInitial());
    });

    test(
        '(Issue #299: Blocker 2) targeted reset of phantom active surface '
        'heals activeSurfaceId and prunes history', () async {
      final session = _createTwoSurfaces();

      session.bloc
        ..add(
          const SubmitAction(
            actionName: 'action_a',
            sourceComponentId: 'a1',
            surfaceId: 'A',
          ),
        )
        ..add(
          const SubmitAction(
            actionName: 'action_b',
            sourceComponentId: 'b1',
            surfaceId: 'B',
          ),
        );

      final initialResponses = await _replayedResponses(session.bloc);
      expect(initialResponses, hasLength(2));

      // Make B a phantom active surface: active is B, but B is deleted externally from groupModel
      session.bloc.processor.groupModel.deleteSurface('B');
      session.states.clear();

      // Targeted reset of phantom active surface B
      session.bloc.add(const ResetSurface(surfaceId: 'B'));

      // Active surface must be healed to surviving surface A
      expect(_surfaceIds(session.bloc), ['A']);
      expect(session.bloc.activeSurfaceId, 'A');

      // State is SurfaceReady for A, NOT stuck on phantom B or unhandled
      expect(session.states, hasLength(1));
      final ready = session.states.single as SurfaceReady;
      expect(ready.surfaceId, 'A');
      expect(ready.availableSurfaceIds, ['A']);

      // B's history was purged even though B was not in groupModel; A's history survives
      final replayed = await _replayedResponses(session.bloc);
      expect(replayed, hasLength(1));
      expect(replayed.single.surfaceId, 'A');
      expect(replayed.single.actionName, 'action_a');
    });
  });
}
