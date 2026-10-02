---
title: "Share State Across Dart Isolates Without Losing Your Mind: Enter shared_map"
published: true
description: "How to bypass tedious SendPort/ReceivePort plumbing and share synchronized in-memory state across Dart Isolates using the zero-dependency shared_map package."
tags: dart, flutter, architecture, concurrency
series: "Dart and Flutter"
---

_This is Part 3 of the **Dart and Flutter** series—practical guides, architectural deep dives, and hard-earned engineering lessons from the field. Each article is completely standalone._

---

Dart’s concurrency model is built on **Isolates**. Unlike threads in Java, C++, or Go, Dart isolates share no memory. Each isolate has its own private heap and its own single-threaded event loop.

This "share-nothing" model is a brilliant design decision. It completely eliminates data races, deadlocks, mutex contention, and tricky thread-synchronization bugs. 

**Until, of course, you actually *need* to share data across isolates.**

Imagine this common production scenario:

You’re building a Flutter app that crunches heavy data in the background—perhaps resizing multiple images, decoding massive JSON payloads, computing cryptographic hashes, or running complex ML calculations. To keep your UI silky smooth at 120 FPS, you offload the work to background isolates using `Isolate.run`.

Now suppose all these concurrent background workers need access to a **shared, in-memory cache** (like parsed metadata, authentication tokens, or shared computation results) to avoid duplicate work.

How do you do that in Dart?

Traditionally, you only had two bad choices:

1. **Serialize and copy the whole data structure** back and forth across isolate boundaries every time. For large maps or high-frequency operations, this burns CPU and produces massive GC pressure.
2. **Hand-roll a message-passing server** using `ReceivePort` and `SendPort`. You have to invent custom request/response DTOs, generate unique request correlation IDs, wire up response completers, and write 150 lines of brittle plumbing just to perform a simple key-value lookup.

