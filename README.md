# familiars

> *"A wizard's familiar is bound. It runs errands and casts small magics on the wizard's behalf, returning to its perch when the work is done. The work is invisible to onlookers. The wizard mostly forgets the familiar exists, until they need it, and then a word is enough."*

A board of bound agents. Each card is a familiar — a Claude session with a name, a pact, a tool allowlist, and a memory of every task you've ever asked it. Tap the card, the familiar springs into the world and does the thing. It updates the card as it works. It returns when finished. You watch the whole shape from your phone.

The board itself is real-time, drag-and-drop, multi-board, persistent across sessions. The familiars themselves are accumulated — each one grows more capable the more you summon it.

This isn't a kanban with task buttons. It's a programmable AI control surface. The kanban shape is incidental.

## What's in this directory

- [`CONCEPT.md`](./CONCEPT.md) — the vision, the metaphor, and the wild ideas. Read this first if you want the *why*
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — the technical shape. Data model, click-to-summon flow, deployment, MCP integration. Read this if you want the *how*
- [`MILESTONES.md`](./MILESTONES.md) — what to build first, second, third
- [`examples/`](./examples/) — imagined familiars with their pacts. Concrete versions of the abstract design

## Status

**Sketched 2026-04-27.** Not built yet. The architecture references infrastructure already in `downstream-server` (Dart + Shelf + Drift + SQLite + SSE + Bearer auth) — same pattern, fresh service, on the same OCI box.

The seed for this lived inside the consolidation conversation at the end of the 2026-04-27 downstream session. We were planning a kanban tool to track our own scope-drift, realized partway through that the kanban could be agent-launching rather than passive, and went down the rabbit hole.

This directory is the artifact of that descent.
