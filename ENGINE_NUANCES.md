# ENGINE_NUANCES.md — the decisions that matter in the long run

Companion to `CLAUDE.md`. This file lists the non-obvious factors the engine
must weigh on each screen, how to model each one, and the starting weights the
evolution tuner will refine.

How to use this file (for Claude Code):

- Treat every section as **requirements and test cases**, not code. When you
  implement a layer, turn its nuances into unit tests or fixtures first.
- Every number marked **[verify]** comes from memory of the game, not from the
  source. Before relying on it, confirm it in `balatro_src/` (search the Lua),
  and update this file with the file and line you found it in.
- Every weight in the **Parameter registry** (end of file) is a starting guess.
  Name it in code exactly as listed so the tuner can find and change it.
- Explain these ideas to the developer in plain words when they come up. Each
  one has a "Why it matters" line written for that purpose.

---

## 0. The principles everything else follows

### 0.1 One currency: probability of winning

Every option on every screen is scored in one unit: estimated probability of
winning the run (or, in practice, a proxy for it — see 0.3). Chips, dollars,
jokers, hand levels, deck edits, and consumables are all converted into that
unit. Never compare "+$4" against "+200 chips" directly.

Why it matters: without one unit, the engine can't compare buying a joker with
rerolling with saving. Every "tradeoff" becomes a judgment call, and judgment
calls can't be graded.

### 0.2 Score options by *odds*, not by *average score*

Expected (average) score is the wrong target whenever there's randomness.

Example: you need 1,000 chips with one hand left.
- Play A: always scores 1,200. Clears 100% of the time.
- Play B: 50% chance of 3,000, 50% chance of 500. Average 1,750. Clears 50%.

Average-score says B. Odds-of-clearing says A. A is right.

The flip side happens automatically: when you're **behind** (no safe play can
clear), the odds metric picks high-variance options, because a long shot beats
a sure loss. The engine "gambles when losing and plays safe when winning"
without a special rule.

Why it matters: Lucky cards, Bloodstone, Glass, Wheel of Fortune, Space Joker,
Gros Michel, and every random draw make this distinction real on most turns.

### 0.3 The proxy objective (what we actually compute)

True run-win probability needs a full-run simulator and a trained evaluator.
Until then, use this proxy:

```
value(state) =
    P(clear every remaining blind this ante)                      × w_this_ante
  + P(clear every blind of next ante | projected build)           × w_next_ante
  + banked_dollar_value(state)       (only counts above safety line, see 4.2)
  + long_run_asset_value(state)      (scaling jokers, deck quality, vouchers)
```

`w_this_ante` > `w_next_ante` because nearer blinds are known better. The
"projected build" is the current build **plus expected future improvement**
(see 4.3 — this is easy to get wrong).

### 0.4 Value most things by re-scoring, not by hand-written weights

For anything whose effect the scorer can compute — planets, enhancements,
editions, seals, scoring jokers, deck edits — **don't assign a weight**. Instead:

1. Sample N representative hands from the deck as it would be after the change.
2. Run the exact scorer with and without the item.
3. The item's value is the change in odds of clearing the upcoming blinds.

Hand-written weights are only for things that can't be computed from the
current screen: future growth of scaling jokers, economy over remaining rounds,
consumables that create other consumables, and build commitment.

Why it matters: chips × mult means the value of "+10 mult" depends entirely on
your current chips and xMult. A fixed weight would be wrong in almost every
run. Re-scoring is always right.

### 0.5 Sunk cost is not commitment

"Commitment to a build" must mean **how much of your current and near-future
scoring depends on that build**, not how much you spent getting there. If a
pivot raises win odds, take it, even if you just bought three Flush planets.

### 0.6 Never use hidden information

- Sample draws from the **remaining deck composition** (the player can see it
  in the deck view), never from the actual upcoming order.
- **Never call the game's random functions** (`pseudorandom`, `pseudoseed`,
  anything that advances them) during analysis. That would change the run's
  future outcomes and could leak the seed. Use a separate RNG owned by the mod.
- Face-down cards are unknown cards. Treat them as a random draw from what the
  player could deduce, not as their true identity.

---

## 1. Playing a hand

