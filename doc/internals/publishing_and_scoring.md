# Monorepo Package Publishing & Pub Points Scoring Guide

This document details the internal requirements, release checklists, and scoring standards needed to achieve maximum quality scores (160/160 pub points) across all 11 published packages in the `BlocSignal` monorepo.

---

## 🎯 1. 160/160 Pub Points Scoring Requirements

When publishing packages to pub.dev:

### A. Explicit Documented Constructors for Dartdoc Analysis
- **Implicit Constructor Issue**: Implicit default constructors on classes without explicit constructor declarations (for example `abstract class BlocSignalObserver` or `class Mutex`) are treated as un-documented symbols by `dartdoc` analysis when re-exported.
- **Requirement**: Always declare explicit documented constructors (for example `const BlocSignalObserver();` and `Mutex();`) on all public classes, abstract classes, and mixins.

### B. Mandatory Package Example
- Every published pub.dev package MUST include a runnable `example/example.dart` top-level file under `example/` in the package root to satisfy the 10/10 points "Package has an example" score checklist rule.

### C. Mandatory `LICENSE` File
- Every published package root directory MUST contain a `LICENSE` file in addition to `pubspec.yaml`, `README.md`, and `CHANGELOG.md`.

### D. Explicit Transitive Dependency Declaration
- Any package directly imported in `lib/` (even if imported only for a type annotation like `SignalEquality` or re-exported transitively) MUST be explicitly listed under `dependencies:` in `pubspec.yaml`. Otherwise, `flutter pub publish` validation fails with missing dependency errors.

### E. Mandatory `flutter pub publish` over `dart pub publish`
- **Flutter SDK Workspace Context**: In monorepo workspaces containing Flutter member packages (for example `bloc_signals_flutter`, `bloc_signals_devtools`) or Flutter example packages (for example `riverpod_marvel_example`), running `dart pub publish` or `dart pub publish --dry-run` fails during dependency version solving with:
  ```
  Because riverpod_marvel_example requires the Flutter SDK, version solving failed.
  Flutter users should use `flutter pub` instead of `dart pub`.
  ```
- **Universal Publishing Rule**: Always invoke `flutter pub publish [--dry-run]` across all workspace packages, including pure Dart packages (`bloc_signals`, `bloc_signals_hydrate`, etc.).

### F. Multi-Major Dependency Lower Bounds (`dart pub downgrade` Scoring Check)
- **Pub.dev Lower Bounds Requirement**: Pub.dev awards 20 points under "Compatible with dependency constraint lower bounds" by running `dart pub downgrade` followed by `dart analyze`.
- **Dual Entrypoint Strategy**: If bridging across multiple major versions of a dependency (for example `riverpod: ">=2.5.0 <4.0.0"`) where export locations changed across versions, import both library entrypoints (`package:foo/foo.dart` and `package:foo/src/internals.dart`) with `hide` clauses for ambiguous classes, and suppress `unnecessary_import: ignore` in `analysis_options.yaml`.
- **Pre-Publishing Validation**: Always run `dart pub global run pana <pkg>` or test `flutter pub downgrade && dart analyze` to ensure 0 errors on lower bounds before publishing.

---

## 📋 2. Monorepo Documentation Consistency

### Uniform Package Catalog Table
Ensure all 11 published workspace package `README.md` files feature the exact same uniform 11-package ecosystem catalog table with pub version badges, pub points badges, and descriptions:
1. `bloc_signals`
2. `bloc_signals_flutter`
3. `bloc_signals_bloc`
4. `bloc_signals_riverpod`
5. `bloc_signals_test`
6. `bloc_signals_lint`
7. `bloc_signals_hydrate`
8. `bloc_signals_otel`
9. `bloc_signals_replay`
10. `bloc_signals_jaspr`
11. `bloc_signals_devtools`

### Mandatory Public API Docstrings
- **Complete Docstring Coverage**: Always write clear, comprehensive Dart doc-comments (`///`) with descriptive summaries, parameter explanations, and runnable code examples.
- **Zero Undocumented Symbols**: No public member, method, constructor, or re-exported symbol should ever be committed or published without complete docstrings.

