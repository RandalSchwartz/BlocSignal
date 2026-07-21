import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// A Flutter widget that provides a [BlocSignal] to its descendants via
/// the element tree and automatically disposes of it when the provider
/// is removed from the tree.
///
/// Example:
/// ```dart
/// BlocSignalProvider(
///   create: (context) => CounterBloc(),
///   child: CounterScreen(),
/// )
/// ```
class BlocSignalProvider<T extends BlocSignalBase<dynamic>>
    extends StatefulWidget {
  /// Creates a [BlocSignalProvider] that manages the lifecycle of a new
  /// [BlocSignal] returned by [create].
  const BlocSignalProvider({
    required this.child,
    required T Function(BuildContext context) this.create,
    this.lazy = true,
    super.key,
  }) : value = null;

  /// Creates a [BlocSignalProvider] that provides an existing [value] to
  /// the tree, without managing its lifecycle (does not close it on dispose).
  const BlocSignalProvider.value({
    required this.child,
    required T this.value,
    super.key,
  })  : create = null,
        lazy = false;

  /// The factory function to create a new [BlocSignal] instance.
  final T Function(BuildContext context)? create;

  /// An existing [BlocSignal] instance to provide to the widget tree.
  final T? value;

  /// Whether the [BlocSignal] should be created lazily.
  ///
  /// Defaults to `true`.
  final bool lazy;

  /// The widget subtree that will have access to the provided [BlocSignal].
  final Widget child;

  /// Looks up the closest [BlocSignal] of type [T] in the widget tree.
  static T of<T extends BlocSignalBase<dynamic>>(
    BuildContext context, {
    bool listen = false,
  }) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<
            _BlocSignalProviderInherited<T>>()
        : context
            .getElementForInheritedWidgetOfExactType<
                _BlocSignalProviderInherited<T>>()
            ?.widget as _BlocSignalProviderInherited<T>?;
    if (provider == null) {
      throw FlutterError(
        'BlocSignalProvider.of() called with a context that does not contain '
        'a BlocSignalProvider of type $T.',
      );
    }
    return provider.state.bloc;
  }

  /// Clones this provider with a new child widget.
  BlocSignalProvider<T> copyWith(Widget child) {
    if (create != null) {
      return BlocSignalProvider<T>(
        create: create!,
        lazy: lazy,
        key: key,
        child: child,
      );
    } else {
      return BlocSignalProvider<T>.value(
        value: value!,
        key: key,
        child: child,
      );
    }
  }

  @override
  State<BlocSignalProvider<T>> createState() => _BlocSignalProviderState<T>();
}

