import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

class _NullComponent extends StatelessComponent {
  const _NullComponent();

  @override
  Component build(BuildContext context) => const Component.empty();
}

/// A Jaspr component that provides a [BlocSignal] to its descendants via
/// the component tree and automatically disposes of it when the provider
/// is unmounted.
///
/// Example:
/// ```dart
/// BlocSignalProvider(
///   create: (context) => CounterBloc(),
///   child: CounterScreen(),
/// )
/// ```
class BlocSignalProvider<T extends BlocSignalBase<dynamic>>
    extends StatefulComponent {
  /// Creates a [BlocSignalProvider] that manages the lifecycle of a new
  /// [BlocSignal] returned by [create].
  const BlocSignalProvider({
    required T Function(BuildContext context) this.create,
    this.child = const _NullComponent(),
    this.lazy = true,
    super.key,
  }) : value = null;

  /// Creates a [BlocSignalProvider] that provides an existing [value] to
  /// the tree, without managing its lifecycle (does not close it on dispose).
  const BlocSignalProvider.value({
    required T this.value,
    this.child = const _NullComponent(),
    super.key,
  })  : create = null,
        lazy = false;

  /// The factory function to create a new [BlocSignal] instance.
  final T Function(BuildContext context)? create;

  /// An existing [BlocSignal] instance to provide to the component tree.
  final T? value;

  /// Whether the [BlocSignal] should be created lazily.
  ///
  /// Defaults to `true`.
  final bool lazy;

  /// The component subtree that will have access to the provided [BlocSignal].
  final Component child;

  /// Looks up the closest [BlocSignal] of type [T] in the component tree.
  static T of<T extends BlocSignalBase<dynamic>>(
    BuildContext context, {
    bool listen = false,
  }) {
    final provider = listen
        ? context.dependOnInheritedComponentOfExactType<
            _BlocSignalProviderInherited<T>>()
        : context
            .getElementForInheritedComponentOfExactType<
                _BlocSignalProviderInherited<T>>()
            ?.component as _BlocSignalProviderInherited<T>?;
    if (provider == null) {
      throw StateError(
        'BlocSignalProvider.of() called with a context that does not contain '
        'a BlocSignalProvider of type $T.',
      );
    }
    return provider.state.bloc;
  }

  /// Clones this provider with a new child component.
  BlocSignalProvider<T> copyWith(Component child) {
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
    if (component.value != null) return component.value!;
    if (!_isInitialized) {
      try {
        _bloc = component.create!(context);
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

  T? get blocInstance => component.value ?? _bloc;

  @override
  void initState() {
    super.initState();
    if (!component.lazy && component.create != null) {
      try {
        _bloc = component.create!(context);
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
  Component build(BuildContext context) {
    return _BlocSignalProviderInherited<T>(
      bloc: component.value ?? _bloc,
      state: this,
      child: component.child,
    );
  }
}

class _BlocSignalProviderInherited<T extends BlocSignalBase<dynamic>>
    extends InheritedComponent {
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
  bool updateShouldNotify(_BlocSignalProviderInherited<T> oldComponent) {
    if (oldComponent.bloc == null && bloc != null) {
      return false;
    }
    return bloc != oldComponent.bloc;
  }
}

class _BlocSignalProviderInheritedElement<T extends BlocSignalBase<dynamic>>
    extends InheritedElement {
  _BlocSignalProviderInheritedElement(super.component);

  T get bloc => (component as _BlocSignalProviderInherited<T>).state.bloc;

  @override
  void didRebuildDependent(Element dependent) {
    super.didRebuildDependent(dependent);
    final selectorState = _elementSelectors[dependent];
    if (selectorState != null) {
      while (selectorState.subscriptions.length >
          selectorState.lastAccessedIndex) {
        final sub = selectorState.subscriptions.removeLast();
        _selectFinalizer.detach(sub);
        sub.dispose();
      }
      selectorState
        ..index = 0
        ..lastAccessedIndex = 0;
    }
  }

  @override
  void deactivateDependent(Element dependent) {
    final weakDependent = WeakReference<Element>(dependent);
    scheduleMicrotask(() {
      final el = weakDependent.target;
      if (el != null && !_isMountedUnderProvider(el, this)) {
        _disposeSelectorsForProvider(el, this);
      }
    });
    super.deactivateDependent(dependent);
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
    final inheritedElement = element.getElementForInheritedComponentOfExactType<
            _BlocSignalProviderInherited<T>>()
        as _BlocSignalProviderInheritedElement<T>?;
    if (inheritedElement == null) {
      throw StateError(
        'BlocSignalProvider.of() called with a context that does not contain '
        'a BlocSignalProvider of type $T.',
      );
    }
    element.dependOnInheritedElement(inheritedElement);
    final bloc = inheritedElement.bloc;

    final selectorState = _elementSelectors[element] ??= _SelectorState();
    final currentIndex = selectorState.index;
    selectorState.index++;
    selectorState.lastAccessedIndex = selectorState.index;

    _SelectSubscription<T, R> subscription;
    if (currentIndex < selectorState.subscriptions.length) {
      subscription = (selectorState.subscriptions[currentIndex]
          as _SelectSubscription<T, R>)
        ..update(bloc, selector, inheritedElement);
    } else {
      subscription = _SelectSubscription<T, R>(
        bloc: bloc,
        selector: selector,
        element: element,
        inheritedElement: inheritedElement,
      );
      selectorState.subscriptions.add(subscription);
      _selectFinalizer.attach(element, subscription, detach: subscription);
    }

    return subscription.value;
  }

  /// Watches the state of container [T] and registers a fine-grained rebuild
  /// dependency on this [BuildContext], returning the current state value [S].
  ///
  /// This method is intended for use inside component `build()` methods when
  /// the component element needs to rebuild whenever the container's state
  /// emits. For composing reactive signals in `computed()` or `effect()`, use
  /// [state] instead.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Component build(BuildContext context) {
  ///   final count = context.value<CounterCubit, int>();
  ///   return div([Component.text('Count: $count')]);
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

/// A Jaspr component that merges multiple [BlocSignalProvider]s into a single
/// linear component hierarchy to improve readability.
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
class MultiBlocSignalProvider extends StatelessComponent {
  /// Creates a [MultiBlocSignalProvider] that provides multiple [providers].
  const MultiBlocSignalProvider({
    required this.child,
    required this.providers,
    super.key,
  });

  /// The list of provider components (such as [BlocSignalProvider]) to inject.
  final List<dynamic> providers;

  /// The child component subtree that will have access to all provided blocs.
  final Component child;

  @override
  Component build(BuildContext context) {
    var current = child;
    for (final provider in providers.reversed) {
      if (provider is BlocSignalProvider) {
        current = (provider as dynamic).copyWith(current) as Component;
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
  final List<_SelectSubscription<dynamic, dynamic>> subscriptions = [];
}

void _disposeSelectorsForProvider(Element element, Element provider) {
  final selectorState = _elementSelectors[element];
  if (selectorState != null) {
    selectorState.subscriptions.removeWhere((sub) {
      if (identical(sub.inheritedElement, provider)) {
        _selectFinalizer.detach(sub);
        sub.dispose();
        return true;
      }
      return false;
    });
    selectorState
      ..index = 0
      ..lastAccessedIndex = 0;
  }
}

bool _isMountedUnderProvider(Element el, Element inherited) {
  final root = el.binding.rootElement;
  var seenInherited = false;
  Element? current = el;
  while (current != null) {
    if (identical(current, inherited)) {
      seenInherited = true;
    }
    if (identical(current, root)) {
      return seenInherited;
    }
    current = current.parent;
  }
  return false;
}

class _SelectSubscription<T extends BlocSignalBase<dynamic>, R> {
  _SelectSubscription({
    required T bloc,
    required R Function(T) selector,
    required Element element,
    required _BlocSignalProviderInheritedElement<T> inheritedElement,
  })  : _bloc = bloc,
        _selector = selector,
        _elementRef = WeakReference(element),
        _inheritedRef = WeakReference(inheritedElement) {
    _initSubscription();
  }

  T _bloc;
  R Function(T) _selector;
  final WeakReference<Element> _elementRef;
  WeakReference<_BlocSignalProviderInheritedElement<T>> _inheritedRef;
  late R _selectedValue;
  late void Function() _dispose;
  bool _isDisposed = false;

  R get value => _selectedValue;

  Element? get inheritedElement => _inheritedRef.target;

  bool _isActive() {
    final el = _elementRef.target;
    final inherited = _inheritedRef.target;
    return el != null &&
        inherited != null &&
        _isMountedUnderProvider(el, inherited);
  }

  void _initSubscription() {
    var isInitial = true;
    _dispose = effect(
      () {
        if (isInitial) {
          isInitial = false;
          _selectedValue = _selector(_bloc);
          return;
        }
        if (!_isActive()) {
          dispose();
          return;
        }
        final newValue = _selector(_bloc);
        if (newValue != _selectedValue) {
          _selectedValue = newValue;
          _elementRef.target?.markNeedsBuild();
        }
      },
      options: EffectOptions(
        name: 'context.select<$T, $R>.effect',
      ),
    );
  }

  void update(
    T newBloc,
    R Function(T) newSelector,
    _BlocSignalProviderInheritedElement<T> newInheritedElement,
  ) {
    if (_isDisposed) return;
    _inheritedRef = WeakReference(newInheritedElement);
    if (_bloc != newBloc || _selector != newSelector) {
      this
        .._bloc = newBloc
        .._selector = newSelector;

      _dispose();
      _initSubscription();
    }
  }

  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _dispose();
    }
  }
}
