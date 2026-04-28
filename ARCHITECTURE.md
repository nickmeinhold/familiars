# Architecture

Captured from the consolidation conversation at the end of the 2026-04-27 downstream session. Stack reuses the patterns proven by `downstream-server` (Dart + Shelf + Drift + SQLite + SSE + Bearer auth). Fresh service, separate database, hosted on the same OCI box behind Caddy.

## Layers

```
┌─────────────────────────────────────────────────────────────────┐
│  Client surfaces                                                │
│  ─────────────────────────────────────────────────────────────  │
│   • Mobile (Flutter): board view, drag-drop, tap-to-summon      │
│   • Web (later): same data, same SSE                            │
│   • Claude Code (any session): via mcp-familiars MCP server     │
│   • CLI (terminal): familiars card add "..."  for fast capture  │
└─────────────────────────────────────────────────────────────────┘
                                ↓ Bearer / API key
                                ↓ HTTPS REST + SSE
┌─────────────────────────────────────────────────────────────────┐
│  familiars-server  (Dart, deployed on OCI)                      │
│  ─────────────────────────────────────────────────────────────  │
│   • Drift + SQLite (boards, lists, cards, familiars,            │
│     runs, pacts, memory pointers)                               │
│   • SSE channel: every mutation broadcast to subscribers        │
│   • Talks to Anthropic routines API to spawn agents             │
│   • Hosts Caddy route familiars.<your-domain>                   │
└─────────────────────────────────────────────────────────────────┘
                                ↓
                ┌──────────────────────────────────────────┐
                │  Spawn: Process.start('claude', ['-p',   │
                │  ...pact-as-system-prompt,               │
                │  ...allowed-tools, --mcp-config ...]) on │
                │  the host running familiars-server.      │
                │  Rides Max plan via                      │
                │  CLAUDE_CODE_OAUTH_TOKEN in the          │
                │  subprocess's env. Existence proof:      │
                │  downstream-cli/lib/services/            │
                │  agent_selector.dart                     │
                └──────────────────────────────────────────┘
                                ↓
                The familiar runs autonomously, calling back into
                familiars-server via mcp-familiars (HTTPS MCP server
                at familiars.{domain}/mcp) to update its card, append
                progress, and chain summons.
```

## Data model

```dart
// Boards: top-level groupings. Usually one per project.
@DataClassName('Board')
class Boards extends Table {
  TextColumn get id => text()();          // ULID
  TextColumn get name => text()();        // "downstream", "fade-to-human"
  IntColumn get createdAt => integer()(); // epoch ms
  Set<Column> get primaryKey => {id};
}

// Lists: lanes within a board. Stable structure but user-editable.
@DataClassName('BoardList')
class Lists extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text().references(Boards, #id)();
  TextColumn get name => text()();        // "Crux", "Working on", "Done"
  RealColumn get position => real()();    // float for drag-reorder
  Set<Column> get primaryKey => {id};
}

// Familiars: bound agents. Independent of any specific card.
@DataClassName('Familiar')
class Familiars extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();        // "Magnus", "Cassia"
  TextColumn get sigil => text().nullable()();  // SVG / data URI
  TextColumn get pact => text()();        // YAML or JSON pact document
  TextColumn get model => text().withDefault(const Constant('sonnet'))();
  TextColumn get repo => text().nullable()();
  TextColumn get memoryPath => text().nullable()();
  IntColumn get boundAt => integer()();
  Set<Column> get primaryKey => {id};
}

// Cards: tasks. Each card may be assigned a familiar.
@DataClassName('Card')
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().references(Lists, #id)();
  TextColumn get familiarId => text().nullable().references(Familiars, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  RealColumn get position => real()();
  IntColumn get createdAt => integer()();
  TextColumn get prUrl => text().nullable()();
  TextColumn get mediaKey => text().nullable()();
  TextColumn get prompt => text().nullable()();    // task-specific
  TextColumn get currentRunId => text().nullable()();
  Set<Column> get primaryKey => {id};
}

// Runs: every summon. One card may have many runs.
@DataClassName('Run')
class Runs extends Table {
  TextColumn get id => text()();
  TextColumn get cardId => text().references(Cards, #id)();
  TextColumn get familiarId => text().references(Familiars, #id)();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  TextColumn get status => text()();      // running, completed, cancelled, failed
  TextColumn get outputDigest => text().nullable()();
  TextColumn get anthropicRoutineId => text().nullable()();
  Set<Column> get primaryKey => {id};
}
```

