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
    required T Function(BuildContext context) this.create,
    this.child = const SizedBox.shrink(),
    this.lazy = true,
    super.key,
  }) : value = null;

  /// Creates a [BlocSignalProvider] that provides an existing [value] to
  /// the tree, without managing its lifecycle (does not close it on dispose).
  const BlocSignalProvider.value({
    required T this.value,
    this.child = const SizedBox.shrink(),
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
  (Object, StackTrace)? _error;

  T get bloc {
    if (widget.value != null) return widget.value!;
    if (!_isInitialized) {
      try {
        _bloc = widget.create!(context);
      } catch (e, s) {
        _error = (e, s);
        rethrow;
      } finally {
        _isInitialized = true;
      }
    }
    if (_error != null) {
      Error.throwWithStackTrace(_error!.$1, _error!.$2);
    }
    return _bloc!;
  }

  T? get blocInstance => widget.value ?? _bloc;

  @override
  void initState() {
    super.initState();
    if (!widget.lazy && widget.create != null) {
      try {
        _bloc = widget.create!(context);
      } catch (e, s) {
        _error = (e, s);
        rethrow;
      } finally {
        _isInitialized = true;
      }
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
  InheritedElement createElement() =>
      _BlocSignalProviderInheritedElement<T>(this);

  @override
  bool updateShouldNotify(_BlocSignalProviderInherited<T> oldWidget) {
    if (oldWidget.bloc == null && bloc != null) {
      return false;
    }
    return bloc != oldWidget.bloc;
  }

  bool shouldNotify(_BlocSignalProviderInherited<T> oldWidget) =>
      updateShouldNotify(oldWidget);
}

class _BlocSignalProviderInheritedElement<T extends BlocSignalBase<dynamic>>
    extends InheritedElement {
  _BlocSignalProviderInheritedElement(super.widget);

  final Set<Element> _dependents = <Element>{};
  int _generation = 0;
  bool _didNotifyDependents = false;

  @override
  void setDependencies(Element dependent, Object? value) {
    _dependents.add(dependent);
    super.setDependencies(dependent, value);
  }

  @override
  void updateDependencies(Element dependent, Object? aspect) {
    _dependents.add(dependent);
    super.updateDependencies(dependent, aspect);
  }

  @override
  void removeDependent(Element dependent) {
    _dependents.remove(dependent);
    _disposeSelectors(dependent);
    super.removeDependent(dependent);
  }

  @override
  void updated(InheritedWidget oldWidget) {
    if (widget is _BlocSignalProviderInherited<T> &&
        oldWidget is _BlocSignalProviderInherited<T>) {
      _didNotifyDependents =
          (widget as _BlocSignalProviderInherited<T>).shouldNotify(oldWidget);
    }
    super.updated(oldWidget);
  }

  @override
  void update(InheritedWidget newWidget) {
    _generation++;
    super.update(newWidget);
    _scheduleSelectorTrim();
  }

  @override
  void performRebuild() {
    _generation++;
    super.performRebuild();
    _scheduleSelectorTrim();
  }

  void _scheduleSelectorTrim() {
    final targetGen = _generation;
    final didNotify = _didNotifyDependents;
    _didNotifyDependents = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trimDependents(targetGen, didNotify);
    });
  }

  void _trimDependents(int targetGen, bool didNotify) {
    for (final dependent in _dependents.toList()) {
      if (!dependent.mounted) {
        _dependents.remove(dependent);
        _disposeSelectors(dependent);
        continue;
      }
      final selectorState = _elementSelectors[dependent];
      if (selectorState != null &&
          selectorState.generation < targetGen &&
          (didNotify ||
              !identical(dependent.widget, selectorState.lastWidget))) {
        _disposeSelectors(dependent);
      }
    }
  }
}

/// Helper extension on [BuildContext] to access [BlocSignal] instances.
extension BlocSignalProviderExtension on BuildContext {
  /// Reads a [BlocSignal] without listening for changes (ideal for calling
  /// methods or dispatching events).
  ///
  /// Example:
  /// ```dart
  /// context.read<CounterBloc>().add(Increment());
  /// ```
  T read<T extends BlocSignalBase<dynamic>>() => BlocSignalProvider.of<T>(this);

  /// Watches a [BlocSignalBase] and registers a rebuild dependency on the
  /// provider.
  ///
  /// Example:
  /// ```dart
  /// final bloc = context.watch<CounterBloc>();
  /// ```
  T watch<T extends BlocSignalBase<dynamic>>() =>
      BlocSignalProvider.of<T>(this, listen: true);

  /// Listens to changes on a selected value of the [BlocSignal] state.
  ///
  /// Note on Generic Type Parameters:
  /// Unlike Riverpod's 3-parameter `context.select` or `package:flutter_bloc`,
  /// `BlocSignal`'s `context.select` takes **2** generic type parameters:
  /// 1. `T`: The [BlocSignalBase] container type
  ///    (for example `CounterBloc` or `UserCubit`).
  /// 2. `R`: The selected return value type (for example `int` or `String`).
  ///
  /// The selector callback receives the **`bloc` instance** directly:
  /// `(bloc) => bloc.stateValue.property`.
  ///
  /// Example:
  /// ```dart
  /// final username = context.select<UserBloc, String>(
  ///   (bloc) => bloc.stateValue.username,
  /// );
  /// ```
  R select<T extends BlocSignalBase<dynamic>, R>(
    R Function(T bloc) selector,
  ) {
    final element = this as Element;
    final inheritedElement = element.getElementForInheritedWidgetOfExactType<
            _BlocSignalProviderInherited<T>>()
        as _BlocSignalProviderInheritedElement<T>?;
    final bloc = BlocSignalProvider.of<T>(this, listen: true);

    final selectorState = (_elementSelectors[element] ??= _SelectorState())
      ..lastWidget = element.widget;
    if (inheritedElement != null) {
      selectorState.generation = inheritedElement._generation;
    }
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
          selectorState
            ..index = 0
            ..lastAccessedIndex = 0;
        } else {
          _disposeSelectors(element);
        }
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

  /// Watches the state of container [T] and registers a fine-grained rebuild
  /// dependency on this [BuildContext], returning the current state value [S].
  ///
  /// This method is intended for use inside widget `build()` methods when
  /// the widget element needs to rebuild whenever the container's state emits.
  /// For composing reactive signals in `computed()` or `effect()`, use
  /// [state] instead.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   final count = context.value<CounterCubit, int>();
  ///   return Text('Count: $count');
  /// }
  /// ```
  S value<T extends BlocSignalBase<S>, S>() {
    return select<T, S>((bloc) => bloc.value);
  }

  /// Looks up the [T] container and returns its reactive state
  /// [ReadonlySignal].
  ///
  /// Registers an inherited dependency on container instance swapping
  /// (triggering a rebuild only if an ancestor replaces the container
  /// instance), but does NOT rebuild when container state emits.
  ///
  /// This method is ideal for composing derived signals via `computed()` or
  /// subscribing via `effect()` without triggering unnecessary element
  /// rebuilds on state emissions.
  ///
  /// Example:
  /// ```dart
  /// final counterSignal = context.state<CounterCubit, int>();
  /// final isEven = computed(() => counterSignal.value.isEven);
  /// ```
  ReadonlySignal<S> state<T extends BlocSignalBase<S>, S>() {
    return BlocSignalProvider.of<T>(this, listen: true).state;
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

  /// The list of provider widgets (such as [BlocSignalProvider]) to inject.
  final List<dynamic> providers;

  /// The child widget subtree that will have access to all provided blocs.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var current = child;
    for (final provider in providers.reversed) {
      if (provider is BlocSignalProvider) {
        current = (provider as dynamic).copyWith(current) as Widget;
      }
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
  int generation = 0;
  Widget? lastWidget;
  final List<_SelectSubscription<dynamic, dynamic>> subscriptions = [];
}

void _disposeSelectors(Element element) {
  final selectorState = _elementSelectors[element];
  if (selectorState != null) {
    for (final sub in selectorState.subscriptions) {
      _selectFinalizer.detach(sub);
      sub.dispose();
    }
    selectorState.subscriptions.clear();
    selectorState
      ..index = 0
      ..lastAccessedIndex = 0;
  }
}

class _SelectSubscription<T extends BlocSignalBase<dynamic>, R> {
  _SelectSubscription({
    required T bloc,
    required R Function(T) selector,
    required Element element,
  })  : _bloc = bloc,
        _selector = selector,
        _elementRef = WeakReference(element) {
    _computed = computed(
      () => _selector(_bloc),
      options: ComputedOptions<R>(
        name: 'context.select<$T, $R>.computed',
      ),
    );
    _selectedValue = _computed.value;

    _dispose = effect(
      () {
        if (_isDisposed) return;
        final el = _elementRef.target;
        if (el == null || !el.mounted) {
          dispose();
          return;
        }
        final newValue = _computed.value;
        if (newValue != _selectedValue) {
          _selectedValue = newValue;
          el.markNeedsBuild();
        }
      },
      options: EffectOptions(
        name: 'context.select<$T, $R>.effect',
      ),
    );
  }

  T _bloc;
  R Function(T) _selector;
  final WeakReference<Element> _elementRef;
  late Computed<R> _computed;
  late R _selectedValue;
  late VoidCallback _dispose;
  bool _isDisposed = false;

  R get value => _selectedValue;

  void update(T newBloc, R Function(T) newSelector) {
    if (_isDisposed) return;
    if (_bloc != newBloc || _selector != newSelector) {
      this
        .._bloc = newBloc
        .._selector = newSelector;

      _dispose();
      _computed = computed(
        () => _selector(_bloc),
        options: ComputedOptions<R>(
          name: 'context.select<$T, $R>.computed',
        ),
      );
      _selectedValue = _computed.value;
      _dispose = effect(
        () {
          if (_isDisposed) return;
          final el = _elementRef.target;
          if (el == null || !el.mounted) {
            dispose();
            return;
          }
          final newValue = _computed.value;
          if (newValue != _selectedValue) {
            _selectedValue = newValue;
            el.markNeedsBuild();
          }
        },
        options: EffectOptions(
          name: 'context.select<$T, $R>.effect',
        ),
      );
    }
  }

  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _dispose();
    }
  }
}