### 1.1 The target is cumulative across hands

The blind needs a **total** across all remaining hands, not one big hand. The
right question is: which play maximizes P(sum of this hand + future hands ≥
chips still needed)?

Consequences:
- A play that scores 60% of the target and leaves strong follow-ups can beat a
  play that scores 80% but burns the cards you need next.
- With several hands left, "play the highest score" is only a heuristic.

Model: for plays that don't clear, estimate the follow-up with a fast rollout
(draw replacements, pick a greedy best play, repeat until hands run out).

### 1.2 When several plays clear the blind, they are NOT all equal

Overkill chips are wasted (they don't carry over), but **side effects of the
clearing play persist**. Tie-break clearing plays by long-run value:

| Factor | What to prefer | Why |
| --- | --- | --- |
| Hands left | Clearing with fewer hands used | Each unused hand pays $1 at cash-out [verify] |
| Gold cards | Keep them **in hand**, don't play them | Pay $3 each if held at end of round [verify] |
| Blue seals | Keep them in hand; play your **build hand** last | Create a planet for the **last played** hand type at end of round |
| Glass cards | Don't play them if you don't need to | 1 in 4 chance to break and leave the deck [verify] |
| Hiker | Play more scoring cards | Each played scoring card gets +5 chips forever |
| Scaling jokers | Feed them (Runner: straights; Spare Trousers: two pair; Square Joker: exactly 4 cards; Wee Joker: 2s) | Permanent growth |
| Ride the Bus | Avoid scoring face cards unless needed | Face card resets it to 0 |
| Obelisk | Avoid your most-played hand type unless needed | Playing it resets the xMult |
| Ice Cream, Seltzer, Popcorn | Prefer fewer hands | They decay per hand or round |
| Gold seals | Play them if free to | $3 when scored [verify] |
| The Tooth (boss) | Play fewer cards | $1 per card played |

### 1.3 Which hand type you play changes the future

Each play increments that hand type's "times played." That count feeds:

- **Telescope** voucher: Celestial packs always include the planet for your
  **most played** hand. Clearing early blinds with Pairs in a Flush build can
  make Pair your most-played hand and steer future planets wrong.
- **Obelisk**: resets when you play your most-played hand.
- **Supernova**: +mult equal to times that hand was played this run.
- **The Ox** (boss): playing your most-played hand sets money to $0.
- **Space Joker**: chance to level the played hand → play your build hand.
- **Card Sharp**: x3 if that hand type was already played **this round** →
  repeating your build hand twice in a round is worth more.
- **Burnt Joker** links to discards (see 2.3).

Rule: when the outcome this round is otherwise equal, play the build hand.

### 1.4 Boss blinds change what "best play" means

The current ante's boss is visible from the start of the ante. Plan the small
and big blinds around it:

- **The Pillar**: cards played earlier this ante are debuffed against the boss.
  → In the small and big blinds, avoid playing your key cards if you can clear
  without them.
- **The Eye**: no repeated hand types this round. **The Mouth**: only one hand
  type. → Plan a sequence, not a single play. The Eye conflicts with Card Sharp.
- **The Psychic**: must play 5 cards. **The Needle**: only 1 hand. → Value
  single-hand burst over consistency.
- **The Hook**: discards 2 random held cards after each hand. → Held-value
  cards (Steel, Gold, Blue seals) are at risk; plan to play fast.
- **The Serpent**: always draw exactly 3. **The Manacle**: −1 hand size.
- **The Plant / The Club / The Goad / The Window / The Head**: debuff face
  cards or a suit. → Builds dependent on those cards need a backup.
- **Amber Acorn** (final-ante boss): flips and shuffles jokers. → Order-
  dependent builds (Blueprint, xMult placement) lose value.
- **Verdant Leaf** (final-ante boss): all cards debuffed until you sell a
  joker. → Keep a cheap or decaying joker to sell.
- **Crimson Heart**, **Cerulean Bell**, **Violet Vessel**: final-ante bosses
  [verify the exact pool].

Final-ante bosses come from a small pool. From around ante 6, the engine should
weight the build's worst-case against that pool.

### 1.5 Probabilistic cards

- Lucky cards (1 in 5 for +20 mult, 1 in 15 for $20) [verify], Bloodstone,
  Glass, Wheel, Gros Michel: enumerate outcomes or sample them; compute **odds
  of clearing**, never expected score (0.2).
- Oops! All 6s doubles every listed probability. Read it from game state.

---

## 2. Discarding

### 2.1 Discards are a resource with value even when unused

| Source | Effect of unused / used discards |
| --- | --- |
| Banner | +30 chips per remaining discard |
| Mystic Summit | +15 mult when 0 discards remain |
| Delayed Gratification | $2 per discard if none were used by end of round |
| Green Joker | −1 mult per discard used (permanent) |
| Ramen | −0.01 xMult per card discarded (permanent) |
| Green Deck | $1 per remaining discard, $2 per remaining hand, no interest [verify] |

So "discard to improve this hand" has a cost the scorer doesn't see. Subtract
the long-run cost of the discard before comparing.

### 2.2 Discards also create value

| Source | Effect |
| --- | --- |
| Purple seal | Creates a Tarot when discarded |
| Trading Card | First discard of the round, if exactly 1 card: destroy it, +$3 (deck thinning **and** money) |
| Faceless Joker | $5 if 3+ face cards discarded at once |
| Mail-In Rebate | $ per discarded card of a set rank |
| Castle | Permanent chips per discarded card of a set suit |
| Hit the Road | xMult per Jack discarded this round |
| Yorick | xMult after enough cards discarded |

Implication: sometimes the best discard is the one that triggers money or
growth, even if it doesn't improve this hand.

### 2.3 Burnt Joker: the first discard levels a hand

Burnt Joker upgrades the level of the **first discarded** poker hand each
round. The first discard should contain your build hand type when possible.
This is easy to miss and compounds every round.

### 2.4 Pick discards by odds, sampled from the real remaining deck

For each candidate discard:
1. Remove the discarded cards; draw replacements from the remaining deck.
2. Find the best play (or apply 1.1 for multi-hand plans).
3. Repeat N times.
4. Score = P(clearing) plus long-run effects from 2.1–2.3.

Use **common random numbers**: the same N sampled draw sequences for every
candidate. This makes comparisons far less noisy at the same sample count.

### 2.5 Performance: prune before simulating

Naively: ~218 discards × N redraws × ~218 plays each = tens of millions of
scorings. Too slow for live play in Lua.

- Prune discards that break every plausible build hand (keep candidates that
  preserve a flush draw, straight draw, pairs, etc.).
- Use a **fast approximate scorer** inside rollouts; use the exact scorer only
  for the final ranking of the top few.
- Stop early when one candidate is clearly ahead (sequential testing).
- Run analysis across frames (coroutines) so the game never freezes. Grading
  is post-decision, so it can finish a second later.

### 2.6 Playing as a discard

With hands to spare but no discards left, playing junk cards cycles the deck.
Treat "play a weak hand to dig" as a discard option whose cost is a hand
($1 at cash-out, plus the chips it fails to add).

---

## 3. Blind select: play or skip

### 3.1 What a skip really costs

Skipping a small or big blind gives a tag but loses:
- The blind's reward ($3 small, $4 big [verify]; Red Stake+ removes the small
  blind reward [verify]).