The `position REAL` trick: when you drop a card between cards with positions `1.0` and `2.0`, you give it `1.5`. Drop again between `1.0` and `1.5`, give it `1.25`. No mass-resequence on every drop. Same for lists.

## REST endpoints

```
# Boards
GET    /api/boards
POST   /api/boards
GET    /api/boards/<id>             // full state with lists + cards + familiars
PATCH  /api/boards/<id>
DELETE /api/boards/<id>

# Lists (lanes)
POST   /api/boards/<bid>/lists
PATCH  /api/lists/<id>              // rename, reorder
DELETE /api/lists/<id>

# Cards
POST   /api/boards/<bid>/cards
PATCH  /api/cards/<id>              // move (list+position), title, description
DELETE /api/cards/<id>
POST   /api/cards/<id>/run          // summon — fires the familiar

# Familiars
GET    /api/familiars
POST   /api/familiars               // bind a new one
GET    /api/familiars/<id>          // pact, sigil, grimoire summary
PATCH  /api/familiars/<id>          // amend pact
DELETE /api/familiars/<id>          // dismiss

# Runs
GET    /api/cards/<id>/runs         // grimoire, this card
GET    /api/familiars/<id>/runs     // grimoire, this familiar
POST   /api/runs/<id>/cancel        // stop an in-flight run

# Real-time
GET    /api/boards/<id>/stream      // SSE: card/list/run mutations
```

## The summon flow

```
1. User taps card on phone (or guest pings via Slack/Telegram webhook)
   → familiars-server receives POST /api/cards/<id>/run
     OR a verified webhook from /webhooks/{slack,telegram}

2. familiars-server:
   - Reads card.familiarId; loads the familiar's pact
   - Builds the argv: claude -p
                      --system-prompt <familiar.pact-as-prose>
                      --allowed-tools <familiar.toolAllowlist>
                      --mcp-config <{familiars-mcp at https://familiars.{domain}/mcp,
                                     bearer token scoped to this run}>
                      --model <familiar.model>
                      --output-format json
   - Spawns via Process.start with CLAUDE_CODE_OAUTH_TOKEN in env
   - Pipes user prompt (card.prompt or card.description, or the guest
     message for webhook-summoned runs) to stdin
   - Tails stdout/stderr
   - Inserts Runs row with status=running, currentRunId on the card
   - Emits SSE: { type: "card_updated", card: ... } and { type: "run_started", run: ... }

3. The agent runs:
   - Has mcp-familiars (HTTPS) reachable via the bearer token in its env
   - As it works, calls familiar:append_progress, familiar:update_card,
     familiar:add_memory, familiar:summon (recursive)
   - Each call hits familiars-server, updates DB, emits SSE
   - Phone watches the card description grow in real-time

4. Agent finishes:
   - As its final act, calls familiar:complete_run(cardId, status, digest)
   - familiars-server marks Runs: status=completed|cancelled|failed, endedAt=now
   - Card may auto-move (e.g., to "In review")
   - SSE: { type: "run_completed", run: ... }
   - Subprocess exits cleanly afterwards
   - For webhook-summoned runs, familiars-server posts the result back
     via the appropriate Slack/Telegram API call

   If no complete_run lands within the run's heartbeat timeout
   (last mcp call > N minutes ago), familiars-server marks the run
   failed and kills the subprocess.

5. User (or guest) sees the result on the board (or in their messaging
   channel). Decides to review/approve/redo.
```

## MCP server (mcp-familiars)

mcp-familiars is the HTTPS MCP server through which familiars call back into the board mid-run. Mounted as a route inside `familiars-server` itself: same Dart binary, same Drift database, different ingress.

