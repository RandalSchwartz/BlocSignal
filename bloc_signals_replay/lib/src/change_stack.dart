part of 'replay_cubit.dart';

typedef _Predicate<T> = bool Function(T state);

class _ChangeStack<T> {
  _ChangeStack({required _Predicate<T> shouldReplay, int? limit})
      : _shouldReplay = shouldReplay,
        _limit = limit;

  final Queue<_Change<T>> _history = ListQueue();
  final Queue<_Change<T>> _redos = ListQueue();
  final _Predicate<T> _shouldReplay;

  int? _limit;

  int? get limit => _limit;

  set limit(int? limit) {
    _limit = limit;
    if (_limit != null && _limit! <= 0) {
      clear();
      return;
    }
    _trimHistory();
  }

  void _trimHistory() {
    if (_limit == null) return;
    while (_history.length > _limit!) {
      _history.removeFirst();
    }
  }

  bool get canRedo => _redos.any((c) => _shouldReplay(c._newValue));
  bool get canUndo => _history.any((c) => _shouldReplay(c._oldValue));

  void add(_Change<T> change) {
    if (_limit != null && _limit! <= 0) return;

    _history.addLast(change);
    _redos.clear();
    _trimHistory();
  }

  void clear() {
    _history.clear();
    _redos.clear();
  }

  void redo() {
    final skipped = <_Change<T>>[];
    while (_redos.isNotEmpty) {
      final change = _redos.removeFirst();
      if (_shouldReplay(change._newValue)) {
        skipped.forEach(_history.addLast);
        _history.addLast(change);
        _trimHistory();
        change.execute();
        return;
      }
      skipped.add(change);
    }
    for (var i = skipped.length - 1; i >= 0; i--) {
      _redos.addFirst(skipped[i]);
    }
  }

  void undo() {
    final skipped = <_Change<T>>[];
    while (_history.isNotEmpty) {
      final change = _history.removeLast();
      if (_shouldReplay(change._oldValue)) {
        skipped.forEach(_redos.addFirst);
        _redos.addFirst(change);
        change.undo();
        return;
      }
      skipped.add(change);
    }
    skipped.reversed.forEach(_history.addLast);
  }
}

class _Change<T> {
  _Change(
    this._oldValue,
    this._newValue,
    this._execute,
    this._undo,
  );

  final T _oldValue;
  final T _newValue;
  final void Function() _execute;
  final void Function(T oldValue) _undo;

  void execute() => _execute();
  void undo() => _undo(_oldValue);
}
