## 📝 Description

<!-- Provide a brief description of the changes introduced by this pull request. -->

Fixes #<!-- Link the issue number here, for example: Fixes #123 -->

---

## 🔍 Type of Change

- [ ] 🐛 Bug fix (non-breaking change fixing an issue)
- [ ] ✨ New feature (non-breaking change adding functionality)
- [ ] 💥 Breaking change (fix or feature causing existing functionality to change)
- [ ] 📚 Documentation update
- [ ] 🛠️ Refactoring / Code quality improvement
- [ ] ⚡ Performance optimization
- [ ] 🧪 Tests / Benchmarks

---

## ✅ Quality & Contributor Checklist

Please verify that all the following criteria are met before requesting review:

- [ ] **100% Line Coverage**: All new or modified code includes unit/widget tests maintaining 100% line coverage.
- [ ] **Workspace Tests Pass**: `dart run tool/run_workspace_tests.dart` executes with zero failures.
- [ ] **Strict Linter Clean**: `dart analyze --fatal-infos` passes with 0 errors, warnings, or infos.
- [ ] **Code Formatted**: `dart format .` has been run on all files.
- [ ] **Phrasing Standards**: No Latin abbreviations (`e.g.` or `i.e.`) are used in documentation or comments (written as "for example" / "that is").
- [ ] **SDK Baseline Constraints**:
  - Published packages (`bloc_signals*`) strictly conform to `sdk: ^3.5.0` without post-3.5 language features.
  - Workspace root, website, and tooling conform to `sdk: ^3.13.0`.
- [ ] **Public API Documentation**: All public classes, methods, and functions include `///` doc comments with runnable examples (160/160 pub points compliance).
- [ ] **Plugin Manifest Integrity**: `dart run tool/validate_agent_plugin.dart` passes cleanly.

