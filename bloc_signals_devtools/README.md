# bloc_signals_devtools

Dedicated Flutter DevTools extension UI for inspecting `BlocSignal` and `CubitSignal` containers, tracing event-to-transition timelines, inspecting state diffs, and warning against memory leaks.

## Features

- **Instance Tree View**: Searchable list of active container instances, state values, types, and closure status.
- **Timeline & Trace Panel**: Chronological timeline mapping events ➔ transitions ➔ state updates.
- **State Diff Inspector**: Interactive object diff viewer (`currentState` vs `nextState`).
- **Leak Detector & Warnings**: Alert badge for unclosed containers and suspicious retain counts.