### Continuous `## Unreleased` Changelog Accumulation & Release Promotion Lifecycle (`SCAR-DOC-18`)
1. **Per-PR `## Unreleased` Accumulation**: Every PR touching `lib/`, `bin/`, or `pubspec.yaml` in a member package must append a categorized bullet (`- **BREAKING (<scope>)**:`, `- **Feat (<scope>)**:`, `- **Fix (<scope>)**:`, `- **Perf (<scope>)**:`, `- **Docs (<scope>)**:`, `- **Dependencies**:`) with `(#XXX)` under `## Unreleased` at the top of that package's `CHANGELOG.md` (creating the `## Unreleased` section above the latest `## X.Y.Z` version heading if absent). Do not bump `version:` in `pubspec.yaml` during regular feature/fix PRs.
2. **Release-Time Promotion (`## Unreleased` to `## X.Y.Z`)**: When cutting a package release, replace the `## Unreleased` heading directly with `## X.Y.Z` (never leave an empty `## Unreleased` section at the top of `CHANGELOG.md`, as `pana` and `pub.dev` expect the top heading to match `pubspec.yaml`'s `version:`), bump `version: X.Y.Z` in `pubspec.yaml`, and synchronize the uniform package catalog table across `README.md` files and `website/lib/src/components/package_catalog.dart`.

---

## 🚫 3. Pre-Release & Unpublished Packages (GenUI & A2UI)

### Why GenUI Packages Cannot Be Published to pub.dev
The monorepo contains two Generative UI packages:
- `bloc_signals_genui` (pure-Dart A2UI streaming state machine)
- `bloc_signals_genui_flutter` (Flutter catalog widgets and surface containers)

These packages currently depend on an unreleased, git-overridden fork of Google's `a2ui_core` package (`ref: fix/widen-preact-signals-a2ui-core`). Because pub.dev strictly disallows packages with git dependencies or dependency overrides, **`bloc_signals_genui` and `bloc_signals_genui_flutter` cannot and must not be published to pub.dev**.

### Operational Rules for GenUI Packages:
1. **Never Run `flutter pub publish` on GenUI Packages**: Do not attempt to publish `bloc_signals_genui` or `bloc_signals_genui_flutter` to pub.dev until Google officially publishes `a2ui_core` on pub.dev and the git dependency override is removed.
2. **Never Add pub.dev Badges to GenUI Packages**: In documentation, websites, and readmes, display "Developer Preview" or "Git Only" badges linking to GitHub rather than generating broken `pub.dev/packages/` links.
3. **Workspace Release Scripts**: Monorepo release scripts must explicitly skip `bloc_signals_genui` and `bloc_signals_genui_flutter` during batch publishing passes.

---

## 🚀 4. Pre-Publishing Checklist

Before running `flutter pub publish` on any member package:
1. **Workspace Tests**: Run `dart run tool/run_workspace_tests.dart` (must pass 100%).
2. **Coverage**: Ensure 100% line coverage across modified packages.
3. **Format**: Run `dart format .`.
4. **Dry Run**: Run `flutter pub publish --dry-run` in the package root to check for any scoring or packaging warnings (verify package is one of the 11 published packages, not a GenUI package).

---

## 🔄 5. Pub.dev Synchronization Publish Sweep Protocol

When asked to perform a `pub.dev` synchronization publish sweep across the workspace:

1. **Discover Candidates**: Scan the 11 published packages (excluding `bloc_signals_genui` and `bloc_signals_genui_flutter`) for `## Unreleased` sections in `CHANGELOG.md`.
2. **Compute Next SemVer Version**: For each candidate package, inspect the categorized bullets under `## Unreleased`:
   - Any `- **BREAKING ...**:` bullet $\implies$ **Major** bump (or minor if `0.x`).
   - Any `- **Feat ...**:` bullet $\implies$ **Minor** bump.
   - Only `- **Fix ...**:`, `- **Perf ...**:`, `- **Docs ...**:`, or `- **Dependencies**:` bullets $\implies$ **Patch** bump.
3. **Promote Changelogs & Bump `pubspec.yaml`**:
   - Replace `## Unreleased` with `## <new_version>` in each candidate package's `CHANGELOG.md` (do not leave an empty `## Unreleased` heading).
   - Update `version: <new_version>` in each candidate package's `pubspec.yaml`.
   - If `bloc_signals` (or another upstream workspace package) is bumped and downstream packages depend on new upstream behavior/contracts, tighten the dependency constraint (`bloc_signals: ^<new_version>`) in the downstream `pubspec.yaml` and record `- **Dependencies**: Bump bloc_signals to ^<new_version>.` in the downstream changelog.
4. **Synchronize Ecosystem Catalogs**:
   - Update the `version:` fields for all bumped packages in `website/lib/src/components/package_catalog.dart` (and any static version tables in `README.md` files if present).
5. **Validate & Commit**:
   - Run `dart format .`, `dart analyze`, `flutter test test/validate_agent_plugin_test.dart`, and `flutter pub publish --dry-run` inside each bumped package directory.
   - Commit the release preparation (`chore(release): bump <packages> to <versions>`) and tag each released package on that commit using `<package_name>-v<new_version>` (for example `bloc_signals_flutter-v1.3.4`).
6. **Topological Publish Execution**:
   - Always publish in topological dependency order so `pub.dev` resolves newly tightened upstream constraints:
     1. **Tier 0 (Core)**: `bloc_signals`
     2. **Tier 1 (Direct Core Dependents)**: `bloc_signals_flutter`, `bloc_signals_bloc`, `bloc_signals_riverpod`, `bloc_signals_test`, `bloc_signals_lint`, `bloc_signals_hydrate`, `bloc_signals_otel`, `bloc_signals_replay`, `bloc_signals_jaspr`, `bloc_signals_devtools`
   - Execute `flutter pub publish --force` (after human approval) in each bumped package directory.


