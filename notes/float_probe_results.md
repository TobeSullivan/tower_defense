# Cross-platform float determinism — probe results

Executes `resim_contract.md` §5.1: *before* converting the sim to a fixed
deterministic tick, measure whether Godot's float math agrees across the
platforms that matter — **Win/Mac clients vs. the Linux re-sim server**. If they
agree bit-for-bit, we build the determinism conversion on floats and keep this
probe as a regression test. If they diverge, sim-critical accumulation (damage,
positions, cooldowns, gold) moves to fixed-point integer math before anything
else is built on top.

**Probe:** [`src/tools/float_probe.gd`](../src/tools/float_probe.gd) —
self-contained (no autoloads/scene/textures), so the *identical file* runs on
every platform. It runs a hot scripted sim (14 mobs looping a path, 8 towers
with varied upgrade loadouts, 9000 ticks) using the real `game_constants.gd`
formulas and the real engine float ops (`Vector2.normalized/length/distance_to`
= sqrt, `pow()` HP curve, multiply-accumulate damage, and the float comparisons
that gate branches). All "randomness" is an integer LCG, so control flow is
platform-independent **by construction** — any output divergence is pure float.

It dumps bit-exact fingerprints (raw IEEE-754 bytes, not rounded prints) of three
accumulators folded every tick, plus a combined XOR fingerprint.

## How to run (same command, each platform)

```
<godot> --headless --path <repo>/src --script res://tools/float_probe.gd
```

- **Windows:** `& "C:\Users\tobes\Desktop\Godot.exe" --headless --path "C:\dev\Maze Battle TD\src" --script "res://tools/float_probe.gd"`
- **macOS:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --path <repo>/src --script res://tools/float_probe.gd`
- **Linux server:** `./Godot_v4.6.3-stable_linux.x86_64 --headless --path <repo>/src --script res://tools/float_probe.gd`

Use the **same Godot version** everywhere (reference was 4.6.3.stable). Compare the
`COMBINED` line (and the three `bits=` lines if it differs, to localize *which*
accumulator drifted).

## Results

| Platform | Godot | COMBINED | total_kills | Status |
|---|---|---|---|---|
| **Windows 11 x64** | 4.6.3.stable | `400dcbdd1e8d0209` | 573 | ✅ reference (3/3 runs identical) |
| macOS | — | — | — | ⏳ pending (no Mac in dev env) |
| Linux x64 (server) | — | — | — | ⏳ pending |

Full Windows reference block:

```
=== FLOAT PROBE RESULT ===
ticks=9000 mobs=14 towers=8
acc_damage  = 80965.374400  bits=40f3c455fd8adaf2
acc_pos     = 112552054.143280  bits=419ad5a1d892b800
acc_hp      = 10932553.861986  bits=4164da293b9562c6
total_kills = 573
COMBINED    = 400dcbdd1e8d0209
=== END ===
```

**Within-platform determinism (Windows): confirmed** — 3 consecutive runs bit-identical.
Cross-platform is the open question; needs the Mac + Linux legs.

## Decision rule

- **All three `COMBINED` match** → floats are safe across our platforms. Proceed
  with the fixed-tick conversion on `float`; promote this probe to a CI regression
  test (matrix: windows/macos/ubuntu) so a future engine/toolchain bump can't
  silently reintroduce divergence.
- **Any divergence** → go **fixed-point** for sim-critical accumulation before
  building the re-sim runner. The `bits=` lines pinpoint which quantity drifted
  (damage vs. position vs. hp) and therefore how deep the fix goes.

## Getting the Mac/Linux legs

1. **GitHub Actions matrix (built)** —
   [`.github/workflows/float-probe.yml`](../.github/workflows/float-probe.yml)
   downloads pinned Godot 4.6.3 on `windows-latest` / `macos-latest` /
   `ubuntu-latest`, runs the probe on each, and **fails the `compare` job if the
   three `COMBINED` lines disagree**. This *is* the permanent regression test §5.1
   asks for. Triggers on changes to the probe, `game_constants.gd`, or the workflow
   itself, and via manual `workflow_dispatch`. **To get the answer: push to GitHub
   and read the `compare` job** (green = floats agree; red = divergence, with each
   leg's `bits=` lines in its uploaded `probe_full.txt` to localize the drift).
   - **Caveat — glibc vs musl:** the ubuntu runner is glibc. If the real re-sim
     server runs Alpine/musl, add a musl leg (`container: alpine`) — musl's libm
     differs from glibc's, so a glibc-only pass wouldn't clear it.
2. **Manual** — alternatively, run the one-liner above on any Mac and on the actual
   Linux server, paste the `COMBINED` lines back, fill in the table. Running on the
   *real* server is the most authoritative Linux leg.
