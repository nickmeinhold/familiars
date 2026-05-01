# Milestones

Loose phasing. Don't treat as a contract — when the conversation evolves, so does this.

## Phase 0: Bones (no agents yet, just the board)

Get the kanban-shaped CRUD running with real-time updates. No familiar logic, no MCP server, no agent spawning. Just: I can drag cards on my phone and they persist.

- familiars-server scaffolded, deploys to OCI alongside downstream-server
- Drift schema for boards / lists / cards (no familiars or runs tables yet)
- REST endpoints for CRUD + reorder
- SSE channel emits card/list mutations
- Mobile screen: list-of-lists, draggable cards, real-time
- Bearer auth (same Firebase project as downstream)
- The Bell: tap-to-capture UI gesture that drops a `[bell]` card into 💡 Ideas with no agent run; triage to a named familiar is a later, deliberate user action

**Why first:** validates the infra pattern translates cleanly. If anything's broken in the boilerplate, you find out before the agent layer compounds the bugs. Also gives you a working tool immediately — usable as a plain kanban while the rest is built.

**Out of scope here:** familiars, agent spawning, mcp-familiars, web UI, sigils, anything fictional. Just the board.

## Phase 1: First binding

Add familiars as entities. Add the summon mechanism. One familiar, one card, one tap, one summon fires.

- Drift tables: familiars, runs
- REST endpoints for familiar CRUD + cards/<id>/run
- mcp-familiars: HTTPS MCP server mounted at `/mcp` inside familiars-server. Minimum tools: `update_card`, `append_progress`, `complete_run`. Per-run bearer auth.
- Spawn integration: `Process.start('claude', ['-p', ...])` from familiars-server, with `CLAUDE_CODE_OAUTH_TOKEN` in env and `--mcp-config` pointing at the local mcp-familiars endpoint. Existence proof in `downstream-cli/lib/services/agent_selector.dart`.
- Mobile: card detail view shows assigned familiar; ▶ button on cards triggers summon
- The agent's run streams output back into the card description via mcp calls

**Bind one familiar to start: Magnus.** Pact: refactoring assistant for the downstream monorepo. Tools: Read, Edit, Bash (constrained), gh. Repo: ~/git/experiments/downstream.

**Open question, must resolve before Phase 1 codes:** where Magnus's subprocess actually executes. OCI box (requires the downstream repo + dart toolchain + ssh keys provisioned there) vs Nick's laptop via a local `familiars-local-agent` daemon (requires that daemon, but no OCI-side code-host setup). See ARCHITECTURE.md "Decisions deferred" — this is the load-bearing one for Magnus.

**The proof point:** create a card "Verify the agentic torrent selector picks something on the Pi", assign Magnus, tap. He SSHes to the Pi, tails logs, triggers a request, watches the agent log line, writes the result back to the card via `familiar:update_card`. The crux of the previous downstream session, executed by tap.

## Phase 2: The bestiary

More familiars. Patterns for binding emerge. Memory accumulation matters.

- Per-familiar memory directories under `~/.familiars/<name>/`
- Familiars can call `familiar:add_memory` during runs
- Bind: Cassia (research), Sieve (triage / health checks), Brick (ops / deploy)
- Bestiary view in mobile: faces of all familiars, recent activity, summon counts
- Sigil generation (start cheap: deterministic glyph from pact text hash)

**Tests the metaphor.** Does specialization actually feel different? Does Magnus get sharper over weeks? Does Cassia start pre-empting your requests because she's seen the patterns?

## Phase 3: Composability

Familiars summon familiars. Council mode.

- mcp-familiars: `familiar:summon` for chaining
- Council: tap "Council" on a card → multi-familiar parallel summon, results side-by-side
- Run history view per familiar: searchable grimoire

**Where it gets weird (in the good way).** This is when the system stops being "I tap, agent runs" and starts being "agents collaborating, I observe."

## Phase 4: Rituals & rest

Recurring summons. Budgets. Familiar moods.

- Cron-driven summons via Anthropic routine scheduling (already supported)
- Per-familiar daily/weekly token budgets; UI grays the card when exceeded
- Sleeping-familiars-dream pattern: nightly memory consolidation per familiar
- Pact amendment proposals: every N runs, familiar suggests pact updates based on its corrections

**This is where the long-term value compounds.** Familiars that improve themselves in their sleep, ritualistic cadences for the work that should never depend on you remembering.

## Phase 5: Branded receiver-style polish

If/when you want to push beyond functional:

- Custom sigil rendering (LLM-generated SVGs, animated?)
- Web client mirroring mobile
- Familiar-to-familiar messaging UI
- Shared familiars across users (the speculative bit from CONCEPT.md)
- Custom Cast receiver for displaying the board on a TV (because of course)

**No rush.** Phases 0–2 are the load-bearing arc. Everything beyond is texture.

## What this directory becomes once Phase 0 starts

This directory is currently a sketch. When we begin building, we either:

1. Fill it with code in place — the `familiars` directory in `~/git/experiments` becomes the actual project root
2. Move the docs into a fresh repo — `git init` here, treat this as the start of a real project

Lean toward (1) — keep the sketch documents alongside the code for context. Future-you reading the codebase wants to see the why.
