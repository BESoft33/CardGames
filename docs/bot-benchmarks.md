# Bot benchmarks

Results of `tool/bot_arena.dart` (AGENTS.md §8.4). Each level must beat the
level below it by a statistically significant margin. Run the arena again
whenever a bot changes, and replace the results below.

## Method

- **Duplicate deals.** Each deal is played twice with the same cards and the
  same dealer: once with bot A at seats 0 and 2, once with A at seats 1 and
  3. A deal's score is A's game points minus B's over both plays, so the luck
  of the cards largely cancels out.
- **Rules.** The defaults of AGENTS.md §6.2. Each play is the first deal of
  a match, scored as the engine scores it.
- **Significance.** A two-sided z-test on the mean score per deal. A level
  passes when p < 0.01 and its mean is positive.
- **Fairness check.** A level against itself should land close to 0.
- **Fair play.** Bots see only their seat's view, serialised as JSON, and use
  their own random numbers, never the deck's (§8.1).

## Results

Recorded 2026-10-05: seed 2026, 4,000 duplicate deals (8,000 plays) per
pairing, 8 worker isolates.

| A | B | A's mean per deal | 95% interval | z | p | Verdict |
|---|---|---|---|---|---|---|
| casual | beginner | +0.316 | 0.282 to 0.350 | 18.22 | < 0.000001 | Casual stronger |
| skilled | casual | +0.460 | 0.417 to 0.502 | 21.21 | < 0.000001 | Skilled stronger |
| skilled | beginner | +0.712 | 0.676 to 0.748 | 38.64 | < 0.000001 | Skilled stronger |
| beginner | beginner | -0.015 | -0.046 to 0.015 | -0.98 | 0.33 | fair |
| casual | casual | -0.013 | -0.041 to 0.015 | -0.89 | 0.37 | fair |
| skilled | skilled | -0.021 | -0.064 to 0.021 | -0.99 | 0.32 | fair |

Recorded 2026-10-10 for Milestone 7: seed 2026, 8 worker isolates; 4,000
duplicate deals per pairing unless the A column says otherwise. Master's
pairings take 15 to 35 minutes, so the two that only check Master further
are shorter.

| A | B | A's mean per deal | 95% interval | z | p | Verdict |
|---|---|---|---|---|---|---|
| expert | skilled | +0.135 | 0.097 to 0.172 | 7.02 | < 0.000001 | Expert stronger |
| master | expert | +0.086 | 0.053 to 0.120 | 5.07 | < 0.000001 | Master stronger |
| master (2,000) | skilled | +0.291 | 0.238 to 0.345 | 10.76 | < 0.000001 | Master stronger |
| expert | expert | -0.032 | -0.065 to 0.001 | -1.88 | 0.061 | fair |
| master (1,000) | master | +0.013 | -0.046 to 0.072 | 0.43 | 0.67 | fair |

Rechecked 2026-10-10 after trump was given power only from the reveal
(docs/decisions.md D-040), which changes the bots' simulation: seed 2026,
800 duplicate deals each.

| A | B | A's mean per deal | 95% interval | z | p | Verdict |
|---|---|---|---|---|---|---|
| expert | skilled | +0.134 | 0.050 to 0.218 | 3.11 | 0.0019 | Expert stronger |
| master | expert | +0.106 | 0.036 to 0.176 | 2.98 | 0.0029 | Master stronger |

Rechecked again 2026-10-10 after the auction became two at a time, with
the old bidder able to match (docs/decisions.md D-041): seed 2026, 800
duplicate deals each.

| A | B | A's mean per deal | 95% interval | z | p | Verdict |
|---|---|---|---|---|---|---|
| expert | skilled | +0.116 | 0.031 to 0.201 | 2.69 | 0.0073 | Expert stronger |
| master | expert | +0.099 | 0.030 to 0.167 | 2.82 | 0.0047 | Master stronger |

Rechecked after the correction that, when trump itself is led, the
highest card of it wins whenever trump was revealed (D-040): seed 2026,
800 duplicate deals each.

| A | B | A's mean per deal | 95% interval | z | p | Verdict |
|---|---|---|---|---|---|---|
| expert | skilled | +0.128 | 0.044 to 0.211 | 2.99 | 0.0028 | Expert stronger |
| master | expert | +0.176 | 0.104 to 0.248 | 4.78 | 0.000002 | Master stronger |

How often the bidding side made its contract, in the same runs:

| Pairing | A's contracts made | B's contracts made |
|---|---|---|
| casual vs beginner | 64.4% of 4,571 | 52.9% of 3,429 |
| skilled vs casual | 73.8% of 3,342 | 45.6% of 4,658 |
| skilled vs beginner | 76.9% of 3,895 | 41.0% of 4,105 |
| expert vs skilled | 70.0% of 3,724 | 61.4% of 4,276 |
| master vs expert | 70.7% of 3,742 | 64.2% of 4,258 |
| master vs skilled | 74.8% of 1,761 | 57.9% of 2,239 |

## Reading the results

- Scores are per duplicate deal, that is, summed over two plays of the same
  cards. Per single play, Skilled gains about 0.23 game points on Casual and
  Casual about 0.16 on Beginner. A match ends at 6 game points.
- Skilled bids less often than Casual but makes far more of its contracts,
  and defends well enough to beat most of Casual's.
- Skilled doubled 546 of Casual's contracts in its run; Casual made 41.9% of
  those, so the doubles paid.
- Expert gains most in the play: it solves 40 sampled deals with alpha-beta
  where Skilled plays each option out once with a fixed policy. Against
  Skilled it doubled 188 times and the contract was made 46.3% of the time;
  Skilled's 312 doubles of Expert were made against 59.9% of the time.
- Master's edge over Expert is smaller but clear. Most of it comes from
  weighting sampled deals by the auction: it bids better (70.7% of its
  contracts made, against 64.2%) and doubles better (44.3% made against
  52.7%). Without the switch to solving 120 weighted deals from trick 4, and
  with 3,000 rather than 12,000 search iterations, its margin on 800 deals
  was +0.080 (p = 0.04); with both, +0.171 on those 800 deals and +0.086 on
  the 4,000 above (docs/decisions.md D-038).
- Each level beats the one below it with p < 0.000001, and the levels are
  in order: Master beats Skilled by more than Expert does.

## Reproduce

```bash
dart run tool/bot_arena.dart --a skilled --b casual --deals 4000 --seed 2026 --markdown
```

The tool prints a summary and, with `--markdown`, a table row. Results do not
depend on the number of worker isolates. The Milestone 7 rows:

```bash
dart run tool/bot_arena.dart --a expert --b skilled --deals 4000 --seed 2026 --markdown
dart run tool/bot_arena.dart --a master --b expert --deals 4000 --seed 2026 --markdown
dart run tool/bot_arena.dart --a master --b skilled --deals 2000 --seed 2026 --markdown
dart run tool/bot_arena.dart --a expert --b expert --deals 4000 --seed 2026 --markdown
dart run tool/bot_arena.dart --a master --b master --deals 1000 --seed 2026 --markdown
```
