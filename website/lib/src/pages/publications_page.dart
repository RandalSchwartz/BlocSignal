import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/footer.dart';
import '../components/navbar.dart';
import '../models/app_route.dart';
import '../models/publications_data.g.dart';

export '../models/publication_item.dart' show PublicationItem;

class const PublicationsPage({super.key}) extends StatefulComponent {
  static const allPublications = publications;

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState() extends State<PublicationsPage> {
  String _activeCategory = 'All';

  @override
  Component build(BuildContext context) {
    final filteredPublications = _activeCategory == 'All'
        ? publications
        : publications
              .where(
                (pub) =>
                    pub.category == _activeCategory ||
                    pub.type == _activeCategory,
              )
              .toList();

    final validPublications = filteredPublications
        .where((pub) => pub.isHttps)
        .toList();

    return div(classes: 'app-root', [
      const Navbar(currentRoute: AppRoute.publications),
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
              'Explore technical deep dives, architectural guides, DEV.to articles, and video walkthroughs by Randal L. Schwartz.',
            ),
          ]),
        ]),

        // Featured Video Section
        div(classes: 'container', [
          div(classes: 'video-featured-card', [
            div(classes: 'video-card-badge', [
              span(classes: 'badge-video', [
                Component.text('🎬 Featured Video'),
              ]),
              span(classes: 'badge-date', [Component.text('Aug 06, 2026')]),
            ]),
            h2(classes: 'video-title', [
              Component.text('BlocSignal 1.0 Architecture & Overview'),
            ]),
            p(classes: 'video-desc', [
              Component.text(
                'By Randal L. Schwartz — A comprehensive technical walkthrough demonstrating synchronous signal graph propagation, 0ms microtask delay, BLoC event traceability, and multi-package interop across Flutter, Riverpod, and Jaspr web.',
              ),
            ]),
            div(classes: 'video-player-box', [
              iframe(
                src: 'https://www.youtube-nocookie.com/embed/fwmlVOjsdgQ',
                attributes: {
                  'title': 'BlocSignal 1.0 Architecture & Overview',
                  'allow': 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture',
                  'allowfullscreen': 'true',
                },
                [],
              ),
            ]),
            div(classes: 'video-watch-footer', [
              a(
                href: 'https://www.youtube.com/watch?v=fwmlVOjsdgQ',
                target: Target.blank,
                attributes: const {'rel': 'noopener noreferrer'},
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
              'Interop & Telemetry',
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
            for (final pub in validPublications)
              a(
                href: pub.url,
                target: Target.blank,
                attributes: const {'rel': 'noopener noreferrer'},
                classes: 'pub-card',
                [
                  div(classes: 'pub-card-top', [
                    span(classes: 'pub-category', [
                      Component.text(pub.category),
                    ]),
                    span(classes: 'pub-readtime', [
                      Component.text(pub.readTime),
                    ]),
                  ]),
                  h3(classes: 'pub-card-title', [Component.text(pub.title)]),
                  p(classes: 'pub-card-desc', [
                    Component.text(pub.description),
                  ]),
                  div(classes: 'pub-card-footer', [
                    div(classes: 'pub-tags-list', [
                      for (final tag in pub.tags)
                        span(classes: 'pub-tag-pill', [
                          Component.text('#$tag'),
                        ]),
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
