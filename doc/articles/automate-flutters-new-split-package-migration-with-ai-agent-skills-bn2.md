---
title: "Automate Flutter's New Split Package Migration with AI Agent Skills"
description: "How to use dart-sdk-skills to empower your AI coding agent to seamlessly migrate Flutter projects to standalone material_ui and cupertino_ui packages."
tags: flutter, dart, ai, webdev
---

## How to use dart-sdk-skills to empower your AI coding agent to seamlessly migrate Flutter projects to standalone material_ui and cupertino_ui packages

The Flutter framework has undergone one of its most significant architectural evolutions: **the complete unbundling of Material Design and Cupertino libraries into standalone pub packages** ([`material_ui`](https://pub.dev/packages/material_ui) and [`cupertino_ui`](https://pub.dev/packages/cupertino_ui)).

While this decoupling brings independent release cycles, lighter core framework footprints, and true headless UI development, it also introduces a massive migration across existing Flutter apps.

If you rely on AI coding assistants (such as Claude Code, Google Antigravity, Cursor, GitHub Copilot, or Cline), you have likely hit a familiar wall: **LLM training cutoffs**. Most models still generate monolithic `package:flutter/material.dart` imports and do not know how to perform the new split package migration.

In this article, we will explore how the open-source [**`dart-sdk-skills`**](https://github.com/RandalSchwartz/dart-sdk-skills) repository gives your AI agent the exact knowledge and execution runbooks to automate this migration in a single prompt.

---

## 🏛️ The Architectural Shift: Why Split Packages?

Historically, Flutter bundled every Material Design and Cupertino widget directly into the core `flutter` SDK. While convenient initially, this approach had drawbacks:

1. **Coupled Release Cycles**: Updating a single Material button style required waiting for a framework release.
2. **Framework Bloat**: Apps building custom enterprise design systems were forced to bundle hundreds of unused Material and Cupertino classes.
3. **Design System Collision**: Mixing platform styles often led to tangled dependencies.

Under the modern decoupled architecture:

```plaintext
┌────────────────────────────────────────────────────────────────────────┐
│ Legacy Flutter (Monolithic)                                            │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ package:flutter/material.dart  &  package:flutter/cupertino.dart │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ package:flutter/widgets.dart   &  package:flutter/rendering.dart │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Modern Decoupled Architecture                                          │
│                                                                        │
│  ┌───────────────────────────────┐   ┌──────────────────────────────┐  │
│  │ package:material_ui           │   │ package:cupertino_ui         │  │
│  └───────────────┬───────────────┘   └──────────────┬───────────────┘  │
│                  └───────────────┬──────────────────┘                  │
│                                  ▼                                     │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Core Flutter SDK (package:flutter/widgets.dart)                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

Both design systems are now maintained as independent packages by the official Flutter team on pub.dev:
* **`material_ui`** (`^1.1.0`): Canonical entrypoint `package:material_ui/material_ui.dart`
* **`cupertino_ui`** (`^1.0.1`): Canonical entrypoint `package:cupertino_ui/cupertino_ui.dart`

---

## 🧩 The Challenge with AI Coding Agents

When you tell an unassisted AI agent:
> *"Migrate my app to the new split Flutter design packages."*

It often stumbles:
* It hallucinates deprecated import paths or non-existent package names.
* It does not know about the automated data-driven fix rules in the Dart analyzer.
* It misses breaking changes in localization delegates (`GlobalMaterialLocalizations`).

This is where **Agent Skills** step in.

---

## ⚡ What is `dart-sdk-skills`?

[**`dart-sdk-skills`**](https://github.com/RandalSchwartz/dart-sdk-skills) is an authoritative repository of version-by-version agent skills for the Dart and Flutter SDKs. Built using the open Agent Skill specification (`SKILL.md`), it progressively discloses precise rules, API matrices, and tactical upgrade runbooks to your AI pair programmer.

### Installing `dart-sdk-skills` in Seconds

You can add the skills globally or per-project using your preferred tool:

#### Universal Install (Node / `npx skills`):
```bash
# Install globally for all AI agents
npx skills add RandalSchwartz/dart-sdk-skills -g
```

#### Dart Skills CLI:
```bash
skills add https://github.com/RandalSchwartz/dart-sdk-skills --global --all
```

#### Google Antigravity / Manual Symlink:
```bash
git clone https://github.com/RandalSchwartz/dart-sdk-skills.git ~/Projects/Dart/dart-sdk-skills
ln -s ~/Projects/Dart/dart-sdk-skills/skills/flutter-sdk-changelog ~/.gemini/config/skills/flutter-sdk-changelog
```

---

## 🤖 The Migration Workflow: Putting Your Agent to Work

Once installed, your agent automatically recognizes split-package requests. Simply prompt:

> **"Migrate this project to the new split Material and Cupertino packages."**

Here is the exact multi-phase pipeline the agent executes based on the skill runbook:

### 1. Automated Analysis and Data-Driven Transforms
The agent leverages the built-in Dart toolchain fix runner:

```bash
dart fix --apply --code=migrate_design_widgets
```

This updates references and applies data-driven transform rules published inside `material_ui/lib/fix_data/`.

### 2. Dependency Configuration (`pubspec.yaml`)
The agent ensures your project bounds satisfy the minimum SDK constraints (`Flutter >=3.44.0`, `Dart ^3.12.0`):

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Standalone design systems
  material_ui: ^1.1.0
  cupertino_ui: ^1.0.1
```

### 3. Canonical Import Rewrites
The agent replaces monolithic imports across all Dart files with the canonical entrypoints:

```dart
// ❌ Legacy Monolithic Imports
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// ✅ Modern Standalone Package Imports
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
```

### 4. Localization Delegate Binding
Both `material_ui.dart` and `cupertino_ui.dart` export their respective global localization delegates without requiring extra legacy glue:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

Widget buildApp() {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en', 'US'),
      Locale('es', 'ES'),
    ],
    home: const HomeScreen(),
  );
}
```

### 5. Automated Verification & Quality Gate
The agent finishes by running static analysis and tests to ensure no ambiguous symbol collisions or unresolved imports remain:

```bash
dart analyze --fatal-infos
dart test
```

---

## 🎨 Bonus: Building Pure Headless Apps

One of the greatest benefits of this decoupling is that Flutter apps with custom enterprise design systems can now completely omit `material_ui` and `cupertino_ui`.

By building directly against `package:flutter/widgets.dart`, you can create a lightweight, high-performance UI layer with zero design system bloat:

```dart
import 'package:flutter/widgets.dart';

class BrandButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const BrandButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: child,
      ),
    );
  }
}
```

---

## 🚀 Get Started Today

The split package architecture is a major milestone for Flutter's scalability and modularity. By equipping your AI development workflow with [**`dart-sdk-skills`**](https://github.com/RandalSchwartz/dart-sdk-skills), you turn what could be a tedious manual refactor into an effortless, one-command migration.

* 🌟 **GitHub Repository**: [github.com/RandalSchwartz/dart-sdk-skills](https://github.com/RandalSchwartz/dart-sdk-skills)
* 📦 **`material_ui` on Pub**: [pub.dev/packages/material_ui](https://pub.dev/packages/material_ui)
* 🍏 **`cupertino_ui` on Pub**: [pub.dev/packages/cupertino_ui](https://pub.dev/packages/cupertino_ui)

Happy coding, and let your agents do the heavy lifting! 🚀
