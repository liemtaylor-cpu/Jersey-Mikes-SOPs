# HANDOFF.md — context from the planning conversation (Oct 22, 2026)

This project was planned in a claude.ai chat before any code existed. This file
carries over the reasoning and history that `CLAUDE.md` and
`ENGINE_NUANCES.md` don't. Read all three at the start of the first session.

Product brief (live doc): https://claude.ai/artifact/V5LV9RS7DiwKPyCtUA4Cua

## About the developer

- Liem, business student (supply chain).
- Beginner at reading/debugging code; Claude writes most of it.
- Wants **direct pushback**, not validation. Prefers practical examples over
  theory. Thinks in action steps.
- Hardware: Windows PC, Ryzen 7 5800X3D (8 cores / 16 threads, 96MB cache).
  CPU-bound simulation is fine; GPU is irrelevant until large-model training.
- Plan: Claude Pro. Long sessions may hit usage limits; keep tasks scoped.

## How the idea evolved (and why)

1. **Started as** "a Balatro Stockfish": a mod that tells you the
   mathematically best choice. Research found no such mod. Closest existing
   tools: BestHandAdvisor (best play only), a Leiden thesis discard tool,
   Balatro Calculator (web), and bots like balatrobot / BalatroLLM that play
   for you rather than coach.
2. **Why nobody has built it:** an optimal policy exists in theory, but
   computing it is out of reach. Hand play and discards are solvable from the
   current screen; shop and joker decisions depend on the rest of the run,
   which needs a value function nobody has built well yet.
3. **Seeds:** make testing reproducible (compare versions on the same seeds),
   but don't make the game easier to solve. Reading the seed would be cheating.
   Seeds are for testing only.
4. **Breeding/evolution:** the developer proposed a genetic-algorithm "breed
   the best bots" approach. Verdict: great for tuning a few dozen weights,
   too slow for evolving a full neural net. Adopted for shop/joker weights.
5. **Build commitment:** the developer proposed organizing joker value around
   a few key builds, choosing the closest build when a card fits several.
   Refined with: soft commitment (a dial, not a switch), a generic-power term
   for jokers that fit everything, and pivots. Adopted.
6. **Product goal changed:** from "engine" to a **training tool** that grades
   player decisions (chess.com Game Review style). Explicitly **not
   monetized**. Player run logs (opt-in) improve testing and show common
   mistakes; they are **not** used to imitate human play.
7. **Money:** the developer argued coins are the most valuable asset.
   Pushback: winning the next blind is; money only matters for what it buys.
   Agreed rule: spend until safe for the next two antes, then bank. The next
   ante's boss is hidden, so it's modeled as unknown.
8. **Core rule (developer's):** on every screen, weigh every option and pick
   the one with the least tradeoffs. Formalized as: score every option on one
   scale (odds of clearing through the next ante + banked money value) and
   pick the highest.
9. **Risk profiles:** the developer proposed a riskier engine. Adopted as a
   setting on the same engine (Safe default; Aggressive and High-score later),
   each with its own tuned weights. Build Safe first.

## Ideas considered and set aside

- **Pure reinforcement learning from scratch:** sparse win/loss reward,
  heavy randomness, no fast simulator yet. Maybe later, after phases 1–5.
- **Copying Stockfish/Nexto code:** Stockfish is GPL-3; borrow ideas only
  (search + evaluation, SPRT testing, PPO, reward shaping, curriculum).
- **Imitation learning from player data:** humans mostly play worse than the
  engine; copying them makes it worse.
- **Monetization:** dropped by the developer.

## Worked example from the chat (useful as a test case)

**Wheel of Fortune:** 1 in 4 to add an edition to a random editionless joker;
on a hit, ~50% Foil / 35% Holo / 15% Polychrome [verify]. Per use: 75% nothing,
12.5% Foil, 8.75% Holo, 3.75% Polychrome. Early game ≈ +10% expected score for
$3 (a planet is usually better); late game ≈ +2% (bad). Always use it when
free. Oops! All 6s doubles the odds. Good fixture for the shop/consumable
sampler: the engine should reach these same conclusions on its own.

## Status at handoff

- Done: product brief, CLAUDE.md, ENGINE_NUANCES.md, license check
  (BestHandAdvisor is MIT; keep its copyright notice).
- Not done (needs the PC): install Lovely + Steamodded, extract
  `balatro_src/` from a copy of Balatro.exe with 7-Zip, verify BestHandAdvisor
  in-game, set up git and the project repo.
- Open questions: exact grade cutoffs, how editions weigh in shop value,
  whether v1 logs stay local or upload. Propose answers when relevant.

## First thing to do in Claude Code

Walk the developer through the first-session checklist in `CLAUDE.md`, one
step at a time, with exact PowerShell commands and what success looks like.
