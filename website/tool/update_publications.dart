import 'dart:convert';
import 'dart:io';

import 'package:blocsignal_website/src/models/publication_generator.dart';

export 'package:blocsignal_website/src/models/publication_generator.dart';

/// Fetches all published DEV.to articles by paginating `per_page=100`
/// across pages until a page returns fewer than `100` items.
Future<List<Map<String, dynamic>>> fetchAllDevToArticles({
  String? apiKey,
  Uri? baseUri,
  int maxPages = 50,
}) async {
  const perPage = 100;
  final endpoint =
      baseUri ??
      Uri.parse('https://dev.to/api/articles?username=randalschwartz');
  final articles = <Map<String, dynamic>>[];
  final seenKeys = <Object>{};
  final client = HttpClient();

  try {
    var page = 1;
    while (true) {
      final pageUri = endpoint.replace(
        queryParameters: <String, String>{
          ...endpoint.queryParameters,
          'per_page': '$perPage',
          'page': '$page',
        },
      );

      final request = await client.getUrl(pageUri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (apiKey != null && apiKey.isNotEmpty) {
        request.headers.add('api-key', apiKey);
      }

      final response = await request.close();
      final jsonString = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to fetch DEV.to API: HTTP ${response.statusCode}',
          uri: pageUri,
        );
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List<dynamic>) {
        throw FormatException(
          'Expected a JSON list from DEV.to API on page $page, '
          'got ${decoded.runtimeType}.',
        );
      }
      final pageArticles = decoded.cast<Map<String, dynamic>>();
      final previousSeenCount = seenKeys.length;
      for (final article in pageArticles) {
        final key = article['id'] ?? article['canonical_url'] ?? article['url'];
        if (key == null || seenKeys.add(key)) {
          articles.add(article);
        }
      }
      final addedNewKeys = seenKeys.length > previousSeenCount;

      if (pageArticles.length < perPage || !addedNewKeys || page >= maxPages) {
        break;
      }
      page++;
    }
  } finally {
    client.close();
  }

  return articles;
}

