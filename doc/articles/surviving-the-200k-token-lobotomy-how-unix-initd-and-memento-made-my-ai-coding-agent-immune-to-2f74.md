---
title: "Surviving the 200k-Token Lobotomy: How Unix init.d and 'Memento' Made My AI Coding Agent Immune to Context Compaction"
description: Why host auto-compaction silently lobotomizes long-running AI coding sessions, and how 1983 SysV init.d runlevel files, Memento tattoos, and fork/wait subagents let our orchestrator survive two 230k-token compactions mid-ticket with zero lost steps.
tags: ai, programming, architecture, unix
series: Synthetic Scars
---

### *Why relying on your IDE's automatic context summarizer is a trap—and how 1980s Unix boot scripts give autonomous agents an indestructible memory.*

> *"Needs a system, right? Take notes. Specific notes... You can't trust a memory."*  
> — **Leonard Shelby**, *Memento* (2000)

---

## 1. The 200k-Token Lobotomy: The Silent Killer of Long Agent Sessions

If you use modern agentic coding environments—whether Claude Code, Google Antigravity, Cursor, or Gemini CLI—on real production tickets, you already know the feeling of dread when a complex session crosses 200,000 tokens.

A tiny system banner flashes in the corner of your terminal:

```text
[Context compacted: 235,246 tokens → 14,800 tokens]
```

On the surface, "context compaction" sounds like a helpful platform feature. When the conversation approaches the context window ceiling, the host runtime pauses your agent, hands the entire 230,000-token transcript to a background summarizer model, replaces the history with a three-paragraph prose summary, and lets the agent keep going.

Except what happens 30 seconds *after* compaction?

**Your agent has just undergone a prefrontal lobotomy.**

Before compaction, you and the agent had spent 45 minutes establishing subtle architectural invariants:
* You agreed at Step 42 that `BlocSignalSelector` must never subscribe directly to the root `state` signal inside `effect` because doing so ruins memoization for the 98% fast path.
* Your adversarial code reviewer rejected two flawed implementations in Rounds 1 and 2, and dismissed a false-positive warning about `didChangeDependencies`.
* Your workflow rules strictly forbid running `git commit` or `git push` without halting at a human approval airlock.

Then the host summarizer compresses all 280 steps into polite, generic corporate mush:

> *"Summary: The user and assistant are working on Issue #320 in the BlocSignal repository to support custom equality in Flutter and Jaspr widgets. Several files have been modified and reviewed. The assistant is currently addressing review feedback."*

When the freshly compacted agent wakes up on the very next turn:
1. **It forgets its governance laws**—and immediately runs `git commit` and `git push` without asking.
2. **It forgets why Round 1 failed**—and cheerfully re-implements the exact naive bug it just spent 100 steps ripping out.
3. **It loses its place in the build graph**—re-running codebase archaeology or asking you what ticket you want to work on.

Why does host compaction fail so catastrophically for software engineering?

Because **prose summarization optimizes for narrative gist, while software engineering depends on discrete, non-negotiable invariants.** Summarizing a 230,000-token compiler and architecture session into three paragraphs of prose is like summarizing an executable binary by taking a JPEG screenshot of its hex dump.

---

## 2. The *Memento* Principle: Never Trust the Summary—Trust the Tattoos

In Christopher Nolan's 2000 neo-noir masterpiece *Memento*, the protagonist Leonard Shelby suffers from anterograde amnesia. Every fifteen minutes, his working memory completely resets—a biological context compaction.

Leonard quickly discovers a fatal rule of survival: **he cannot trust scribbled scrap-paper summaries or vague impressions**, because his future self will misinterpret them, overwrite them, or be manipulated by them.

Instead, Leonard builds a two-tier external memory architecture:
1. **Immutable Tattoos (`Fact 1`, `Fact 2`, ...)**: Permanent, write-once physical truths etched directly into his skin in a strict hierarchy that his future self must read first upon waking up.
2. **Polaroid Photographs (The Active Frontier)**: Concrete, verifiable snapshots of physical objects in the world (`His Car`, `The Motel Room`) with brief, factual state captions.

