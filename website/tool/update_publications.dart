import 'dart:convert';
import 'dart:io';

/// Automated tool to fetch the latest DEV.to articles for @randalschwartz
/// and regenerate `website/lib/src/pages/publications_page.dart`.
Future<void> main() async {
  final apiKey = Platform.environment['DEVTO_API_KEY'];
  final client = HttpClient();

  final Uri uri = Uri.parse(
    'https://dev.to/api/articles?username=randalschwartz&per_page=50',
  );

  print('📡 Fetching latest DEV.to articles for @randalschwartz...');

  final request = await client.getUrl(uri);
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
  client.close();

  if (response.statusCode != 200) {
    print('❌ Failed to fetch DEV.to API: HTTP ${response.statusCode}');
    exit(1);
  }

  final List<dynamic> articles = jsonDecode(jsonString);

  // Check if latest one-shot side effects article is present; if not, prepend it
  const sideEffectsArticleUrl =
      'https://dev.to/gde/one-shot-ui-side-effects-in-blocsignal-snackbars-dialogs-and-navigation-without-state-pollution-52j4';
  final hasSideEffectsArticle = articles.any(
    (a) => (a['canonical_url'] ?? a['url']) == sideEffectsArticleUrl,
  );
  if (!hasSideEffectsArticle) {
    articles.insert(0, {
      'title':
          'One-Shot UI Side Effects in BlocSignal: Snackbars, Dialogs, and Navigation Without State Pollution',
      'description':
          'Why persistent domain state is the wrong place for transient dialogs and snackbars, how classic BLoC solved it with bloc_presentation, and how to handle one-shot side effects in BlocSignal with zero dependencies.',
      'url': sideEffectsArticleUrl,
      'canonical_url': sideEffectsArticleUrl,
      'readable_publish_date': 'Aug 15',
      'reading_time_minutes': 4,
      'tag_list': ['flutter', 'dart', 'statemanagement', 'webdev'],
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

  // Check if primary constructors article is present; if not, prepend it
  const primaryConstArticleUrl =
      'https://dev.to/gde/dart-313-primary-constructors-blocsignal-boilerplate-free-reactive-architecture-5fll';
  final hasPrimaryArticle = articles.any(
    (a) => (a['canonical_url'] ?? a['url']) == primaryConstArticleUrl,
  );
  if (!hasPrimaryArticle) {
    articles.insert(1, {
      'title': 'Dart 3.13 Primary Constructors + BlocSignal: Boilerplate-Free Reactive Architecture',
      'description': 'Discover how Dart 3.13 primary constructors, \'this\' constructor bodies, and constructor shorthands transform BlocSignal into the cleanest state management architecture in Flutter.',
      'url': primaryConstArticleUrl,
      'canonical_url': primaryConstArticleUrl,
      'readable_publish_date': 'Aug 14',
      'reading_time_minutes': 4,
      'tag_list': ['flutter', 'dart', 'statemanagement', 'programming'],
    });
  }

  print('✅ Found ${articles.length} published articles on DEV.to.');

  final buffer = StringBuffer();
  buffer.writeln("import 'package:jaspr/dom.dart';");
  buffer.writeln("import 'package:jaspr/jaspr.dart';");
  buffer.writeln("import '../components/footer.dart';");
  buffer.writeln("import '../components/navbar.dart';");
  buffer.writeln();
  buffer.writeln('class const PublicationItem({');
  buffer.writeln('  required final String title,');
  buffer.writeln('  required final String description,');
  buffer.writeln('  required final String url,');
  buffer.writeln('  required final String date,');
  buffer.writeln('  required final String readTime,');
  buffer.writeln('  required final String category,');
  buffer.writeln('  required final String type,');
  buffer.writeln('  required final List<String> tags,');
  buffer.writeln('});');
  buffer.writeln();
  buffer.writeln('const List<PublicationItem> _publications = [');

  for (final article in articles) {
    final title = (article['title'] as String).replaceAll("'", "\\'");
    final description = (article['description'] as String).replaceAll(
      "'",
      "\\'",
    );
    final url = article['canonical_url'] ?? article['url'];
    final readTime = '${article['reading_time_minutes']} min read';
    String publishDate = article['readable_publish_date']?.toString() ?? '';
    if (publishDate.isEmpty || publishDate == 'null') {
      final rawDate = article['published_at'] ?? article['created_at'];
      if (rawDate != null) {
        try {
          final dt = DateTime.parse(rawDate.toString());
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          publishDate = '${months[dt.month - 1]} ${dt.day}';
        } catch (_) {
          publishDate = 'Aug 8';
        }
      } else {
        publishDate = 'Aug 8';
      }
    }
    final tagList = (article['tag_list'] as List<dynamic>)
        .map((t) => t.toString())
        .toList();

    // Categorization logic
    String category = 'Architecture';
    final lowerTitle = title.toLowerCase();
    if (tagList.contains('jaspr') ||
        lowerTitle.contains('flutter') ||
        lowerTitle.contains('form')) {
      category = 'Flutter & Jaspr';
    } else if (lowerTitle.contains('bloc') ||
        lowerTitle.contains('state') ||
        lowerTitle.contains('fsm') ||
        lowerTitle.contains('cubit')) {
      category = 'State Machines';
    } else if (tagList.contains('opentelemetry') ||
        lowerTitle.contains('observability') ||
        lowerTitle.contains('async')) {
      category = 'Interop & Telemetry';
    }

    final tagsJson = jsonEncode(tagList);

    buffer.writeln('  PublicationItem(');
    buffer.writeln("    title: '$title',");
    buffer.writeln("    description: '$description',");
    buffer.writeln("    url: '$url',");
    buffer.writeln("    date: '$publishDate',");
    buffer.writeln("    readTime: '$readTime',");
    buffer.writeln("    category: '$category',");
    buffer.writeln("    type: 'Article',");
    buffer.writeln('    tags: $tagsJson,');
    buffer.writeln('  ),');
  }

  buffer.writeln('];');
  buffer.writeln();
  buffer.writeln(
    '''class const PublicationsPage({super.key}) extends StatefulComponent {
  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState() extends State<PublicationsPage> {
  String _activeCategory = 'All';

  @override
  Component build(BuildContext context) {
    final filteredPublications = _activeCategory == 'All'
        ? _publications
        : _publications
            .where((pub) => pub.category == _activeCategory || pub.type == _activeCategory)
            .toList();

    return div(classes: 'app-root', [
      const Navbar(currentPath: '/publications'),
      main_([
        div(classes: 'publications-hero container', [
          div(classes: 'section-badge', [
            span([Component.text('📚 Media & Articles')]),
          ]),
          h1(classes: 'hero-title', [
            Component.text('BlocSignal '),
            span(classes: 'highlight-text', [Component.text('Publications')]),
          ]),
          p(classes: 'hero-motto', [
            Component.text(
                'Explore technical deep dives, architectural guides, DEV.to articles, and video walkthroughs by Randal L. Schwartz.'),
          ]),
        ]),

        // Featured Video Section
        div(classes: 'container', [
          div(classes: 'video-featured-card', [
            div(classes: 'video-card-badge', [
              span(classes: 'badge-video', [Component.text('🎬 Featured Video')]),
              span(classes: 'badge-date', [Component.text('Aug 06, 2026')]),
            ]),
            h2(classes: 'video-title', [
              Component.text('BlocSignal 1.0 Architecture & Overview'),
            ]),
            p(classes: 'video-desc', [
              Component.text(
                  'By Randal L. Schwartz — A comprehensive technical walkthrough demonstrating synchronous signal graph propagation, 0ms microtask delay, BLoC event traceability, and multi-package interop across Flutter, Riverpod, and Jaspr web.'),
            ]),
            div(classes: 'video-player-box', [
              iframe(
                src: 'https://www.youtube-nocookie.com/embed/fwmlVOjsdgQ',
                attributes: {
                  'title': 'BlocSignal 1.0 Architecture & Overview',
                  'allow':
                      'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture',
                  'allowfullscreen': 'true',
                },
                [],
              ),
            ]),
            div(classes: 'video-watch-footer', [
              a(
                href: 'https://www.youtube.com/watch?v=fwmlVOjsdgQ',
                target: Target.blank,
                classes: 'btn-primary btn-watch-video',
                [Component.text('Watch on YouTube ↗')],
              ),
            ]),
          ]),
        ]),

        // Category Filter Tags
        div(classes: 'container pub-filter-container', [
          h3(classes: 'pub-section-heading', [
            Component.text('Published DEV.to Articles by Randal L. Schwartz'),
          ]),
          div(classes: 'pub-filter-tags', [
            for (final cat in [
              'All',
              'Architecture',
              'Flutter & Jaspr',
              'State Machines',
              'Interop & Telemetry'
            ])
              button(
                classes: 'btn-filter \${_activeCategory == cat ? 'active' : ''}',
                onClick: () {
                  setState(() {
                    _activeCategory = cat;
                  });
                },
                [Component.text(cat)],
              ),
          ]),
        ]),

        // Article Cards Grid
        div(classes: 'container pub-grid-section', [
          div(classes: 'pub-grid', [
            for (final pub in filteredPublications)
              a(
                href: pub.url,
                target: Target.blank,
                classes: 'pub-card',
                [
                  div(classes: 'pub-card-top', [
                    span(classes: 'pub-category', [Component.text(pub.category)]),
                    span(classes: 'pub-readtime', [Component.text(pub.readTime)]),
                  ]),
                  h3(classes: 'pub-card-title', [Component.text(pub.title)]),
                  p(classes: 'pub-card-desc', [Component.text(pub.description)]),
                  div(classes: 'pub-card-footer', [
                    div(classes: 'pub-tags-list', [
                      for (final tag in pub.tags)
                        span(classes: 'pub-tag-pill', [Component.text('#\$tag')]),
                    ]),
                    span(classes: 'pub-link-btn', [
                      Component.text('Read on DEV.to ↗'),
                    ]),
                  ]),
                ],
              ),
          ]),
        ]),
      ]),
      const Footer(),
    ]);
  }
}''',
  );

  final targetFile = File('lib/src/pages/publications_page.dart');
  await targetFile.writeAsString(buffer.toString());
  print('💾 Updated lib/src/pages/publications_page.dart');

  // Format code
  final fmtResult = Process.runSync('dart', ['format', targetFile.path]);
  if (fmtResult.exitCode == 0) {
    print('✨ Code formatted successfully.');
  }

  print(
    '🎉 Done! Run `dart compile js lib/main.dart -o build/www/main.dart.js` to build static site.',
  );
}
