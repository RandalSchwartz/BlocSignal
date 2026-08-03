# Minesweeper Example (`BlocSignal` & `HydratedBlocSignal`)

A complete, responsive Minesweeper game built with Flutter, `BlocSignal`, and `HydratedBlocSignal`.

## ✨ Features

- **Reactive State Management**: Powered by `BlocSignal` and `HydratedBlocSignal`.
- **Exhaustive Event Handling**: Uses Dart 3 pattern matching (`switch (event)`) inside `onEvent` over sealed `GameEvent` types.
- **Synchronous Persistence**: Automatically saves and restores game state (board layout, timer, flagged mines, difficulty) across app restarts using `HydratedStorage`.
- **Synchronous Area Reveal**: BFS flood fill reveals empty cell regions synchronously in a single frame.
- **Three Difficulty Levels**: Beginner (9x9, 10 mines), Intermediate (16x16, 40 mines), and Expert (16x30, 99 mines).
- **Safe First Click**: Guarantees the first click and its immediate neighbors are never mines.

## 🚀 Running the Example

```bash
cd examples/mine_sweeper
flutter run
```

## 🧪 Running Tests

```bash
cd examples/mine_sweeper
flutter test
```
