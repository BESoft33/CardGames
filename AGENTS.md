# AGENTS.md

Instructions for AI coding agents in this repository. Read all of it before your first change. If a chat request conflicts with this file, stop and ask the owner.

## 1. Product

A card-game collection for Android and iOS: one app, many games, picked from a lobby. The first game is **Twenty-Nine (29)** as played in Nepal.

Requirements that shape every decision:

- Play as a **guest** or **sign in with Google**; sign in and out at any time.
- Fully playable **offline** against bots, from first launch, with no network.
- **Coins** (virtual currency) earned by playing, by watching rewarded ads, or by purchase.
- **Bots** at several skill levels that never use hidden information.
- Every game and economy action is logged locally, then synced to the remote database when the device is back online.
- All user data is protected at rest, in transit, and on the server.
- Card art comes only from **owner-provided assets**.

## 2. Stack

Locked. Ask before changing any row.

| Concern | Choice |
|---|---|
| App | Flutter (stable channel), one codebase for Android and iOS |
| State, routing | Riverpod, go_router |
| Rules and bots | Pure Dart packages, shared by the app and the server |
| Local storage | Drift (SQLite) with an encrypted database; keys and tokens in `flutter_secure_storage` |
| Backend | Supabase: Auth (Google + anonymous), Postgres with row-level security (RLS) |
| Server logic | Dart service in `server/`: log validation by replay, wallet, multiplayer tables |
| Ads | `google_mobile_ads` rewarded ads with server-side verification (SSV) |
| Purchases | `in_app_purchase` with server-side receipt validation |

- Use the latest stable version of every package and read its current docs before calling it. Do not write plugin or SDK code from memory.
- A new dependency needs a one-line justification in the commit message.
- No web or desktop targets.

## 3. Repository layout

```
.
├── AGENTS.md                  # this file
├── CLAUDE.md                  # one line: @AGENTS.md
├── pubspec.yaml               # pub workspace root
├── apps/mobile/               # Flutter app
│   ├── lib/app/               # bootstrap, routing, theme, providers
│   ├── lib/features/          # auth, lobby, wallet, store, ads, settings
│   ├── lib/features/games/twentynine/   # UI only, no rules
│   ├── lib/data/              # local db, event log, sync, API clients
│   ├── lib/shared/            # PlayingCard widget, CardAssetResolver
│   └── assets/cards/          # owner-provided, read-only
├── packages/
│   ├── game_core/             # cards, deck, RNG, GameDefinition, PlayerView, events
│   ├── game_twentynine/       # 29 rules engine
│   ├── bots/                  # bot framework and policies
│   └── sync_protocol/         # event envelope and DTOs shared with the server
├── server/                    # Dart service
├── supabase/                  # SQL migrations, RLS policies
├── tool/                      # check.sh, bot_arena.dart
└── docs/                      # decisions.md, bot-benchmarks.md, MISSING_ASSETS.md
```

## 4. Commands

```bash
flutter pub get                                      # repo root
dart format --output=none --set-exit-if-changed .
flutter analyze
(cd packages/game_twentynine && dart test)           # same for game_core, bots, sync_protocol, server
(cd apps/mobile && flutter test)
(cd apps/mobile && dart run build_runner build --delete-conflicting-outputs)
(cd apps/mobile && flutter run --dart-define-from-file=env/dev.json)
tool/check.sh                                        # format + analyze + every test suite
dart run tool/bot_arena.dart --a expert --b skilled --deals 2000
```

