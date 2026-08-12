import '../models/pub_package.dart';

/// Repository handling package search queries against pub.dev.
class PubRepository {
  /// Mock dataset of popular Flutter / Dart packages.
  static const List<PubPackage> _mockPackages = [
    PubPackage(
      name: 'bloc_signals',
      version: '1.0.0',
      description: 'Synchronous state management combining BLoC and Signals.',
    ),
    PubPackage(
      name: 'bloc_signals_flutter',
      version: '1.0.0',
      description: 'Flutter bindings and UI providers for BlocSignal.',
    ),
    PubPackage(
      name: 'signals',
      version: '7.1.0',
      description: 'Reactive signals primitives for Dart and Flutter.',
    ),
    PubPackage(
      name: 'flutter_bloc',
      version: '8.1.3',
      description: 'Flutter widgets that make it easy to integrate BLoCs.',
    ),
    PubPackage(
      name: 'riverpod',
      version: '2.5.1',
      description:
          'A simple, compile-time safe provider framework for Flutter.',
    ),
    PubPackage(
      name: 'jaspr',
      version: '0.12.0',
      description: 'A modern web framework for Dart.',
    ),
    PubPackage(
      name: 'freezed',
      version: '2.5.2',
      description: 'Code generation for immutable classes and unions.',
    ),
  ];

  /// Searches packages matching [query].
  Future<List<PubPackage>> search(String query) async {
    // Simulate network latency
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return _mockPackages;

    return _mockPackages
        .where((pkg) =>
            pkg.name.toLowerCase().contains(trimmed) ||
            pkg.description.toLowerCase().contains(trimmed))
        .toList();
  }
}
