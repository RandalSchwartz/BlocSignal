import 'dart:io';

/// Builds the static web bundle for blocsignal.dev, compiling Dart to JS
/// and creating static route fallbacks for Firebase Hosting and static web servers.
Future<void> main() async {
  print('🚀 Starting static build for blocsignal.dev...');

  final websiteDir = Directory.current.path.endsWith('/website')
      ? Directory.current
      : Directory('website');

  final buildWww = Directory('${websiteDir.path}/build/www');
  if (!buildWww.existsSync()) {
    buildWww.createSync(recursive: true);
  }

  // 1. Compile Dart to JS
  print('📦 Compiling lib/main.dart to JS...');
  final compileResult = await Process.run('dart', [
    'compile',
    'js',
    'lib/main.dart',
    '-o',
    'build/www/main.dart.js',
  ], workingDirectory: websiteDir.path);

  if (compileResult.exitCode != 0) {
    print('❌ JS compilation failed:');
    print(compileResult.stderr);
    print(compileResult.stdout);
    exit(1);
  }
  print('✅ JS compilation succeeded.');

  // 2. Copy web/ static assets to build/www/
  print('📂 Copying web/ assets to build/www/...');
  final webDir = Directory('${websiteDir.path}/web');
  for (final entity in webDir.listSync(recursive: true)) {
    final relativePath = entity.path.substring(webDir.path.length + 1);
    final targetPath = '${buildWww.path}/$relativePath';

    if (entity is Directory) {
      Directory(targetPath).createSync(recursive: true);
    } else if (entity is File) {
      File(targetPath).parent.createSync(recursive: true);
      entity.copySync(targetPath);
    }
  }

  // 3. Create route fallback directories with index.html
  final indexHtml = File('${buildWww.path}/index.html');
  if (!indexHtml.existsSync()) {
    print('❌ build/www/index.html not found!');
    exit(1);
  }

  final routes = [
    'showcase',
    'ported-examples',
    'minesweeper',
    'publications',
    'docs',
    'docs/overview',
    'docs/installation',
    'docs/quickstart',
    'docs/decision-matrix',
    'docs/cubit-vs-bloc',
    'docs/state-modeling',
    'docs/events-and-handlers',
    'docs/event-transformers',
    'docs/lifecycle-and-observers',
    'docs/signals-reactivity',
    'docs/flutter-providers',
    'docs/flutter-widgets',
    'docs/flutter-context',
    'docs/testing-guide',
    'docs/pkg-hydrate',
    'docs/pkg-replay',
    'docs/pkg-riverpod',
    'docs/pkg-otel',
    'docs/pkg-devtools',
    'docs/pkg-lint',
    'docs/pkg-jaspr',
    'docs/recipe-one-shot',
    'docs/recipe-form-validation',
    'docs/recipe-controllers',
    'docs/recipe-caching',
    'docs/recipe-batching',
    'docs/migration-bloc',
    'docs/migration-riverpod',
  ];

  print('🗺️ Generating static route fallbacks for ${routes.length} routes...');
  for (final route in routes) {
    final routeDir = Directory('${buildWww.path}/$route');
    routeDir.createSync(recursive: true);
    indexHtml.copySync('${routeDir.path}/index.html');
  }

  print('🎉 Static build complete! Output ready in build/www/');
}
