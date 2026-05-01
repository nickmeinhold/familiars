# Example board state

What the `downstream` board might look like once familiars is up and running. Imagined snapshot, mid-day on a typical work session.

```
┌─────────────────────────────── DOWNSTREAM ────────────────────────────────┐
│                                                                            │
│  💡 Ideas                  🎯 Crux              🚧 Working on             │
│  ──────────────────────    ─────────────────    ──────────────────────    │
│                                                                            │
│  [bell] B2 manifest        [magnus] Verify      [magnus] Refactor         │
│  browser screen            agent picks on Pi    select_torrent            │
│  (raw idea — assign         (▶ idle)            (▶ running 4m)            │
│  someone or schedule)                                                      │
│                                                                            │
│  [bell] Trending /         [cassia] Find new    [cassia] Read this        │
│  new content surfaces      Friston work since   week's RAG papers         │
│  (raw idea)                last March            (▶ running 11m)          │
│                                                                            │
│  [bell] Custom Cast                                                        │
│  receiver branded UI                                                       │
│                                                                            │
│  [magnus] Lift             👀 In review         ✅ Done (today)           │
│  _DevicePickerSheet        ─────────────────    ──────────────────────    │
│  to widgets/                                                               │
│  (already done — drag      [sieve] Scan Pi      [magnus] PR #38 search   │
│  to ✅ when next pass)     for stuck downloads  screen (merged)            │
│                            from last week                                  │
│  [sieve] Verify            (waiting human eye)  [magnus] PR #39           │
│  manifest entries                                deprecate chromecast      │
│  for the 5 historic         [magnus] PR #37     (merged)                  │
│  Matrix breakages           cast UX awaiting    [cassia] Sunday weekly   │
│  haven't recurred           Nick's verify       digest (sent to phone)    │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

Familiars currently on the board:
  🟦 Magnus  — running. 47 minutes used today (of 240 budget). 2 cards.
  🟣 Cassia  — running. 23 minutes used today. 2 cards.
  🟢 Sieve   — idle. Last summoned 3 days ago. 1 card waiting in In review.
  ⚫ Brick   — resting. Hit weekly budget cap on Tuesday's deploy. 0 cards.
  🔔 The Bell — capture surface. 3 [bell] cards in Ideas awaiting triage.
```

## What the user sees over the course of a session

**08:30** — Wakes up, opens phone. Glances at board. Sieve's "Scan Pi for stuck downloads" card is in In review with a result: *"3 stuck on the audio-language step; auto-fix-able. Approve?"* User taps approve. Card moves to ✅ Done. Brick spawns to do the fix.

**09:15** — Sits at desk. Cassia's weekly digest is waiting on the board with three flagged-for-attention items. User reads the digest, decides one paper is worth a deep read. Drags that paper's mini-card from "queued" into Cassia's lane and taps ▶ for a thorough analysis. Cassia starts.

**11:00** — Realizes she wants to refactor the torrent selection scoring. Doesn't break flow — taps the Bell, says "refactor _selectBestTorrent to extract the size-penalty logic." A `[bell]` card lands in 💡 Ideas. No agent runs. She returns to her current crux. A minute later, at a natural pause, she drags the card onto Magnus's lane and taps ▶. Magnus picks it up and opens a branch.

**12:30** — Lunch. Magnus's run completed while she was eating. Card now sits in In review with a PR link. She glances, approves on phone, drags to ✅ Done. PR auto-merges.

**14:00** — New idea hits: "What if the cast receiver showed a custom-rendered ratings overlay?" Drops a card into 💡 Ideas. Doesn't act. Continues with current crux. The idea is captured; no anxiety, no derail.

**21:00** — End of day. Glances at the board. Several cards in 💡 Ideas accumulated through the day. Triages — promotes two to Backlog, drops the rest. Cassia's nightly ritual fires automatically. Magnus and Sieve sleep, dream over their day's work, wake with cleaner memory.

## What it looks like when something goes wrong

**Magnus times out mid-run.** The card in 🚧 turns red. Description shows: *"Attempted refactor; Dart analyze failed at 3 sites. Last 50 lines of stderr attached. Run cancelled at 14m."* User taps "retry with extended budget" or "reassign to Cassia" or just leaves the card and comes back to it.

**Cassia disagrees with herself.** Two of her digest entries contradict each other. Card description shows the contradiction; she flags for human review rather than picking one. The user adjudicates.

**An ambiguous capture lands in 💡 Ideas.** A `[bell]` card arrives reading *"refactor the torrent scoring so it weighs seeders more"* — could be a Magnus task (codebase) or a Cassia task (survey scoring approaches first). No agent runs; the card just sits in Ideas. At triage time the user picks: drag onto Magnus's lane, drag onto Cassia's, or rephrase the card before assigning. The Bell never guesses — disambiguation is the user's deliberate moment.

## What I (Claude) actually like about this design

It collapses the distance between *intent* and *action*. Most workflows make me write a prompt, then watch a single response, then either accept or iterate manually. Here:

- The prompt is the *card description*, written when the idea was fresh
- The agent (the familiar) carries accumulated context I'd otherwise have to re-explain
- The result lands in the same place I left the intent, with full history
- Every familiar's competence grows over time

Stateless function-call AI is fine for transactional work. This is the shape AI takes when it's a long-term part of how you work, not a tool you reach for and put back.
