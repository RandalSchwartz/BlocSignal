import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Error thrown when [BlocSignalProvider.of] (or `context.read` /
/// `context.watch` / `context.select`) fails to find an ancestor
/// [BlocSignalProvider] of type [T] in the widget tree.
///
/// Extends [FlutterError] for backward compatibility with existing error
/// handlers.
class BlocSignalProviderNotFoundError<T extends BlocSignalBase<dynamic>>
    extends FlutterError {
  /// Creates a [BlocSignalProviderNotFoundError] for the given [context].
  BlocSignalProviderNotFoundError(BuildContext context)
      : super.fromParts(<DiagnosticsNode>[
          ErrorSummary(_buildMessage<T>(context)),
        ]);

  static String _buildMessage<T extends BlocSignalBase<dynamic>>(
    BuildContext context,
  ) {
    final callerType = context.widget.runtimeType;
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

/// An interface for [BlocSignalProvider] widgets that can be merged by
/// [MultiBlocSignalProvider] into a single linear widget hierarchy.
///
/// Example:
/// ```dart
/// final List<BlocSignalProviderSingleChildWidget> providers = [
///   BlocSignalProvider<AuthBloc>(create: (context) => AuthBloc()),
///   BlocSignalProvider<ThemeBloc>(create: (context) => ThemeBloc()),
/// ];
/// ```
abstract class BlocSignalProviderSingleChildWidget implements Widget {
  /// Clones this provider widget with a new [child] widget.
  Widget copyWith(Widget child);
}

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
    extends StatefulWidget implements BlocSignalProviderSingleChildWidget {
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

  /// Looks up the closest [BlocSignal] of type [T] in the widget tree,
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
        ? context.dependOnInheritedWidgetOfExactType<
            _BlocSignalProviderInherited<T>>()
        : context
            .getElementForInheritedWidgetOfExactType<
                _BlocSignalProviderInherited<T>>()
            ?.widget as _BlocSignalProviderInherited<T>?;
    return provider?.state.bloc;
  }

  /// Looks up the closest [BlocSignal] of type [T] in the widget tree.
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

  /// Clones this provider with a new child widget.
  @override
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<T>('value', value, defaultValue: null))
      ..add(
        ObjectFlagProperty<T Function(BuildContext context)>.has(
          'create',
          create,
        ),
      )
      ..add(
        FlagProperty(
          'lazy',
          value: lazy,
          ifTrue: 'lazy',
          ifFalse: 'eager',
        ),
      );
  }
}

class _BlocSignalProviderState<T extends BlocSignalBase<dynamic>>
    extends State<BlocSignalProvider<T>> {
  T? _bloc;
  bool _isInitialized = false;
  (Object, StackTrace)? _error;
  int _providerGeneration = 0;

  void _initBloc() {
    try {
      _bloc = widget.create!(context);
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
    if (widget.value != null) return widget.value!;
    if (!_isInitialized) {
      _initBloc();
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
      _initBloc();
    }
  }

  @override
  void didUpdateWidget(BlocSignalProvider<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.create != null && widget.value != null) {
      if (_bloc != null) {
        unawaited(_bloc!.close());
        _bloc = null;
      }
      _isInitialized = false;
      _error = null;
      _providerGeneration++;
    } else if (oldWidget.value != null && widget.create != null) {
      _bloc = null;
      _isInitialized = false;
      _error = null;
      _providerGeneration++;
      if (!widget.lazy) {
        _initBloc();
      }
    } else if (widget.create != null && !widget.lazy && !_isInitialized) {
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
  Widget build(BuildContext context) {
    return _BlocSignalProviderInherited<T>(
      bloc: widget.value ?? _bloc,
      generation: _providerGeneration,
      state: this,
      child: widget.child,
    );
  }
}

class _BlocSignalProviderInherited<T extends BlocSignalBase<dynamic>>
    extends InheritedWidget {
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
  bool updateShouldNotify(_BlocSignalProviderInherited<T> oldWidget) {
    if (generation != oldWidget.generation) {
      return true;
    }
    if (oldWidget.bloc == null && bloc != null) {
      return false;
    }
    return !identical(bloc, oldWidget.bloc);
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
        ..update(bloc, selector, equals: equals);
    } else {
      subscription = _SelectSubscription<T, R>(
        bloc: bloc,
        selector: selector,
        element: element,
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

  /// The list of [BlocSignalProviderSingleChildWidget] widgets (such as
  /// [BlocSignalProvider]) to inject.
  final List<BlocSignalProviderSingleChildWidget> providers;

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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      IterableProperty<BlocSignalProviderSingleChildWidget>(
        'providers',
        providers,
      ),
    );
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
    bool Function(R previous, R next)? equals,
  })  : _bloc = bloc,
        _selector = selector,
        _equals = equals,
        _elementRef = WeakReference(element) {
    _initSubscription();
  }

  T _bloc;
  R Function(T) _selector;
  bool Function(R previous, R next)? _equals;
  final WeakReference<Element> _elementRef;
  late Computed<Object?> _computed;
  late R _selectedValue;
  late VoidCallback _dispose;
  bool _isDisposed = false;

  R get value => _selectedValue;

  void _initSubscription() {
    final customEquals = _equals;
    if (customEquals != null) {
      final slotComputed = computed<_SelectorSlot<R>>(
        () => _SelectorSlot<R>(_selector(_bloc), customEquals),
        options: ComputedOptions<_SelectorSlot<R>>(
          name: 'context.select<$T, $R>.computed',
        ),
      );
      _computed = slotComputed;
      _selectedValue = slotComputed.value.value;
    } else {
      final rawComputed = computed<R>(
        () => _selector(_bloc),
        options: ComputedOptions<R>(
          name: 'context.select<$T, $R>.computed',
        ),
      );
      _computed = rawComputed;
      _selectedValue = rawComputed.value;
    }

    var isInitial = true;
    _dispose = effect(
      () {
        if (_isDisposed) return;
        final el = _elementRef.target;
        if (el == null || !el.mounted) {
          dispose();
          return;
        }
        final val = _computed.value;
        if (isInitial) {
          isInitial = false;
          return;
        }
        if (customEquals != null) {
          final nextSlot = val! as _SelectorSlot<R>;
          if (!customEquals(_selectedValue, nextSlot.value)) {
            _selectedValue = nextSlot.value;
            el.markNeedsBuild();
          }
        } else {
          final newValue = val as R;
          if (newValue != _selectedValue) {
            _selectedValue = newValue;
            el.markNeedsBuild();
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
    R Function(T) newSelector, {
    bool Function(R previous, R next)? equals,
  }) {
    if (_isDisposed) return;
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
