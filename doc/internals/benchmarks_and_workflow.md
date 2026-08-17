# Benchmarking Rigor, CI & Maintainer Workflow Guide

This document details the internal performance benchmarking protocols, CI script safety, and maintainer workflow guidelines for the `BlocSignal` monorepo.

---

## ⚡ 1. Benchmarking Rigor & Performance Measurement

When authoring or executing performance benchmarks (`package:benchmark_harness` under `benchmarks/`):

### A. Drained Stream Microtask Measurement
- **The Issue**: Calling `bloc.add(event)` in classic stream-based BLoC only measures microtask queue insertion time, not the actual state propagation latency.
- **Fair Comparison**: To measure true end-to-end event-to-state execution latency, always await microtask queue draining (`await bloc.stream.take(N).drain()`) to compare fairly against synchronous `BlocSignal` emissions.

### B. Flutter Engine Execution Environment Wrapper
- Benchmark runners that import `package:flutter` UI bindings cannot run via bare `dart run`.
- Always provide a `flutter test` test wrapper (`test/benchmark_runner_test.dart`) to execute benchmarks under the Flutter engine test environment.

### C. High-Frequency Benchmark Loops & UI Re-render Decoupling
- **Decouple Loops from Per-Event `setState`**: In synchronous reactive architectures (`BlocSignal`), firing `add(event)` in a loop executes immediately in the current frame. Avoid attaching raw `.subscribe((_) => setState())` handlers that trigger framework component rebuilds on every individual iteration.
- **Batch Update Pattern**: Allow the loop to execute cleanly in memory under `Stopwatch` timing, then invoke a single `setState()` at the conclusion of the batch to update metrics, logs, and derived view states without browser UI thrashing.

---

## 🤖 2. Maintainer Workflow & Automated Bot Triage

### A. Delivery Path Verification Early
- Immediately after selecting or planning a task, clarify whether the change will be delivered via a GitHub Pull Request (PR) or direct commit to `main`.

### B. Mandatory Bot Review Simulation (GCA Persona)
- Even when bypassing a GitHub PR for direct commits to `main`, NEVER skip the automated Bot Triage Simulation (GCA Persona).
- Objective review must always be performed before committing and publishing to catch boundary edge cases (such as missing `onError` exception routing or uncovered lines).

---

## 🛡️ 3. CI & GitHub Actions Script Safety

### GitHub Actions Inline Script Syntax Safety
When writing inline Node.js scripts in `.github/workflows/*.yml` via `actions/github-script`:
- **Avoid `${...}` Interpolation**: Avoid JS template literal `${variable}` syntax inside YAML block scalars (`script: |`), as GitHub Actions attempts to parse `${...}` as GitHub Actions expressions.
- **Standard Concatenation**: Use standard string concatenation (`'hello ' + name`) instead.

---

## 🔄 4. Agent Skills Synchronization & Push Protocol

When framework architecture, state primitives, builders, providers, or testing conventions change:
1. **Skill Bundle Maintenance**: Update the corresponding skill file(s) under `plugins/bloc-signals/skills/bloc-signals/`.
2. **Validation**: Run `dart run tool/validate_agent_plugin.dart` to verify skill bundle integrity.
3. **Commit & Push**: Commit and push skill updates so the broader agent ecosystem operates on up-to-date knowledge.