- $1 per unused hand at cash-out [verify].
- One round of interest.
- **A whole shop visit.** This is usually the biggest cost: one fewer chance
  at jokers, vouchers, and packs.
- Tempo: you reach the boss with fewer upgrades.

What it gains:
- The tag's value (below).
- Throwback: +x0.25 per blind skipped.
- Speed tag value grows with skips.

### 3.2 Tag values (rough tiers, tune them)

Score each tag by re-scoring where possible (Orbital: +3 levels to a hand;
Polychrome/Negative: apply to your best joker) and by dollars where not:

- **Strong:** Negative (free joker slot), Polychrome, Rare, Investment ($25
  after the boss), Economy (doubles money, max +$40), Double (copies the next
  tag), Orbital (if it hits your build hand), Voucher.
- **Situational:** Coupon (free shop items), D6 (rerolls start at $0),
  Juggle (+3 hand size next round), Boss (reroll the boss), Charm/Meteor/
  Ethereal/Buffoon/Standard (free packs), Speed, Handy/Garbage (money per hand
  played / discard unused).
- **Weak late:** Top-up, Foil, Holographic.

Economy tag nuance: it's worth exactly `min(dollars, 40)`, so skip for it when
holding a lot of money and the blind is skippable safely.

### 3.3 Skipping is only allowed if it doesn't kill you