There is a third, vastly superior option that almost nobody talks about: **[`package:shared_map`](https://pub.dev/packages/shared_map)**.

---

## What is `shared_map`?

Created by veteran Dart engineer Graciliano M. Passos, `shared_map` provides a versatile, synchronized `Map` data structure designed specifically to be shared across Dart isolates and asynchronous workflows.

Here is what makes it an architectural gem:
* **Zero Dependencies**: It is pure, clean Dart with zero third-party dependencies.
* **160 / 160 Pub Points**: Flawless quality score on pub.dev and fully Dart 3 compatible.
* **Universal Platform Support**: Runs anywhere Dart runs—iOS, Android, macOS, Windows, Linux, Web, and backend CLI/servers.
* **Familiar Map Semantics**: You interact with it using standard async key-value methods like `get()`, `put()`, `putIfAbsent()`, and `update()`.

Instead of you manually orchestrating ports, `shared_map` manages the cross-isolate communication protocol transparently under the hood.

---

## How It Works: The Reference Pattern

The core mental model of `shared_map` is dead simple:

1. **Main Instance**: You create a `SharedMap` on your primary isolate (like your Flutter UI thread or main server loop). This instance acts as the authoritative source of truth.
2. **Shared Reference**: You call `.sharedReference()` to generate a lightweight, serializable token.
3. **Auxiliary Instance**: You pass that lightweight token across an isolate boundary (e.g. into `Isolate.run`). Inside the isolate, you reconstruct a proxy instance using `SharedMap.fromSharedReference(ref)`.

Any reads, writes, or mutations performed by the worker isolate are automatically dispatched back to the main instance and synchronized across all isolates!

---

## See It In Action

Let’s write a complete, self-contained example. We'll simulate multiple concurrent worker isolates crunching data, reading from a shared cache, and populating cache entries on the fly:

```dart
import 'dart:isolate';
import 'package:shared_map/shared_map.dart';

void main() async {
  // 1. Create a SharedStore and a SharedMap on the main isolate
  final store = SharedStore('app_cache');
  final userCache = await store.getSharedMap<String, String>('users');

  // Seed an initial value
  await userCache!.put('user_101', 'Randal (Admin)');

  // 2. Extract the lightweight, serializable reference
  final cacheReference = userCache.sharedReference();

  print('--- Spawning Background Worker 1 ---');

  // 3. Pass the reference into a background isolate
  final worker1Result = await Isolate.run(() async {
    // Reconstitute the synchronized map proxy
    final workerMap = SharedMap<String, String>.fromSharedReference(cacheReference);

    // Read the value previously stored by the main isolate:
    final user = await workerMap.get('user_101');
    print('[Worker 1] Read from shared cache: $user');

    // Put a new value into the shared cache from this background worker:
    await workerMap.put('user_102', 'Wilhelm (Engineer)');
    return 'Worker 1 finished';
  });

  print(worker1Result);

  print('--- Spawning Background Worker 2 ---');

  // 4. Spawn a second isolate to prove cross-isolate synchronization
  final worker2Result = await Isolate.run(() async {
    final workerMap = SharedMap<String, String>.fromSharedReference(cacheReference);

    // Worker 2 can immediately read what Worker 1 just wrote!
    final user102 = await workerMap.get('user_102');
    print('[Worker 2] Read value written by Worker 1: $user102');

    // Use putIfAbsent atomically
    final user103 = await workerMap.putIfAbsent('user_103', 'Guest User');
    return '[Worker 2] Added: $user103';
  });

  print(worker2Result);

  // 5. Verify the main isolate reflects all updates
  print('--- Back on Main Isolate ---');
  print('Total entries in cache: ${await userCache.length()}');
  print('user_102 on main: ${await userCache.get('user_102')}');
  print('user_103 on main: ${await userCache.get('user_103')}');
}
```

### The Console Output
```plaintext
--- Spawning Background Worker 1 ---
[Worker 1] Read from shared cache: Randal (Admin)
Worker 1 finished
--- Spawning Background Worker 2 ---
[Worker 2] Read value written by Worker 1: Wilhelm (Engineer)
[Worker 2] Added: Guest User
--- Back on Main Isolate ---
Total entries in cache: 3
user_102 on main: Wilhelm (Engineer)
user_103 on main: Guest User
```

Notice what just happened:
* Two independent background isolates communicated and shared data back to the main thread.
* **Not a single `SendPort`, `ReceivePort`, `Completer`, or serialization boilerplate line was written.**

---

## Superpower: Local Read Caching with `SharedMapCached`

If your worker isolates perform thousands of rapid reads, you might not want every single `get()` call to perform a cross-isolate message dispatch.

`shared_map` includes a built-in subclass called **`SharedMapCached`**:

```dart
final cachedWorkerMap = SharedMapCached<String, String>.fromSharedReference(
  cacheReference,
  // Cache items locally in this isolate for high-throughput reads
  timeout: const Duration(seconds: 30),
);
```

When you query an existing key with `SharedMapCached`, it caches the value locally in the worker's isolate heap. If subsequent reads occur within the timeout window, they resolve instantly without cross-isolate latency.

---

## Grouping Maps with `SharedStore`

In complex applications, you rarely have just one cache. You might have:
* An image cache (`SharedMap<String, Uint8List>`)
* A user profile cache (`SharedMap<String, UserProfile>`)
* A rate limiter map (`SharedMap<String, int>`)

Instead of passing dozens of individual references around, you pass a single **`SharedStoreReference`**:

```dart
// Main thread:
final store = SharedStore('global_store');
await store.getSharedMap<String, String>('tokens');
await store.getSharedMap<String, int>('rate_limits');

final storeRef = store.sharedReference();

// Inside any background isolate:
await Isolate.run(() async {
  final workerStore = SharedStore.fromSharedReference(storeRef);
  
  // Dynamically resolve any map registered under this store:
  final tokens = await workerStore.getSharedMap<String, String>('tokens');
  final rateLimits = await workerStore.getSharedMap<String, int>('rate_limits');
  
  // ...
});
```

---

## Senior Engineering Wisdom: When to Use (and Not Use) `shared_map`

As with any tool, understanding the architectural sweet spot is key.

### ✅ When to Reach for `shared_map`:
1. **CPU-Intensive Worker Coordination**: When running pools of background isolates (`Isolate.run` or persistent worker isolates) that need shared lookups.
2. **In-Memory Deduping & Caching**: Preventing concurrent workers from calculating or downloading the exact same asset twice.
3. **Cross-Isolate Metrics & Counters**: Collecting stats, telemetry, or rate-limit tokens across multiple threads.

### ⚠️ When NOT to Use `shared_map`:
1. **Persistent On-Disk Storage**: `shared_map` is an in-memory data structure. If your data must survive app restarts, use SQLite, Drift, or a persistent key-value store.
2. **Single-Isolate Applications**: If all your code runs on the root UI isolate, a standard Dart `Map<K, V>` or reactive Signal is all you need—there's no reason to pay the asynchronous abstraction cost.

---

## Summary

Dart's isolate architecture keeps our code safe from concurrency bugs, but you shouldn't have to write hundreds of lines of port plumbing just to share an in-memory cache across worker tasks.

By bringing in **[`shared_map`](https://pub.dev/packages/shared_map)**:
1. You keep isolates isolated and UI threads responsive.
2. You eliminate manual `SendPort` and `ReceivePort` spaghetti code.
3. You get atomic, synchronized key-value storage with zero external dependencies.

Add `shared_map: ^1.1.9` to your `pubspec.yaml` and stop reinventing isolate messaging from scratch.

---

### What's your take?
How do you currently coordinate data between background isolates in your Flutter apps? Have you been writing custom ports, or relying on `Isolate.run` return values? Let me know in the comments below!

---

*Randal L. Schwartz is a Google Developer Expert (GDE) for Dart & Flutter and veteran software architect.*

* 📺 Watch deep dives and walkthroughs on YouTube: **[@RandalOnDartAndFlutter](https://www.youtube.com/@RandalOnDartAndFlutter)**
* 💻 Connect on GitHub: **[@RandalSchwartz](https://github.com/RandalSchwartz)**