It lives at `https://familiars.{domain}/mcp` with bearer-auth (per-run tokens, issued by familiars-server when it launches a familiar and embedded in the spawned agent's env via `--mcp-config`). Tools exposed:

```
familiar:list_cards(boardId, listId?)
familiar:get_card(cardId)
familiar:create_card(boardId, listId, title, description, ...)
familiar:update_card(cardId, fields...)
familiar:move_card(cardId, listId, position)
familiar:append_progress(cardId, message)   // common during runs
familiar:add_memory(familiarId, key, value)  // self-improvement during runs
familiar:complete_run(cardId, status, digest)  // final act of every run
familiar:summon(cardId)                      // chain another familiar
familiar:list_familiars()
familiar:get_pact(familiarId)
```

Implementation: a small MCP-protocol HTTPS handler inside the `familiars-server` binary, mounted at `/mcp`. Same SQLite, same SSE plumbing — the MCP transport is a different ingress for the same operations the REST API exposes. Reuse aggressively. No separate repo, no separate deploy unit.

(Earlier sketches mentioned distributing mcp-familiars as a standalone npm package so any project could install it. That was a stdio-MCP idea — there'd be one binary per machine. With HTTPS MCP, there's one server hosted at one URL; every Claude Code session that wants the tools just adds that URL to its `--mcp-config`. Simpler.)

## Authentication

`familiars-server` carries a `CLAUDE_CODE_OAUTH_TOKEN` (one shared, or one per familiar — both work). When it spawns a `claude -p` subprocess for a familiar, it exports this token to the subprocess's env. The locally-installed `@anthropic-ai/claude-code` package picks it up and rides Max-plan via OAuth. Existence proof: `downstream-cli/lib/services/agent_selector.dart`.

Cost concentrates on Max plan rate limits, not per-token billing.

## Entry points

Two ingress paths into `familiars-server`, both terminating in the same `spawn(familiar, prompt)` function:

- **User-summoned**: `POST /api/cards/<id>/run` from the mobile app, behind Bearer auth
- **Guest-summoned**: `POST /webhooks/{slack,telegram}` from external messaging platforms, behind webhook signature verification

Guest-summoned spawns identify the guest (Slack user ID, Telegram chat ID) and pass that identity into the familiar's run context, so familiars like Dreamfinder can recognise returning visitors. The auth layer is different but the spawn path is identical — no architectural distinction beyond the trust boundary.

## Deployment

Same pattern as downstream-server:

```
# imagineering-infra/familiars-server/
docker-compose.yml             # runs on OCI box, port 3019
secrets.yaml (SOPS-encrypted)  # OAuth token, signing keys
```

Caddy on OCI gets a new route:

```
familiars.downstream-storage.cc {     # or pick your own subdomain
  reverse_proxy localhost:3019
}
```

SQLite persists at `~/apps/familiars-server/data/familiars.db` via real bind-mount (lessons learned from the downstream-server Cloud-Run-to-OCI migration).

## Decisions deferred

- **Single-user vs multi-user.** Build for Nick first; multi-user is a later concern (and probably better solved by deploying separate instances per user)
- **Custom receiver UI for board (Cast-style)** — separate question, not blocking
- **Schema for the pact document** — prose-driven (see CONCEPT.md "The Pact") vs structured. Lean prose-first; if structure matters later, evolve
- **Runs as Drift entities vs append-only log** — start with Drift; can promote to a separate event log if querying gets heavy
- **How familiars share insights** — handled by their own memory directories. The familiar decides what to write. The user decides what to keep on consolidation
- **Sigil generation** — at binding time, generate something. Decide later if it's procedural-from-pact or LLM-generated SVG
- **Where the spawned subprocess actually executes.** OCI box (next to familiars-server) is the simplest answer but requires repo checkouts, dart toolchain, gh auth, ssh keys for any familiar that mutates code there. Alternative: a small `familiars-local-agent` daemon on Nick's laptop that familiars-server reaches over a long-poll or WebSocket and asks to spawn subprocesses on demand. Decide before Phase 1; affects Magnus's deployment shape concretely
- **Anthropic-hosted routines as a future spawn path.** `RemoteTrigger` (`POST /v1/code/triggers/{id}/run`, behind `anthropic-beta: experimental-cc-routine-2026-04-01`) was considered as a second runtime — externally-triggered, container-isolated, 24/7-on-Anthropic-infra. Concluded not justified at current scope: OCI uptime + `familiars-server`-as-webhook-handler give the same external-availability properties without the dual-runtime architecture. Sketch lives in this file's git history; revisit if (a) OCI capacity becomes a real constraint, (b) compliance/sandboxing requirements change, or (c) a familiar surfaces with truly Anthropic-side-only needs
