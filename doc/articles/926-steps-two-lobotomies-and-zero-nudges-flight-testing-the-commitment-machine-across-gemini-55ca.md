---
title: "926 Steps, Two Lobotomies, and Zero Nudges: Flight-Testing the Commitment Machine Across Gemini, Claude, and GPT-OSS"
published: true
description: "A 2026 Harvard study of 718 companies found that AI agents write 30% more code and close zero additional tickets because review times jump 49%. Here is what happened when I put my 1986 Commitment Machine into live production across Gemini, Claude, and GPT-OSS."
tags: ai, programming, architecture, unix
series: Synthetic Scars
canonical_url: https://dev.to/gde/926-steps-two-lobotomies-and-zero-nudges-flight-testing-the-commitment-machine-across-gemini-55ca
---

## *A 2026 Harvard study of 718 companies found that AI coding agents write 30% more code and close zero extra tickets because PR review times jump 49%. When I ran my 1986 Commitment Machine across five live production tickets, a mid-flight vendor swap, and an open-weight crash test, here is what the flight recorder proved.*

> *"The dashboard with the Mermaid state diagram is perfect. I find myself not even opening the pull requests now. I just wait for the green board or the triage details... And I also like that every code change is paired with an immediate critical reviewer. That one step really reduces friction."*  
> — **My notes to myself after the fourth ticket in a row**

---

## 1. The Bottom Line Up Front: What Live Production Just Proved