/// Automated tool to fetch the latest DEV.to articles for @randalschwartz
/// and regenerate `website/lib/src/models/publications_data.g.dart`.
Future<void> main() async {
  final apiKey = Platform.environment['DEVTO_API_KEY'];

  print('📡 Fetching latest DEV.to articles for @randalschwartz...');

  final List<Map<String, dynamic>> articles;
  try {
    articles = await fetchAllDevToArticles(apiKey: apiKey);
  } on HttpException catch (error) {
    print('❌ ${error.message}');
    exit(1);
  }

  // Check if latest symmetry of state article is present; if not, prepend it
  const symmetryArticleUrl =
      'https://dev.to/gde/the-symmetry-of-state-why-flutter-deserves-contextvalue-and-contextstate-4250';
  final hasSymmetryArticle = articles.any(
    (a) => (a['canonical_url'] ?? a['url']) == symmetryArticleUrl,
  );
  if (!hasSymmetryArticle) {
    articles.insert(0, {
      'title': 'The Symmetry of State: Why Flutter Deserves context.value and context.state',
      'description': 'Eliminating the widget builder tax, closure fatigue, and the context.watch trap in Flutter: how 1:1 symmetry between containers and BuildContext unlocks cleaner, faster reactive apps.',
      'url': symmetryArticleUrl,
      'canonical_url': symmetryArticleUrl,
      'readable_publish_date': 'Sep 11',
      'reading_time_minutes': 9,
      'tag_list': ['flutter', 'dart', 'architecture', 'programming'],
    });
  }

  // Check if latest dogfooding article is present; if not, prepend it
  const dogfoodArticleUrl =
      'https://dev.to/gde/dogfooding-blocsignal-on-the-web-building-a-100k-opssec-reactive-app-with-jaspr-and-dart-313-4am7';
  final hasDogfoodArticle = articles.any(
    (a) => (a['canonical_url'] ?? a['url']) == dogfoodArticleUrl,
  );
  if (!hasDogfoodArticle) {
    articles.insert(0, {
      'title': 'Dogfooding BlocSignal on the Web: Building a 100K Ops/sec Reactive App with Jaspr and Dart 3.13',
      'description': 'A behind-the-scenes look at how we dogfooded bloc_signals_jaspr on blocsignal.dev, achieving 100K ops/sec in browser JS with declarative consumer components and Dart 3.13.',
      'url': dogfoodArticleUrl,
      'canonical_url': dogfoodArticleUrl,
      'readable_publish_date': 'Aug 14',
      'reading_time_minutes': 5,
      'tag_list': ['flutter', 'dart', 'webdev', 'statemanagement'],
    });
  }

  // Check if latest one-shot side effects article is present; if not, prepend it
  const sideEffectsArticleUrl =
      'https://dev.to/gde/one-shot-ui-side-effects-in-blocsignal-snackbars-dialogs-and-navigation-without-state-pollution-52j4';
  final hasSideEffectsArticle = articles.any(
    (a) => (a['canonical_url'] ?? a['url']) == sideEffectsArticleUrl,
  );
  if (!hasSideEffectsArticle) {
    articles.insert(0, {
      'title': 'One-Shot UI Side Effects in BlocSignal: Snackbars, Dialogs, and Navigation Without State Pollution',
      'description': 'Why persistent domain state is the wrong place for transient dialogs and snackbars, how classic BLoC solved it with bloc_presentation, and how to handle one-shot side effects in BlocSignal with zero dependencies.',
      'url': sideEffectsArticleUrl,
      'canonical_url': sideEffectsArticleUrl,
      'readable_publish_date': 'Aug 15',
      'reading_time_minutes': 4,
      'tag_list': ['flutter', 'dart', 'statemanagement', 'webdev'],
    });
  }

  // Check if latest 'Why BlocSignal Doesn't Need Provider' article is present; if not, prepend it
  const providerArticleUrl =
      'https://dev.to/gde/why-blocsignal-doesnt-need-provider-and-why-classic-bloc-always-did-1j3g';
  final hasProviderArticle = articles.any(
    (a) => (a['canonical_url'] ?? a['url']) == providerArticleUrl,
  );
  if (!hasProviderArticle) {
    articles.insert(0, {
      'title': "Why BlocSignal Doesn't Need Provider (And Why Classic BLoC Always Did)",
      'description': "How shedding package:provider eliminates dependency hell, fixes Flutter's lingering ghost rebuild bug, and delivers fine-grained synchronous reactivity in 2026.",
      'url': providerArticleUrl,
      'canonical_url': providerArticleUrl,
      'readable_publish_date': 'Aug 16',
      'reading_time_minutes': 6,
      'tag_list': ['flutter', 'dart', 'statemanagement', 'webdev'],
    });
  }

  // Check if primary constructors article is present; if not, prepend it
  const primaryConstArticleUrl =
      'https://dev.to/gde/dart-313-primary-constructors-blocsignal-boilerplate-free-reactive-architecture-5fll';
  final hasPrimaryArticle = articles.any(
    (a) => (a['canonical_url'] ?? a['url']) == primaryConstArticleUrl,
  );
  if (!hasPrimaryArticle) {
    articles.insert(1, {
      'title': 'Dart 3.13 Primary Constructors + BlocSignal: Boilerplate-Free Reactive Architecture',
      'description': "Discover how Dart 3.13 primary constructors, 'this' constructor bodies, and constructor shorthands transform BlocSignal into the cleanest state management architecture in Flutter.",
      'url': primaryConstArticleUrl,
      'canonical_url': primaryConstArticleUrl,
      'readable_publish_date': 'Aug 14',
      'reading_time_minutes': 4,
      'tag_list': ['flutter', 'dart', 'statemanagement', 'programming'],
    });
  }

  print('✅ Found ${articles.length} published articles on DEV.to.');

  final generatedContent = generatePublicationsDataFile(articles);

  final websiteDir = Directory.current.path.endsWith('/website')
      ? Directory.current
      : Directory('website');
  final targetFile = File(
    '${websiteDir.path}/lib/src/models/publications_data.g.dart',
  );
  await targetFile.writeAsString(generatedContent);
  print('💾 Updated ${targetFile.path}');

  // Format code
  final fmtResult = Process.runSync('dart', ['format', targetFile.path]);
  if (fmtResult.exitCode == 0) {
    print('✨ Code formatted successfully.');
  }

  print(
    '🎉 Done! Run `dart run website/tool/build_static.dart` to build static site.',
  );
}