Skipping the big blind means facing the boss after one shop instead of two.
Only skip if the safety check (4.2) still passes for the boss with the reduced
shop count.

---

## 4. Money and economy

### 4.1 The interest curve has thresholds

Interest pays $1 per $5 held at end of round, up to the cap ($5 at $25 by
default; $10 at $50 with Seed Money; $20 at $100 with Money Tree) [verify].

- Value of a dollar is **not linear**: crossing $20 → $25 earns a full $1 per
  round; going $25 → $29 earns nothing extra (until the next cap).
- Spending that drops you below a multiple of $5 costs $1 per round until you
  rebuild. Count that over the rounds you'd stay below.
- **Selling to hit a threshold** is real value: at $23 with a dead $2 sell-value
  joker, selling it earns $1 every round from then on.
- [verify] Whether interest is computed before or after the blind's reward and
  hand money. This decides whether you need $25 *before* the blind or whether
  reward money counts toward it. Get this exactly right; the threshold logic
  depends on it.

### 4.2 The safety line (spend until safe, then bank)

Below the safety line, a dollar is worth what it buys toward safety. Above it,
a dollar is worth its future interest and future buying power.

`safety(state)` = projected P(clear every blind through the end of the next
ante). If `safety < SAFETY_TARGET`, money's value drops to `DOLLAR_VALUE_UNSAFE`
and the engine recommends spending on whatever raises safety most per dollar.

### 4.3 The trap: measuring safety with today's build only

If the safety forecast assumes **no future purchases**, the engine will never
bank early. In ante 1, no build can beat the ante 3 boss, so a "current build
only" check always says unsafe → always spend → never reaches $25.

Real players bank early because they know they'll keep improving. The forecast
must credit **expected future improvement**:

```
projected_strength(ante + k) = current_strength × growth_rate^k
```

`growth_rate` starts as a guess, then gets **measured** from simulated runs
(how much does an average build improve per shop visit at this ante and
money level?). This one number decides the whole economy balance. Tune it
early and treat it as the most important economic weight.

### 4.4 Money can be a scoring resource

Some jokers turn held money into score, so spending **lowers your score**:
- Bull: +2 chips per $1 held.
- Bootstraps: +2 mult per $5 held.

And some make money worth more:
- To the Moon: +$1 interest per $5 held.
- Rocket, Golden Joker, Cloud 9, Egg (growing sell value), Gift Card (sell
  values grow every round).

The dollar value function must read these from current jokers, not assume
dollars are only for spending.

### 4.5 Debt and negative money

Credit Card allows going to −$20. Debt has no interest but blocks Bull and
Bootstraps value. Model it as negative dollars with the same curve, floored.

### 4.6 Money timing with consumables

- **Hermit**: doubles money, max +$20. Best used at exactly $20+. Holding it
  until then is correct if a slot is free.
- **Temperance**: gives total joker sell value, max $50. Use after sell values
  grow (Egg, Gift Card).
- **Wraith**: creates a rare joker and **sets money to $0**. Use when broke.
- **Immolate**: destroys 5 random cards, +$20.

These need a "use now vs hold" decision with the same value function.

### 4.7 Deck and stake change the money rules

- **Green Deck**: no interest; $2 per remaining hand, $1 per remaining
  discard [verify]. Dollars are worth only their buying power. Hands and
  discards become money.
- **Yellow Deck**: +$10 start.
- **Rental** jokers (higher stakes): cost $3 per round [verify]. That's 60% of
  max interest; often worse than buying nothing.

Read deck and stake from game state. Never hardcode default-deck rules.

---

## 5. The shop

### 5.1 Joker slots have an opportunity cost

