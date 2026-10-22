# Balatro Trainer

A free Balatro mod that grades every decision you make (Best, Good,
Inaccuracy, Mistake, Blunder) and shows a stronger choice, like chess.com's
Game Review. It's a trainer, not an autoplayer: it never uses hidden
information (upcoming draws, shop contents, the seed).

Built on [BestHandAdvisor](https://github.com/JCMexplains/balatro-best-hand)
by JCMexplains (MIT).

**Status:** planning done, no playable mod yet. Start with
[`FIRST_SESSION.md`](FIRST_SESSION.md).

## Files

| File | What it's for |
| --- | --- |
| `CLAUDE.md` | How the project works and the build plan. Read first. |
| `ENGINE_NUANCES.md` | Every factor the engine weighs, with test cases. |
| `HANDOFF.md` | History and reasoning from the planning chat. |
| `FIRST_SESSION.md` | PC setup checklist: Lovely, Steamodded, `balatro_src/`. |
| `grade.lua` | Phase 1 grade rule (Best … Blunder). Not hooked in yet. |
| `test_grade.lua` | Tests for `grade.lua`. Run `lua test_grade.lua`. |
