import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';

/// A [ScrollController] that is also a [CubitSignalMixin] emitting a boolean
/// indicating whether the scroll viewport is within [threshold] of the bottom.
///
/// **Pattern A: Separation of Concerns**
/// This controller tracks Flutter scroll metrics and emits a de-duplicated
/// boolean state (`isNearBottom`). Because [emit] automatically de-duplicates
/// equal values, scrolling continuously past the threshold does not produce
/// redundant state emissions.
class PagingScrollController extends ScrollController
    with CubitSignalMixin<bool> {
  /// Creates a [PagingScrollController] with the given scroll [threshold] in
  /// logical pixels.
  ///
  /// For example, a threshold of `200.0` triggers when the user is within 200
  /// pixels of the bottom.
  PagingScrollController({this.threshold = 200.0}) {
    initCubitSignal(initialState: false);
    addListener(_onScrollChanged);
  }

  /// The remaining scroll extent in logical pixels under which near-bottom
  /// status becomes true.
  final double threshold;

  bool _isControllerDisposed = false;

  void _onScrollChanged() {
    if (!hasClients) return;
    // position.extentAfter returns the exact remaining pixels after the viewport!
    final isNearBottom = position.extentAfter <= threshold;

    // emit() automatically de-duplicates: only triggers subscribers when flipping!
    emit(isNearBottom);
  }

  @override
  void dispose() {
    if (_isControllerDisposed) return;
    _isControllerDisposed = true;
    removeListener(_onScrollChanged);
    close();
    super.dispose();
  }

  @override
  Future<void> close() async {
    if (!_isControllerDisposed) {
      _isControllerDisposed = true;
      removeListener(_onScrollChanged);
      super.dispose();
    }
    await super.close();
  }
}