When slots are full, a joker is worth **(its value − value of the weakest
joker it replaces + that joker's sell value)**, not its raw value. Slots get
more valuable as the run goes on.

- Negative jokers don't use a slot: value them separately from their effect.
- **Joker Stencil**: xMult per empty slot. Buying any joker **lowers Stencil**.
  The engine must re-score, not add values.

### 5.2 Joker order is part of a joker's value

Jokers trigger left to right. +mult before xMult. Blueprint copies the joker
to its right; Brainstorm copies the leftmost. Ceremonial Dagger destroys the
joker to its right.

Value a new joker **in its best position**, and output the recommended order.
Amber Acorn scrambles order (1.4).

### 5.3 Scaling jokers: value = now + growth − decay

```
value(joker) = current_contribution
             + expected_growth_per_round × rounds_remaining × discount
```

- Scaling (grows): Ride the Bus, Green Joker, Hologram, Constellation,
  Lucky Cat, Glass Joker, Madness, Campfire, Throwback, Vampire, Wee Joker,
  Runner, Square Joker, Spare Trousers, Castle, Hiker (via cards), Caino,
  Yorick, Obelisk.
- Decaying (shrinks): Ice Cream, Popcorn, Ramen, Seltzer, Turtle Bean,
  Gros Michel (can die).

Growth depends on the player's build: Runner is worthless if you never play
straights. Use build commitment (5.6) to estimate growth rate.

**Early scaling jokers are worth far more than late ones** because of
rounds remaining. Sell decaying jokers before their value drops below what
the slot is worth.

### 5.4 Rerolls

Reroll cost starts at $5 and rises $1 per reroll in that shop [verify];
resets each shop. D6 tag and Chaos the Clown change this.

```
reroll_value = E[best option in new shop] − E[best option in current shop]
               − reroll_cost − interest_lost(reroll_cost)
```

Estimate `E[best option in new shop]` by sampling from the shop's item pool
(rarity weights, current vouchers like Hone/Glow Up). Each extra reroll is
worth less (cost rises, and you already hold what you bought). Stop when the
next reroll's value is negative.

### 5.5 Vouchers are permanent: value scales with time left

```
value(voucher) = benefit_per_round × rounds_remaining
```

Buy early; skip late unless the per-round benefit is huge. Notes:
- **Seed Money / Money Tree** only pay if you'll actually hold $50 / $100.
- **Observatory**: each Planet card *held* gives x1.5 mult to its hand.
  Changes consumable slot value completely.
- **Telescope**: steers Celestial packs (1.3).
- **Hieroglyph / Petroglyph**: −1 ante (huge) at the cost of a hand/discard.
- **Director's Cut / Retcon**: reroll the boss. Value = how bad current bosses
  are for this build.
- **Overstock, Clearance Sale, Reroll Surplus**: value depends on how much
  you'll shop.

### 5.6 Build commitment (from the brief, with nuances)

```
joker_value = generic_power + Σ_builds fit_b × commitment_b
```

- `commitment_b` should come from **current scoring dependence**: what share
  of your expected score comes from build b's hand types? Plus hand levels,
  deck composition (suit/rank counts), and build jokers. Not money spent (0.5).
- Early antes: commitment is near zero for everything. `generic_power` and
  economy dominate. This is intentional, not a bug.
- **Commitment ramp**: commitment rises with investment but should be capped
  so a strong enough off-build joker can still trigger a pivot. The pivot
  threshold is a tuned weight.
- **Anti-synergies** must subtract: Ride the Bus with face builds, Obelisk with
  one-hand builds, Ceremonial Dagger next to key jokers, Madness/Ankh/Hex
  destroying jokers, Vampire stripping enhancements, Midas Mask turning faces
  Gold (overwriting other enhancements).

### 5.7 Packs

- Buffoon packs: only worth it with a free slot or a weak joker to replace.
- Arcana/Spectral packs: value depends on which tarots fit the build (Star/
  Moon/Sun/World for flush, Strength for straights/pairs, Death for copying,
  Hanged Man for thinning).
- Celestial packs: value = your build's planet probability (Telescope helps).
- Standard packs: cards with enhancements/seals; only valuable when deck
  edits help the build.
- Picking **inside** a pack is its own screen: enumerate each pick and skip.

---

## 6. Deck building

### 6.1 Deck quality = probability of drawing the build hand

The deck's value for a build is: P(making the build hand within one hand plus
available discards), with current hand size. Compute it by simulation.

