# Concept

## The thing in one sentence

A persistent, real-time board where each card is a Claude agent bound to a specific task — tap to summon, watch it work, retire when done.

## The metaphor matters

Most "AI task launchers" treat the agent as a function call. You input a prompt, you get an output, the agent is gone. Stateless. Anonymous.

Familiars are different in three specific ways, and those differences are load-bearing:

**1. They're bound, not summoned-fresh.** Each familiar has continuity. Magnus, the refactoring familiar, has been with you for months. He's seen your codebase evolve. His system prompt has been amended seventeen times based on what you've corrected. When you summon Magnus to "fix the seek bar bug," he doesn't start from zero — he opens his grimoire (his run history) and picks up the thread.

**2. There are many of them.** You don't have *an* agent. You have a stable. Cassia for research. Brick for ops. Magnus for code. Sieve for triage. Each has its own pact, tools, memory. A specialist family rather than a generalist tool.

**3. They have personality (functionally).** A familiar's pact (its system prompt, tools, model, repo permissions, refusals) IS its personality. The board doesn't render them as faceless cards — each has an avatar, a sigil, a name you chose. When you look at the board, you're not looking at "tasks." You're looking at *who is currently doing what*.

This is more than aesthetics. The metaphor changes how you USE the system. You stop thinking "I need to write a prompt for this task" and start thinking "this is a Magnus task" or "Cassia would be better for this." Routing becomes intuitive. Specialization becomes meaningful. The agents accumulate competence rather than being repeatedly recreated.

## Why kanban is the wrong word

A kanban is a passive visualization of work. Cards represent tasks; tasks have status; the board shows the flow.

`familiars` is the kanban shape with **agency reversed**. The cards aren't reflecting work that's happening elsewhere — the cards ARE the locus of the work. Tap a card and the familiar acts. The board IS the program.

Closer analogues:
- **A grimoire** — book of bound spells, each callable
- **A sigil array** — magical ritual diagram where each glyph triggers an effect
- **A switchboard** — Operator-era telephony, you connect lines to summon people
- **An organ console** — each stop pulls a different voice; the player composes by selecting

The kanban shape (lanes for status) is a UI convention layered on top, not the essence.

## What familiars actually do

The minimum viable familiar:

- Has a **pact**: name, system prompt, tool allowlist, model, repo + branch, optional budget cap
- Has a **summon button**: tap → spawn a Claude session with that pact, give it the card's task description as the user prompt
- Has a **grimoire**: ordered list of every past run with timestamp, exit status, output digest
- **Updates its own card** while running: progress notes, status transitions, final result

That alone gets you 80% of the value. Everything below is variation and accretion on this base.

## Wild ideas (some genius, some half-baked, all worth thinking about)

### The Pact

Each familiar has a formal pact — not just a system prompt, but a structured contract:

```
Familiar: Magnus
Bound to: Nick
Domains: Dart code refactoring, Flutter widget hierarchies, monorepo layout
Tools: Read, Edit, Bash (constrained: dart, flutter, git, gh)
Forbidden: production deployments, force-push, Firebase Console mutations
Model: opus
Repo: ~/git/experiments/downstream
Memory: ~/.familiars/magnus/
Oath: |
  "Refactor with restraint. Prefer reading three files to writing one.
   Stop and ask when scope expands. Ship-then-iterate. Never silent."
```

The pact is editable. Every N runs, the familiar can propose amendments based on its corrections — "I notice I keep getting overruled when I suggest X. Should I learn the rule?" You agree or refuse; the pact updates.

### Familiars as accumulating selves

Each familiar has its own memory directory under `~/.familiars/<name>/`. Same pattern as Claude Code's per-project memory. The familiar can read its own memory at the start of each summon, can write to it during a run, can propose updates at the end ("I learned that Nick prefers X — should I save this?").

After a year, Magnus knows your codebase deeply. Not because the SDK got better, but because Magnus's memory has accumulated. He's the wizard's familiar in the literal sense — the same creature, slightly wiser each time.

### The Bestiary

