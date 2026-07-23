import 'dart:async';

/// An asynchronous mutual exclusion lock.
///
/// Ensures that only one async operation executes at a time within a protected
/// block, queueing subsequent invocations in FIFO order.
class Mutex {
  Completer<void>? _current;

  /// Whether the lock is currently held by an active operation.
  bool get isLocked => _current != null;

  /// Executes [computation] exclusively under the mutex lock.
  ///
  /// If another computation is currently executing, this computation will wait
  /// in line until prior computations complete.
  Future<T> protect<T>(FutureOr<T> Function() computation) async {
    final previous = _current;
    final completer = Completer<void>();
    _current = completer;

    if (previous != null) {
      try {
        await previous.future;
      } on Object catch (_) {
        // Ignored; previous failure does not block the queue execution.
      }
    }

    try {
      return await computation();
    } finally {
      completer.complete();
      if (identical(_current, completer)) {
        _current = null;
      }
    }
  }
}