- **Thinning** (Hanged Man, Trading Card, Immolate, Glass breaks) raises
  consistency for focused builds. Removing an off-suit card in a flush deck
  can be worth more than an enhancement.
- **Adding cards** (Hologram, DNA, Cryptid, Marble Joker's Stones, Standard
  packs) dilutes the deck unless they fit the build.
- Suit conversion (Star/Moon/Sun/World): +flush probability.
- Strength (+1 rank): straights and pairs.
- Death: copy your best card (often a Glass/Steel/Red-seal card).

### 6.2 Enhancements want different positions

- Played: Mult, Bonus, Glass, Lucky, Wild, Stone.
- **Held**: Steel (x1.5 mult), Gold ($3 at end of round), Blue seal (planet).
- Conflict: a Steel card in your flush suit is valuable held but needed played.
  Model both uses; don't assume enhancements are always good to play.

### 6.3 Hand size, hands, discards

These trade against each other (Troubadour, Merry Andy, Stuntman, Turtle Bean,
Painted Deck, Black Deck). Value them by re-simulating build-hand probability
and clear odds with the changed limits. +1 hand size is usually worth more than
it looks for focused builds.

---

## 7. Consumables

- Two slots by default; holding costs a slot. With Observatory, a held Planet
  is a permanent xMult and should not be used.
- **Use-now vs hold** is a decision on every screen where a consumable exists.
- Timing-sensitive: Hermit, Temperance, Wraith, Immolate (4.6); Wheel of
  Fortune (only targets jokers without an edition; more valuable when your best
  joker is the only editionless one); The Fool (copies the last used card).
- Destructive spectrals: Ankh (copy one random joker, destroy the rest), Hex
  (polychrome one, destroy the rest), Ectoplasm (negative + −1 hand size).
  Value them by the outcome distribution over your actual jokers.

---

## 8. Grading (how the player sees it)

### 8.1 Grade by change in win probability, not absolute value

Chess engines grade by drop in win chance for a reason:
- In a lost position, every move "loses" — don't scream Blunder at all of them.
- In a won position, small inefficiencies don't matter — don't punish them.

Grade = `value(best option) − value(player's option)`, measured in probability.

### 8.2 Don't grade noise

Monte Carlo estimates have error. If the gap between two options is smaller
than the estimate's noise, both are "Best." Rules:
- Compute a confidence interval for each option's value.
- Only grade below Best when the gap exceeds the noise margin.
- Exact layers (hand scoring) don't need this; sampled layers (discards, shop)
  do.

Mis-grading near-ties is the fastest way to lose a player's trust.

### 8.3 Explain the dominant factor in one line

Each grade shows the single biggest reason, e.g.:
- "Keeps 2 Gold cards in hand: +$6"
- "Same clear odds, but feeds Runner (+15 chips permanently)"
- "Drops you below $25: −$1 interest for ~6 rounds"
- "Plays Pairs: Telescope will offer the wrong planet"

### 8.4 Run review: find where the run was lost

After a run ends, list the 3 decisions with the biggest win-probability drops.
That's the lesson. A run lost at the ante 8 boss was usually lost earlier.

---

## 9. Tuning and testing nuances

- **Separate seeds for tuning and testing.** Tune on one seed set, report
  results on a held-out set. Otherwise the tuner memorizes seeds.
- **Tune per deck and stake**, or include them as inputs. A weight good on Red
  Deck White Stake can be wrong on Green Deck Gold Stake.
- **The tuner will exploit simulator bugs.** If a weight set looks too good,
  replay its games in the real game (via balatrobot) before trusting it.
