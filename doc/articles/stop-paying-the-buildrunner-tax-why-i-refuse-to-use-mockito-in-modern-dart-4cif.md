---
title: "Stop Paying the build_runner Tax: Why I Refuse to Use Mockito in Modern Dart"
published: true
description: "Why code-generated mocks ruin developer velocity in modern Dart and Flutter, and how switching to mocktail restores true zero-friction TDD."
tags: dart, flutter, testing, architecture
series: "Dart and Flutter"
---

_This is Part 1 of the **Dart and Flutter** series—practical guides, architectural deep dives, and hard-earned engineering lessons from the field. Each article is completely standalone._

---

Picture this familiar scene:

You’re deep in the zone. You’re practicing disciplined Test-Driven Development (TDD). You write a failing test, write the minimal code to satisfy it, and refactor. Red, green, refactor. Your fingers are flying.

Then, you add a single new method to your `UserRepository` interface:

```dart
Future<void> updatePreferences(UserPreferences prefs);
```

You switch back to your test file to stub it, and everything grinds to a dead stop. Your IDE lights up with red squiggly lines because the generated mock doesn't know about `updatePreferences` yet. 

You sigh, drop into the terminal, and type the dreaded incantation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Now you wait. 15 seconds. 30 seconds. On a large enterprise Flutter codebase, maybe two full minutes. The fan spins up. Your train of thought derails. By the time the builder finishes generating boilerplate Dart files, you've lost your flow state.

Why on earth are we running heavyweight compile-time code generation just to create a mock object for a unit test?

It’s time to stop using `mockito` in modern Dart. There is a much better way.

---

## How Did We End Up Here?

To be fair to the `mockito` maintainers, `mockito` didn’t set out to be slow. 

In the pre-null-safety era of Dart, `mockito` was the undisputed king. You created a mock class with `class MockRepo extends Mock implements Repo {}`, and Dart’s runtime dynamic invocation (`noSuchMethod`) handled everything under the hood with zero code generation. It was snappy and painless.

Then came **Sound Null Safety** in Dart 2.12.

Null safety is one of the best things that ever happened to Dart, but it broke `mockito`'s runtime magic. In a soundly typed null-safe language, if an interface method declares that it returns a non-nullable `User`, `noSuchMethod` cannot simply return `null` while waiting for your `when(...)` stub to register. Returning `null` violates the type system and throws an immediate runtime error before your stubbing logic even runs.

Because Dart has deliberately avoided heavy runtime reflection (`dart:mirrors` is disabled in Flutter for performance and tree-shaking reasons), `mockito` chose the only route available to it at the time: **compile-time code generation via `build_runner`**.

It solved the type-safety problem, but it introduced the dreaded **`build_runner` tax**.

---

## The Three Sins of Modern Mockito

Relying on `mockito` today saddles your codebase with three distinct engineering bottlenecks:

### 1. The Iteration Tax (Destroying the TDD Flow)
TDD relies on tight feedback loops measured in milliseconds. When every interface change or mock signature update requires running code generation, the feedback loop stretches into tens of seconds. Developers stop running tests frequently. They batch their changes, commit without verifying, and run tests as an afterthought. Velocity plummets.

### 2. Git Diff Pollution & Merge Conflict Hell
For every test file with mocks, `mockito` generates a `.mocks.dart` sibling file. These files are thousands of lines of machine-generated boilerplate. 
* They pollute pull request reviews.
* They clutter repository search results.
* When two developers touch overlapping service interfaces on separate branches, merging their generated `.mocks.dart` files triggers brutal, unreadable merge conflicts.

### 3. Brittle Annotation Coupling
With `mockito`, your tests are coupled to global library annotations:

```dart
// test/user_service_test.dart
import 'user_service_test.mocks.dart';

@GenerateMocks([HttpClient, UserRepository])
void main() {
  // ...
}
```

Want to mock a third dependency? You have to edit the annotation list, rerun `build_runner`, wait for the file system to update, and import the generated symbols. It's clunky and mechanical.

---

## Enter Mocktail: Zero-Config Runtime Mocking

