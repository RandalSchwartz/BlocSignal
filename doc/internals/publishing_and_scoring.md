# Monorepo Package Publishing & Pub Points Scoring Guide

This document details the internal requirements, release checklists, and scoring standards needed to achieve maximum quality scores (160/160 pub points) across all 10 packages in the `BlocSignal` monorepo.

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

---

## 📋 2. Monorepo Documentation Consistency

### Uniform Package Catalog Table
Ensure all 10 workspace package `README.md` files feature the exact same uniform 10-package ecosystem catalog table with pub version badges, pub points badges, and descriptions:
1. `bloc_signals`
2. `bloc_signals_flutter`
3. `bloc_signals_riverpod`
4. `bloc_signals_test`
5. `bloc_signals_lint`
6. `bloc_signals_hydrate`
7. `bloc_signals_otel`
8. `bloc_signals_replay`
9. `bloc_signals_jaspr`
10. `bloc_signals_devtools`

### Mandatory Public API Docstrings
- **Complete Docstring Coverage**: Always write clear, comprehensive Dart doc-comments (`///`) with descriptive summaries, parameter explanations, and runnable code examples.
- **Zero Undocumented Symbols**: No public member, method, constructor, or re-exported symbol should ever be committed or published without complete docstrings.

---

## 🚀 3. Pre-Publishing Checklist

Before running `flutter pub publish` or `dart pub publish` on any member package:
1. **Workspace Tests**: Run `dart run tool/run_workspace_tests.dart` (must pass 100%).
2. **Coverage**: Ensure 100% line coverage across modified packages.
3. **Format**: Run `dart format .`.
4. **Dry Run**: Run `dart pub publish --dry-run` in the package root to check for any scoring or packaging warnings.
