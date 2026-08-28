# Website Architecture, Publications & Deployment (`blocsignal.dev`)

This document details the internal operations, build pipeline, content workflows, and deployment protocols for the official documentation hub and showcase website (`website/` at `blocsignal.dev`).

---

## 🌐 1. Website Structure & Navigation Architecture

- **Framework**: Built with Jaspr Web (static / client mode).
- **Routing**: Supported routes include:
  - `HomePage` (`/`)
  - `ShowcasePage` (`/showcase`)
  - `PortedExamplesPage` (`/ported-examples`)
  - `MinesweeperPage` (`/minesweeper`)
  - `PublicationsPage` (`/publications`)
  - `DocsPage` (`/docs`, `/docs/:chapter`)
- **URL Handling**: Supports both HTML5 history API pathnames and `/#<route>` hash routing fallbacks for static hosting environments.

### SPA Navigation Architecture (Button Navigation vs Link Navigation)
In Single Page Applications (SPAs) with 0ms synchronous DOM swapping:
- **Semantic `<button>` Elements**: Sidebar navigation items, category links, and footer pagination cards MUST use semantic `<button>` elements (with CSS resets) rather than `<a>` tags for internal state-driven route switching.
- **Double-Bounce Prevention**: This eliminates trailing native browser navigation conflicts and `preventDefault` JS interop errors on extension types during 0ms synchronous DOM swaps, while maintaining full keyboard accessibility and clean HTML5 history integration.

### CSS `backdrop-filter` Stacking Context & Full-Viewport Overlays
When designing mobile drawers, modals, or fixed overlay panels nested inside sticky/glassmorphic headers:
- **Containing Block Trap**: In the CSS specification, any ancestor element with `backdrop-filter` or `transform` creates a new containing block for `position: fixed` children, causing `position: fixed; inset: 0;` to resolve relative to the ancestor's box rather than the viewport.
- **Full-Viewport Protection**: To prevent fixed overlays from getting constrained to navbar heights, explicitly specify `width: 100vw; height: 100vh; height: 100dvh;` on `.nav-drawer-backdrop` and `.nav-drawer-panel` with high z-indices (`10001+`).

### Modern Dart Web Interop & Wasm Safety
- **`package:web` as Standard**: Use `import 'package:web/web.dart' as web;`. Do NOT use `dart:html`, `dart:js`, `dart:js_util`, or `package:js`, as they rely on legacy JS runtime boxing and fail under Dart WebAssembly (Wasm) compilation.
- **String Arguments**: Modern `package:web` APIs (such as `web.window.navigator.clipboard.writeText(str)`) accept standard Dart `String` arguments directly without requiring manual `.toJS` casting.
- **Defensive Fault-Tolerance**: Always wrap browser APIs in `try-catch` blocks to prevent uncaught exceptions in headless, iframe, or permission-restricted environments.

---

## 📚 2. Documentation Hub & Symbol Registry

### API Symbol Registry Synchronization (`PubApiRegistry` & `DocSymbol`)
When publishing new packages or adding new public classes, mixins, extensions, or major methods across the monorepo:
1. **Registry Alignment**: Update `DocSymbol` in `website/lib/src/models/pub_api_registry.dart` with the canonical pub.dev dartdoc entry (`<package>`, `<symbolName>`, `<htmlFile>`).
2. **Interactive Linking**: Use `apiLink(DocSymbol.<name>)` or `apiLink(DocSymbol.<name>, label: '...')` across documentation pages, matrices, and prose paragraphs so developers can click through directly to official pub.dev API reference pages.
3. **Heading Typography Hygiene**: Section titles and headings (`h2`, `h3`) must remain clean plain text (for example `h2([Component.text('1. BlocSignalBuilder')])`) rather than wrapped in interactive code badges. Reserve `apiLink` badges exclusively for body prose, table cells, and callout descriptions.
4. **Unit Testing**: Keep `website/test/pub_api_registry_test.dart` updated with test expectations verifying URL formation and symbol presence.

### Dual Dart Syntax Documentation Standard (`selectedDartVersion`)
When authoring code snippets and documentation in the website:
- **Dual Presentation**: Maintain the dual Dart 3.13+ (modern primary constructors, parameter shorthands, `this` bodies) vs Dart 3.5 (baseline) presentation in docs and snippets whenever feasible.
- **Global Preference with Local Overrides**: Connect `DocsCodeBlock` to `DocsCubit.selectedDartVersion` via the global sidebar toggle (`3.13+ Modern` vs `3.5 Baseline`), while allowing readers to override individual code blocks via inline tabs.

### Jaspr Component Reactivity & `BlocSignalBuilder`
- **Declarative Builders**: `StatelessComponent.build()` executes during initial rendering but will NOT automatically re-render when a state container (`DocsCubit` or `BlocSignal`) emits new state unless the component is wrapped in `BlocSignalBuilder<B, S>` (or uses `SignalBuilder` / `Observer`).
- **State Wrapping**: Always wrap dynamic article viewers or state-dependent components in `BlocSignalBuilder` to ensure state updates trigger immediate UI rebuilds.

---

## 📰 3. DEV.to Articles & Publications Sync

### Automated DEV.to Publications Sync Tools
- **Publications Directory Sync**: `website/tool/update_publications.dart`
  - Function: Queries the DEV.to public API (`https://dev.to/api/articles?username=randalschwartz&per_page=50`), extracts canonical article URLs, titles, descriptions, reading times, publish dates, and tags, and automatically regenerates `website/lib/src/pages/publications_page.dart`.
  - Command: `cd website && dart run tool/update_publications.dart`
- **Markdown Article Archive Sync**: `tool/sync_all_articles.dart`
  - Function: Downloads and refreshes the full markdown bodies of all published DEV.to articles into `doc/articles/` to maintain a local repository knowledge base.
  - Command: `dart run tool/sync_all_articles.dart`
  Run these tools whenever new DEV.to articles or media are published.

### DEV.to Article Frontmatter & Series Protocol
When generating or updating DEV.to draft articles:
1. **Series Frontmatter**: Always include `series: "BlocSignal Architecture & Practice"` (or the designated series title) as the **very first line** inside the YAML frontmatter right under `---`. Placing `series:` at the top of frontmatter ensures DEV.to's API & background parser index the article into the correct series automatically.
2. **Frontmatter Standards**: Always set `published: true`, `title:`, `description:`, and `tags:`. Do NOT include `cover_image:` or `canonical_url:` because DEV.to is the canonical publisher and host.
3. **Body Subhead**: Always start the article body text (immediately after the closing `---` of frontmatter) with a Level 2 subhead (`## ...`).

---

## 🚀 4. Re-compile, Preview & Deployment Protocol

1. **Version Alignment**: Update `website/lib/src/components/package_catalog.dart` with newly published package version numbers.
2. **Hero Snippet Alignment**: Update `website/lib/src/components/hero.dart` code snippets to reflect published pubspec dependency constraints.
3. **Compile Static Bundle**:
   Compile static bundle and generate route fallback index files for static servers (`dhttpd` and Firebase Hosting):
   ```bash
   dart run website/tool/build_static.dart
   ```
4. **Local Preview Server in AGY IDE**:
   The user runs `(cd website/build/www && dhttpd -p 0)` in their AGY IDE terminal window to serve `website/build/www/` on a random port for live visual testing without interfering with agent test runners. Always run `dart run website/tool/build_static.dart` after updating website code so the user's IDE preview window reflects the latest build.
5. **Deploy to Firebase Hosting**:
   ```bash
   firebase deploy --only hosting
   ```