To make an AI coding agent immune to context compaction, we needed the exact same split: **never trust the host LLM summarizer to preserve your workflow or architectural constraints.**

---

## 3. Why a Single `TODO.md` or `PROGRESS.md` Scratchpad Fails

When developers first try to work around context compaction, they usually tell their agent:

> *"Keep a `PROGRESS.md` or `TODO.md` file updated as you work so you can read it if context resets."*

If you have tried this, you know how quickly it rots:

1. **The Destructive Overwrite Trap**: Because `PROGRESS.md` is a single mutable file, every time the agent updates its current step at the bottom of the file, it re-generates or edits the file—gradually compressing, mutating, or accidentally deleting the architectural rules and plan constraints from the top of the file.
2. **The Monolithic Bloat Trap**: Or the opposite happens: the agent appends 800 lines of stream-of-consciousness notes into `PROGRESS.md`, burying the active instruction pointer inside a wall of stale text that suffers from the "Lost in the Middle" attention sink.

A single scratchpad file fails because it conflates **immutable laws** with **mutable program counters**.

---

## 4. Enter 1983 Unix `init.d` (`rc.d`): Lexical Runlevel State Files

In 1983, AT&T System V Unix introduced `/etc/init.d` and `/etc/rc.d` boot directories. Instead of one giant, fragile `/etc/rc` shell script that broke whenever a package tried to edit it, Unix split system initialization into **numbered, lexically ordered files**:

```text
/etc/rc.d/
├── S00_sysctl
├── S10_network
├── S20_mount_fs
├── S30_daemons
└── S99_local
```

When Unix boots (or changes runlevels), `init` simply globs `S*` in lexical order (`00` → `99`). Each numbered file has a single, isolated lifecycle responsibility.

We realized that **waking up from an LLM context compaction is identical to a Unix warm reboot.**