Enter **[mocktail](https://pub.dev/packages/mocktail)**, created by Felix Angelov (of Bloc and Very Good Ventures fame).

`mocktail` delivers the exact same intuitive API you know from `mockito`, but with **zero code generation**. No `build_runner`. No `.mocks.dart` files. No annotations.

How? By leveraging two native features of Dart:
1. **Dart’s implicit interfaces**: In Dart, every class implicitly defines an interface. You can implement any class without inheriting its implementation.
2. **Closures for stubbing**: Instead of evaluating the mock invocation directly (which triggers the null-safety problem), `mocktail` wraps the invocation inside a closure: `() => mock.getUser()`. This defers execution until `mocktail` can safely intercept and return the registered stub or a fallback value.

Here is how you declare a mock in `mocktail`:

```dart
import 'package:mocktail/mocktail.dart';

// No annotations. No build_runner. Just pure, clean Dart.
class MockUserRepository extends Mock implements UserRepository {}
class MockHttpClient extends Mock implements HttpClient {}
```

That’s it. You define the class right in your test file (or in a shared `test_helpers.dart`), hit save, and run your tests instantly.

---

## Side-by-Side: Mockito vs. Mocktail

The migration from `mockito` to `mocktail` requires practically zero mental re-learning:

| Feature | `mockito` | `mocktail` 🍹 |
| :--- | :--- | :--- |
| **Code Generation** | Requires `build_runner` | **None (Pure runtime)** |
| **Declaration** | `@GenerateMocks([UserRepo])` | `class MockUserRepo extends Mock implements UserRepo {}` |
| **Synchronous Stub** | `when(repo.name).thenReturn('Randal')` | `when(() => repo.name).thenReturn('Randal')` |
| **Asynchronous Stub** | `when(repo.fetch()).thenAnswer((_) async => user)` | `when(() => repo.fetch()).thenAnswer((_) async => user)` |
| **Argument Matchers** | `anyNamed('id')`, `anyString` | `any(named: 'id')`, `any()` |
| **Verification** | `verify(repo.login()).called(1)` | `verify(() => repo.login()).called(1)` |

Notice the only primary syntax difference: `mocktail` passes the invocation as an anonymous function `() => mock.method()`. 

That simple closure is the secret sauce that bypasses the need for compile-time code generation.

---

## The One "Gotcha": Custom Type Fallbacks

To be an objective engineer, you must evaluate the trade-offs. `mocktail` has exactly one gotcha, and once you understand it, it takes 5 seconds to address.

### The Problem
When you use flexible argument matchers like `any()` on a method that accepts a **non-nullable custom type**:

```dart
when(() => mockRepo.saveUser(any())).thenAnswer((_) async => true);
```

Dart’s sound type system insists that *something* matching the type `User` must be passed into `saveUser` during internal matcher registration. Under the hood, `mocktail` cannot synthesize an instance of your custom `User` class out of thin air. If it passed `null`, Dart would throw a type error.

If you don't tell `mocktail` how to satisfy that type, it will throw an informative exception:
```plaintext
Bad state: A test tried to use any() or captureAny() on a User which was not registered.
Register a fallback value using `registerFallbackValue`.
```

### The Solution
You define a dummy `Fake` and register it in `setUpAll`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// 1. Create a Fake implementation that satisfies the type checker
class FakeUser extends Fake implements User {}

void main() {
  setUpAll(() {
    // 2. Register it once before any tests run
    registerFallbackValue(FakeUser());
  });

  test('saves user profile', () async {
    final repo = MockUserRepository();
    when(() => repo.saveUser(any())).thenAnswer((_) async => true);

    final service = UserService(repo);
    final result = await service.updateProfile(User(id: '123', name: 'Randal'));

    expect(result, isTrue);
    verify(() => repo.saveUser(any())).called(1);
  });
}
```

That’s all there is to it. A two-line `Fake` registration in `setUpAll` completely eliminates the need to run `build_runner` on your entire project.

---

## How to Migrate Without Boiling the Ocean

If you’re staring at an existing codebase with dozens of `build_runner`-powered `.mocks.dart` files, you don't need to rewrite everything in a single frantic weekend PR. 

Take an incremental approach:

1. **Add `mocktail` to `dev_dependencies`**:
   ```yaml
   dev_dependencies:
     mocktail: ^1.0.4
   ```
2. **Migrate one test file at a time**:
   * Whenever you open an existing test file to add or modify a test, migrate *just that file*.
   * Delete the `.mocks.dart` import.
   * Replace `@GenerateMocks` with simple `class MockX extends Mock implements X {}` declarations.
   * Wrap your `when` and `verify` invocations in `() => ...`.
   * Delete the obsolete `.mocks.dart` file from disk.
3. **Commit the diff**: Notice how clean and readable your git diff is without hundreds of lines of autogenerated noise.

---

## The Verdict

The official Flutter documentation and cookbooks still mention `mockito` largely due to historical inertia. But we no longer live in 2020. 

In modern Dart, testing should be fast, expressive, and friction-free. Waiting on `build_runner` just to verify that a service method was called with the right argument is a waste of your machine's CPU cycles and your mental bandwidth.

Switch to `mocktail`. Your TDD cycle will thank you.

---

### What's your take?
Are you still running `build_runner` for your mocks, or have you already made the switch to `mocktail` (or hand-rolled fakes)? Let me know in the comments below!

---

*Randal L. Schwartz is a Google Developer Expert (GDE) for Dart & Flutter and veteran software architect.*

* 📺 Watch deep dives and walkthroughs on YouTube: **[@RandalOnDartAndFlutter](https://www.youtube.com/@RandalOnDartAndFlutter)**
* 💻 Connect on GitHub: **[@RandalSchwartz](https://github.com/RandalSchwartz)**
