import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

/// Error thrown when [BlocSignalProvider.of] (or `context.read` /
/// `context.watch` / `context.select`) fails to find an ancestor
/// [BlocSignalProvider] of type [T] in the component tree.
///
/// Extends [StateError] for backward compatibility with existing error
/// handlers.
class BlocSignalProviderNotFoundError<T extends BlocSignalBase<dynamic>>
    extends StateError {
  /// Creates a [BlocSignalProviderNotFoundError] for the given [context].
  BlocSignalProviderNotFoundError(BuildContext context)
      : super(_buildMessage<T>(context));

  static String _buildMessage<T extends BlocSignalBase<dynamic>>(
    BuildContext context,
  ) {
    final callerType = switch (context) {
      final Element element => element.component.runtimeType,
    };
    final buffer = StringBuffer()
      ..writeln(
        'BlocSignalProvider.of<$T>() called with a context ($callerType) that '
        'does not contain a BlocSignalProvider<$T>.',
      );
    if (T == BlocSignalBase<dynamic>) {
      buffer.writeln(
        'Warning: The generic type argument was omitted (inferred as '
        'BlocSignalBase<dynamic>). Specify the concrete bloc type explicitly, '
        'for example BlocSignalProvider.of<MyBloc>(context) or '
        'context.read<MyBloc>().',
      );
    }
    buffer
      ..writeln(
        'No ancestor could be found starting from the context that was passed '
        'to BlocSignalProvider.of<$T>().',
      )
      ..writeln(
        'Hints:\n'
        '- If you are trying to read the bloc in the same build method that '
        'creates the BlocSignalProvider, wrap the consumer in a Builder to '
        'obtain a descendant BuildContext.\n'
        '- If you navigated to a new route using Navigator, provide the '
        'existing bloc to the new route using '
        'BlocSignalProvider.value(value: context.read<$T>(), child: ...).',
      );
    return buffer.toString();
  }
}

/// An interface for [BlocSignalProvider] components that can be merged by
/// [MultiBlocSignalProvider] into a single linear component hierarchy.
///
/// Example:
/// ```dart
/// final List<BlocSignalProviderSingleChildComponent> providers = [
///   BlocSignalProvider<AuthBloc>(create: (context) => AuthBloc()),
///   BlocSignalProvider<ThemeBloc>(create: (context) => ThemeBloc()),
/// ];
/// ```
abstract class BlocSignalProviderSingleChildComponent implements Component {
  /// Clones this provider component with a new [child] component.
  Component copyWith(Component child);
}

