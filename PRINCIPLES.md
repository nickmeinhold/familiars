# Design principles

The constraints that should hold across every design decision in this project. If a feature violates one of these, it's probably wrong, even if it's locally appealing.

## 1. Continuity over freshness

Every familiar accumulates. A familiar's value compounds with use. Resist any pattern that treats familiars as ephemeral. If you find yourself designing "stateless mode," ask whether you actually want a one-off skill instead — those exist already.

The wizard's familiar in folklore is *the same creature*, summoned again and again, slightly wiser each time. Build for that.

## 2. The metaphor isn't decoration

Names matter. "Pact," "grimoire," "sigil," "ritual," "summons" — these aren't UI flourishes. They shape how the user thinks. If the project's vocabulary drifts toward "config," "log," "icon," "schedule," "trigger," then the metaphor weakens, and the *behavioral* benefits of the metaphor (taking pacts seriously, respecting budgets, valuing accumulation) weaken with it.

When in doubt, use the magical-fictional word. The technical word is always there to escape to if the fiction breaks down for a specific user.

## 3. The board is the program

The kanban shape is not a passive visualization. Cards aren't reflections of work happening elsewhere; cards are *where work happens*. Reorderings, attribute changes, tap-to-summon — these are program operations.

Implication: the API should be designed for direct user interaction, not "view of remote process." A card moved to "Done" by a drag is a real state change, not a reporting update.

## 4. Friction-free capture, deliberate triage

Adding a card to 💡 Ideas should take less effort than the cost of remembering the idea otherwise. One tap, one sentence, done. *Triage* — promoting an idea to a real card, or dropping it — is a separate, deliberate moment. Don't conflate the two.

This is the load-bearing UX claim: if capture is friction-free, the brain releases the idea and the reactive-pivot pattern dissolves.

## 5. Visible specialization

A user looking at the bestiary should be able to tell, at a glance, what each familiar is good at. From sigil, from name, from recent activity, from memory excerpts. *Specialization* is what makes the system feel like a team rather than a tool.

Resist any feature that "smooths over" specialization. Don't auto-route everything to a generalist. The Bell is a *capture* surface, not a router — it drops a `[bell]` card into 💡 Ideas; assignment-by-name during triage is always explicit.

## 6. Agents are bound, not borrowed

Each familiar is bound to one user (initially). The pact is personal. The memory is private. Sharing across users is an explicit, signed, audit-able operation — not a default mode.

This matters because it makes the user feel ownership over the agent's accumulated competence. *Magnus is mine.* That ownership is what motivates investment in pact refinement and memory curation.

## 7. The wizard respects the familiar's limits

Budgets aren't grim cost-control infrastructure. They're an expression of the same philosophy that drives everything else here: agents that improve over time deserve protection from being ground into the dirt.

Practically: hard budget caps. When a familiar hits its cap, the card grays out. Override is possible but explicit. Don't let runaway loops or "just one more retry" patterns burn through quotas invisibly.

## 8. Every run is a memory candidate

A familiar finishes a task. Before the run closes, the familiar can propose: "I learned X. Should I save this?" The user accepts or refuses. Saved memories are persistent and influence future runs.

This is the slow-loop equivalent of the fast-loop pact-amendments. Both compound.

## 9. Composability via summons, not workflows

If you find yourself designing a workflow engine — DAGs, conditional branches, pipelines — stop. The composability mechanism is "a familiar can summon another familiar." That's it. Magnus needs ops help → summons Brick. Cassia wants a refactor of her grimoire → summons Magnus.

Workflows emerge from this. Don't pre-bake them.

## 10. Surprise is the write signal

(Borrowed wholesale from the consolidation skill, but applies here too.) When a familiar runs, the *interesting* output is the part that surprised either the familiar or the user. Routine completions can be summarized into the run digest and forgotten. Surprises should be flagged for memory candidacy.

This applies in reverse too: the board UI should highlight surprising mutations. A familiar moving a card to "In review" with a long description that contains a surprising finding — that should pull the user's eye. A familiar moving a card to "Done" with no comment should be invisible.

---

These principles aren't deliverables. They're the rubric. When a PR feels off, check it against these. When a feature is appealing but you can't say why, check it against these. When you're tempted to bolt on something fashionable, check it against these.

If the project ever stops feeling magical, one of these was violated.
