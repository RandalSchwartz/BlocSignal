import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';

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
class BlocSignalProvider<T extends BlocSignal<dynamic, dynamic>>
    extends StatefulWidget {
  /// Creates a [BlocSignalProvider] that manages the lifecycle of a new
  /// [BlocSignal] returned by [create].
  const BlocSignalProvider({
    required this.child,
    required T Function(BuildContext context) this.create,
    super.key,
  }) : value = null;

  /// Creates a [BlocSignalProvider] that provides an existing [value] to
  /// the tree, without managing its lifecycle (does not close it on dispose).
  const BlocSignalProvider.value({
    required this.child,
    required T this.value,
    super.key,
  }) : create = null;

  /// The factory function to create a new [BlocSignal] instance.
  final T Function(BuildContext context)? create;

  /// An existing [BlocSignal] instance to provide to the widget tree.
  final T? value;

  /// The widget subtree that will have access to the provided [BlocSignal].
  final Widget child;

  /// Looks up the closest [BlocSignal] of type [T] in the widget tree.
  static T of<T extends BlocSignal<dynamic, dynamic>>(
    BuildContext context, {
    bool listen = false,
  }) {
    final provider = listen
        ? context
              .dependOnInheritedWidgetOfExactType<
                _BlocSignalProviderInherited<T>
              >()
        : context
              .findAncestorWidgetOfExactType<_BlocSignalProviderInherited<T>>();
    if (provider == null) {
      throw FlutterError(
        'BlocSignalProvider.of() called with a context that does not contain '
        'a BlocSignalProvider of type $T.',
      );
    }
    return provider.bloc;
  }

  /// Clones this provider with a new child widget.
  BlocSignalProvider<T> copyWith(Widget child) {
    if (create != null) {
      return BlocSignalProvider<T>(
        create: create!,
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

class _BlocSignalProviderState<T extends BlocSignal<dynamic, dynamic>>
    extends State<BlocSignalProvider<T>> {
  T? _bloc;

  T get _effectiveBloc => widget.value ?? _bloc!;

  @override
  void initState() {
    super.initState();
    if (widget.create != null) {
      _bloc = widget.create!(context);
    }
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BlocSignalProviderInherited<T>(
      bloc: _effectiveBloc,
      child: widget.child,
    );
  }
}

class _BlocSignalProviderInherited<T extends BlocSignal<dynamic, dynamic>>
    extends InheritedWidget {
  const _BlocSignalProviderInherited({
    required this.bloc,
    required super.child,
  });

  final T bloc;

  @override
  bool updateShouldNotify(_BlocSignalProviderInherited<T> oldWidget) {
    return bloc != oldWidget.bloc;
  }
}

/// Helper extension on [BuildContext] to access [BlocSignal] instances.
extension BlocSignalProviderExtension on BuildContext {
  /// Reads a [BlocSignal] without listening for changes (ideal for calling
  /// methods or dispatching events).
  T read<T extends BlocSignal<dynamic, dynamic>>() =>
      BlocSignalProvider.of<T>(this);

  /// Watches a [BlocSignal] and registers a rebuild dependency on the provider.
  T watch<T extends BlocSignal<dynamic, dynamic>>() =>
      BlocSignalProvider.of<T>(this, listen: true);
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
  final List<BlocSignalProvider<BlocSignal<dynamic, dynamic>>> providers;

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