/// Alias for [BlocSignalProviderSingleChildComponent] for API symmetry with
/// `package:bloc_signals_flutter`.
///
/// Example:
/// ```dart
/// final List<BlocSignalProviderSingleChildWidget> providers = [
///   BlocSignalProvider<AuthBloc>(create: (context) => AuthBloc()),
///   BlocSignalProvider<ThemeBloc>(create: (context) => ThemeBloc()),
/// ];
/// ```
typedef BlocSignalProviderSingleChildWidget
    = BlocSignalProviderSingleChildComponent;

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
    extends StatefulComponent
    implements BlocSignalProviderSingleChildComponent {
  /// Creates a [BlocSignalProvider] that manages the lifecycle of a new
  /// [BlocSignal] returned by [create].
  const BlocSignalProvider({
    required T Function(BuildContext context) this.create,
    this.child = const Component.empty(),
    this.lazy = true,
    super.key,
  }) : value = null;

  /// Creates a [BlocSignalProvider] that provides an existing [value] to
  /// the tree, without managing its lifecycle (does not close it on dispose).
  const BlocSignalProvider.value({
    required T this.value,
    this.child = const Component.empty(),
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

  /// Looks up the closest [BlocSignal] of type [T] in the component tree,
  /// returning `null` if no matching [BlocSignalProvider] ancestor is found.
  ///
  /// When [listen] is `true`, registers a rebuild dependency on the ancestor
  /// provider so the calling context rebuilds if the provided bloc instance
  /// changes.
  ///
  /// Example:
  /// ```dart
  /// final bloc = BlocSignalProvider.maybeOf<CounterBloc>(context);
  /// ```
  static T? maybeOf<T extends BlocSignalBase<dynamic>>(
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
    return provider?.state.bloc;
  }

  /// Looks up the closest [BlocSignal] of type [T] in the component tree.
  ///
  /// Throws [BlocSignalProviderNotFoundError] if no matching
  /// [BlocSignalProvider] ancestor is found.
  static T of<T extends BlocSignalBase<dynamic>>(
    BuildContext context, {
    bool listen = false,
  }) {
    final bloc = maybeOf<T>(context, listen: listen);
    if (bloc == null) {
      throw BlocSignalProviderNotFoundError<T>(context);
    }
    return bloc;
  }

  /// Clones this provider with a new child component.
  @override
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
  int _providerGeneration = 0;

  void _initBloc() {
    try {
      _bloc = component.create!(context);
      // Intentional `on Object catch` (SCAR-ERR-02): cache any factory
      // throwable (`Exception` or `Error`) before rethrowing so subsequent
      // rebuilds deterministically rethrow `_error` instead of hitting a
      // secondary `NullCheckError` on `_bloc!`.
    } on Object catch (e, s) {
      _error = (e, s);
      rethrow;
    } finally {
      _isInitialized = true;
    }
  }

  T get bloc {
    if (component.value != null) return component.value!;
    if (!_isInitialized) {
      _initBloc();
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
      _initBloc();
    }
  }

  @override
  void didUpdateComponent(BlocSignalProvider<T> oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.create != null && component.value != null) {
      if (_bloc != null) {
        unawaited(_bloc!.close());
        _bloc = null;
      }
      _isInitialized = false;
      _error = null;
      _providerGeneration++;
    } else if (oldComponent.value != null && component.create != null) {
      _bloc = null;
      _isInitialized = false;
      _error = null;
      _providerGeneration++;
      if (!component.lazy) {
        _initBloc();
      }
    } else if (component.create != null && !component.lazy && !_isInitialized) {
      _initBloc();
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
      generation: _providerGeneration,
      state: this,
      child: component.child,
    );
  }
}

class _BlocSignalProviderInherited<T extends BlocSignalBase<dynamic>>
    extends InheritedComponent {
  const _BlocSignalProviderInherited({
    required this.bloc,
    required this.generation,
    required this.state,
    required super.child,
  });

  final T? bloc;
  final int generation;
  final _BlocSignalProviderState<T> state;

  @override
  InheritedElement createElement() =>
      _BlocSignalProviderInheritedElement<T>(this);

  @override
  bool updateShouldNotify(_BlocSignalProviderInherited<T> oldComponent) {
    if (generation != oldComponent.generation) {
      return true;
    }
    if (oldComponent.bloc == null && bloc != null) {
      return false;
    }
    return !identical(bloc, oldComponent.bloc);
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

  /// Reads a [BlocSignal] without listening for changes, returning `null` if
  /// no matching [BlocSignalProvider] ancestor is found.
  ///
  /// Example:
  /// ```dart
  /// context.maybeRead<CounterBloc>()?.add(Increment());
  /// ```
  T? maybeRead<T extends BlocSignalBase<dynamic>>() =>
      BlocSignalProvider.maybeOf<T>(this);

  /// Watches a [BlocSignalBase] and registers a rebuild dependency on the
  /// provider.
  ///
  /// Example:
  /// ```dart
  /// final bloc = context.watch<CounterBloc>();
  /// ```
  T watch<T extends BlocSignalBase<dynamic>>() =>
      BlocSignalProvider.of<T>(this, listen: true);

  /// Watches a [BlocSignalBase] and registers a rebuild dependency on the
  /// provider, returning `null` if no matching [BlocSignalProvider] ancestor
  /// is found.
  ///
  /// Example:
  /// ```dart
  /// final bloc = context.maybeWatch<CounterBloc>();
  /// ```
  T? maybeWatch<T extends BlocSignalBase<dynamic>>() =>
      BlocSignalProvider.maybeOf<T>(this, listen: true);

  /// Listens to changes on a selected value of the [BlocSignal] state.
  ///
  /// An optional [equals] comparator can be provided to customize when changes
  /// to the selected value trigger a rebuild.
  ///
  /// Example:
  /// ```dart
  /// final username = context.select<UserBloc, String>(
  ///   (bloc) => bloc.stateValue.username,
  /// );
  /// ```
  R select<T extends BlocSignalBase<dynamic>, R>(
    R Function(T bloc) selector, {
    bool Function(R previous, R next)? equals,
  }) {
    final element = this as Element;
    final inheritedElement = element.getElementForInheritedComponentOfExactType<
            _BlocSignalProviderInherited<T>>()
        as _BlocSignalProviderInheritedElement<T>?;
    if (inheritedElement == null) {
      throw BlocSignalProviderNotFoundError<T>(this);
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
        ..update(bloc, selector, inheritedElement, equals: equals);
    } else {
      subscription = _SelectSubscription<T, R>(
        bloc: bloc,
        selector: selector,
        element: element,
        inheritedElement: inheritedElement,
        equals: equals,
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

  /// The list of [BlocSignalProviderSingleChildComponent] components (such as
  /// [BlocSignalProvider]) to inject.
  final List<BlocSignalProviderSingleChildComponent> providers;

  /// The child component subtree that will have access to all provided blocs.
  final Component child;

  @override
  Component build(BuildContext context) {
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

const Object _inactiveSelectorSentinel = Object();

@immutable
class _SelectorSlot<R> {
  const _SelectorSlot(this.value, this.customEquals);

  final R value;
  final bool Function(R previous, R next) customEquals;

  @override
  bool operator ==(Object other) =>
      other is _SelectorSlot<R> && customEquals(value, other.value);

  @override
  int get hashCode => value.hashCode;
}

class _SelectSubscription<T extends BlocSignalBase<dynamic>, R> {
  _SelectSubscription({
    required T bloc,
    required R Function(T) selector,
    required Element element,
    required _BlocSignalProviderInheritedElement<T> inheritedElement,
    bool Function(R previous, R next)? equals,
  })  : _bloc = bloc,
        _selector = selector,
        _equals = equals,
        _elementRef = WeakReference(element),
        _inheritedRef = WeakReference(inheritedElement) {
    _initSubscription();
  }

  T _bloc;
  R Function(T) _selector;
  bool Function(R previous, R next)? _equals;
  final WeakReference<Element> _elementRef;
  WeakReference<_BlocSignalProviderInheritedElement<T>> _inheritedRef;
  late Computed<Object?> _computed;
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
    final customEquals = _equals;
    var hasInitializedComputed = false;
    _computed = computed<Object?>(
      () {
        // SCAR-JASPR-01: after initial dependency tracking, gate unmounted
        // evaluations before invoking _selector(_bloc).
        if (hasInitializedComputed && !_isActive()) {
          return _inactiveSelectorSentinel;
        }
        hasInitializedComputed = true;
        final next = _selector(_bloc);
        return customEquals != null
            ? _SelectorSlot<R>(next, customEquals)
            : next;
      },
      options: ComputedOptions<Object?>(
        name: 'context.select<$T, $R>.computed',
      ),
    );
    final initial = _computed.value;
    _selectedValue = customEquals != null
        ? (initial! as _SelectorSlot<R>).value
        : initial as R;

    var isInitial = true;
    _dispose = effect(
      () {
        if (_isDisposed) return;
        final val = _computed.value;
        if (identical(val, _inactiveSelectorSentinel) || !_isActive()) {
          dispose();
          return;
        }
        if (isInitial) {
          isInitial = false;
          return;
        }
        if (customEquals != null) {
          final nextSlot = val! as _SelectorSlot<R>;
          if (!customEquals(_selectedValue, nextSlot.value)) {
            _selectedValue = nextSlot.value;
            _elementRef.target?.markNeedsBuild();
          }
        } else {
          final newValue = val as R;
          if (newValue != _selectedValue) {
            _selectedValue = newValue;
            _elementRef.target?.markNeedsBuild();
          }
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
    _BlocSignalProviderInheritedElement<T> newInheritedElement, {
    bool Function(R previous, R next)? equals,
  }) {
    if (_isDisposed) return;
    _inheritedRef = WeakReference(newInheritedElement);
    if (!identical(_bloc, newBloc) ||
        _selector != newSelector ||
        _equals != equals) {
      this
        .._bloc = newBloc
        .._selector = newSelector
        .._equals = equals;

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
