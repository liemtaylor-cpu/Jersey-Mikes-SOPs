# CLAUDE.md — Balatro Trainer

Guidance for Claude Code working in this repository. Read this whole file at the
start of every session.

Full product brief (the source of truth for *what* we're building):
https://claude.ai/artifact/V5LV9RS7DiwKPyCtUA4Cua

Detailed decision factors, weightings, tunable parameters, and facts to verify:
`ENGINE_NUANCES.md`. Read the relevant section before building any engine layer.

## What this is

A free Balatro mod that grades every decision the player makes (Best, Good,
Inaccuracy, Mistake, Blunder) and shows the engine's stronger choice, like
chess.com's Game Review. It is a **trainer**, not an autoplayer:

- It never uses hidden information (upcoming draws, shop contents, the seed).
- Live hints are **off by default**; post-hand and run review are the core.
- Not monetized.

It is built on top of **BestHandAdvisor** by JCMexplains
(https://github.com/JCMexplains/balatro-best-hand, MIT license). Keep its
copyright notice in our LICENSE file alongside ours.

## Working with the developer (important)

The developer is a **beginner** at reading and debugging code. Always:

1. Explain each step in plain words before doing it, and why.
2. Make **one small, testable change at a time**. Never batch unrelated changes.
3. Give exact **Windows PowerShell** commands and say where to run them.
4. After each change, say how to test it **in-game** and what should happen.
5. Commit to git after every working step, with a clear message, so any
   mistake can be undone with one command. Show that command.
6. If something fails, show the exact error, explain what it means, then fix it.
7. Push back when an idea is weak or out of order. Don't just agree.

## Environment

- Windows, Steam copy of Balatro.
- Mod loader: **Lovely** (lovely-injector) + **Steamodded** (SMODS).
- Mods folder: `%APPDATA%\Balatro\Mods\`
- Language: **Lua 5.1** (what Balatro ships). Syntax-check every edit with
  `luac -p <file>.lua`.
- Style: Olivine-Labs Lua style (see `STYLE.md`). Two spaces, single quotes,
  `snake_case`, `local function`, 80-char lines.
- Steamodded needs the manifest and main Lua file at the **mod root**. Keep the
  flat layout. Extra modules are loaded from the main file with
  `assert(SMODS.load_file('name.lua'))()`.
- Offline test tools need `balatro_src/`: the game's Lua source, extracted by
  opening a **copy** of `Balatro.exe` with 7-Zip. It is gitignored and must
  never be committed or shipped (it's the game's code).

## Settled decisions (don't re-ask)

| Area | Decision |
| --- | --- |
| Grade metric | Change in **odds of beating the current blind** (later: next two antes), not raw score |
| Live hints | Off by default |
| Editions (foil/holo/poly/negative) | Scored exactly in play; weighted in shop value |
| Jokers from other mods | Pause grading, show a short notice |
| Simulator language (Phase 4) | Decide then; lean Rust |
| Risk profiles | Safe (default) first. Aggressive and High-score later, same engine, different weights |

## Engine design (summary — the brief has full detail)

**Core rule:** on every screen, enumerate every option (including doing
nothing), give each one score on one scale, and grade the player's choice
against the best. The scale: estimated odds of clearing every blind through the
end of the next ante, plus the value of money banked once that safety target is
met.

Layers:

1. **Hand scorer** — exact. Every 1–5 card subset (~218 for 8 cards), every
   order when order-sensitive jokers are present. From BestHandAdvisor.
2. **Discard advisor** — Monte Carlo redraws against the blind target.
3. **Shop advisor** — build commitment model:
   `joker value = generic power + Σ (fit_b × commitment_b)` over builds
   (Flush, Pairs/Full House, Straight, N-of-a-kind, High-card xMult, Steel
   Kings, Face cards, Glass/Lucky). Verify the build list against the wiki.
4. **Money** — dollars valued in the same units as jokers.
   Spend until safe for the next two antes, then bank. Interest is $1 per $5
   up to the cap ($25 default); count lost interest over remaining rounds.
   Current boss is visible; next ante's boss is unknown, so model it as an
   average weighted toward the worst.
5. **Evolution tuner** — population of weight sets, same seeded runs, keep a
   change only if it wins statistically more often (Fishtest/SPRT style).
   Seeds are for **testing only**, never for advice.

## Build phases (do them in order; each has a gate)

1. **Hand grader** — grade each played hand. Gate: predictions match the game
   on 500+ logged hands.
2. **Discard grader** — Gate: stable advice; beats simple rules in seeded tests.
3. **Public release** — free on Thunderstore, opt-in logging.
4. **Fast simulator** — Gate: matches the real game on a logged-state suite.
5. **Shop advisor** — Gate: tuned bot beats the hand-written baseline
   significantly before shop advice is shown to players.

Do not start a phase before the previous gate passes.

## Code map: BestHand.lua (as of upstream commit 133bfa5, 2026-05-28)

Line numbers drift as we edit; search by function name.

| Function | ~Line | What it does | Why we care |
| --- | --- | --- | --- |
| `combinations`, `permutations` | 95, 117 | Subset / order enumeration | Reuse for discards |
| `fast_evaluate_poker_hand` | 701 | Identifies the poker hand | Hot path |
| `is_flint_active`, `is_hand_debuffed_by_blind`, `describe_blind_restriction` | 881–938 | Boss blind handling (Eye, Mouth, Psychic, Arm, Flint, Cerulean Bell) | **Gap:** most bosses unmodeled (Verdant Leaf, Needle, Wall, …) |
| `resolve_jokers`, `build_combo_precomputed` | 1182, 1228 | Blueprint/Brainstorm resolution, per-hand cached flags | Call once per screen |
| `score_combo(cards, all_cards, prob_config, range_config, precomputed)` | 1606 | Scores one candidate play; returns hand name + score | **The core function we build on** |
| `analyze_hand_inner` | 2846 | Scores every combo into `best`, then keeps only the **top 2** | **Change:** keep the full ranked list so any play can be graded |
| `SMODS.Keybind` F2 | 3055 | Prints top 2 to the console | Replace with in-game UI later |
| `extract_game_state` | 3362 | Snapshots state (hands/discards left, dollars, cards, jokers) | Reuse for opt-in logs |
| `install_evaluate_play_wrapper` | 3505 | Hooks `G.FUNCS.evaluate_play`, runs when the player plays a hand | **Where Phase 1 grading hooks in** |

Upstream also has its own `CLAUDE.md` (scoring pipeline details) — read it
before editing the scorer.

## Phase 1 plan (first coding work)

Start only after the first-session checklist (`FIRST_SESSION.md`) is done
(Lovely + Steamodded installed, `balatro_src/` extracted, upstream mod verified
in-game, git set up).

1. Fork upstream into our repo; rename the mod (id, name, json) to Balatro
   Trainer; keep upstream's LICENSE notice.
2. Make `analyze_hand_inner` return the **full** ranked list, not just top 2.
   Verify F2 still prints the same top 2.
3. In the `evaluate_play` wrapper, find the player's played combo in that list
   and compute a grade. Print it to the console first; UI comes later.
4. Grade rule for Phase 1 (provisional, refine in Phase 2):
   - Chips still needed = `G.GAME.blind.chips - G.GAME.chips`.
   - If **any** play clears the blind: every clearing play is Best; a play
     that fails to clear when one could is a **Blunder**.
   - If it's the **last hand** and nothing clears: grade by score vs best.
   - If hands remain and nothing clears: grade by score vs best, but label it
     **provisional**, since the true best may be a setup play. Phase 2's
     redraw simulation fixes this.
   - Provisional score cutoffs: Best ≥ 99% of best, Good ≥ 90%,
     Inaccuracy ≥ 75%, Mistake ≥ 50%, Blunder below that.
5. Show the grade in-game (small text near the hand), behind a settings toggle.

## Testing

- `luac -p BestHand.lua` after every edit.
- `lua batch_verify.lua` replays logged hands; `lua synth_fuzz.lua 1000`
  fuzzes against the real game's scoring. Both need `balatro_src/`.
- Only run offline tools on capture files we produced ourselves (they execute
  the files).
- In-game check after every change: start a run, play a hand, confirm the
  console output and the actual score.
