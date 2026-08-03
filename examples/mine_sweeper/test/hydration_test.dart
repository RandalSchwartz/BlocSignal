import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_sweeper_example/src/models/difficulty.dart';
import 'package:mine_sweeper_example/src/state/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);
  });

  group('HydratedBlocSignal State Persistence', () {
    test('State is persisted and restored across bloc restarts', () async {
      final bloc1 = GameBlocSignal();
      bloc1.add(const ResetGameEvent(GameDifficulty.intermediate));
      bloc1.add(const ToggleFlagEvent(0, 0));
      bloc1.add(const TickTimerEvent());
      bloc1.add(const TickTimerEvent());

      expect(bloc1.stateValue.difficulty, GameDifficulty.intermediate);
      expect(bloc1.stateValue.timer, 2);
      expect(bloc1.stateValue.grid[0][0].isFlagged, isTrue);

      // Re-instantiate bloc (simulating app restart)
      final bloc2 = GameBlocSignal();

      expect(bloc2.stateValue.difficulty, equals(GameDifficulty.intermediate));
      expect(bloc2.stateValue.timer, equals(2));
      expect(bloc2.stateValue.grid[0][0].isFlagged, isTrue);
    });

    test('State can be cleared via bloc.clear()', () async {
      final bloc1 = GameBlocSignal();
      bloc1.add(const ResetGameEvent(GameDifficulty.expert));
      expect(bloc1.stateValue.difficulty, GameDifficulty.expert);

      await bloc1.clear();

      final bloc2 = GameBlocSignal();
      expect(bloc2.stateValue.difficulty, GameDifficulty.beginner);
    });
  });
}