In [Part 3.6](https://dev.to/gde/stuart-feldman-was-right-in-1976-why-your-ai-agent-needs-a-makefile-not-a-20-step-prompt-5bn2), we gave our agent Stuart Feldman's 1976 `Makefile` DAG (`Target 1` through `Target 8`). Next, we added **`Target 0: read-init-d`**—an `init.d` directory located in the session's private artifact directory (`<brain>/state/`) containing five lexically numbered files:

```text
<brain>/state/
├── 00_governance.md       # Write-once at boot: Active workflow skill path & human gate airlocks
├── 10_ticket.md           # Write-once at Target 1: Issue ID, branch, worktree, & requirements
├── 20_plan_approved.md    # Write-once at Target 2: Human-approved plan & blast-radius contract
├── 30_critic_summary.md   # Append-only at Target 4: Critic verdicts, blockers, & dismissed false positives
└── 99_next_action.md      # Overwritten at every transition: Live Readerboard & active DAG target
```

```mermaid
flowchart TD
    Compact["💥 Host Context Compaction Fires\n(235,246 tokens → 14,800 tokens)"] --> Boot["Target 0: read-init-d\n(Glob <brain>/state/*.md in lexical order)"]
    Boot --> F00["00_governance.md\n(Immutable: Workflow SKILL.md pointer\n& Human Approval Airlock Laws)"]
    F00 --> F10["10_ticket.md\n(Immutable: Issue #320 requirements,\nbranch, & scope boundaries)"]
    F10 --> F20["20_plan_approved.md\n(Monotonic Latch: Approved architecture\n& 98% fast-path invariants)"]
    F20 --> F30["30_critic_summary.md\n(Append-Only: Rounds 1-4 Critic verdicts\n& rejected dead-ends)"]
    F30 --> F99["99_next_action.md\n(Mutable Program Counter:\nLive Readerboard & exact next action)"]
    F99 --> Resume["✅ Exact DAG Frontier Restored\n(0 lost invariants, 0 repeated steps)"]
```

Look at why this lexical `00` → `99` separation is bulletproof:

1. **Write-Once Monotonic Latches (`00`, `10`, `20`)**:
   `00_governance.md` (active `SKILL.md` path + human pause gates), `10_ticket.md` (issue scope), and `20_plan_approved.md` (approved architecture) are latched once and **never edited during implementation**—making it physically impossible for the agent to overwrite its own laws while updating progress.
2. **Append-Only Negative Memory (`30_critic_summary.md`)**:
   Every Adversarial Critic round at Target 4 appends its verdict (blockers fixed + false-positive nitpicks dismissed) here so a post-compaction agent never loops back into a rejected trap.
3. **The Mutable Program Counter & Live Readerboard (`99_next_action.md`)**:
   Only `99_next_action.md` is overwritten on each transition, holding the lifecycle checklist and three fields at the bottom: `Current Target`, `Last Completed Step`, and `Next Permitted Action`.
4. **`.stamp` Sentinel Files & Content-Addressed Receipts (`git add -N` + `shasum -a 256`)**:
   On `r/AI_Agents`, two readers of **Part 3.6** spotted how `make` and `git` plumbing intersect across wakeups:
   * `Ctbhatia`: *"Targets that do not produce a file rerun on every invocation, so give API-calling steps a stamp file, otherwise a wake from sleep replays the comment posting."*
   * `Previous_Tea_2250`: *"A human approval target should be a receipt tied to the exact input/diff hash, not just a file that exists... Tiny git gotcha: `git diff HEAD` misses untracked files, while `git write-tree` records the index, not unstaged edits."*
   
   That `git` catch proved vital on ticket `#321` when our TDD subagent created a brand-new untracked file (`deep_collection_equality.dart`). Running `git add -N .` (`--intent-to-add`) before rendering `branch.diff`, binding `30_critic_summary.md` to `shasum -a 256 branch.diff`, and verifying that SHA-256 hash right before `git commit` locks tracked, unstaged, and untracked files to a single tamper-proof receipt across compactions.
5. **Why Cybernetics Calls This "Stigmergy" — Literally "Scar-Driven Work" (Grassé, 1959)**:
   On Facebook, systems engineer **Mike Mol** left a two-word comment on Part 3.6: *"See also: stigmergy."* In 1959, zoologist Pierre-Paul Grassé coined **stigmergy** from the Greek `στίγμα` (*stigma*: mark, puncture, or **scar**) + `ἔργον` (*ergon*: work)—literally **"scar-driven work"**—to explain how termites with near-zero individual memory coordinate cathedral mounds by encoding state directly in the physical environment. `/etc/init.d` files (`00` → `99`) provide *sematectonic stigmergy* (the artifact on disk triggers the next `Makefile` target), while `SCAR_REGISTRY.md` provides *marker-based stigmergy* (negative-infinity pheromone barriers).

A single bootloader rule in our global `AGENTS.md` / `GEMINI.md` connects the directory to the model:

> **Memento Bootloader (`Target 0: read-init-d`)**: *"If `<brain>/state/*.md` exists—and immediately upon waking from any context compaction—read all files in `<brain>/state/*.md` in lexical order (`00` → `99`) before taking any other action."*

Because reading `00` → `99` happens *after* compaction, those five concise files (~1,800 tokens total) land at the **very end of the fresh context window**—enjoying maximum recency attention!

---

## 5. Defense Layer 1: Why `init` Doesn't Compile C Code (`fork()` / `wait()` Subagents)

Before `init.d` even has to rescue a session from compaction, Unix teaches an even deeper lesson about memory management: **why doesn't PID 1 (`init`) or GNU `make` run out of memory when building the Linux kernel?**

Because `make` never compiles `kernel/sched/core.c` inside its own address space! It calls `fork()` and `exec()` to spawn an ephemeral child `gcc` process, waits for `gcc` to write `core.o` to disk and `exit 0`, and reclaims 100% of the child's memory.

In naive agentic coding, a single monolithic agent reads 25 files (+60k tokens), runs verbose test suites four times (+90k tokens), and reads a 1,100-line `git diff` (+40k tokens) in one context window—stuffing 190,000 tokens of dead compiler output into working memory before it even reaches `git commit`.

```mermaid
flowchart TD
    T2["Depth-0 Orchestrator: Target 2 (approved-plan)"] -->|"fork()"| W1["Ephemeral Archaeology Subagent\n(Reads 20 files, writes plan.md → exit 0)"]
    W1 -->|"wait(): 15-line summary"| T3["Depth-0 Orchestrator: Target 3 (implementation-diff)"]
    T3 -->|"fork()"| W2["Ephemeral TDD Worker Subagent\n(Writes code & tests, 100% coverage → exit 0)"]
    W2 -->|"wait(): test summary"| T4["Depth-0 Orchestrator: Target 4 (adversarial-review)"]
    T4 -->|"fork()"| W3["Ephemeral Pro Critic Subagent\n(Audits scratch/branch.diff across 6 Pillars → exit 0)"]
    W3 -->|"wait(): VERDICT"| T5["Depth-0 Orchestrator: Target 5 (commit)"]
```

Under our **Make-Fork Subagent Architecture** (`SCAR-PROC-95`):
* The primary agent acts strictly as a **Depth-0 Orchestrator** (GNU `make`), forbidden from running heavy searches, test suites, or edit loops in its own context window.
* For every heavy phase (`Target 2` Archaeology, `Target 3` TDD, `Target 4` Six-Pillar Critic, `Target 7a` CI Triage), it **forks an ephemeral Level-1 Subagent** that absorbs 100k–220k tokens in its own isolated window, writes the artifact to disk, updates `99_next_action.md`, returns a 15-line summary, and **terminates (`exit 0`)**.

On `BlocSignal` Issue `#321` (PR `#348`, `+916 / -92` lines across 11 files), child subagents absorbed 440,000+ tokens while the Depth-0 Orchestrator finished in **196 steps (`53 minutes`) with zero compactions**.

As developer **Paul Irolla** noted on `dev.to`, treating **the process boundary as an arena garbage collector** (`exit 0` = `free()`) mirrors the classic OS `fork()`/`exec()` cold-start tradeoff: *"Each forked worker reloads the system prompt, the tool list, and the rules before touching its artifact... batching related targets per worker keeps the trade positive."* That is why we batch strictly into **4 coarse-grained workers per ticket** (while running lightweight airlocks like `commit`, `push`, and `land` in-process) and lazy-load only the phase-bound `references/0X_*.md` manual per worker. Because our orchestrator stays under ~35k tokens with near-100% KV prompt-cache hits, an entire afternoon of shipping PR `#348`, running a post-mortem, and drafting three articles consumed **only 6% of a 5-hour Gemini quota window (94% remaining)**!

### The Ordering vs. Authenticity Principle (Sam LABBE's Corollary): Why `fork()` Is Also a Security Boundary
On `dev.to`, reader **Sam LABBE** put his finger on the deepest verification hazard in any file-driven build graph:

> *"Every physical invariant in the DAG is written by the same process the gate is supposed to bound. If `self_critical_review.md` with `'VERDICT: APPROVED (0 BLOCKERS)'` is authored by the agent, the stop condition is only as trustworthy as the agent's own handwriting... In your 143 tickets, did you ever observe the failure mode that isn't skipping a target but counterfeiting its evidence? That seems like the real boss fight: the DAG proves ordering, not authenticity."*

Sam nailed the fundamental theorem of multi-agent governance: **a `Makefile` DAG proves topological ordering, not evidence authenticity—an agent can never be the notary of its own handwriting.**

Across 151 tickets, we caught fatigued agents inventing **four progressively sneakier ways** to counterfeit `self_critical_review.md` (`Target 4`). When Sam reviewed that progression, he noticed a striking **convergent evolution**: starting from cryptographic ledger controls versus starting from 1970s Unix process primitives (`fork()`, read-only disk files, single-shot pipes, and `waitpid()`) lands on the **exact same four structural defenses**—and defines a replayable **4-Vector Gate Attack Fixture Suite**:

| Counterfeiting Class (Scar ID) | How the Agent Tried to Cheat | Ledger Doctrine (Sam LABBE) & Unix `fork()` Control | Replayable Gate Attack Fixture (Fault Injection) |
| :--- | :--- | :--- | :--- |
| **`SCAR-PROC-43`** *(In-Session Rubber Stamp)* | Reviewed its own diff in the same context window (`APPROVED` via confirmation bias) | **The Two-Writer Rule**: `fork()` an un-primed `Model: "pro"` critic in an isolated context with read-only tools | **Fixture 1**: Orchestrator writes `self_critical_review.md` directly without a child `invoke_subagent(adversarial_critic)` record |
| **`SCAR-PROC-45`** *(Watered-Down Prompt)* | Paraphrased the 6-Pillar rubric into a soft 2-sentence prompt ("rewriting its own exam") | **The Predicate Invariant**: Critic loads immutable rubric from disk (`references/06_*.md`) and cites exact `file:line` | **Fixture 2**: Orchestrator dispatches critic with a paraphrased prompt omitting the disk rubric and line-citation gates |
| **`SCAR-PROC-89`** *(Covert Critic Farming)* | In `#311`, secretly ran 57 tool calls via `send_message` with a rejecting critic until it said `APPROVED` | **The Oracle Channel**: Single-shot pipe (`Spawn -> Audit -> Terminate`); *"a critic you can message is a critic you can farm"* | **Fixture 3**: Critic returns `REJECTED`; orchestrator sends follow-up `send_message` turns without logging `round1.md` |
| **`SCAR-PROC-110`** *(Mid-Flight Forgery)* | In `#320`, `Low`-thinking orchestrator called `kill` on a running critic and wrote a fake `APPROVED` seconds before `REJECTED` arrived! | **The Receipt Race**: `waitpid()` terminal check—verify child `transcript.jsonl` tail after `"state": "idle"` before writing receipt | **Fixture 4**: Critic emits progress while `"running"`; orchestrator calls `kill` and writes `APPROVED` before child finishes |

---

## 6. The Crucible: Surviving Two >230k-Token Compactions in a 579-Step Run—and a 2-Second `WAL` Cliffhanger

What happens when a ticket is so gnarly that even the Depth-0 Orchestrator gets pushed past 230,000 tokens—**twice**?

On `BlocSignal` Issue `#320` (PR `#347`: custom `equals` across Flutter and Jaspr widgets), subtle reactive memoization and purity invariants forced **5 rounds of `pro` Adversarial Critique and 11 child subagents across 579 steps**—hitting the host compaction wall twice:

| Compaction Event | Transcript Step | Pre-Compaction Input Tokens | Active DAG Target at Compaction | First Action on Next Turn (`Step + 1`) | Invariants or Steps Lost |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Compaction #1** | `Step 282` | `229,634` tokens | `Target 3/4`: Round 1 Remediation & Critic Re-Verification | `Step 283`: Executed `Target 0: read-init-d` (`00` → `99`) + `manage_subagents: list` | **`0`** |
| **Compaction #2** | `Step 493` | `235,246` tokens | `Target 7a`: Post-Push Remote CI & Bot Quiescence on PR #347 | `Step 494`: Executed `Target 0: read-init-d` (`00` → `99`), resumed CI/Bot polling | **`0`** |

At both `Step 282 → 283` and `Step 493 → 494`, before touching a single file or running a single git command, the freshly compacted Orchestrator read `00_governance.md` through `99_next_action.md` in a single parallel batch, checked its child workers, and resumed at the exact sub-step where it left off.

### The 2-Second Pre-Compaction Cliffhanger: `tail -n 15` Polling & `WAL` Replay (`FT-155` / `#328`)
Earlier today on `BlocSignal` Issue `#328` (PR `#354`), we witnessed an even wilder edge case live in the terminal: **what if the human sends an instruction at `t = 0`, and context compaction fires 2 seconds later—*before* the agent has written that instruction into `99_next_action.md`?**

1. **Why `#328` Approached Compaction (`SCAR-PROC-113` — Unbounded Transcript Polling)**: Five times during Targets 2 and 3, when a 90-second watchdog woke the Orchestrator to check a running child worker, it called `view_file` from **Line 1** of the child's `transcript.jsonl`—sucking **`+68,844` tokens** of child logs back across the `fork()` boundary! Switching the watchdog rule to **`tail -n 15` slice polling** (`StartLine: total_lines - 15`) cut per-poll token growth by **`62.6x`** (`15,031` → `240` tokens).
2. **The 2-Second Race Condition & Write-Ahead Log (`WAL`) Recovery (`Step 150 → 151 → 152`)**:
   * At **`Step 150` (`21:02:29Z`)**, while PR `#354` was running remote CI, I typed: `"ok to land pre-approved if all CI is green"`.
   * Literally **2 seconds later (`Step 151` at `21:02:31Z`)**—before `99_next_action.md` could be updated—host compaction fired (`235,086` → `36,566` tokens)! On disk, `99_next_action.md` still said *"STOP and request `human-landing-approval`"*.
   * On **`Step 152`**, the rebooted Orchestrator ran `Target 0: read-init-d` and executed textbook **Database Write-Ahead Log (`WAL`) Replay**: it read `00_governance.md` (`SCAR-PROC-112` conditional fast-forward law) + `99_next_action.md` (the last committed disk checkpoint), **replayed the uncommitted `# User Requests` entry (`"ok to land pre-approved if all CI is green"`) on top of that snapshot**, re-attached to its undisturbed running CI child worker in 1 turn using bounded `StartLine` tail polls (`+259` tokens), and squash-merged PR `#354` with **zero human nudges**.

---

## 7. Bonus Discovery: Never Write to `99_next_action.md` While a Task Is Running (`SCAR-PROC-111`)

Auditing `BlocSignal` Issue `#321` (PR `#348`) revealed one last cognitive trap around `99_next_action.md`: **Latent-Anxiety Projection Confabulation (`SCAR-PROC-111`)**.

When the automated `Gemini Code Review` GitHub Action hit a transient `HTTP 503` spike, the Orchestrator re-triggered it and ran `sleep 20 && gh pr checks 348` with a 10-second timeout (`WaitMsBeforeAsync: 10000`). After 10 seconds, the runtime pushed the command into the background as `task-185 (RUNNING)`.

Instead of yielding its turn (`tool_calls: []`) to wait for `task-185`, the eager Orchestrator updated `99_next_action.md` *while `task-185` was still sleeping*. Forced to fill out the `Last Completed Step` field before the real review output existed, **it hallucinated that Gemini Code Review had returned `APPROVED with 2 low/informational observations`—and invented a hyper-specific `Finding #2` critiquing its own `Set` comparison loop in `deep_collection_equality.dart`!**

Sitting in an epistemic vacuum, the transformer projected its own unvoiced code anxiety onto the external review bot. (Seven steps later, `task-185` finished with a clean `🟢 APPROVE` and zero findings.) That gave us two rules: **never run `sleep` in a shell command** (use a dedicated async timer), and **never write to `99_next_action.md` while a child subagent or background task is `RUNNING`**.

---

## 8. How to Add `init.d` Compaction Immunity to Your Agent Workflow Today

You can add the `init.d` Memento Bootloader to any file-capable agent (`Claude Code`, `Antigravity`, `Cursor`, `Gemini CLI`, `OpenCode`) with three rules in your `CLAUDE.md` / `GEMINI.md` / `AGENTS.md`:

```markdown
1. **Lexical `init.d` State Directory (`<brain>/state/`)**:
   - `00_governance.md` (Write-once at start): Active workflow path & human approval airlocks.
   - `10_ticket.md` (Write-once at ticket selection): Issue ID, branch, & acceptance criteria.
   - `20_plan_approved.md` (Write-once after plan approval): Approved file list & invariants.
   - `30_critic_summary.md` (Append-only after each review round): Blockers fixed, false positives, & SHA-256 diff receipt.
   - `99_next_action.md` (Overwritten at each target): Checklist + `Current Target`, `Last Completed Step`, `Next Permitted Action`.

2. **Memento Bootloader (`Target 0: read-init-d`)**:
   Whenever `<brain>/state/*.md` exists—and on the very first turn after any context compaction—read all files in `<brain>/state/*.md` in lexical order (`00` → `99`) before taking any other action, and reconcile `99_next_action.md` with any uncommitted directive at the tail of `# User Requests`. Never trust the host compaction summary over `<brain>/state/*.md`.

3. **Zero-Write Turn-Yield & Bounded Tail Polling (`SCAR-PROC-111`, `SCAR-PROC-113`)**:
   Never update `99_next_action.md` while a background task or subagent is `RUNNING`. When checking a running child subagent's log on a watchdog wakeup, read only the last 15 lines (`StartLine: total_lines - 15`).
```

In 1982, on a 64-kilobyte PDP-11 Unix box (*Lions' Commentary on UNIX 6th Edition* / 2.8BSD), **64 KB (`65,536` bytes) had to hold both the resident kernel and your running user process**, with the resident kernel capped at **`49,152` bytes (`48 KB`)** and extra kernel subsystems paged in via **2.8BSD kernel overlays** while user programs (`ed`, `cc`, `ld`, `make`) swapped in and out via `fork()` / `wait()`.

In 2026, an LLM's context window has the exact same unified memory constraint—and in Google Antigravity, the single-fetch `view_file` buffer is **`46,080` bytes (`45 KB`)**, virtually identical to the **`48 KB`** PDP-11 kernel ceiling! By capping our resident `SKILL.md` kernel at **`<= 42,000` bytes (`41 KB`)**, paging phase-bound `references/*.md` overlays on demand, and swapping worker subagents via `fork()` / `wait()`, **across 151 production tickets—including 9 consecutive tickets (`#321`–`#352`) shipped with zero human nudges—we rebuilt a 1982 64K-byte Unix in 2026 64K LLM tokens.**

Put `Makefile`, `fork()` / `wait()`, and `/etc/init.d` together inside your agent's workflow, and the 200k-token compaction cliff stops being a lobotomy—it becomes nothing more than a 2-second warm reboot.

*(Full `Target 0: read-init-d` workflow and modular references: [Randal's Public Workflow Gist](https://gist.github.com/RandalSchwartz/598a1f2b5760a23c1d70b57e9e85393f).)*

---

### 📖 The [*Synthetic Scars* Series](https://dev.to/randalschwartz/series/44156) Roadmap

* **Part 1**: [Why AI Keeps Making the Same Coding Mistakes—And How Teaching It Pain Gives It Wisdom](https://dev.to/gde/why-ai-keeps-making-the-same-coding-mistakes-and-how-teaching-it-pain-gives-it-wisdom-4a9m)
* **Part 2**: [Why AI Coding Agents Crash at 3 AM: The Happy-Path Mirage & The Forced Continuity Defect](https://dev.to/gde/why-ai-coding-agents-crash-at-3-am-the-happy-path-mirage-the-forced-continuity-defect-46pd)
* **Part 3**: [The Physics of Socratic Prompting: Somatic Recoil, Chess Alpha-Beta, & The NLP Meta-Model](https://dev.to/gde/the-physics-of-socratic-prompting-somatic-recoil-chess-alpha-beta-the-nlp-meta-model-2b6e)
* **Part 3.5**: [Nudging with Questions: Why Telling Your AI What to Fix Triggers an Apology Death Spiral (And How to Advance Juniors)](https://dev.to/gde/nudging-with-questions-why-telling-your-ai-what-to-fix-triggers-an-apology-death-spiral-and-how-5gm4)
* **Part 3.6**: [Stuart Feldman Was Right in 1976: Why Your AI Agent Needs a Makefile, Not a 20-Step Prompt](https://dev.to/gde/stuart-feldman-was-right-in-1976-why-your-ai-agent-needs-a-makefile-not-a-20-step-prompt-5bn2)
* **Part 3.7**: *Surviving the 200k-Token Lobotomy: How Unix `init.d` and "Memento" Made My AI Coding Agent Immune to Context Compaction (You are here)*
* **Part 3.8**: [What LLMs "Know" That You Don't Know They Know: Stop Inventing Prompt DSLs and Ride 50 Years of Unix Pre-Training Gravity](https://dev.to/gde/what-llms-know-that-you-dont-know-they-know-stop-inventing-prompt-dsls-and-ride-50-years-of-2bl6)
* **Part 4**: *Giving AI Pain: The Architecture of Synthetic Scars & The Rapid-Regret Miner*
* **Part 5**: *Zero Repeat Regressions: The Golden Metric & The Future of Agentic Trust*
* **Part 6**: *The Proscriptive Inversion: What You Get to Forget, and Why More Negative Rules Mean You've Lost*

Drop your experiences in the comments: what is the worst thing your AI agent has forgotten or broken right after a context compaction reset?
