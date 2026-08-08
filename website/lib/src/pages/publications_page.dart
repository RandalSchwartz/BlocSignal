import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../components/footer.dart';
import '../components/navbar.dart';

class PublicationItem {
  final String title;
  final String description;
  final String url;
  final String date;
  final String readTime;
  final String category;
  final String type; // 'Video' or 'Article'
  final List<String> tags;

  const PublicationItem({
    required this.title,
    required this.description,
    required this.url,
    required this.date,
    required this.readTime,
    required this.category,
    required this.type,
    required this.tags,
  });
}

const List<PublicationItem> _publications = [
  PublicationItem(
    title:
        'From Raw Signals to BlocSignal: Taming Reactivity for Enterprise Scale',
    description:
        'Learn how BlocSignal encapsulates raw signals inside BLoC & Cubit containers to bring dispatch rigor, event hierarchies, and 0ms synchronous speed to Flutter and Jaspr apps.',
    url:
        'https://dev.to/gde/from-raw-signals-to-blocsignal-taming-reactivity-for-enterprise-scale-2cmi',
    date: 'Aug 8',
    readTime: '6 min read',
    category: 'State Machines',
    type: 'Article',
    tags: ["flutter", "dart", "architecture", "webdev"],
  ),
  PublicationItem(
    title: 'Exploring Form Management Patterns in Flutter with BlocSignal',
    description:
        'Master form handling in Flutter with BlocSignal. Learn how to separate Primary vs. Derived state using computed signals, compare 3 clean form architectural patterns, and pick the right one for your app.',
    url:
        'https://dev.to/gde/exploring-form-management-patterns-in-flutter-with-blocsignal-1c8j',
    date: 'Aug 4',
    readTime: '6 min read',
    category: 'Flutter & Jaspr',
    type: 'Article',
    tags: ["flutter", "dart", "bloc", "signals"],
  ),
  PublicationItem(
    title:
        'Porting 16 BLoC & Signal Benchmark Apps to BlocSignal: Elevating Flutter UX & DX',
    description:
        'We ported 16 official example apps from felangel/bloc and rodydavis/signals.dart to showcase how BlocSignal simplifies Flutter state management with synchronous frame updates, computed() derivations, and streamless Mutex concurrency.',
    url:
        'https://dev.to/gde/porting-16-bloc-signal-benchmark-apps-to-blocsignal-elevating-flutter-ux-dx-2dnl',
    date: 'Aug 2',
    readTime: '2 min read',
    category: 'Flutter & Jaspr',
    type: 'Article',
    tags: ["flutter", "dart", "architecture", "webdev"],
  ),
  PublicationItem(
    title:
        'Solving Riverpod’s Family Provider Cache Dilemma with Signals & mapSignal',
    description:
        'When separate family providers store parameterized network queries as isolated state silos, updating an entity in one subset creates stale data across others. Here is how a normalized mapSignal store fixes it.',
    url:
        'https://dev.to/gde/solving-riverpods-family-provider-cache-dilemma-with-signals-mapsignal-474',
    date: 'Aug 2',
    readTime: '5 min read',
    category: 'Architecture',
    type: 'Article',
    tags: ["flutter", "dart", "riverpod", "architecture"],
  ),
  PublicationItem(
    title:
        'Layered Architecture in Flutter with BlocSignal: Bringing BLoC Discipline and Signals Speed to CodeWithAndrea’s Pattern',
    description:
        'Learn how to adapt CodeWithAndrea\'s classic 4-layer Flutter architecture (Domain, Data, Application, Presentation) using BlocSignal for synchronous reactivity, instant hydration, and clean code.',
    url:
        'https://blocsignal.dev/articles/layered-architecture-in-flutter-with-blocsignal',
    date: 'Jul 31',
    readTime: '8 min read',
    category: 'Flutter & Jaspr',
    type: 'Article',
    tags: ["flutter", "dart", "architecture", "statemanagement"],
  ),
  PublicationItem(
    title:
        'Beyond Flutter: Running BlocSignal State Machines in Pure Dart, Jaspr Web, and CLI Tools',
    description:
        'Discover how BlocSignal\'s zero-Flutter core package enables unified state management across CLI tools, Jaspr web apps, and Dart Frog server backends with native DevTools telemetry.',
    url:
        'https://dev.to/gde/beyond-flutter-running-blocsignal-state-machines-in-pure-dart-jaspr-web-and-cli-tools-51f6',
    date: 'Jul 28',
    readTime: '5 min read',
    category: 'Flutter & Jaspr',
    type: 'Article',
    tags: ["flutter", "dart", "webdev", "architecture"],
  ),
  PublicationItem(
    title:
        'Why ValueNotifier Fails at Scale: The Non-Composability Problem (and How Signals Fix It)',
    description:
        'Discover how signals and BlocSignal eliminate ValueNotifier callback spaghetti, memory leaks, and nested ValueListenableBuilder pyramids in Flutter.',
    url:
        'https://dev.to/gde/why-valuenotifier-fails-at-scale-the-non-composability-problem-and-how-signals-fix-it-4dbc',
    date: 'Jul 28',
    readTime: '5 min read',
    category: 'Architecture',
    type: 'Article',
    tags: ["flutter", "dart", "architecture", "statemanagement"],
  ),
  PublicationItem(
    title:
        'Seamless Flutter Hooks Integration with BlocSignal via signals_hooks',
    description:
        'Discover how BlocSignal and signals_hooks eliminate flutter_bloc glue code, stream overhead, and widget tree nesting in Flutter Hooks applications.',
    url:
        'https://dev.to/gde/seamless-flutter-hooks-integration-with-blocsignal-via-signalshooks-55e',
    date: 'Jul 27',
    readTime: '5 min read',
    category: 'Flutter & Jaspr',
    type: 'Article',
    tags: ["flutter", "dart", "bloc", "statemanagement"],
  ),
  PublicationItem(
    title:
        'Switching Tracks in BlocSignal: The Universal State Switchyard for BLoC, Riverpod, and Provider',
    description:
        'Stop derailing your Flutter apps! Learn how BlocSignal acts as a central railway switchyard bridging BLoC, Riverpod, and Provider synchronously without microtask stream latency or heavy code generation.',
    url:
        'https://dev.to/gde/switching-tracks-in-blocsignal-the-universal-state-switchyard-for-bloc-riverpod-and-provider-929',
    date: 'Jul 27',
    readTime: '5 min read',
    category: 'State Machines',
    type: 'Article',
    tags: ["flutter", "dart", "riverpod", "architecture"],
  ),
  PublicationItem(
    title: 'The Six Flavors of Dependency Injection in Flutter',
    description:
        'Dependency injection isn\'t just one pattern or package. Here is a breakdown of all six distinct DI mechanisms in Dart & Flutter, from InheritedWidget to compile-time IoC.',
    url:
        'https://dev.to/gde/the-six-flavors-of-dependency-injection-in-flutter-lea',
    date: 'Jul 24',
    readTime: '4 min read',
    category: 'Flutter & Jaspr',
    type: 'Article',
    tags: ["flutter", "dart", "architecture", "mobile"],
  ),
  PublicationItem(
    title:
        'Beyond ProviderNotFound: How BlocSignal Rethinks State Location and Synchronous Propagation',
    description:
        'Learn how BlocSignal escapes ProviderNotFound runtime exceptions with flexible location patterns while delivering synchronous performance for DX, UX, and testing.',
    url:
        'https://dev.to/gde/beyond-providernotfound-how-blocsignal-rethinks-state-location-and-synchronous-propagation-4ak6',
    date: 'Jul 24',
    readTime: '5 min read',
    category: 'State Machines',
    type: 'Article',
    tags: ["flutter", "dart", "architecture", "statemanagement"],
  ),
  PublicationItem(
    title:
        'How We Achieved Full BLoC API & Protocol Parity in BlocSignal 0.2.0',
    description:
        'A deep dive into bridging the classic BLoC/Cubit pattern with the synchronous, reactive power of signals in Flutter & Dart.',
    url:
        'https://dev.to/randalschwartz/how-we-achieved-full-bloc-api-protocol-parity-in-blocsignal-020',
    date: 'Jul 21',
    readTime: '5 min read',
    category: 'State Machines',
    type: 'Article',
    tags: ["flutter", "dart", "statemanagement", "signals"],
  ),
  PublicationItem(
    title: 'BLoC meets Signals: How to Pitch BlocSignal to Your Dev Leads',
    description:
        'Introducing a new state manager to a Flutter team is hard. Here is how to handle the tough architectural reviews for BlocSignal (BLoC + Signals).',
    url:
        'https://dev.to/gde/bloc-meets-signals-how-to-pitch-blocsignal-to-your-dev-leads-3m98',
    date: 'Jul 20',
    readTime: '5 min read',
    category: 'State Machines',
    type: 'Article',
    tags: ["flutter", "dart", "statemanagement", "architecture"],
  ),
  PublicationItem(
    title:
        'Introducing BlocSignal: Unidirectional Data Flow Meets Reactive Signals',
    description:
        'Bridge the architectural boundaries of BLoC/Cubit with the synchronous performance and simplicity of reactive Signals in Dart and Flutter.',
    url:
        'https://dev.to/gde/introducing-blocsignal-unidirectional-data-flow-meets-reactive-signals-48b2',
    date: 'Jul 19',
    readTime: '4 min read',
    category: 'State Machines',
    type: 'Article',
    tags: ["flutter", "dart", "statemanagement", "blocsignal"],
  ),
];

class PublicationsPage extends StatefulComponent {
  const PublicationsPage({super.key});

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  String _activeCategory = 'All';

  @override
  Component build(BuildContext context) {
    final filteredPublications = _activeCategory == 'All'
        ? _publications
        : _publications
            .where((pub) =>
                pub.category == _activeCategory || pub.type == _activeCategory)
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
              span(
                  classes: 'badge-video',
                  [Component.text('🎬 Featured Video')]),
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
                classes: 'btn-filter ${_activeCategory == cat ? 'active' : ''}',
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
                    span(
                        classes: 'pub-category',
                        [Component.text(pub.category)]),
                    span(
                        classes: 'pub-readtime',
                        [Component.text(pub.readTime)]),
                  ]),
                  h3(classes: 'pub-card-title', [Component.text(pub.title)]),
                  p(
                      classes: 'pub-card-desc',
                      [Component.text(pub.description)]),
                  div(classes: 'pub-card-footer', [
                    div(classes: 'pub-tags-list', [
                      for (final tag in pub.tags)
                        span(
                            classes: 'pub-tag-pill', [Component.text('#$tag')]),
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
}