- Create `tool/check.sh` in the first milestone. It must pass before any task is reported as done.
- Release builds: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols` and `flutter build ipa --release --obfuscate --split-debug-info=build/symbols`.
- iOS builds need macOS and Xcode. If you cannot build for iOS in your environment, say so; do not report it as working.

## 5. Architecture rules

1. **Rules are pure Dart.** Nothing under `packages/` imports Flutter, `dart:ui`, or `dart:io`.
2. **The engine is a deterministic reducer.** `apply(state, action)` returns a new state. No clocks, no I/O, no global randomness. The same seed and the same actions give the same state on the device and on the server.
3. **Own the RNG.** Implement a seeded PRNG in `game_core` (xoshiro256** or PCG) and a Fisher–Yates shuffle with unbiased bounded integers, so the sequence is defined by our code. Seeds come from `Random.secure()`. Never bias a shuffle.
4. **Every game implements one interface** and registers in `GameRegistry`:

   ```dart
   abstract interface class GameDefinition<S, A, V> {
     String get id;                        // 'twentynine'
     int get rulesVersion;
     S init(MatchConfig config, int seed);
     List<A> legalActions(S state, Seat seat);
     S apply(S state, A action);           // throws IllegalActionException
     V viewFor(S state, Seat seat);        // everything that seat may see, nothing more
     MatchResult? result(S state);
   }
   ```

5. **`PlayerView` is the visibility boundary.** The UI for a seat and every bot receive a `PlayerView`, never the full state (see §8.1).
6. **State changes only through logged events** (see §9). If it is not in the log, it did not happen.
7. **A released `rulesVersion` is frozen.** A behaviour change needs a new version; the server keeps old versions so old logs still replay.
8. **Features depend on interfaces** (`AuthRepository`, `WalletRepository`, `SyncRepository`, `AdsService`, `PurchaseService`), each with a fake for tests.
9. **Adding a game** means a new `packages/game_<id>/`, a registry entry, and UI under `features/games/<id>/`. Auth, wallet, sync, ads and store stay untouched.
10. **UI.** Local player at the bottom, partner at the top. Seating on screen must match the configured play direction (counter-clockwise means the next player is on the right). All strings live in ARB files so Nepali can be added later.

## 6. Twenty-Nine (29): complete rules

Card IDs are rank + suit: `JH`, `10S`, `7C`. Suits are `S H D C`.

### 6.1 Setup

- Four players in two fixed teams; partners sit opposite. Seats 0–3 in play order; teams are {0, 2} and {1, 3}.
- 32 cards: 7, 8, 9, 10, J, Q, K, A in each suit.
- Rank in every suit, high to low: **J, 9, A, 10, K, Q, 8, 7**.
- Card points: J = 3, 9 = 2, A = 1, 10 = 1, K/Q/8/7 = 0. That is 28 in the deck. The last trick adds 1, for 29.
- Traditionally the spare 2s–5s mark the trump and the 6s keep score (red pips positive, black pips negative). Show both in the UI.
- **Corner score display.** Each team keeps a fixed pair of sixes in a top corner of the table: 6♠ and 6♦ for the player's team (top left), 6♥ and 6♣ for the opponents (top right). The pair's red six counts game points won, its black six game points lost.
  - At 0, both sixes of the pair lie side by side, not overlapping.
  - At ±1 to ±5, the six of that sign shows that many pips, from the owner's `_visible` art (§13). At ±6 the match is over and the whole six shows.
  - One match card, 5, 4, 3 or 2, shows the net match record in the game (§6.13), in one corner only: the leading team's in its red suit, or the trailing team's in its black suit.

### 6.2 Rule configuration

Every option lives in `TwentyNineConfig`. A host player can change the rules according to the following table. Never hard-code one. Defaults are the Nepal table rules.

| Key | Default | Alternative |
|---|---|---|
| `direction` | counter-clockwise | clockwise |
| `minBid` | 16 | 15 |
| `lastTrickPoint` | on (29 points, `maxBid` 29) | off (28 points, `maxBid` 28) |
| `askTrump` | optional; asker must then play a trump if holding one | mandatory ask, no duty to trump |
| `allPass` | dealer must bid `minBid` | redeal |
| `pair` | on | off |
| `doubleRedouble` | on | off |
| `seventhCard` | on | off |
| `redealChecks` | on | off |
| `singleHand` | on | off |
| `targetGamePoints` | 6, fixed | none: players cannot change it |
| `redealRoatation` | off | on |

"Next player" below always means next in the configured direction. The **first player** is the one next to the dealer (dealer's right when counter-clockwise).

`targetGamePoints` is fixed at 6, because games (§6.13) and the corner display (§6.1) count on it. The engine keeps the key so released logs still replay (§5.7).

### 6.3 Sequence of a deal

1. The first dealer is random. The deal passes to the next player after each deal.
2. Shuffle; deal four cards to each player.
3. Redeal check A (§6.7).
4. Auction (§6.4).
5. Trump selection (§6.5).
6. Double and redouble (§6.6).
7. Deal four more cards each; everyone holds eight.
8. Redeal check B (§6.7).
9. Single-hand window, if enabled (§6.8).
10. Play eight tricks (§6.9), with Pair declarations (§6.10).
11. Score the deal and test for match end (§6.11).

### 6.4 Auction

- Players bid on their first four cards only.
- Bidding goes in the direction of the deal, from the first player. Only two players bid at a time: at first, the first player and the next one.
- The **old bidder**, the one of the two in the auction longer, speaks first. With no bid yet, they open with a bid from `minBid` to `maxBid`, or pass.
- Facing the new bidder's bid, the old bidder may **match** it (take it at the same number), raise it, or pass. The **new bidder** must raise or pass. A pass is final for that deal.
- When one of the two passes, the next player in order joins against the one left, who is now the old bidder.
- When one of the last two passes, the other is the **bidder**, and the highest bid is the contract. A bid nobody can go over ends the auction: `maxBid`, once the old bidder has matched it or passed.
- If the first three players pass without a bid, the dealer must bid `minBid`.
- The bidder names trump (§6.5).

### 6.5 Trump

- The bidder secretly chooses a trump suit. Nobody else, partner included, knows it until it is revealed.
- **Seventh card** (if enabled): instead of choosing, the bidder calls "seventh card". The third card of the bidder's second batch (their seventh overall) is set aside face down and its suit is trump. Only the bidder may look at it. Until trump is revealed:
  - it does not count as part of the bidder's hand for following suit;
  - it cannot be led, unless it is the bidder's only remaining card;
  - if the bidder cannot follow suit from hand, the bidder may discard or reveal trump (§6.9).
  When trump is revealed the card is shown to all and joins the bidder's hand. Playing it as the last card also reveals trump.

### 6.6 Double and redouble

After trump is chosen and before the second deal:

- Each opponent of the bidder, in play order, may say **double**. The stake becomes 2.
- If doubled, the bidder and then the bidder's partner may say **redouble**. The stake becomes 4.

### 6.7 Redeal checks

House rules; on by default. A redeal is a fresh shuffle by the same dealer with no score, logged as `dealCancelled` with the reason.

- **A, after the first four cards:** the first player holds no point card (no J, 9, A or 10).
- **B, after all eight cards:** any player holds no point card, or all four Jacks, or eight cards of one suit.
- **C, a team doesn't have trump suit:** if both players combined, in a team don't get a trump suit, the deal is cancelled (only after all 8 cards are distributed).

### 6.8 Single hand

Off by default. After the second deal and before the first lead, a player may declare **single hand**: they must win all eight tricks alone.

- There is no trump for this deal, and any double or redouble is void.
- The declarer leads. The declarer's partner puts their hand face down and is skipped; tricks have three cards.
- All eight tricks won: the declarer's team scores +3 game points. Otherwise −3.
- If several players want it, priority runs in play order from the first player.

### 6.9 Play

- The first player leads the first trick. The winner of each trick leads the next.
- You must follow the suit led if you can.
- **Cannot follow, trump still hidden.** Choose one:
  - play any card without asking; it has no trump power, even if trump is revealed later in the same trick; or
  - ask for trump. The bidder's trump is shown to everyone, and you must then play a trump if you hold one, otherwise any card.
  The bidder has the same choice: discard, or reveal their own trump and then play a trump if able.
- **Cannot follow, trump revealed.** Play any card. There is no duty to trump.
- Only a player who cannot follow suit may ask for trump.
- Before the reveal the trump suit has no power: the highest card of the suit led wins, and the bidder may lead trump-suit cards like any others.
- A trump-suit card is a trump only if it is played after trump is revealed. From the reveal onward, the highest trump in a trick wins it. A trump-suit card played on another suit before the reveal is a plain card, even in the trick in which trump is revealed; the revealer's own card, played right after asking, counts, and so does a seventh card that reveals trump by being played. With no trump in the trick, the highest card of the suit led wins.
- When the trump suit itself is led, every card of it follows suit: the highest card of it wins, whether trump was revealed before the trick, during it, or not at all.
- If all eight tricks end with trump never revealed, the deal is void and nobody scores.

### 6.10 Pair (also Royals or Marriage)

The Pair is the King and Queen of trump held in one hand. A player may declare it only when all of these hold:

- trump has been revealed;
- the player still holds both cards;
- the player's team has just won a trick, at or after the trick in which trump was revealed.

Offer the declaration immediately after such a trick, before the next lead. Effect on the contract target (bidder's team point reduce takes effect only if the bid >= 20):

- declared by the bidder's team: `target = max(minBid, bid − 4)`;
- declared by the opponents: `target = min(maxBid, bid + 4)`.

At most one Pair per deal. There is no Pair in a single-hand deal.

### 6.11 Scoring

- A team's card points are the values of the cards in the tricks it won, plus 1 for the last trick if `lastTrickPoint` is on.
- If the bidder's team reaches the target, it gains the stake in game points; otherwise it loses the stake. Only the bidding team's score changes.
- Stake: 1 normally, 2 doubled, 4 redoubled, 3 for single hand.
- The match ends when a team reaches +6 (that team wins) or −6 (that team loses).

### 6.12 Engine invariants (must be tested)

- 32 unique cards; card points total 28; team points sum to 28 or 29 in every completed deal.
- `legalActions` is never empty for the seat to act, and `apply` rejects anything outside it.
- Replaying a seed and its action list reproduces the same state hash.
- No seat's `PlayerView` exposes another hand, undealt cards, the seed, or a hidden trump.

### 6.13 Games

A **game** is a series of matches at one table, with the same rules, seats and table fee.

- **Match record:** each team's matches won minus matches lost in the game, so a win cancels a loss. It is computed from the logged match records, never kept as a separate counter.
- **Match card:** one card shows the record: 5 at 1, 4 at 2, 3 at 3, 2 at 4, none at 0 (§6.1). When a match takes the record away from level, the card goes to the winning team in its red suit if the match ended with that team reaching +6, or to the losing team in its black suit if it ended with that team reaching −6. A match that brings the record back toward level leaves the card where it is, one step lower. Each card replaces the last.
- **Continue vote:** after each match the players vote whether to play the next one (§7). Against bots only the player votes.
- **End:** the game ends after the match played with a 2 showing (there is no vote after it), when the vote ends it, or when a player quits.
- **Tie:** a game the vote ends with the record level is tied (§11).

## 7. Multiplayer rules (online tables)

Offline play is one human with three bots. Online play follows these rules.

**Tables**

- A table has four seats, two teams, and one `TwentyNineConfig` fixed at creation and shown to every player before they sit. It cannot change during a match.
- **Quick match:** random seating, default config.
- **Private table:** six-character invite code; the host picks the config and seats. Partners sit opposite.
- Seats still empty after the matchmaking timeout are filled by bots, labelled as bots.
- One account holds one seat at one live table.

**Authority**

- The server shuffles with a CSPRNG, holds the only full state, and validates every action with `game_twentynine`.
- Each client receives only its own `PlayerView` updates. No client ever receives another hand, the hidden trump, or the seed.
- Clients send intents carrying `actionId` (UUID), `matchId` and the expected `seq`. Duplicates are ignored. Out-of-turn or illegal intents are rejected with a reason, and the client resyncs from the server view.
- Client and server must share the same `rulesVersion`; otherwise the app asks the player to update.

**Timing and absence**

- Turn timers (configurable): 20 s for auction, trump and doubling decisions; 15 s for a card.
- On timeout the server acts for the seat: pass in the auction, no double, a legal card chosen by the Casual bot. A Pair is declared automatically.
- After two timeouts in a row the seat is marked away and a bot plays it until the player acts again.
- A disconnected player may rejoin at any time before the match ends and receives a fresh view. A bot covers the seat meanwhile.
- Leaving on purpose forfeits the match and ends the game for that player; the pot goes as §11 says. A bot finishes the seat so the others can play on.

**Conduct**

- During a deal in quick match there is no free text or voice, only fixed emotes and phrases that say nothing about cards. Private tables may enable chat.
- **Continue vote:** after each match every human votes, within 15 s, whether to play the next match of the game (§6.13). The game goes on only if all vote to continue; a missing vote counts as no. Bots always vote to continue. A new game needs every human to accept within 15 s.

**Stakes and records**

- The server debits entry fees at match start and credits payouts at match end through the wallet ledger (§11), with the penalties and refunds of §11. A match abandoned through server fault is refunded.
- The server logs every online match with the event envelope in §9. The server log is the source of truth.
- Online tables need a connection. If it drops, offer offline play; never simulate an online match on the device.

## 8. Bots

### 8.1 Fair-play contract

- A bot's only inputs are the `PlayerView` for its seat, its own RNG, and a search budget.
- `PlayerView` holds exactly what a human in that seat can see: own hand; bid history, bidder and contract; cards played to the current and earlier tricks; tricks and points per team; whether trump is revealed and, if so, the suit; any declared Pair; double state; game score. The chosen trump or seventh card is included only for the bidder.
- A bot never has: other players' hands, its partner's hand, undealt cards (the second four during the auction), the deck seed, or a hidden trump it did not choose.

Enforcement, all required:

1. `BotPolicy.decide(PlayerView view, BotContext ctx)` is the only entry point.
2. Bots run in their own isolate. Only the serialised `PlayerView` crosses the boundary, so the real state is unreachable.
3. Any world a bot searches is built from its own samples with its own RNG, seeded independently of the deck.
4. CI tests:
   - **View equivalence:** two different full states with equal views for a seat, same bot seed and budget, give the same decision.
   - **Hidden shuffle:** redistribute unseen cards among the other seats with the view unchanged; the decision does not change.
   - **Serialisation:** a non-bidder's view before the reveal contains no trump suit and no card from another hand.

Difficulty comes only from how well a bot thinks. Never rig deals, peek, or adjust shuffles for or against anyone. Bots use the same legal-move generator and timers as humans, and their actions are logged like any other.

### 8.2 Why not plain chess search

A chess engine runs alpha-beta over a fully visible board. In 29 the hands are hidden, and for three players so is the trump. The bot therefore reasons over possible deals and runs chess-style search inside each one.

### 8.3 Building blocks

1. **Belief tracker**, built from the view only.
   - Hard constraints: own hand; cards already played; hand sizes; a player who failed to follow a suit holds none of it; a player who asked for trump and then played a non-trump holds no trump; a declared Pair fixes K and Q of trump; the seventh card is set aside.
   - Soft weights: the bidder probably holds J or 9 and length in trump; a higher bid implies a stronger first four cards; early passers are weaker.
   - Before the reveal, a non-bidder keeps a probability for each suit being trump and updates it from the bidder's play.
2. **Determinisation.** Sample complete deals consistent with the hard constraints, weighted by the soft ones.
3. **Alpha-beta minimax** inside one sampled deal, teams as max and min. Use a transposition table with Zobrist hashing, move ordering (winners and point cards first), and merging of equivalent cards. Depth-limit with a heuristic evaluation early in the deal; search to the end from about trick 4.
4. **PIMC (Perfect Information Monte Carlo).** Solve each sampled deal with step 3 and pick the move with the best average result.
5. **ISMCTS (Information Set Monte Carlo Tree Search).** One tree over what the bot knows; each iteration samples a deal; UCB1 with availability counts. It avoids PIMC's habit of assuming it will know the hidden cards later.
6. **Exact endgame.** When few consistent deals remain (about 2,000 or fewer), enumerate all of them instead of sampling.
7. **Objective.** Maximise the chance of the contract outcome: the bidder's side wants P(points ≥ target), the defenders want P(points < target). Use expected points only to break ties.
8. **Bidding, trump and doubling.** For each candidate trump, Monte Carlo over the unseen cards with fast heuristic playouts to estimate the team's points. Bid up to the highest value whose success chance clears the level's risk threshold. Double or redouble on the same estimate. Always declare a Pair.

### 8.4 Skill levels

| Level | Method | Limits |
|---|---|---|
| 1 Beginner | Legal move from a few rules; bids from a point-count table | 25% random moves |
| 2 Casual | Heuristics; remembers only the current trick and the trump | 10% random moves |
| 3 Skilled | Heuristics, full card counting, void tracking, one-trick lookahead, small Monte Carlo bidding | none |
| 4 Expert | PIMC with alpha-beta and exact endgame | about 40 deals per move |
| 5 Master | ISMCTS with weighted sampling, exact endgame, Monte Carlo bidding | about 0.8 s per move |

- Tune levels only with these knobs: sample count, search budget, inference on or off, memory, mistake rate.
- Budgets are counted in iterations or nodes so results are reproducible; wall-clock caps are a safety net.
- Add a cosmetic 0.6–1.8 s delay before a bot acts.
- `tool/bot_arena.dart` plays duplicate deals with seats swapped. Each level must beat the one below by a statistically significant margin. Record results in `docs/bot-benchmarks.md`.

## 9. Event log and offline sync

Every state-changing action is an immutable event, appended to the encrypted local database first and uploaded later. Gameplay never waits for the network.

**Envelope** (defined in `sync_protocol`)

```json
{
  "eventId": "uuid-v7",
  "matchId": "uuid",
  "seq": 42,
  "type": "twentynine.cardPlayed",
  "actor": "seat:2",
  "payload": { "card": "JH" },
  "clientTime": "2026-10-04T10:15:30.123Z",
  "userId": "…",
  "deviceId": "…",
  "gameId": "twentynine",
  "rulesVersion": 1,
  "appVersion": "…",
  "prevHash": "…",
  "hash": "sha256(prevHash + canonicalJson(event))"
}
```

**What is logged**

- Match: created (config, seats, bot levels), deal started (seed), deal cancelled (reason), deal scored, match ended.
- Game (§6.13): the game and the match's number in it (in match created), continue vote, quit with the score at that moment, game ended (reason and match record).
- Moves: bid, pass, trump chosen, seventh card called, double, redouble, single hand declared, card played, trump asked, trump revealed, Pair declared, trick won, timeout action.
- Economy: entry fee, reward pending (quit and tie refunds included), penalty pending, ad reward requested, purchase started.
- Session: sign-in, sign-out, sync started, sync result.
- Never: tokens, email addresses, or other personal data.

**Local store**

- Each event has a `syncState`: `pending`, `sent`, `acked` or `rejected`.
- Events are namespaced by user ID. One user's log is never shown or uploaded under another.
- After the server acknowledges a match, delete its events and keep only a compact summary for the history screen. The log is temporary by design.
- If unsynced data hits the storage cap, stop awarding pending coins and ask the player to go online. Never drop pending events silently.

**Sync**

1. Trigger on connectivity regained, app foreground, match end, and a background task where the OS allows.
2. Upload per match, in `seq` order, in batches of at most 200 events, compressed.
3. The server upserts by `eventId` (so retries are harmless), checks `seq` continuity and the hash chain, then replays the match with the same `rulesVersion`.
4. A match that replays cleanly is acknowledged and its rewards are credited. A match that does not is rejected with a reason, earns nothing, and is flagged.
5. Retry with exponential backoff and jitter. Resume from the last acknowledged `seq`.

Tests must cover duplicate upload, an interrupted batch, out-of-order arrival, a tampered chain, and sync after sign-in from guest.

## 10. Accounts

- **Guest** is the default. First launch creates a device-local profile with a random UUID and works with no network. On first connection, silently create an anonymous Supabase user and bind the profile to it.
- **Google sign-in** uses the native Google flow and exchanges the ID token with Supabase. Link the Google identity to the current anonymous user so progress carries over under the same user ID.
- If that Google account already has a profile, switch to it. The server moves the guest's unsynced logs and pending rewards after validation. Never merge on the client.
- **Sign-out:** try to flush the sync queue. If events remain unsynced, tell the player, keep them encrypted under that user ID, and upload them at the next sign-in. Revoke the session, delete tokens, and return to a guest profile.
- A signed-in player keeps playing offline on the cached session. Signing in needs a connection; say so plainly.
- Provide in-app account deletion that removes server data.
- Keep providers behind `AuthRepository` so another one (for example Sign in with Apple) can be added without touching features.

## 11. Coins

- One soft currency, integers only. Name and all amounts live in one config file; never scatter numbers through code.
- **The server owns the balance.** The wallet is an append-only ledger in Postgres (`user_id`, `delta`, `reason`, `ref_id`, `created_at`) with a unique key on (`user_id`, `reason`, `ref_id`) so nothing is credited twice.
- The client never sends a balance or an amount. It sends events; the server computes the delta.
- **Earning by play:** the device shows a pending reward at once. On sync the server recomputes it from the replayed log and credits the ledger. The UI shows confirmed and pending separately.
- **Offline earnings** are capped per day, because an offline device can be tampered with. State the cap in the config.
- **Rewarded ads:** credit only on the ad network's server-side verification callback. Ads need a connection. No ads during a deal. Use test ad units in debug builds.
- **Purchases:** consumable products through the platform stores only. Grant coins only after the server validates the receipt, then complete the transaction. Handle pending and interrupted purchases on next launch.
- **Spending:** table entry fees now; cosmetics later.
- **Stakes** (amounts in the config; docs/decisions.md D-024):
  - **Pot:** with four people, all four fees, split among the winners. Against bots, twice the player's fee; bots never win or lose coins.
  - **Deal bonus:** each deal a team wins pays each of its players a share of their own fee.
  - **Loss penalty:** each losing player adds 25% of the match pot at match end, charged after the continue vote (§7). It still applies if the vote ends the game.
  - **Quitting against bots** returns a share of the pot, by the player's team score at that moment: 50% from −3 to +3, 25% below −3, 75% above +3. There is no loss penalty.
  - **Quitting against people** gives the whole pot to everyone still playing, the quitter's partner included.
  - **Tied game** (§6.13): every table fee of the game is refunded. Winnings and deal bonuses are kept; penalties are not refunded.
  - Beating bots earns nothing beyond this.
  - The server alone applies penalties and refunds, from the replayed logs; the device only shows them as pending.
- Coins have no cash value: no cash-out, no transfer between players, no trading.

## 12. Data protection

- **At rest:** the local database is encrypted with a random 256-bit key held in the Keychain or Android Keystore. Tokens live only in secure storage, never in preferences, files or logs. Exclude the database from device backups.
- **In transit:** HTTPS and WSS only; no cleartext traffic on either platform.
- **Server:** RLS on every table; a user reads only their own rows; wallet and match-result tables are written only by the server role. The service-role key never ships in the app.
- **Secrets:** nothing secret in the repo. Use `--dart-define-from-file` with git-ignored env files and CI secrets. Never commit keystores, provisioning profiles or `.env` files.
- **Integrity:** the hash chain catches corruption and casual edits; server replay is the real check. Add Play Integrity and App Attest in the hardening milestone.
- **Minimisation:** store the provider user ID, display name and avatar URL. Do not store or log email unless the owner asks.
- **Logging:** no personal data, tokens, or hidden game information (other hands, hidden trump) in console logs or crash reports.
- **Consent:** show the ad-consent form and the iOS tracking prompt before requesting personalised ads. Link a privacy policy from settings.
- **Release:** obfuscate Dart code and keep the symbol files out of the repo.

## 13. Assets

- The owner supplies card art in `apps/mobile/assets/cards/`. Use only these files. Do not generate, download, redraw, rename, recompress or edit them.
- Before writing the resolver, list the folder and infer the naming scheme and format (PNG, WebP or SVG). If it is ambiguous, ask.
- All card images resolve through one `CardAssetResolver` (card ID → asset path). No asset path appears anywhere else.
- 29 needs 32 faces (7 to A in four suits) and a card back. If 2s–6s are supplied, use them for the trump marker and score pips; otherwise draw those in code and note it. The corner score display (§6.1) also needs `6_of_<suit>_<pips>_visible` for 1 to 5 pips in each suit of the two pairs.
- If a file is missing, show a clearly labelled placeholder in debug builds and add the file name to `docs/MISSING_ASSETS.md`. Never ship a substitute.
- A test must assert that every card ID used by a registered game resolves to a file declared in `pubspec.yaml`.

## 14. Testing and definition of done

- **Engine:** a table-driven scenario test for every rule in §6, property tests (10,000 random legal matches never throw and keep the §6.12 invariants), and golden replays. Line coverage for `game_twentynine` at least 95%.
- **Bots:** the three fair-play tests in §8.1, plus an arena run when a bot changes.
- **Sync and wallet:** against a fake server, covering the cases in §9; ledger idempotency.
- **App:** widget tests for guest start, sign-in, sign-out, lobby, a full offline deal, and the wallet screen.

A task is done when `tool/check.sh` passes, new behaviour has tests, any decision is recorded in `docs/decisions.md`, and your summary states what you verified and what you could not (for example "not run on a physical iOS device").

## 15. Milestones

Work in order. Stop and report at the end of each.

1. **Scaffold:** workspace, lints, `tool/check.sh`, app shell, `CardAssetResolver` and its test.
2. **Engine:** `game_core` and `game_twentynine` with the full §6 test suite. No UI.
3. **Bots 1–3** and the arena tool, with the fair-play tests.
4. **Offline 29:** table UI with the provided assets, encrypted local event log.
5. **Shell:** lobby and game registry, guest profile, settings, wallet with pending rewards.
6. **Backend:** Supabase schema and RLS, Google sign-in and sign-out, guest linking, sync, server replay, ledger.
   - 6a. **Score display:** the corner sixes and match cards of §6.1; target fixed at 6.
   - 6b. **Games against bots:** §6.13 with the continue vote, the match record from logged match records, and the §11 penalties and refunds, applied on the server only.
7. **Bots 4–5:** PIMC, ISMCTS, exact endgame, benchmarks.
8. **Monetisation:** rewarded ads with SSV, purchases with receipt validation.
9. **Online multiplayer** per §7.
10. **Hardening:** attestation, account deletion, consent flows, store checklists.

## 16. Boundaries

**Ask first**

- Changing the stack, a rule default in §6.2, any economy number, or a migration that has already run.
- Adding a paid service or a dependency with native code.
- Anything that touches store listings, signing, or production data.

**Never**

- Give a bot anything beyond its `PlayerView`, or bias a shuffle.
- Credit coins on the client or trust a client-supplied amount.
- Commit secrets, or put production ad or product IDs in debug builds.
- Modify or replace provided assets.
- Disable RLS, a lint, or a failing test to get a green run.
- Log personal data or hidden game information.
- Report something as working that you did not run.

## 17. Open questions for the owner

Ask this before the milestone that needs it.

1. What is the pot at a table that mixes people and bots (§11)?

Settled, with where the answer is kept: rule defaults (§6.2; docs/decisions.md D-010), assets (§13; D-006), currency and every number (§11; D-024), app identity (D-007), the Supabase project (D-029).

Not questions but checks, at the milestones that need them: Sign in with Apple under Apple's current guidelines, and age ratings and the stores' simulated-gambling policies, before submission (Milestone 10); a host for `server/` before the backend goes live (docs/backend-setup.md).
