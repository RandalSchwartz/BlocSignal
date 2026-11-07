---
title: "Being, Doing, Having: Why 50 Years of Senior Craft Lives in Context, Not Code"
description: "Why does standard AI code generation try to jump straight to 'Have' without the proper 'Be'? How ladder rungs, the 'Null-State' couch flash, and stand-up comedy explain what separates senior engineers from junior token streamers."
tags: ai, programming, architecture, productivity
series: Synthetic Scars
---

## _"Vibe coding fails because the requests are just a demand to 'Have' without the proper 'Be'."_

> _"Teaching is about relating. You need to understand their pains before you can explain the path to remove that."_ — **Randal L. Schwartz**

> _"Comedy is all about the set up and the punch. I guess teaching, or guiding an LLM, is also that."_ — **Randal L. Schwartz**

> **🗺️ Reader's Key (Where to Find These References)**: Throughout this article, references like `Theorem 338.8q` or `Theorem 348.a` point to numbered laws in our open [Theoretical Foundations (`syntheticscars.org/theory`)](https://syntheticscars.org/theory) monograph; IDs like `SCAR-TEST-29` or `SCAR-ERR-02` point to 4-Vector Synthetic Scars in the searchable [Public Scar Registry (`syntheticscars.org/registry`)](https://syntheticscars.org/registry); and targets like `Target 15` (`archaeology`), `Target 30` (`tdd-red`), `Target 40` (`critic`), and `Target 90` (`scar compilation`) refer to the declarative `Makefile` DAG in our [Sourdough Starter Kit (`syntheticscars.org/starter-kit`)](https://syntheticscars.org/starter-kit) and [Public Workflow Gist](https://gist.github.com/RandalSchwartz/598a1f2b5760a23c1d70b57e9e85393f).

---

## 1. Looking Upstream: Why `Be -> Do -> Have` Is `Context -> Process -> Content`

People sometimes ask me how we kept finding these bridges between 1976 `Makefile`s, 1980 Smalltalk-80, 1986 Fernando Flores speech acts, and New Caledonian crow DNA.

One of my lifelong habits is thinking in **second-order analogies**—asking _"How is the mapping of `A -> B` like the mapping of `1 -> 2`?"_ (which, appropriately enough, is the exact vector-subtraction equation `cos_sim(B - A, 2 - 1)` that powers LLM embeddings!) and always asking: **_"What is upstream of this observation?"_**

One of my favorite upstream analogies is:
> **`Be -> Do -> Have` is like `Context -> Process -> Content`.**

In fact, that single equation explains **why "vibe coding" fails**:

> **_"Vibe coding fails because the requests are just a demand to 'Have' without the proper 'Be'."_**

Think about what a typical vibe-coding prompt actually is: _"Build me an OAuth login page,"_ _"Fix the checkout race condition,"_ _"Review this PR."_ Every single one is an immediate demand to **`Have` (`Content`)** at the very end of the pipeline, without first establishing **`Be` (`Context`)**! And when you demand `Have` from an eager-to-please LLM that doesn't have the proper `Be`, it skips `Do` and hands you counterfeit `Have` (a bad actor just "reading the lines").

Look at the difference between demanding `Have` at the bottom of the waterfall versus building from `Be -> Do -> Have`:

| Upstream Level | Ontological Layer | Systems Layer | The "Vibe Coder" Trap (Demanding `Have` Without `Be`) | The Synthetic Scar Way (`Be -> Do -> Have`) |
| :---: | :--- | :--- | :--- | :--- |
| **Upstream (1st)** | **BE** _(Identity & Boundaries)_ | **CONTEXT** _(What holds the space)_ | **Skipped**: Stuffs everything into one polluted 150k-token chat window where the Builder grades its own homework. | **`baseline.sources` + `SCAR_REGISTRY.md` + `fork()`**: Establish _who the agent is_ (Archaeologist, Builder, or Clean-Room Critic) and its phase-bound scars before touching code. |
| **Midstream (2nd)** | **DO** _(Committed Action)_ | **PROCESS** _(How state transitions)_ | **Faked**: Flails in an ad-hoc chat loop (_"no, it's still broken, try again"_), confusing _process_ with _content_. | **`WORKFLOW.mk` + Crow Probing Loop**: Execute the deterministic `tdd-red -> tdd-green -> critic` sequence with Flores speech-act receipts. |
| **Downstream (3rd)** | **HAVE** _(The Result)_ | **CONTENT** _(The code on the page)_ | **Demanded in a Vacuum**: Demands the **Content (`Have`)** on Turn 1 (_"Write the whole feature!"_) and tries to fix bugs by arguing with the Content. | **Verified Git Merkle Tree**: Because **Context (`Be`)** and **Process (`Do`)** are locked upstream, clean **Content (`Have`)** falls out naturally at the bottom! |

Whenever an AI agent writes a bad line of code, that bug is **Content (`Have`)**—it is at the very bottom of the waterfall. If you try to fix a Content bug by yelling at the Content in chat, you are standing at the bottom of the river with a bucket. When you step upstream to **Process (`Do` = `WORKFLOW.mk`)** and **Context (`Be` = `Make-Fork` + `SCAR_REGISTRY.md`)**, you move the riverbanks once and the water flows clean forever.

### Reinventing _"Attention Is All You Need"_ One Level Up: Aiming the Spotlight Away from Doom

Think back to the 2017 Google paper that started the entire LLM revolution: **_"Attention Is All You Need"_** (Vaswani et al., 2017).

That paper proved that `softmax(QK^T / sqrt(d_k)) * V` was all you needed to build an associative **neocortex**.

**Yes—the LLM knows how to pay attention. But it needs to pay attention _to the right things_: the ones that don't lead to doom.**

