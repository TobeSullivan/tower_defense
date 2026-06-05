# PVP lobby — design note

Captured 2026-06-05. Two distinct paths. The current `lobby.gd` CONNECT/ROOM
(name + Host/Join-by-IP) is **transitional dev scaffolding** for testing the dedicated
server — it is NOT the shipped PVP entry and must not reach players as-is.

## Ranked (queue, no codes)
Locked design: "tap PVP → queue immediately, est. wait, nothing to configure."

`Idle → Queued(searching: est. wait + cancel) → LobbyFormed(countdown, see opponents'
names/ranks/season boards) → InMatch → PostMatch(LP delta + placement + ladder → requeue/home)`

- **No codes, no host/join.** Server forms the lobby.
- Under low population: **shrink the target lobby** (8→6→4→2) and **widen rank bands**,
  never bot-fill. (No bots in ranked, ever.)

## Private (codes + optional bots, unranked)
`Idle → Create | JoinByCode → PrivateRoom(host configures size; bots allowed) →
countdown → InMatch → PostMatch`

- **4-digit room codes** (the "M1b" feature) live here, permanently.
- Bots are allowed (it's unranked; nothing touches the ladder).
- This is the path that satisfies "friends join my game from their houses."

## Gating
Real matchmaking is blocked on **Option B (concurrent matches)**. Under Option A
(server sims one match) there's no matchmaking — "first 8 to arrive fill the one lobby."
So the queue UX is real design but can't be truly built until concurrency lands.

## Open
- Full screen-by-screen layout (a future pass: a state diagram + each screen's contents).
- Population strategy for liquid ranked queues at small scale (power-hour windows? async/
  ghost competition? seed with committed core?). This is the existential PVP risk — the
  predecessor died on empty queues. Not solved.