class _BlocSignalProviderState<T extends BlocSignalBase<dynamic>>
    extends State<BlocSignalProvider<T>> {
  T? _bloc;
  bool _isInitialized = false;

  T get bloc {
    if (widget.value != null) return widget.value!;
    if (!_isInitialized) {
      _bloc = widget.create!(context);
      _isInitialized = true;
    }
    return _bloc!;
  }

  T? get blocInstance => widget.value ?? _bloc;

  @override
  void initState() {
    super.initState();
    if (!widget.lazy && widget.create != null) {
      _bloc = widget.create!(context);
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    if (_bloc != null) {
      unawaited(_bloc!.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BlocSignalProviderInherited<T>(
      bloc: widget.value ?? _bloc,
      state: this,
      child: widget.child,
    );
  }
}

class _BlocSignalProviderInherited<T extends BlocSignalBase<dynamic>>
    extends InheritedWidget {
  const _BlocSignalProviderInherited({
    required this.bloc,
    required this.state,
    required super.child,
  });

  final T? bloc;
  final _BlocSignalProviderState<T> state;

  @override
  bool updateShouldNotify(_BlocSignalProviderInherited<T> oldWidget) {
    return bloc != oldWidget.bloc;
  }
}

/// Helper extension on [BuildContext] to access [BlocSignal] instances.
extension BlocSignalProviderExtension on BuildContext {
  /// Reads a [BlocSignal] without listening for changes (ideal for calling
  /// methods or dispatching events).
  T read<T extends BlocSignalBase<dynamic>>() => BlocSignalProvider.of<T>(this);

  /// Watches a [BlocSignalBase] and registers a rebuild dependency on the
  /// provider.
  T watch<T extends BlocSignalBase<dynamic>>() =>
      BlocSignalProvider.of<T>(this, listen: true);

  /// Listens to changes on a selected value of the [BlocSignal] state.
  R select<T extends BlocSignalBase<dynamic>, R>(
    R Function(T bloc) selector,
  ) {
    final element = this as Element;
    final bloc = BlocSignalProvider.of<T>(this);

    final selectorState = _elementSelectors[element] ??= _SelectorState();
    final currentIndex = selectorState.index;
    selectorState.index++;
    selectorState.lastAccessedIndex = selectorState.index;

    if (currentIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (element.mounted) {
          while (selectorState.subscriptions.length >
              selectorState.lastAccessedIndex) {
            final sub = selectorState.subscriptions.removeLast();
            _selectFinalizer.detach(sub);
            sub.dispose();
          }
        }
        selectorState
          ..index = 0
          ..lastAccessedIndex = 0;
      });
    }

    _SelectSubscription<T, R> subscription;
    if (currentIndex < selectorState.subscriptions.length) {
      subscription = (selectorState.subscriptions[currentIndex]
          as _SelectSubscription<T, R>)
        ..update(bloc, selector);
    } else {
      subscription = _SelectSubscription<T, R>(
        bloc: bloc,
        selector: selector,
        element: element,
      );
      selectorState.subscriptions.add(subscription);
      _selectFinalizer.attach(element, subscription, detach: subscription);
    }

    return subscription.value;
  }
}

/// A widget that merges multiple [BlocSignalProvider]s into a single linear
/// widget hierarchy to improve readability.
///
/// Example:
/// ```dart
/// MultiBlocSignalProvider(
///   providers: [
///     BlocSignalProvider<AuthBloc>(create: (context) => AuthBloc()),
///     BlocSignalProvider<ThemeBloc>(create: (context) => ThemeBloc()),
///   ],
///   child: HomeScreen(),
/// )
/// ```
class MultiBlocSignalProvider extends StatelessWidget {
  /// Creates a [MultiBlocSignalProvider] that provides multiple [providers].
  const MultiBlocSignalProvider({
    required this.child,
    required this.providers,
    super.key,
  });

  /// The list of [BlocSignalProvider] instances to inject.
  final List<BlocSignalProvider<BlocSignalBase<dynamic>>> providers;

  /// The child widget subtree that will have access to all provided blocs.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var current = child;
    for (final provider in providers.reversed) {
      current = provider.copyWith(current);
    }
    return current;
  }
}

final Expando<_SelectorState> _elementSelectors = Expando<_SelectorState>();

final Finalizer<_SelectSubscription<dynamic, dynamic>> _selectFinalizer =
    Finalizer<_SelectSubscription<dynamic, dynamic>>((sub) => sub.dispose());

class _SelectorState {
  int index = 0;
  int lastAccessedIndex = 0;
  final List<_SelectSubscription<dynamic, dynamic>> subscriptions = [];
}

class _SelectSubscription<T extends BlocSignalBase<dynamic>, R> {
  _SelectSubscription({
    required T bloc,
    required R Function(T) selector,
    required Element element,
  })  : _bloc = bloc,
        _selector = selector,
        _elementRef = WeakReference(element) {
    _computed = computed(() => _selector(_bloc));
    _selectedValue = _computed.value;

    _dispose = effect(() {
      final newValue = _computed.value;
      if (newValue != _selectedValue) {
        _selectedValue = newValue;
        final el = _elementRef.target;
        if (el != null && el.mounted) {
          el.markNeedsBuild();
        }
      }
    });
  }

  T _bloc;
  R Function(T) _selector;
  final WeakReference<Element> _elementRef;
  late Computed<R> _computed;
  late R _selectedValue;
  late VoidCallback _dispose;

  R get value => _selectedValue;

  void update(T newBloc, R Function(T) newSelector) {
    if (_bloc != newBloc || _selector != newSelector) {
      this
        .._bloc = newBloc
        .._selector = newSelector;

      _dispose();
      _computed = computed(() => _selector(_bloc));
      _selectedValue = _computed.value;
      _dispose = effect(() {
        final newValue = _computed.value;
        if (newValue != _selectedValue) {
          _selectedValue = newValue;
          final el = _elementRef.target;
          if (el != null && el.mounted) {
            el.markNeedsBuild();
          }
        }
      });
    }
  }

  void dispose() {
    _dispose();
  }
}