- **SPRT** (Stockfish's method): play two versions on paired seeds until the
  result is statistically clear, then stop. Cheaper than fixed-size tests.
- **Start with the weights that matter most** (see registry "priority").
  Tuning 60 weights at once with noisy fitness rarely converges.

---

## 10. Parameter registry

Starting guesses. Every name is a tunable constant in code. Priority 1 = tune
first.

| Name | Start | Priority | Meaning |
| --- | --- | --- | --- |
| `SAFETY_TARGET` | 0.85 | 1 | P(clear through next ante) required before banking money |
| `GROWTH_RATE_PER_SHOP` | 1.35 | 1 | Expected build strength multiplier per shop visit; measure from sims (4.3) |
| `W_THIS_ANTE` | 1.0 | 1 | Weight on clearing the rest of this ante |
| `W_NEXT_ANTE` | 0.6 | 1 | Weight on clearing the next ante |
| `DOLLAR_VALUE_SAFE` | 1.0 | 1 | Value of $1 above the safety line, in dollar-equivalents incl. future interest |
| `DOLLAR_VALUE_UNSAFE` | 0.3 | 1 | Value of $1 below the safety line (only its buying power) |
| `LATE_RUN_DOLLAR_DECAY` | 0.15 | 2 | Per-ante drop in dollar value approaching ante 8 |
| `INTEREST_HORIZON_ROUNDS` | 6 | 2 | How many rounds of lost interest to count when dropping below a threshold |
| `SCALING_DISCOUNT` | 0.9 | 2 | Per-round discount on a scaling joker's future growth |
| `PIVOT_THRESHOLD` | 1.5 | 2 | Off-build joker must be this many times better than on-build value to pivot |
| `COMMITMENT_CAP` | 0.8 | 2 | Max commitment to any one build (keeps pivots possible) |
| `SLOT_VALUE_BY_ANTE` | 0.2 → 1.0 | 2 | Opportunity cost of a joker slot, rising with ante |
| `SHOP_VISIT_VALUE` | tuned | 2 | Value of one shop visit (cost of skipping a blind) |
| `TAG_VALUES` | table | 3 | Dollar-equivalent value per tag (3.2) |
| `VOUCHER_BENEFIT_PER_ROUND` | table | 3 | Per-round value per voucher (5.5) |
| `FINAL_BOSS_WORST_CASE_WEIGHT` | 0.5 | 3 | Weight on worst final-ante boss vs average, from ante 6 |
| `HELD_CARD_TIEBREAK` | on | 3 | Prefer clearing plays that keep Gold/Steel/Blue-seal cards in hand |
| `MC_SAMPLES_DISCARD` | 500 | 3 | Redraw samples per discard candidate (with common random numbers) |
| `MC_NOISE_MARGIN` | 2 × std err | 3 | Gap below which two options are both graded Best |
| `GRADE_CUTOFFS` | 0.5 / 2 / 5 / 10 pp | 3 | Win-prob drop in percentage points for Good / Inaccuracy / Mistake / Blunder |
| `RISK_PROFILE` | safe | — | safe / aggressive / high_score; each has its own weight set |

---

## 11. Facts to verify in `balatro_src/` before use

Search the Lua source and record file + line next to each in this file.

- [ ] Blind rewards: $3 small, $4 big, $5 boss; Red Stake removes the small reward
- [ ] $1 per unused hand at cash-out; unused discards pay $0 except on Green Deck
- [ ] Interest: $1 per $5, caps ($25 / $50 / $100), and **exact timing** relative to blind reward and hand money
- [ ] Green Deck payout rules
- [ ] Reroll base cost and increment; reset timing
- [ ] Glass break chance and xMult
- [ ] Gold card and Gold seal payouts, and when they trigger
- [ ] Blue seal: "last played hand" at end of round
- [ ] Lucky card odds and payouts
- [ ] Ante base chip requirements per ante and stake scaling; boss multipliers (The Wall, Violet Vessel)
- [ ] Final-ante (showdown) boss pool
- [ ] Rental cost per round; Perishable round count
- [ ] Wheel of Fortune edition weights (believed 50% Foil / 35% Holo / 15% Poly on a hit)
- [ ] Which game functions advance the RNG (so the mod never calls them)
- [ ] A blind is beaten at exactly the required chips (`>=`, not `>`); `grade.lua` assumes `>=`
- [ ] Whether `G.GAME.current_round.hands_left` is already decremented when `G.FUNCS.evaluate_play` runs (decides how the hook computes `is_last_hand`)