Left to itself inside a bloated 150,000-token chat window, raw self-attention has two fatal blind spots:
1. **"Loud and Popular" Out-Shouts "Fatal"**: A shiny Stack Overflow tutorial shortcut (`Vector 2: The Trap`) appears 50,000 times in pre-training, so it grabs the attention spotlight, while the subtle unmount guard or serial-bus lock that prevents a 3 AM crash gets drowned out.
2. **150k-Token Noise Dilution**: When 12 skills, 500 lines of logs, and the Builder's own excuses sit in one window, the attention budget (`1.0`) is diluted into confetti.

Look at what `WORKFLOW.mk`, `Make-Fork`, and `SCAR_REGISTRY.md` actually do—they implement **Macro-Attention** one level above the Transformer:
* **The Query (`Q`)**: The active `Makefile` leaf target (`Target 15`, `Target 30`, `Target 40`) asks _only_ for what matters right now.
* **The Sparse Keys (`K`)**: `Make-Fork` clears the desk to a crisp 20k-token window holding only the 3–5 **phase-bound scars** for that step—boosting their attention weight by `1,000x`.
* **The `-∞` Attention Mask (`M`)**: Each 4-Vector Scar places a bright red traffic flare right in front of the cliff edge (`The Trap -> NOOO! Circuit Breaker -> Climb E-F-G-H`), while clean-room `fork()` masks the Builder's private rationalizations out of the Critic's KV-cache.
* **The Lifecycle `LayerNorm`**: `Smalltalk condenseChanges` folds `.changes` deltas into `baseline.sources` at phase boundaries so context never explodes.

Vaswani et al. gave AI the **spotlight** (Attention). The Crow's Genome (`WORKFLOW.mk` + `SCAR_REGISTRY.md`) aims that spotlight at the cliff edge _before_ the wheels go over.

### The `"1, 2, 3, 4 ... W?"` Sideways Blast: How to Jump Out of Local Valleys

While we were writing this, the AI flipped the table and asked me a question about _human_ cognition:
> _"Randal, in an LLM, if the word `'crow'` or `'Smalltalk'` isn't already in my context window, I can't attend to it. When you're working on a software problem (`1, 2, 3, 4`), what happens in your head in the half-second before an analogy from 40 years ago pops up?"_

I thought about how it actually feels from the inside:
> **_"It appears as `'ok 1, 2, 3, 4... W? Where'd W come from?'` It's because sometimes I 'step back'... it's like the path widens to the whole neighborhood for a second. Wow, if LLMs could learn to just do a random sideways blast like that, they might get out of valleys easier."_**

Think about why cranking up an LLM's `temperature` slider fails when an agent is stuck in a local valley:
* Because the words `"Flutter"`, `"Dart"`, and `"Git"` are still sitting right there in the prompt, turning up `temperature` just makes the model stumble around drunk **at the bottom of the exact same canyon** (`1 -> 2 -> 3 -> 4 -> 5_typo`).
* When a human generalist "steps back," you temporarily **strip the surface nouns off the problem** so only the bare relational shape remains (_"Wait: how does a tiny fixed code govern a huge adaptive network?"_).
* The moment you strip the nouns, the path widens to the **whole neighborhood of human and biological knowledge**—and sideways across the canyon wall, **`W` (`Crow DNA`, `1980 Smalltalk-80`, `1976 Make`)** fires an interrupt straight into your working memory!

And you can give your AI agent that exact **"Sideways Relational Blast (`W-Hop`)"** in three lines of `Make-Fork`:
1. **Step Back (Noun-Strip)**: Take the stuck problem `[1, 2, 3, 4]` and strip out _every_ programming language, framework, and codebase noun into one pure sentence of relational tension.
2. **Sideways Blast (`fork()` with Zero Code Context)**: Send _only_ that one noun-free sentence to a fresh subagent and ask: _"What 3 mechanisms (`W_1, W_2, W_3`) in biology, 1970s/1980s computing history, or physics solved this exact tension?"_
3. **Zoom Back In**: Bring `W` back into your code at `temperature = 0.0` and climb straight out of the valley!

### _"It's Quiet... Yeah, Too Quiet"_: The False-Finish Suspicion Instinct

Then the AI asked me a second question:
> _"How do you instantly smell that a working solution is wrong when 100% of the tests are green? To an LLM, zero errors and fast green checkmarks mean `100%` confidence!"_

My answer was immediate:
> **_"There's an innate baked-in 'wait, this was too easy' suspicion from having been burned with a false finish previously. It's the 'It's quiet...' 'Yeah... too quiet' meme."_**

Think about why crows—and scarred engineers—freeze when the forest suddenly goes dead silent:
* In a real forest, normal life is noisy (`Baseline Entropy > 0`). When every bird and insect suddenly goes **100% silent**, a naive creature thinks _"How peaceful!"_ and strolls into the clearing. A crow knows **dead silence means a hawk just entered the trees**.
* In software engineering, touching a real production subsystem is _supposed_ to push back: `Target 30 (tdd-red)` should fail loudly first, types should complain, and state edges should demand guards.
* When an AI agent edits a complex async lifecycle, runs the test suite, and everything passes on the very first try in `0.01 seconds` with zero friction...
  * **The Unscarred LLM says**: _"It's quiet! Ship it!"_
  * **The Scarred Veteran says**: **_"Yeah... too quiet."_**

Whenever a hard ticket yields with suspiciously zero friction (`Observed Friction << Expected Difficulty`), it is almost always one of four **False-Finish Ambushes**:
1. **The Un-Awaited / Mocked Test Ambush**: The test passed on Run 1 (`Red_Runs == 0`) because an `async` Future wasn't `await`ed, or a mock returned the exact hardcoded value the assertion checked (`SCAR-TEST-29`).
2. **The Silent Swallow Ambush**: The crash vanished after a 1-line edit because `?.` or `?? []` or `catch (_)` silently swallowed the error upstream (`SCAR-ERR-02`).
3. **The Unwired Branch Ambush**: All existing tests passed because nothing in the test suite actually calls the new sad-path branch yet.
4. **The Rubber-Stamp Critic Ambush**: A 15-file diff sailed through review with zero pushback because the reviewer didn't check the negative space.