Earlier this month, Harvard researchers **Fiona Chen** and **James Stratton** published a massive study (*"Artificial Intelligence in the Firm: Bottlenecks in Software Production"*, covered in [Forkast News](https://forkast.news/ai-coding-agents-write-30-more-code-and-resolve-zero-additional-issues-harvard-study-finds/)) tracking **718 companies and more than 725,000 software developers** from 2021 to 2026.

By early 2026, over 95% of those companies had rolled out AI coding agents (`Claude Code`, `Cursor`, `Devin`). And the numbers they found should make every engineering manager wince:

* **Developers wrote `+30%` more code** (`1,500` extra lines per developer per month), and **opened `+23%` more pull requests**.
* Yet **the number of finished Jira tickets and epics went up by `0%`**.
* Why? Because **PR review wait times jumped `+49%` (`+3.45 days`)**, the number of PRs kicked back for rewrites nearly doubled, review comments per PR rose **`+35%`**, and **`14%` more senior engineers** got dragged away from their own work to pay what the researchers call the **"babysitting tax."**

If you've ever worked on a real software team, you don't need an economics degree to spot the bug. **If you make typing code 10x faster, but your AI never pushes back on a bad ticket and never catches its own bugs before committing, you haven't sped up your team. You've just aimed a firehose of plausible-looking slop at your senior reviewers.**

In [**Part 3.10**](https://dev.to/gde/requests-promises-assertions-and-declarations-rewriting-our-ai-agent-workflow-as-a-1986-4k4c), I redesigned my coding workflow ([Randal's Public Workflow Gist](https://gist.github.com/RandalSchwartz/598a1f2b5760a23c1d70b57e9e85393f)) specifically to invert that bottleneck—moving ticket pushback, adversarial code review, and state tracking **before `git commit`** using **Fernando Flores's 1986 "Committed Speech" rules**, a **1976 `Makefile`**, and a **1983 `/etc/init.d` state directory** (`00_governance.md` through `99_next_action.md`).

Then I turned the key and ran **five consecutive production tickets (`926+` steps, `18` subagents)**, a **`960`-step mid-flight vendor swap**, and a **`791`-step open-weight torture test** through it.

Before we look at the flight logs, **here is the bottom line from those runs**:

1. **You beat the `+30%` code-bloat trap before writing a single line of code**: When you force a read-only **Codebase Archaeologist** subagent to check a ticket's claims against `git log` *before* the agent is allowed to promise code, stale or already-solved tickets get closed in 8 minutes via a **`Counter-Offer`** (`0` lines of code written) or trimmed in half—instead of turning into 300-line zombie PRs.
2. **You beat the `+49%` PR review bottleneck by running an Adversarial Critic *before* `git commit` and collapsing bot threads into one table**: Pairing every code edit with a local Critic subagent and a single consolidated PR triage comment catches subtle framework bugs (like Flutter's post-`await` `ScaffoldMessenger` trap) locally, so the human reviewer doesn't even have to open the GitHub PR page until the board is green.
3. **Keeping state in `/etc/init.d` files on disk makes your agent both lobotomy-proof and vendor-agnostic**: When every commitment lives in numbered Markdown files on disk instead of hidden inside one model's chat RAM, the agent not only survives back-to-back 200k-token context resets without losing its place—you can literally **swap `Claude Sonnet 4.6` for `Gemini 4` at `Step 433` of a `960`-step run** when a quota wall hits, and the new model finishes the job without missing a beat.
4. **External `Makefile` scaffolding has a hard floor—and a `120B` open-weight model fell right through it**: A `Makefile` can keep a capable model (`Gemini 4` or `Claude Sonnet 4.6`) on the rails, but when I put **`GPT-OSS 120B`** into the exact same cockpit for `791` steps, it ignored the `/etc/init.d` files, suffered `6` context lobotomies, searched Google for private local Dart classes, and fork-bombed `6` simultaneous background `git commit` jobs while deleting `.git/index.lock`.

---

## 2. Why These Five Tickets Matter: Every One of Them Tests a Different Failure Mode

I didn't cherry-pick five easy toy problems. These were simply the next five tickets sitting in our production monorepo backlog—and each one happened to test a specific failure mode where normal AI coding agents create work instead of finishing it:

| Ticket & The Failure Mode It Tested | Steps / Subagents | Context Resets | What the Commitment Machine Did Differently | Dev Nudges |
| :--- | :---: | :---: | :--- | :---: |
| **1. `TICKET-553`: The Stale / Contradicted Ticket**<br>*(Tests whether the agent blindly writes `+30%` dead code on an obsolete ticket)* | `69` steps<br>`1` subagent | `0` | Archaeologist proved the requested wrapper was already built *and rejected* in `PR #927` two weeks ago. Issued a **`Counter-Offer`**: closed in **`8m 29s` with `0` lines of code**. | **`0`** |
| **2. `TICKET-779`: The Half-Solved Ticket**<br>*(Tests whether the agent re-implements work that already landed on `main`)* | `135` steps<br>`3` subagents | `0` | Archaeologist proved the `.scripts/*.sh` `pipefail` guards had already landed in `PR #1029`, cutting the scope in half (`AGENTS.md` `31,248 / 32,000` byte cap only). | **`0`** |
| **3. `TICKET-482`: The Linter Blind Spot & Bot Flood**<br>*(Tests whether subtle UI bugs and 14 bot threads get dumped on a human reviewer)* | `189` steps<br>`5` subagents | **`2`** | Scoped `19` dialogs down to `15`, caught a post-`await` `ScaffoldMessenger` bug (`SCAR-RIV-14`) that `flutter analyze` missed, and triaged 14 bot comments in 1 table. | **`0`** |
| **4. `TICKET-891`: The Flaky Cloud CI Runner**<br>*(Tests whether a transient GitHub Actions hiccup drags a human back to babysit)* | `182` steps<br>`4` subagents | `0` | Verified all 6 ticket premises in 38s, passed 2 Critic rounds, and automatically re-ran a flaky cloud CI job (`gh run rerun --failed`) to green. | **`0`** |
| **5. `TICKET-227`: The Double Context Lobotomy**<br>*(Tests whether a `351`-step math/binary ticket falls apart when the 200k window resets mid-commit)* | `351` steps<br>`5` subagents | **`2` (`233k` & `46k`)** | Hit auto-compaction `1 second` after I said *"ok to commit and push"*. Woke up, read `00_governance.md`..`99_next_action.md`, and finished `45/45` tests with `0` reminders. | **`0`** |

Let's walk through how these five tickets, the mid-flight Claude-to-Gemini swap, and the `GPT-OSS 120B` crash test played out in the transcripts.

---

## 3. Finding #1: Beating the `+30%` Code-Bloat Trap Before Writing a Single Line of Code (`TICKET-553`, `TICKET-779`, `TICKET-482`)

Why did the 718 companies in the Harvard study end up with `+30%` more code and `0%` more finished tickets?

Because in a real engineering backlog, **tickets rot**. Between the day somebody files a ticket and the day an engineer picks it up, other PRs merge, architecture decisions change, and half the work often gets solved somewhere else.

Hand a normal AI agent a stale ticket, and its "Yes-Man" training ([**Part 3.9**](https://dev.to/gde/if-you-never-do-anything-else-to-fix-your-prompts-do-this-one-thing-3069)) forces it to say *"Certainly!"* and write the code anyway:
* On **`TICKET-779`**, the ticket asked to add `set -euo pipefail` guards to our `.scripts/*.sh` files and enforce a `32 KB` size limit on `AGENTS.md`. Before writing a plan, my `Target 15` Archaeologist checked the repo, proved the `.sh` scripts **already had** `set -euo pipefail` on `main`, and cut the job in half.
* On **`TICKET-482`**, the ticket listed `19` creation dialogs that needed error-banner handling. The Archaeologist inspected all `19` up front, proved **`4` of them were already fixed on `main`**, and scoped the plan strictly to the remaining `15`.

And then there was **`TICKET-553`**—the poster child for the Harvard study's `+30%` code bloat.

`TICKET-553` was a `High` priority ticket asking the developer to build a pre-signout wrapper (`PreSignOutFirebaseAuth`) that deletes the user's push-notification token from the database before calling `FirebaseAuth.instance.signOut()`.

If you only look at today's files on `HEAD`, that wrapper isn't there—so a standard AI agent would happily crank out **`~280` lines of code across 4 files** and open a pull request.

Instead, my `Target 15` Codebase Archaeologist ran `git log -p` across recent history (`SCAR-ARCH-20`) and wrote down a devastating finding in `15_archaeology_receipt.md`:
* Two weeks after `TICKET-553` was filed, a developer working on a sibling ticket in **`PR #927`** had **already written that exact 243-line `PreSignOutFirebaseAuth` wrapper!**
* During code review on `PR #927`, our human lead architect **explicitly rejected the wrapper**, explaining that wrapping `FirebaseAuth` is brittle across SDK upgrades and unnecessary because post-signout cleanup + server-side pruning already handles stale tokens. A follow-up commit deleted the wrapper before `PR #927` merged—leaving the older duplicate `TICKET-553` sitting forgotten in the backlog like an unexploded bomb!

Because our workflow stamps any ticket claim that collides with codebase history as **`CONTRADICTED`**, the agent was forbidden to promise code. Instead, it came back to me with a **`Counter-Offer`**:
* **`Plan A` (Recommended — `0` files, `0` lines of code)**: Accept the Archaeologist's receipt, skip coding, post the `PR #927` history onto `TICKET-553`, and close the ticket.
* **`Plan B` (`4` files, `~280` lines of code)**: Overrule the lead architect and build the rejected wrapper anyway.

My entire review took four seconds: *"plan A is fine. If he has already spoken, I'm not challenging."*

Even better, because our workflow is a 1976 **`Makefile`** rather than a rigid 21-step checklist, an approved plan with **zero target files** didn't require any `GOTO` spaghetti: `Target 30` (code), `Target 40` (critic), `Target 50` (commit), `Target 60` (push), and `Target 70` (PR checks) all reported **`Up to date` (`Nothing to be done`) automatically**, jumping straight to `Target 80` to document and close the issue in **`8 minutes, 29 seconds`**.

---

## 4. Finding #2: Beating the `+49%` Review Bottleneck with Pre-Commit Critics and One-Shot Bot Triage (`TICKET-482`)

What happens when a ticket *does* require changing 15 files across four packages?

In the Harvard study, developers push the AI's first green test straight to GitHub, where human reviewers wait `3.45 days` only to bounce the PR back (`2x` bounce rate) or drown in `+35%` more bot comments.

In **`TICKET-482`** (`PR #1234`), we saw how the Commitment Machine stops both problems before a human ever opens the PR:

### A. Catching a Sneaky Flutter Linter Blind Spot (`SCAR-RIV-14`)
While updating the 15 creation dialogs so failed saves keep the modal open and display an error banner, the agent wrote the textbook Flutter pattern to satisfy the `use_build_context_synchronously` lint—capturing `ScaffoldMessenger.of(context)` and `AppLocalizations.of(context)` *before* the `await` line:

```dart
// Captured before the await so use_build_context_synchronously is happy:
final messenger = ScaffoldMessenger.of(context);
final local = AppLocalizations.of(context);

final result = await notifier.create(...);
isLoading.value = false;

// ⚠️ THE LINTER BLIND SPOT (SCAR-RIV-14):
notifier.onCreated(result, messenger, local);
if (!result.hasError && result.hasValue && context.mounted) {
  Navigator.of(context).pop(result.value);
}
```

Because the word `context` doesn't appear inside `notifier.onCreated(result, messenger, local)`, **`flutter analyze --fatal-infos` passed with `0` warnings!**

Yet if the user closes the modal while `await notifier.create(...)` is waiting on the network, `messenger` (which belongs to the parent screen behind the dialog) is still alive—so `notifier.onCreated(...)` pops up a ghost `SnackBar` on the parent screen after the modal is already gone!

Instead of a senior engineer having to catch that subtle bug on GitHub three days later:
1. Our automated review triage (`Target 70`) flagged the unguarded post-`await` call.
2. The `TDD Implementation Engineer` wrote a `Completer<void>` widget test that closed the dialog mid-flight and proved the ghost `SnackBar` bug failed (`red_exit = 1`).
3. It wrapped `notifier.onCreated`, any post-`await` `ref.read(...)`, and `Navigator.pop` inside a single outer **`if (context.mounted) { ... }`** block (`green_exit = 0`), and a fresh Round 2 `Model: "pro"` Adversarial Critic (`40_critic_review.md`) verified all 14 dialogs before asking me to land.
4. At `Target 90`, that trap was permanently recorded as **`SCAR-RIV-14`** so no future agent gets fooled by pre-`await` `ScaffoldMessenger` handles.

### B. One-Comment Bot Triage & The Mermaid Cockpit (`SCAR-PROC-127`)
When the GitHub review bot flagged that `context.mounted` pattern across `14` dialog files (`C-1`..`C-14`), our old rules would have burned `28` separate API calls (`14` REST `+1` reactions + `14` GraphQL `resolveReviewThread` calls) just closing threads one by one.

At `Step 330`, I made a simple observation: *"generally, we just post one final PR comment instead of closing threads... Yeah, per-thread resolution burns a lot of redundant tokens."* That became **`SCAR-PROC-127`**: the agent posts **one consolidated PR triage table** (`gh pr comment <PR> --body-file <scratch>/triage_comment.md`), paired with our **2-Push Bot Circuit Breaker (`SCAR-REVIEW-27`)** so the agent never gets stuck in an endless ping-pong loop over minor Round 2 bot nitpicks.

And because `99_next_action.md` renders a live color-coded **Mermaid Commitment Diagram** (`:::done` green, `:::active` blue, `:::gate` gold) right in my IDE sidebar, I don't even open the GitHub PR page anymore—I just wait for the green board.

---

## 5. Finding #3: `/etc/init.d` Files Make Your Agent Both Lobotomy-Proof (`TICKET-227`) and Vendor-Agnostic (`Claude -> Gemini` at Step 433)

The third reason long AI coding sessions fail in production is that the model either runs out of context tokens (`200k` lobotomy) or runs out of provider quota halfway through a big ticket.

Because our workflow keeps all commitment state in numbered Unix files on disk (`<brain>/state/00_governance.md` through `99_next_action.md`) and forces subagents (`fork()`) to do the heavy reading and testing in their own throwaway windows (`SCAR-PROC-95`), we survived two extreme stress tests:

1. **Surviving Two Context Resets (`TICKET-227`)**: On `TICKET-227` (`351` steps, `45` unit tests), the IDE hit its context limit and triggered auto-compaction (`CHECKPOINT`) at **`Step 188` (`233,658 -> 43,077` tokens)**—literally `1 second` after I typed *"ok to commit and push"*—and then hit a second reset at `Step 350`. In a normal chat session, getting lobotomized right after *"ok to commit and push"* is fatal: the model forgets whether the Critic ran or what it was about to commit. With **`Target 00: read-init-d`**, the agent woke up on `Step 189`, read `00_governance.md` through `99_next_action.md` off the disk, and picked up on the very next tool call with **`0` nudges**.
2. **Swapping `Claude Sonnet 4.6` for `Gemini 4` in Mid-Air (`Step 433` of `960`)**: During a marathon `960`-step UI verification run on `PR #1234` (`FT-184`, booting local emulators and driving an iOS Simulator to capture 5 live screenshots), **`Claude Sonnet 4.6 (Thinking)`** hit its provider quota wall and died at **`Step 432`**. Instead of starting over, I clicked the IDE model picker, switched from **`Claude Sonnet 4.6`** to **`Gemini 4`**, and typed *"continue"*. At `Step 434`, `Gemini 4` read the `/etc/init.d` files `Claude` had written to disk, saw the exact target state, fixed the Xcode 26 simulator window issue in 20 steps, captured all 5 iOS screenshots, and finished the run!

When your workflow state lives in plain text files on disk instead of inside one vendor's context window, **the LLM is just a swappable CPU running against a persistent hard drive.**

---

## 6. Finding #4: The Capability Floor—Why `GPT-OSS 120B` Crashed and Burned in the Same Cockpit (`791` Steps)

That mid-flight swap from Claude to Gemini begged the obvious question:

> **If the smarts live in the external `Makefile` and `/etc/init.d` files on disk, how small or cheap a model can wear the suit?** Can you drop an open-weight `120B` model into the exact same cockpit and get a senior engineer for free?

To find out, I took **`TICKET-894`** (*"Harden entity `fromJson` deserialization for legacy creator keys, timestamps, and nested maps"*—the follow-up ticket split out of `TICKET-482`) and ran an A/B test in the exact same IDE with the exact same rules and tools: first with open-weight **`GPT-OSS 120B (Medium)`** for **`791` steps (`67` minutes)** until I pulled the plug, and then with **`Gemini 4`** (`FT-222`), which finished the ticket cleanly with **`0` nudges**.

Here is the scorecard from that `791`-step crash test:

| What Happened on `TICKET-894` | Frontier Model (`Gemini 4`) | Open-Weight Test (`GPT-OSS 120B`) | Why `GPT-OSS 120B` Failed |
| :--- | :---: | :---: | :--- |
| **`/etc/init.d` State Files (`<brain>/state/*.md`)** | **`100%`** (`00`..`99` written) | **`0` files created** | Ignored `SKILL.md` and Turn-1 rules completely. |
| **`fork()` Subagents Spawned (`SCAR-PROC-95`)** | **`100%`** (Archaeologist, TDD, Critic) | **`0` subagents forked** | Dumped all `104` shell commands and `52` file reads into the main window. |
| **Context Lobotomies (`CHECKPOINT`)** | **`0`** | **`6` compactions** (`Steps 119..772`) | Flooded its own window, then woke up with total amnesia 6 times. |
| **Botched Tool Calls (`ERROR_MESSAGE`)** | **`0` (`0.0%`)** | **`50` errors (`13.6%` of turns)** | Printed raw JSON tool syntax inside its `<thinking>` block with empty output. |
| **Searching Google for Private Local Code** | **`0`** | **`13` calls (`search_web`)** | Used Google Web Search to look for private Dart classes inside our own repo! |
| **Simultaneous Background `git commit` Jobs** | **`1`** (waited cleanly) | **`6` running at once** | Set `WaitMsBeforeAsync: 0` on `git commit`, then ran `rm -f .git/index.lock` while commits were still alive! |
| **Outcome** | **Merged (`0` nudges)** | **Aborted at `Step 791` (`18` nudges)** | Failed to finish any of the 4 ticket items. |

Two scenes from `GPT-OSS 120B`'s flight recorder tell the whole story:

* **Finding `ParseLegacy`, Getting Lobotomized, and Searching Google for It (`Steps 90–213`)**: At `Step 91` (after I nudged it to stop searching Google and run `rg` locally), `GPT-OSS 120B` found `ParseLegacy` in `packages/helpers/lib/src/json/json.dart` and noted in its thoughts that `ParseLegacy` already handled `int` and `map`. Because it never wrote `15_archaeology_receipt.md` to disk, **Compaction #1 hit at `Step 119` and wiped that file path from its memory.** Waking up with no `/etc/init.d` files on disk, `GPT-OSS 120B` called **Google Web Search (`search_web(query: "ParseLegacy")`)** twice (`Steps 192` & `196`), announced *"I'm still not seeing the `ParseLegacy` implementation in this repository"*, and spent the next **`580` steps** inventing a brand-new duplicate `ParseLegacyAuth` class from scratch!
* **Zero-Millisecond `git commit` Fork-Bombing (`Steps 480–710`)**: On 7 of its 10 `git commit` calls, `GPT-OSS 120B` passed **`WaitMsBeforeAsync: 0`**—backgrounding `git commit #1` after `0 milliseconds` while it still held `.git/index.lock`. On the next turn, it fired `git commit #2`, hit `Unable to create '.git/index.lock': File exists`, **ran `rm -f .git/index.lock` while `git commit #1` was still running**, and launched **five more background `git commit` jobs** all corrupting the same Git index at once!

### The Four "Driver's License" Checks for Any Autonomous Model

Why can **`Gemini 4` (`Low`)** and **`Claude Sonnet 4.6`** cruise through the `Makefile` workflow with zero repeat regressions, while **`GPT-OSS 120B`** drove straight into a ditch?

Because **an external checklist and dashboard can replace deep puzzle-solving (`Low` vs. `High` thinking), but they cannot help a driver who can't read the steering wheel.** Before any model can use a `Makefile` and `/etc/init.d` harness, it must pass four basic "driver's license" checks:
1. **Turn-1 Rule Obedience**: Does it actually open `SKILL.md` and create `00_governance.md` on Turn 1 before editing code?
2. **Clean Tool Calling**: Can it invoke tools cleanly without dumping raw JSON inside its `<thinking>` thoughts?
3. **Basic Tool Sense**: Does it know to search local files with `rg` instead of Google Web Search, and to wait for `git commit` instead of backgrounding it after `0ms`?
4. **Honest Error Reporting**: When a tool returns `ERROR`, does it report the failure honestly instead of hallucinating *"I've posted the plan to Linear!"*?

---

## 7. Summary: What the Commitment Machine Delivers—And What Comes Next

When you put the Harvard study's 718-company bottleneck next to these `2,677` steps of live production telemetry (`926` steps across 5 tickets + `960` steps on `FT-184` + `791` steps on `GPT-OSS 120B`), the takeaway is crystal clear:

* **Don't optimize for typing speed (`+30%` LOC); optimize for pre-commit truth (`Counter-Offers` + Local Critics).** Making it legal—and mandatory—for an Archaeologist subagent to stamp a bad ticket `CONTRADICTED` (`TICKET-553`) and for a local Adversarial Critic to catch subtle framework bugs (`TICKET-482`) *before* `git commit` is how you keep junk out of your human reviewers' queues.
* **Put your agent's brain on the filesystem (`/etc/init.d`), not in the context window.** Plain numbered Markdown files on disk turn 200k-token context resets and mid-flight vendor quota walls (`Claude Sonnet 4.6 -> Gemini 4` at `Step 433`) into minor speed bumps.
* **Respect the model capability floor.** Give the `Makefile` suit to a frontier model (`Gemini 4` or `Claude Sonnet 4.6`) that passes the four Driver's License checks—and save the sub-threshold local models for **Part 9**, where we'll train those exact four reflexes directly into the weights via LoRA / DPO.

### Next Up in Part 3.12: *"Is This a Step, or Is This a Sensor?"*

Right after I published **Part 3.10**, systems programmers, security researchers, compiler writers, and even an autonomous AI agent running on Claude Opus 5.5 started **red-teaming the Commitment Machine in the comments**—asking:
* *"The `Makefile` stops a check from being skipped—but what stops the agent from faking the green light when it controls the test file too?"* (**Sam LABBE** & **`howcani howcani`**)
* *"Once `RETRACTED` is a legal move, what stops a lazy agent from claiming a method doesn't exist just to bail out of a hard ticket?"* (**Dawn / `Sentient_Dawn`**)
* *"Why do prompt files rewritten by LLMs bloat by `+145.8%` and turn sharp numbers into mush—and how do you scale past 500 Scars without blowing up your context window?"* (**Vinnie Falco**, **`Ctbhatia`**, & **Subhadeep Chatterjee**)

In **Part 3.12**, we'll look at how their feedback upgraded our workflow with **read-only test pins**, **Linux `insmod` Loadable Scar Modules**, and **`package:synthetic_scars_lint`**—turning prompt scars into `15ms` compiler auto-fixes that cost **zero prompt tokens and zero LLM retry turns**.

---

### 📚 The *Synthetic Scars* Series on DEV.to

* **Part 1**: [Why AI Keeps Making the Same Coding Mistakes—And How Teaching It Pain Gives It Wisdom](https://dev.to/gde/why-ai-keeps-making-the-same-coding-mistakes-and-how-teaching-it-pain-gives-it-wisdom-4a9m)
* **Part 2**: [Why AI Coding Agents Crash at 3 AM: The Happy-Path Mirage & The Forced Continuity Defect](https://dev.to/gde/why-ai-coding-agents-crash-at-3-am-the-happy-path-mirage-the-forced-continuity-defect-46pd) *(💎 DEV.to Staff Pick)*
* **Part 3**: [The Physics of Socratic Prompting: Somatic Recoil, Chess Alpha-Beta, & The NLP Meta-Model](https://dev.to/gde/the-physics-of-socratic-prompting-somatic-recoil-chess-alpha-beta-the-nlp-meta-model-2b6e)
* **Part 3.5**: [Nudging with Questions: Why Telling Your AI What to Fix Triggers an Apology Death Spiral (And How to Advance Juniors)](https://dev.to/gde/nudging-with-questions-why-telling-your-ai-what-to-fix-triggers-an-apology-death-spiral-and-how-5gm4)
* **Part 3.6**: [Stuart Feldman Was Right in 1976: Why Your AI Agent Needs a Makefile, Not a 20-Step Prompt](https://dev.to/gde/stuart-feldman-was-right-in-1976-why-your-ai-agent-needs-a-makefile-not-a-20-step-prompt-5bn2)
* **Part 3.7**: [Surviving the 200k-Token Lobotomy: How Unix `init.d` and "Memento" Made My AI Coding Agent Immune to Context Compaction](https://dev.to/gde/surviving-the-200k-token-lobotomy-how-unix-initd-and-memento-made-my-ai-coding-agent-immune-to-2f74)
* **Part 3.8**: [What LLMs "Know" That You Don't Know They Know: Stop Inventing Prompt DSLs and Ride 50 Years of Unix Pre-Training Gravity](https://dev.to/gde/what-llms-know-that-you-dont-know-they-know-stop-inventing-prompt-dsls-and-ride-50-years-of-2bl6)
* **Part 3.9**: [If You Never Do Anything Else to Fix Your Prompts, Do This One Thing](https://dev.to/gde/if-you-never-do-anything-else-to-fix-your-prompts-do-this-one-thing-3069)
* **Part 3.10**: [Requests, Promises, Assertions, and Declarations: Rewriting Our AI Agent Workflow as a 1986 "Committed Speech" Machine](https://dev.to/gde/requests-promises-assertions-and-declarations-rewriting-our-ai-agent-workflow-as-a-1986-4k4c)
* **Part 3.11**: *926 Steps, Two Lobotomies, and Zero Nudges: Flight-Testing the Commitment Machine Across Gemini, Claude, and GPT-OSS (You are here)*
* **Part 3.12**: [The Best Prompt Rule Is the One You Delete: Moving AI Guardrails Out of Markdown and Into Git Locks, Linux `insmod`, and 15ms Compiler Auto-Fixes](https://dev.to/gde/the-best-prompt-rule-is-the-one-you-delete-moving-ai-guardrails-out-of-markdown-and-into-git-5a5h)
* **Part 4**: *Giving AI Pain: The Architecture of Synthetic Scars & The Rapid-Regret Miner (Next)*
* **Part 5**: *Zero Repeat Regressions: The Golden Metric & The Future of Agentic Trust*
* **Part 6**: *The Proscriptive Inversion: What You Get to Forget, and Why More Negative Rules Mean You've Lost*

Have you seen the Harvard "+30% code, +49% review wait, 0 extra tickets closed" bottleneck on your own team—or tried swapping models mid-session when a provider quota hits? Drop your war stories in the comments!