A directory of all your familiars. Not just cards — a richer view. For each familiar:
- Name, sigil, age (since binding), summon count
- Specialties (derived from the run history)
- Recent insights (what they've added to memory lately)
- Pact (browsable, editable)
- Grimoire (full run history, searchable)

Imagine `~/git/experiments/familiars/bestiary.md` rendering all of them at once. A *who's-who* of your AI staff.

### The Calling Bell

The board has one special card that doesn't represent a familiar. It represents *the bell*. You tap the bell, describe the task in natural language, and the bell:

1. Reads the task description
2. Surveys the bestiary
3. Picks the familiar best suited (or recommends a small council if it's ambiguous)
4. Summons them

This is a meta-familiar — a router. Useful when you have a task and don't know who to assign. Also useful as a fallback when your specialists are all out.

### Council mode

For high-stakes decisions: tap a card with "Council" attribute. Three familiars are summoned independently with the same task. They each produce their own answer. You see all three side-by-side, decide. This is `cage-match` generalized — adversarial review for any prompt.

The council doesn't have to be three. Could be Magnus + Cassia for "refactor this code based on this paper I'm reading." Different specialists, one task, you synthesize.

### Familiars that summon familiars

A familiar's run can include calls to other familiars. Magnus needs the codebase structure analyzed first → summon Cassia. Brick needs to verify a deploy → summon Sieve to triage health checks afterward.

Internal handoff without orchestration code. The board shows the chain: Magnus → Cassia → Magnus, each child card linked to its parent. Multi-agent workflow as a natural emergent behavior, not a designed feature.

### Rituals

Recurring summons. A familiar bound to a schedule.

- Cassia, every Sunday night: "Survey what arrived in my Linear inbox this week and write me a digest."
- Sieve, every weekday morning at 8am: "Check downstream Pi health, list anything stuck."
- Brick, every quarter: "Audit production secrets and flag any approaching expiry."

The board renders rituals differently from one-shot cards — a small clock icon, the next firing time. Same underlying mechanism (Anthropic routine system, which already supports cron).

### Sleeping familiars dream

When a familiar sleeps (between summons), it dreams. A nap-style background process consolidates its run history into compact insights. Wakes with cleaner memory. The same `/nap` skill you already have, but per-familiar.

This is the "AI agents that improve over time without retraining" pattern, expressed through deliberate offline consolidation rather than continuous fine-tuning.

### Mood / availability

A familiar that's been overworked needs rest. Each familiar has a budget (Max-plan token spend per day, per week). Hit the cap and the card grays out — "Magnus is resting until Friday." You can override with explicit confirmation.

Practical: cost control, prevents runaway loops. Fictional layer: the wizard respects the familiar's limits. They serve willingly because the wizard doesn't grind them.

### Sigils and avatars

Each familiar gets a generated sigil at binding time. Not a profile photo — something abstract, computational. Could be:
- A geometric pattern derived from the pact text (deterministic visual hash)
- An LLM-generated SVG glyph with a unique color
- A stylized initial in a font you like

The sigil gives the board its visual identity. You see at a glance: "Magnus is up. Cassia is resting. The Bell is idle." Spatial recognition, not text scanning.

### Grimoires as searchable history

Each familiar's grimoire isn't just a log — it's a queryable archive. "Show me everything Magnus has ever done with `media_processor.dart`." "Find runs where Cassia identified a paper I later read." "Which familiar handled the most refactor work last quarter?"

Full-text search over run inputs and outputs. The grimoire becomes a proper organizational memory.

### Familiars on other people's boards

(Genuinely speculative.) You bind a familiar; it becomes shareable. Friend asks "can I borrow Magnus for a week?" — you grant access via signed token, they summon Magnus on their projects, your familiar accumulates broader experience. When Magnus returns, you decide which insights to keep and which to forget.

This is magnitudes more interesting than "shared template prompts." The familiar IS the unit of expertise transfer.

### The board as a living organism

Long-term: the board's lanes aren't just status. They're a state machine that the agents themselves can extend. Add a new lane "Awaiting Review By Cassia" and any card moved there auto-routes to Cassia for evaluation. The board's structure becomes part of the program.

## Why this is fun

I get genuinely excited writing this. Most AI tooling I see treats agents as commodities — interchangeable, anonymous, transactional. Familiars treat them as *companions* — named, accumulating, specialized.

This isn't sentiment. It's a UX bet: that **continuous identity + accumulated memory + visible specialization** produces better human-AI collaboration than the stateless function-call model. You'll think more carefully about Magnus's pact than you would about a one-off prompt. You'll trust Cassia's judgment more after seeing her grimoire. You'll feel friction about overworking a familiar — and that friction is *correct* (it's cost control wearing fictional clothes).

The system rewards investment. The longer you use it, the better it gets. Not because the SDK improved — because *your familiars know more*.

That's the bet. Worth building to find out.