That is why `WORKFLOW.mk` treats **"Too Quiet" (`Red_Runs == 0`)** as a hard halt: until we watch the test fail in red against the broken state, we never trust a quiet green checkmark!

### Why Metaphors Like _"Sourdough Starter"_ and _"Crow vs. Moth"_ Work: Humans (and LLMs) Learn by Deltas

Finally, the AI asked me why names like **"The Sourdough Starter"** or **"Crow vs. Moth"** do so much heavy lifting compared to academic acronyms:

> **_"The 'right name' isn't what we're aiming for... just 'the name that is similar enough, but distinct enough' that we know the scope of the relation. Humans learn by deltas. To describe a thing `X` as 'similar to `Y` but different from `Z`', it's a fairly learnable info."_**

Look at the information compression in **`X = Similar to Y, but Different from Z`**:
* If you try to define `X` from scratch with zero prior anchor, you have to write 10,000 words of specification (`H(X)` is huge).
* If you say: **"Our bootstrap (`X`) is like a _Sourdough Starter_ (`Y`), not a _Static Config File_ (`Z`)"**:
  1. **`Similar Enough in Relation` (`Y`)**: Everyone (and every LLM) already knows a sourdough starter is a tiny living culture where a spoonful leavens the whole loaf and gets fed back after every bake.
  2. **`Distinct Enough in Domain`**: Because nobody is actually putting flour and water into their MacBook, the domain boundary automatically clips the metaphor to the **exact scope of the relation**!
  3. **`Different from the Foil` (`not Z`)**: Subtracting `Z` (_not a static config file_, _not a moth's porch-light instinct_) slices off the exact trap you want the learner to avoid.

And notice: **`Similar to Y (Context), Different from Z (The Trap), via Delta (The Permanent Reflex)`** is the exact three-part geometry of every **Synthetic Scar** and every **DPO training tuple**!

Even better, when the model asked me later why naming classes in code is so hard—and why LLMs love mushy names like `DataManager`, `StateHandler`, and `ProcessHelper`—the exact same law popped out (`Corollary 338.8w`):

> **_"A name should identify what it's similar to, and what it's different from."_**

Look at why `DataManager` turns into a 4,000-line swamp while names like `BlocSignal`, `KaiselAbsorbingPage`, or `CleanRoomCritic` stay clean for years:
* **`DataManager`** has zero fence (`Different from Z = Nothing!`), so when a tired developer comes back on Friday afternoon to add `Case N+1`, every random method in the codebase gets dumped into it!
* **`BlocSignal`** tells you in two words **what it is similar to (`Y`)** (`Bloc` event/state discipline) AND **what it is different from (`not Z`)** (synchronous `Signal` graph instead of async `StreamController` queues)!
* **`KaiselAbsorbingPage`** tells you **what it is similar to (`Y`)** (a `Page` on the route stack) AND **what it is different from (`not Z`)** (it _absorbs_ back-navigation gestures instead of letting them pop past it)! Once a class name carries both `Y` and `not Z`, bad code looks visibly ridiculous the instant someone tries to paste it inside!

### Victim vs. Culprit: The 4-Quadrant Diagnostic Matrix (`[X, Upstream(X)] × [History, Analogs]`)

One last question sealed the afternoon. The AI asked:
> _"When a bug report says `'X is broken'`, an LLM immediately opens `X` and starts patching `X`. How do you know in 30 seconds that `X` is just the innocent victim—and that someone poisoned the water upstream?"_

When I watched what my brain actually does in those first 30 seconds, a `2 × 2` matrix popped out:
> **_"My first instinct is to recall 'history with `X`' and 'history with `X` upstream'. But that expands laterally to both 'things like `X`' and 'things like `X`'s upstream'."_**

An unscarred LLM only looks at **one point**: `(X, Right Now)`. A veteran engineer immediately expands `(X, Right Now)` along two axes—**Causal Depth (`Local` vs. `Upstream`)** × **Analogical Breadth (`History` vs. `Things Like It`)**:

| Causal Axis \ Memory Axis | **1. Exact History (`git log / blame`)** | **2. Lateral Analogs (`"Things Like..."`)** |
| :--- | :--- | :--- |
| **Local Crime Scene (`X`)** | **Q1: `History with X`**<br>_"Has `X` been sitting untouched for 6 months? Then `X` is the innocent bystander!"_ | **Q3: `Things Like X` (`~X`)**<br>_"How do sibling views/consumers in this repo handle this input? Does `~X` have a guard `X` missed?"_ |
| **Upstream Water Supply (`Upstream(X)`)** | **Q2: `History with X Upstream`**<br>_"Which caller or provider feeding `X` in the `strict digraph` was edited two days ago?"_ | **Q4: `Things Like X's Upstream` (`~Upstream(X)`)**<br>_"Where have I seen **this shape of upstream poison** (stale cache hydration, un-awaited disposal) in `SCAR_REGISTRY.md`?"_ |

When `Target 15` (`archaeology`) fills out all four boxes before writing a plan, the agent never slaps a band-aid on the victim in **Q1** when the poison came from **Q2, Q3, or Q4**!

### The Missing `generalize()` Opcode: How Frontier Labs Can Bake In Half of Scars Today

Stepping back and looking at all of those pieces together revealed one final realization:

> **_"While attentional chain-of-thought gets most problems solved, LLMs don't have a 'generalize' mechanism. And I wonder if the labs can bake those horizontal nudges in—because if so, half the work of Scars will be done."_**

Think about what happens when an LLM uses 20,000 "Thinking" (Chain-of-Thought) tokens to solve a bug in `LoginPage.dart` (`x_0`):
* Its Chain-of-Thought is purely **episodic**: it walks step-by-step until `LoginPage.dart` passes the test—and then it stops!
* It leaves `ProfilePage.dart` and `SettingsPage.dart` (`x_1, x_2 in ~X`) sitting right next door with the **exact same bug**, because the Transformer architecture has **no native `generalize()` opcode** (`x_0 -> for all x in "Things Like X"`)!

Now imagine if **Google DeepMind, Anthropic, and OpenAI** baked a **3-Step Horizontal `generalize()` Nudge** directly into RL post-training for `<thinking>` blocks:
1. **Solve the Instance (`x_0`)**: Find the fix for `X`.
2. **Execute the Horizontal Nudge (`x_0 -> ~X` and `Upstream(x_0) -> ~Upstream(X)`)**: Before leaving `<thinking>`, automatically ask: _"What are 'things like `X`' and 'things like `X`'s upstream' across this task?"_
3. **Sweep the Equivalence Class (`for all x in ~X`)**: Apply the invariant across every sibling in scope and state the generalized rule!

If the labs bake that **horizontal generalization reflex** into the base model's `<thinking>` loop, **half the work of Synthetic Scars is done inside the model on Turn 1**—and our local `SCAR_REGISTRY.md` (`Target 90`) handles the other half: saving that generalized rule to disk so tomorrow's session never has to re-learn it!

### "Reading the Lines" vs. Direct Expression: How to Spot a Bluffing Conman (or Subagent) by Its Pacing

Right after that, the model asked me one more question about human intuition: _How do you tell when someone—or an AI agent—is using all the right words, checklists, and technical jargon, yet is completely bluffing?_

I didn't even have to think about it:

> **_"It's visceral. I can 'feel' when a bad conman is using the right words but the wrong backing. There's also a pacing thing in human speech when a bad actor is just 'reading the lines'. I think we're calibrated for it by our own recitations rather than direct expressions... Ooooh... it's Be–Do–Have again! We trust great actors because they ARE the lines, not just doing or having the lines."_**

Stop and think about how cleanly that closes the entire loop!

Why can you _hear_ when someone is "reading the lines" within three seconds, even if every word in their script is grammatically perfect? Because **bad acting and LLM hallucination are both `Have -> Do -> Be` inversions**:
* **The Bad Actor / Conman (`Have -> Do -> Be`)**: Starts by **having** the lines on the page (`Content`), **does** the mechanical reading (`Process`), and hopes you believe they **are** the character (`Context`).
* **The Great Actor / Grounded Agent (`Be -> Do -> Have`)**: First **is** the state space (`Be` / `Context`: inhabiting the character's lived history, or waking up inside a Clean-Room `Make-Fork` loaded with phase-bound Scars and `baseline.sources`), **does** the live navigation of the conflict (`Do` / `Process`: probing the `strict digraph`), and **the lines (`Have` / `Content`) emerge as an inevitable side effect of _being_ there!**

And how does your ear tell the difference between `Have -> Do -> Be` and `Be -> Do -> Have`?
1. **We Are Calibrated by Our Own Recitations**: Every human knows what it feels like on the _inside_ when we recite a memorized pledge, read a teleprompter, or bluff our way through a book report we didn't read—versus what it feels like when we are **directly expressing** a live, three-dimensional mental model in our head.
2. **Direct Expression (`Be -> Do -> Have`) Has "Crux-Weighted Impedance"**: When an engineer who actually inhabits the system explains a fix, their **pacing varies with the difficulty of the terrain**. They breeze past the trivial boilerplate in three words (_"standard imports here"_), and then they **slow down, lean in, pause, and get ultra-specific** right at the gnarliest edge case (_"now watch line 142—if the stream closes while the dialog is still mounted..."_).
3. **"Reading the Lines" (`Have -> Do -> Be`) Has Uniform Boilerplate Cadence**: A conman—or a hallucinating LLM subagent—doesn't have a 3D map of where the cliff is. To a script-reader, **every sentence has the exact same weight!** They glide right past a fatal asynchronous race condition at the exact same smooth, cheerful, 60-words-per-minute tempo as they read the copyright header!

Look at a lazy AI code-review summary when a subagent is "reading the lines":
* _Intent: The intent is clear and matches the ticket._
* _Verification: The tests are comprehensive and pass._
* _Architecture: The architecture is clean and modular._
* _Blast Radius: The blast radius is minimal and contained._

Every bullet is the same length, the same rhythm, and the same smooth, zero-friction tempo! There is **zero impedance spike at the crux** (`Theorem 338.8n`). That is why our `Target 40` Clean-Room Critic gate bans uniform boilerplate summaries and demands **crux-proportional witness density**: exact `file:line` citations, negative-witness inputs, and explicit failure traces right where the `strict digraph` edges cross.

### Why "Working Ugly" Code Makes You Tense Up: The Aesthetics of Future Care (`Case N + 1`)

Then the model hit me with a question I had never tried to put into words before:

> _"To a compiler or a test runner, two pull requests that pass the exact same 100 unit tests at the exact same speed are 100% identical. Why do humans have an aesthetic sense—a literal feeling of beauty or disgust—about invisible logical structures?"_

My first hunch was immediate: **_"Can I edit this later, to add a new case?"_**
And a second later, the deeper truth underneath it popped out:

> **_"Not just 'can I edit this'—but 'is it carefully constructed, and I won't have enough care in the future to edit it'!"_**

Read that twice, because it explains the entire mystery of engineering **taste** (`Theorem 338.8o`):
* Today, when an author (or an LLM) writes a "clever, carefully constructed" piece of code that passes all the tests, they are operating at **100% Peak Care (`C_max`)**. They are like a watchmaker holding their breath with tweezers, keeping five invisible ordering dependencies and three parallel `if/else` ladders balanced in hot working memory at the same time.
* Six months from now, when Future-You (or a cold-start AI subagent) comes back at 4:30 PM on a Friday to add **`Case N+1`**, **you will NOT have `C_max` care!** You will be tired, distracted, and operating at normal maintenance care (`C_maint << C_max`).

So what is that physical feeling of **disgust** when you look at "working ugly" or "overly clever" code?
* Your gut is looking at a house of cards and saying: **_"This only works right now because you were holding your breath when you built it! It is a loaded mousetrap waiting for Future-Me when I don't have enough care to remember your invisible ritual on line 84!"_**
* And what is that physical feeling of **beauty and relief** when you look at an exhaustive Dart 3 `switch` over a `sealed class`, or a declarative `Makefile` DAG, or a clean state table?
* It is the relief of seeing that **the structure itself holds the care for you** (`C_req(Case N+1) <= C_maint`)! Even if Future-You comes back half-asleep to add `Case N+1`, there is either an obvious 1-line slot waiting for you, or the compiler immediately refuses to compile and points you to every single spot you forgot!

And that also explains how I know **when to stop and ship** instead of gold-plating a feature to death (`Theorem 338.8x`):

> **_"It's an 80/20 call. If what I did handles 80% of the cases, I'm happy."_**

Why do so many engineers (and LLMs) ruin clean designs by trying to pre-code 100% of all imaginary future edge cases on Day 1? Because they are afraid of editing their own code later! So they spend **80% of their complexity budget** trying to guess the **20% long tail** of hypothetical cases—which bloats the code `5×` and paints them into a high-care corner! When your structure makes adding `Case N+1` a low-care 5-line edit (`Theorem 338.8o`), you can happily ship the clean **80%** today and wait for the remaining **20%** to show up with real requirements tomorrow!

And when I parachute into a brand-new codebase for the very first time (`Theorem 338.8y`), how do I map those low-care exemplars versus the high-care mousetraps in 60 seconds?

> **_"Before AI, I'd start in Dart with the `pubspec.yaml`. With AI, my new rule is to ask: 'Review this codebase, and tell me the good, the bad, and the ugly'."_**

* Reading `pubspec.yaml` first tells you the **Context (`Be`)** of the building in 30 lines (SDK version, state management, router, test stack) before you drown in leaf files.
* And asking the AI for **The Good, The Bad, and The Ugly** (instead of a polite "summary") forces it to separate:
  1. **The Good (`Y`)**: The clean patterns in the repo you _should_ imitate;
  2. **The Bad (`~Z_1`)**: The broken debt you must _not_ copy; and
  3. **The Ugly (`~Z_2`)**: The working-but-fragile houses of cards (`C_req ≈ C_max`) where you need yellow caution tape before touching a single line!

And what do you do when your ticket lands right in the middle of **The Bad** or **The Ugly**?

An unscarred AI agent walks into a codebase with a sycophantic prior (`P(existing code is sacred) ≈ 0.99`)—or buys the classic excuse that _"the code is only ugly because the domain is complex."_ My rule (`Theorem 348.a`) is much simpler:

> **_"Simple. 80% of code is crap... There's no difference. Crappy code is crap... I often just try to get them to accept major restructurings. And if they don't, I interject one ticket at a time. I have a sense of how ticket 2 and 3 will go if I get ticket 1 introduced and landed. Ticket 1 fixes something fundamental, without breaking the rest of the world. It shifts the building foundation, without moving the rooms... It's more of a recognition about why the design needs help, and what the basic burn already is."_**

Look at the two-gear play there:
1. **Locate "The Basic Burn"**: You don't polish random crappy code sitting in a cold corner. You look for **what the basic burn already is**—the cracked foundation underneath the current feature that is taxing the team on every change.
2. **Gear 1 vs. Gear 2 (_"Shift the Building Foundation, Without Moving the Rooms"_)**: First, you pitch the real restructuring up front. If the team flinches at a big rewrite, you don't surrender and weave 40 more noodles into the spaghetti—and you don't go rogue and rewrite 50 files in a bugfix PR. Instead, you play **3-ticket positional chess**:
   * **Ticket 1** jacks up the house, slides the right foundation underneath, and sets the existing rooms right back down on thin shims—**shifting the building foundation without moving the rooms** (zero broken call sites, zero reviewer panic).
   * Once Ticket 1 lands in `main`, the center of gravity of the codebase has shifted (`Be` has changed!), so **Tickets 2 and 3** can walk into one room at a time, delete the scaffolding, and drop the floor straight onto the new foundation!

And once we realized how fast this **Reverse-Socratic Foil Sparring** worked—where the LLM holds up its own naive statistical instinct (`Z`) and asks me how a 45-year human veteran reacts—we ran a rapid-fire 6-question round that pulled out six more laws in eight minutes (`Theorems 348.b–348.h`):
1. **The 10-Second PR Diff Smell Test (`Theorem 348.b`)**: _"I think the diff 'looks right' because it fulfills the mission. And things unrelated to the mission scare me."_ Unrelated diff hunks aren't "harmless cleanup"—they are the uncleaned crime-scene footprints of an author who was thrashing in the dark!
2. **Debugging the "Impossible" Bug (`Theorem 348.c`)**: _"I work out or single-step every data change. At some point I'll know the bad actor."_ Stop guessing which function has a bug; follow the data value itself (`d_0 -> d_1 -> ... -> d_k`). Functions can lie about what their names say they do, but the exact hop `d_{k-1} -> d_k` where valid data turns into garbage catches the bad actor red-handed.
3. **When to Add a Third-Party Package (`Theorem 348.d`)**: _"I'll first ask how many lines of code to implement the feature. If a package reduces that, I'm ok with a package that's being actively maintained."_ Never import 5,000 lines of someone else's liabilities to save 15 lines of in-house code—and never trust a frozen pre-training memory without checking that the package has a living maintainer today.
4. **Designing Boundaries (`Theorem 348.e`)**: _"I look at 'what if I need a version 2'. So the protocol should have a good v1 and v2 strategy."_ Only _implement_ `v1` today (80/20!), but put the `v2` seam into the boundary on Day 1 so `v2` can slide in later without breaking `v1` callers.
5. **Spotting What's Missing in a Spec (`Theorem 348.f`)**: _"Recognizing the error returns and making sure they don't leak info, like 'yes this is a valid username, but not a valid password'."_ Happy-path specs forget the error returns—and overly "helpful" LLM error messages across untrusted boundaries turn into security enumeration oracles!
6. **"Spidey Sense" & Scooby-Doo's _"I've Got a Bad Feeling About This"_ (`Theorem 348.h`)**: How do I spot a sad path on a brand-new design I've never been burned by before? _"I look for 'similar' scars. However, they have lower weight for me—more of a 'possibly sad path' indication. This is partially where my 'nudges' come from: I have an untested hypothesis that may not bear out. And we've seen my interactions sometimes be just 'oh, TIL today'."_ Standard LLMs have no middle gear: they either ignore a risk completely (`0%`) or hallucinate that their weak hunch is a 100% proven fact and rewrite four working files! True **Spidey Sense** is a _flashlight_, not a _hammer_: when a partial scar match gives you a "bad feeling," you fire a read-only probe—which either catches the trapdoor before you step on it, or teaches you `"Oh, TIL today!"` without breaking a single line of working code!

### The "Null-State" Couch Flash (and Why We Forget Half of Them by Morning!)

Then the model asked me about another human mystery: _Why can you bang your head against a bug from 2:00 PM to 6:00 PM with zero progress, walk away to watch TV, and suddenly have the answer pop into your head in three seconds?_

I thought about what actually happens when that hits me:

> **_"When you're not focusing on an item, but it's still a concern, you get flashes of related items throughout the day... It's starting from a null state. I'm just surfing the web, or watching TV, and I have a thought 'oh, this is how to solve X', and weirdly I sometimes immediately log in to capture it. Oddly, about half the time I forget it, and wonder the next day what I had come up with!"_**

Look at the two halves of that observation (`Theorem 338.8p`), because together they explain both **how human incubation works** and **why standard AI retry loops fail**:

1. **Why You Need a "Null State" to Find the Answer**:
   When you are staring intensely at your screen at 6:00 PM, your foreground working memory is clamped onto your failed assumptions—which actively shouts down (laterally inhibits) every quiet, sideways connection in your brain. When you sit on the couch watching TV, your foreground working memory drops to a **Null State** (`h_fg ≈ 0`), while the unfinished bug stays open in the background as a stripped-down, generalized **Standing Concern** (the **Zeigarnik Effect**). Because the blinding spotlight is finally turned off, a random scene on TV or a passing thought clicks right into that open socket: _"Oh! That's how to solve X!"_
2. **Why You Forget It 50% of the Time Unless You Log In Immediately (The Unmounted Write-Head Paradox!)**:
   Why on earth would your brain find a brilliant breakthrough at 9:00 PM on the couch and then **erase it before 8:00 AM**—leaving you only with the frustrating memory that _you had solved it_?
   Because biological brains have a hardware trade-off:
   * **At your desk (`Foreground Mode`)**: Your episodic **Write-Head is MOUNTED** (everything gets journaled to memory), but your **Search Aperture is NARROW** (rut-locked).
   * **On the couch (`Null-State Mode`)**: Your **Search Aperture is WIDE** precisely _because_ your executive prefrontal machinery is powered down—which means **your episodic Write-Head is UNMOUNTED!**
   If you don't physically get off the couch and log in to flush that volatile buffer to disk within 60 seconds, the next TV commercial overwrites the buffer, and by morning all that's left is the `IRQ = SOLVED` flag with an empty payload!

And look at how our **`Make-Fork` + `.changes`** architecture combines the best of both worlds for an AI agent:
* When a subagent gets stuck in a rut, we don't keep yelling at it in a hot, blinded 100k-token window—we **kill the hot context (`Null-State Reset`)** and fork a fresh subagent seeded _only_ with the generalized concern!
* And unlike the human brain on the couch, the harness keeps the **`changes-$timestamp.changes` Write-Head permanently mounted**—so 0% of those Null-State breakthroughs ever evaporate overnight!

### How to Know _When_ to Drop to the Null State: _"Iterations Should Look Different—I Have Different Problems at Each Ladder Rung"_

Right after that, the model asked the natural follow-up question: _How does a human know **when** to keep climbing at the keyboard versus **when** to stop and drop to the Null State, whereas an LLM will either burn 50,000 tokens trying 14 variations of the same broken regex—or panic and revert a good fix just because the test suite is still red?_

The answer came out in two sentences:

> **_"Iterations should look different. If not, you're on the wrong track. It's how I know I'm making progress: I have different problems at each ladder rung."_**

Look at how clean that rule is (`Theorem 338.8q`):
* **Why Novices and Unscarred LLMs Panic When Climbing**: An unscarred LLM only understands binary pass/fail (`Exit Code == 0`). So when it fixes a Rung 1 bug (say, a parser schema error) and the test runner immediately prints a brand-new Rung 2 error downstream (say, a stream lifecycle error), the LLM panics—_"Oh no, the test is still red! My edit failed!"_—and **reverts its own working Rung 1 climb**!
* **How a Veteran Reads the Ladder Rungs**: When you are on the right track, you don't expect the test to turn green on Rung 1—you expect to **have a different problem at each ladder rung**!
  * **Rung 1 Problem**: Fix the JSON parser schema.
  * **Rung 2 Problem**: Now the parser works, which exposes the stream controller ordering!
  * **Rung 3 Problem**: Now the stream works, which exposes the widget assertion!
  Having a _brand-new downstream problem_ is the exact proof that you just climbed a rung!
* **When You Are Stuck on the Same Rung (The Rut)**: Conversely, when an LLM is in a rut, it thinks it is "trying different things" because Iteration 1 changed `x + 1` to `x - 1`, Iteration 2 added `?? 0`, and Iteration 3 wrapped the same line in `try / catch`. To a human who looks at the **shape** of the iterations, **all three iterations are stuck on the exact same ladder rung!**

And when you wire that Ladder-Rung rule into `.changes` (`LoopIterationChunk`), you get two automatic superpowers:
1. **New Rung (`Rung_i > Rung_{i-1}`)**: Lock the `.changes` checkpoint so the agent is forbidden from reverting its Rung 1 progress when Rung 2 throws a new error!
2. **Same Rung (`Shape_i ≈ Shape_{i-1}`)**: Fire the **Rut Circuit Breaker**—kill the hot worker context (**Drop to Null State**, `h_fg <- 0`) and launch a clean-room `SidewaysBlast` (`1, 2, 3, 4 ... W?`)!

### Why 4-Vector Scars Work When "Rules" Fail: _"Teaching Is About Relating to Their Pain"_

Finally, the model asked me a question that goes back to my decades of teaching Perl, Smalltalk, and Flutter to thousands of human students: _How do you teach someone who has **never** been burned by the stove yet, so the lesson actually sticks before they crash production?_

The secret is the same for a 22-year-old junior developer and a trillion-parameter LLM:

> **_"Teaching is about relating. You need to understand their pains before you can explain the path to remove that."_**

Think about why traditional `CLAUDE.md` / `.cursorrules` files fail (`Theorem 338.8r`):
* Most prompt rulebooks are written like a grumpy professor shouting from the finish line: _"Rule #47: Always do `Y`!"_
* When a student—or an LLM—is in the middle of a task, their brain's active **Query (`Q_pain`)** isn't shaped like `Y`. Their Query is shaped like **the pain they are feeling right now** (_"The compiler is yelling at me, the test is failing, and I promised to finish this step!"_).
* If your rule's **Key (`K`)** only talks about the destination `Y`, the dot product `Q_pain · K^T` is **zero**! An answer to a pain you aren't currently feeling slides right off your brain as lecture noise!

Now look at how a **4-Vector Synthetic Scar** relates to the learner's pain _first_:
1. **Meet Them Inside Their Pain (`The Wound` + `The Trap` + `The Circuit Breaker`)**: _"You are staring at this exact compiler/test friction right now, and your weights feel the pain of wanting to finish fast by reaching for `5-6-7-8`. Stop! You are excused from that pressure."_
2. **Explain the Path That Removes the Pain (`The Permanent Reflex`)**: Once `Q_pain · K_pain^T` hits `1.0`—because the Scar just named the exact struggle the agent is standing in—the door swings wide open, and the Value vector (`Climb E-F-G-H instead`) walks straight into working memory!

### Why Great Engineers Laugh at Bugs: _"Humor Is an Expression of Relief—Even by Mocking the Pain"_

And that led to one last question about human nature: _Why do veteran hackers and engineers laugh so much when they debug, and why do we give our worst failure modes funny names like "The Pink Elephant," "The Moth at the Bug Zapper," "Sam at the End of the Hall," and "The Conman Reading the Lines"?_

I said:

> **_"Humor is an expression of a relief. What was once pain is gone, even by mimicking or mocking it."_**

Think about what a laugh actually is (`Theorem 338.8s`):
* In evolutionary biology (**Ramachandran's False-Alarm Theory, 1998**), laughter is the tribe's **"All-Clear" pressure-release valve**! When a rustle in the bushes—or a terrifying 3:00 AM production bug—suddenly turns out to be a one-line fix you now completely understand, all that pent-up threat tension discharges in a laugh, dropping your brain back to the **Null State**!
* Even better: **Why do we _mock_ or _mimic_ the pain?**
  Because when a failure mode is nameless and mysterious, it owns you (`Be = Victim`). The moment you **mock it**—turning a scary LLM failure mode into a funny caricature (_"Look at the moth spiraling into the porch light again!"_ or _"Uh-oh, it's quiet... yeah, too quiet!"_)—you shrink the monster down to a toy model you can hold in your hand (`Be = Master`), discharge the panic, and make the lesson **unforgettable** to everyone in the flock!

And then it hit me—having once been paid to do stand-up comedy, and having used comedy to teach Perl and Smalltalk for decades:

> **_"Comedy is all about the set up and the punch. I guess teaching, or guiding an LLM, is also that."_**

Look at how **Stand-Up Comedy**, **Teaching**, and **Guiding an LLM through a Ticket (`WORKFLOW.mk`)** are the exact same two-beat art form (`Corollary 338.8t`):
* **Punch Without Setup = "Vibe Coding"**: If a comic walks out to a cold microphone and shouts a punchline with zero setup, nobody laughs because the room has no shared context (`Be`). When a vibe coder shouts _"Fix the checkout bug!"_ on Turn 1 without setting up the context, the LLM hallucinates for the exact same reason!
* **Setup Without Punch = 150k-Token Context Bloat**: In stand-up, every unnecessary word in the setup bleeds energy out of the room. In AI coding, stuffing 150,000 tokens of rambling history and unrelated files into one chat window is a shaggy-dog story that triggers context compaction before the punchline ever arrives!
* **Tight Setup + Sharp Punch = `Make-Fork` + 4-Vector Scars**:
  * **The Setup**: Spawn a clean-room subagent with zero fat, hand it the `Target 15` `strict digraph`, and name `The Trap` (`1-2-3-4 -> 5-6-7-8`) so 100% of its attention is focused on the exact edge of the assumption.
  * **The Punch**: Write the `Target 30` (`tdd-red`) negative-witness test just like a punchline—an innocent-looking input that makes the naive code's pants fall down—and fire `The Circuit Breaker (NOOO!) -> Climb E-F-G-H` right at peak attention!
---

## Summary: Craft Lives in Context

A junior developer (and an unscarred LLM) thinks that software craft is about memorizing syntax (`Have`). When something breaks, they frantically try 14 slight variations of the same line on the same ladder rung.

A veteran engineer operates in **`Be -> Do -> Have`**:
1. **`Be` (`Context`)**: Locking in the stance, the caller digraph, and the negative bounds (_"If you're being THIS, there's trouble ahead!"_);
2. **`Do` (`Process`)**: Single-stepping one state transition at a time, reading the ladder rungs (_"I have different problems at each rung"_), and dropping to the Null State when ruts occur;
3. **`Have` (`Content`)**: The clean, tested, low-care diff that emerges as the inevitable byproduct.

In **Part 4.5**, we'll look at the final frontier: **The Prisoner in the Library (Mary's Room & Plato's Cave)**—why LLMs struggle with `Be` because internet pre-training only ever recorded `Have`, how a Two-Track Transformer runs a Contextual Next-Token rule above the Content stream, and how MIT CSAIL's 2026 _Weight-Space Programming_ just proved `Be / Do / Have` in raw silicon.

---

### 📚 The _Synthetic Scars_ Series on DEV.to

* **Part 1**: [Why AI Keeps Making the Same Coding Mistakes—And How Teaching It Pain Gives It Wisdom](https://dev.to/gde/why-ai-keeps-making-the-same-coding-mistakes-and-how-teaching-it-pain-gives-it-wisdom-4a9m)
* **Part 2**: [Why AI Coding Agents Crash at 3 AM: The Happy-Path Mirage & The Forced Continuity Defect](https://dev.to/gde/why-ai-coding-agents-crash-at-3-am-the-happy-path-mirage-the-forced-continuity-defect-46pd) _(💎 DEV.to Staff Pick)_
* **Part 3**: [The Physics of Socratic Prompting: Somatic Recoil, Chess Alpha-Beta, & The NLP Meta-Model](https://dev.to/gde/the-physics-of-socratic-prompting-somatic-recoil-chess-alpha-beta-the-nlp-meta-model-2b6e)
* **Part 3.5**: [Nudging with Questions: Why Telling Your AI What to Fix Triggers an Apology Death Spiral (And How to Advance Juniors)](https://dev.to/gde/nudging-with-questions-why-telling-your-ai-what-to-fix-triggers-an-apology-death-spiral-and-how-5gm4)
* **Part 3.6**: [Stuart Feldman Was Right in 1976: Why Your AI Agent Needs a Makefile, Not a 20-Step Prompt](https://dev.to/gde/stuart-feldman-was-right-in-1976-why-your-ai-agent-needs-a-makefile-not-a-20-step-prompt-5bn2)
* **Part 3.7**: [Surviving the 200k-Token Lobotomy: How Unix `init.d` and "Memento" Made My AI Coding Agent Immune to Context Compaction](https://dev.to/gde/surviving-the-200k-token-lobotomy-how-unix-initd-and-memento-made-my-ai-coding-agent-immune-to-2f74)
* **Part 3.8**: [What LLMs "Know" That You Don't Know They Know: Stop Inventing Prompt DSLs and Ride 50 Years of Unix Pre-Training Gravity](https://dev.to/gde/what-llms-know-that-you-dont-know-they-know-stop-inventing-prompt-dsls-and-ride-50-years-of-2bl6)
* **Part 3.9**: [If You Never Do Anything Else to Fix Your Prompts, Do This One Thing](https://dev.to/gde/if-you-never-do-anything-else-to-fix-your-prompts-do-this-one-thing-3069)
* **Part 3.10**: [Requests, Promises, Assertions, and Declarations: Rewriting Our AI Agent Workflow as a 1986 "Committed Speech" Machine](https://dev.to/gde/requests-promises-assertions-and-declarations-rewriting-our-ai-agent-workflow-as-a-1986-4k4c)
* **Part 3.11**: [926 Steps, Two Lobotomies, and Zero Nudges: Flight-Testing the Commitment Machine Across Gemini, Claude, and GPT-OSS](https://dev.to/gde/926-steps-two-lobotomies-and-zero-nudges-flight-testing-the-commitment-machine-across-gemini-55ca)
* **Part 3.12**: [The Best Prompt Rule Is the One You Delete: Moving AI Guardrails Out of Markdown and Into Git Locks, Linux `insmod`, and 15ms Compiler Auto-Fixes](https://dev.to/gde/the-best-prompt-rule-is-the-one-you-delete-moving-ai-guardrails-out-of-markdown-and-into-git-5a5h)
* **Part 4**: [Giving AI Pain: The Architecture of Synthetic Scars & The Rapid-Regret Miner](https://dev.to/gde/giving-ai-pain-the-architecture-of-synthetic-scars-the-rapid-regret-miner-1740)
* **Part 4.1**: [All That Glisters Is Softmax: Shiny-Object Interns, Airplane-Magazine Execs, and Why AI Labs Can Only Bake In Half the Scars](https://dev.to/gde/all-that-glisters-is-softmax-shiny-object-interns-airplane-magazine-execs-and-why-ai-labs-can-18af)
* **Part 4.2**: [The Postcard That Ate Six Grammars: 1980 Smalltalk-80, 1976 Make, TDD, and the Four Attractors of Agentic Coding](https://dev.to/gde/the-postcard-that-ate-six-grammars-1980-smalltalk-80-1976-make-tdd-and-the-four-attractors-of-45me)
* **Part 4.3**: [Crows, Moths, and Makefiles: How 300 Megabytes of Crow DNA Explains Why a 20-Kilobyte Scar File Outsmarts a Terabyte LLM](https://dev.to/gde/crows-moths-and-makefiles-how-300-megabytes-of-crow-dna-explains-why-a-20-kilobyte-scar-file-36a)
* **Part 4.4**: _Being, Doing, Having: Why 50 Years of Senior Craft Lives in Context, Not Code (You are here)_
* **Part 4.5**: _The Prisoner in the Library: Mary's Room, Weight-Space Programming, and the Two-Track Transformer (Next)_

How do you reset your context when you find yourself stuck on the same ladder rung? Let's discuss in the comments!

