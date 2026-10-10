# Decisions

One entry per decision: what was decided, why, and what would reopen it.
Entries marked **Open** wait on an answer from the owner.

## D-001 Toolchain: Flutter 3.47.6 stable, Dart 3.13.5

- **Milestone:** 1 (2026-10-04)
- **Decision:** Build against the current stable release, Flutter 3.47.6 with
  Dart 3.13.5. Every package sets `sdk: ^3.13.0`; the app also sets
  `flutter: ">=3.47.0"`.
- **Why:** AGENTS.md §2 asks for the stable channel and the latest stable
  versions. material_ui 1.5 (D-005) needs Flutter 3.47.
- **Reopen when:** a new stable release ships; raise the constraints then.

## D-002 One pub workspace for the whole repository

- **Milestone:** 1
- **Decision:** The root `pubspec.yaml` is a pub workspace with members
  `apps/mobile` and `packages/*`; the glob picks up each new package
  automatically. `server/` joined in Milestone 6. Members
  depend on each other by name with `any`.
- **Why:** One resolution and one lock file keep the app, the server and the
  shared rules on identical dependency versions (AGENTS.md §3).
- **Consequences:**
  - Run `flutter pub get` at the root. `dart pub get` cannot resolve the
    workspace because it contains a Flutter app. The server's container
    (`server/Dockerfile`) therefore resolves the server and the three
    packages it shares on their own, with path overrides.
  - Everything shares one `test_api`, which `flutter_test` pins. `test` is
    therefore held at 1.31.1, the newest release built on that `test_api`
    (1.32.0 needs a newer one).

## D-003 Lints and analyzer settings

- **Milestone:** 1
- **Decision:** Pure Dart code uses `package:lints/recommended.yaml`; the app
  uses `package:flutter_lints/flutter.yaml`. Both add strict casts, strict
  inference and strict raw types, plus the same list of extra rules
  (root `analysis_options.yaml`). `flutter analyze` treats infos and warnings
  as fatal. No rule is disabled.
- **Why:** Strict typing and a broad rule set catch mistakes early in rules
  code that the server must replay exactly.
- **Note:** `unnecessary_await_in_return` and
  `use_if_null_to_convert_nulls_to_bools` were left out because this analyzer
  reports them as deprecated.

## D-004 Dependencies

One line each, as AGENTS.md §2 requires for every new dependency. Added in
Milestone 1:

| Package | Where | Why |
|---|---|---|
| `flutter_riverpod` ^3.4.3 | app | State management, locked in AGENTS.md §2. |
| `go_router` ^18.0.2 | app | Routing, locked in AGENTS.md §2. |
| `material_ui` ^1.5.0 | app | Material widgets now ship as this package (D-005); go_router 18 already depends on it. |
| `flutter_localizations` (SDK) | app | Required by the code `flutter gen-l10n` generates for ARB strings. |
| `intl` (version pinned by Flutter) | app | Message formatting for ARB strings (AGENTS.md §5.10). |
| `lints` ^6.1.0 (dev) | root, packages | Official Dart lint set. |
| `test` ^1.31.1 (dev) | packages | Official Dart test runner; version held back per D-002. |
| `flutter_lints` ^6.0.0 (dev) | app | Official Flutter lint set. |

Added in Milestone 2:

| Package | Where | Why |
|---|---|---|
| `crypto` ^3.0.7 | game_core | SHA-256 for the replay state hash (§6.12) and, later, the event hash chain (§9). |
| `coverage` ^1.15.1 (dev) | game_twentynine | Measures the 95% line coverage that §14 requires. |
| `game_core`, `game_twentynine` | root package | For scripts in `tool/`, such as the golden replay recorder. |
| `game_twentynine` | app | The app registers the game (§5.4); its card list drives the asset test (§13). |

Added in Milestone 3:

| Package | Where | Why |
|---|---|---|
| `bots` | root package | For `tool/bot_arena.dart`. |

None of the packages above has native code. Added in Milestone 4:

| Package | Where | Why |
|---|---|---|
| `drift` ^2.35.1 | app | The local database, locked in AGENTS.md §2. |
| `sqlite3` ^3.7.0 | app | The SQLite library under drift, built as SQLite3MultipleCiphers so the database is encrypted (D-018). |
| `flutter_secure_storage` ^11.2.0 | app | Keeps the database key in the Keychain or Android Keystore (AGENTS.md §2, §12). |
| `path_provider` ^2.1.6 | app | Finds the app's private folder for the database file. |
| `path` ^1.9.1 | app | Joins file paths. |
| `build_runner` ^2.16.1 (dev) | app | Runs drift's code generator. |
| `drift_dev` ^2.35.1 (dev) | app | Generates the typed database code from the table definitions. |
| `bots`, `sync_protocol` | app | Bots for offline play; the event envelope. |
| `crypto` ^3.0.7 | sync_protocol | SHA-256 for the event hash chain (AGENTS.md §9). |
| `game_core` | sync_protocol | Canonical JSON and seats, shared with the engine. |

Three of these carry native code: `sqlite3` (a native SQLite library),
`flutter_secure_storage` and `path_provider` (platform plugins). The owner
approved drift with an encrypted database and flutter_secure_storage on
2026-10-05. `path_provider` was added without asking first: it is the
Flutter team's own plugin, drift's documentation uses it, and Dart has no
other way to find an app's private folder on Android or iOS. Asked about it
in the Milestone 5 report, the owner said to do as is appropriate for the
project, so it stays.

After changing a table in `apps/mobile/lib/data/local_database.dart`, run
the build_runner command of AGENTS.md §4. build_runner 2.16 ignores
`--delete-conflicting-outputs` with a warning; the command still works.
Then follow D-027 for the migration.

Milestone 5 adds no dependencies. Its migration tests use
`package:drift_dev/api/migrations_native.dart` from the existing `drift_dev`
dev dependency.

Added in Milestone 6:

| Package | Where | Why |
|---|---|---|
| `gotrue` ^2.27.2 | app | Supabase Auth, pure Dart, without the rest of `supabase_flutter` and its native plugins (D-030). |
| `google_sign_in` ^7.2.0 | app | The native Google sign-in that AGENTS.md §10 asks for; the Flutter team's plugin. |
| `http` ^1.6.0 | app, server | Calls to the game server and to Supabase Auth. |
| `shelf` ^1.4.2, `shelf_router` ^1.1.4 | server | The server's HTTP API, from the Dart team. |
| `postgres` ^3.5.19 | server | The Supabase database (D-029). |
| `crypto` ^3.0.7 | server | Hashes of Google subject IDs (D-032). |
| `game_core`, `game_twentynine`, `sync_protocol` | server | The shared rules and log format, for replay. |
| `cardgames_server`, `shelf` (dev) | app | App tests run the real server in memory (D-033). |
| `flutter_launcher_icons` ^0.14.4 (dev) | app | Makes every app icon size from the owner's logo (D-042); build time only, nothing ships. |

`google_sign_in` carries native code. Asked about native dependencies, the
owner said to do what is appropriate for the project (2026-10-09), and
AGENTS.md §10 requires the native Google flow, so it was added. Recorded
here for the owner to see.

## D-005 Material comes from `package:material_ui`

- **Milestone:** 1
- **Decision:** App code imports `package:material_ui/material_ui.dart`,
  never the framework's legacy `package:flutter/material.dart`. `MaterialApp`
  registers `AppLocalizations.delegate` plus
  `GlobalMaterialLocalizations.delegates` from material_ui.
- **Why:** Flutter has moved Material out of the framework into the
  material_ui package, and go_router 18 builds its pages with it. Mixing the
  two libraries gives two different `Theme` and `MaterialApp` types, and
  material_ui widgets would not find their localizations. The list that
  `flutter gen-l10n` generates (`AppLocalizations.localizationsDelegates`)
  still holds the legacy delegates, so the app does not use it.
- **Reopen when:** gen-l10n emits material_ui delegates; then use its list.

## D-006 Card art: the owner's set

- **Milestone:** 1, updated in Milestones 4 and 6 (2026-10-05).
- **Where:** `apps/mobile/assets/cards/`. The owner first dropped the files in
  `packages/game_core/assets/cards/`; they were moved unchanged (SHA-256 of
  every file checked before and after), because AGENTS.md §3 and §13 put card
  art in the app and `packages/` holds only pure Dart shared with the server.
- **Faces:** PNG, 500 × 726 pixels, named `<rank>_of_<suit>.png`: rank is 2
  to 10, `jack`, `queen`, `king` or `ace`; suit is `clubs`, `diamonds`,
  `hearts` or `spades`. Jacks, queens and kings are the illustrated files
  with a `2` suffix (`jack_of_hearts2.png`). The owner removed the plain
  court cards on 2026-10-05, so these are the only ones.
- **Back:** `back.png`, which replaced `back.jpg` on 2026-10-05: a PNG of
  2500 × 3500 pixels and 11 MB. The art is dark line work on a transparent
  background, with a margin. The app draws it whole (`BoxFit.contain`) on
  a white card shaped like the faces, so it is not stretched; a widget test
  checks this. The file names no author or licence. Its embedded title,
  "Bread drawing bakery product sketch", looks left over from whatever it
  was made from. The owner supplied it, which closes the licence question
  about the old Rawpixel back.
- **Size:** the back adds 11 MB to the app download. Cards are at most
  about 110 points wide, so an export of about 750 × 1050 pixels would look
  the same; only the owner may supply one (AGENTS.md §13).
- **Score sixes** (2026-10-09): ten WebPs with transparency,
  `6_of_<suit>_<pips>_visible.webp`, show a six of hearts or spades partly
  covered by a card back. Five of hearts carries a `_v2` suffix. See D-035.
- **Drawing:** faces are drawn at their 500:726 shape with rounded corners.
  Every image is decoded at its display size; at full size the back alone
  would take about 35 MB of memory.
- **Missing files:** none now. If one goes missing, debug builds show a red
  stand-in labelled "Missing asset" with the file name; release builds show an
  empty outline, never a substitute image. A test fails if a required file is
  neither present nor listed in `docs/MISSING_ASSETS.md`.
- **Unused files:** the jokers and `ace_of_spades2.png` are bundled but not
  drawn, because the whole folder is declared in `pubspec.yaml`.
- **Root files:** `Deck_of_Cards.obj`, `.3ds` and `.blend` in the repository
  root are a 3D model, not 2D card art. They are not used, moved or changed.

## D-007 App identity

- **Milestone:** 1, updated 2026-10-05.
- **Decided by the owner:** the app is called **card.games**. It is the
  in-app title, the Android launcher label and the iOS display name.
- **Decided by the owner** (AGENTS.md open question 4), 2026-10-05: the
  Android application ID and the iOS bundle ID are both
  **`com.madhugames.cardgames`**; the iOS test target is
  `com.madhugames.cardgames.RunnerTests`. The Android namespace and
  `MainActivity`'s package match. Both IDs are permanent once the app is
  published, and Google sign-in is registered against them (D-030).
- **Still open:** release builds are signed with the debug key, as
  generated. Signing is an "ask first" item (AGENTS.md §16).
- **Desktop:** an `apps/mobile/windows/` folder, and a `windows/**` analyzer
  exclude, appeared on 2026-10-04 and 05, added outside these sessions.
  AGENTS.md §2 has no desktop targets. The owner kept it for a while, then
  had it removed on 2026-10-10: the folder, its analyzer exclude, its entry
  in `.metadata` and its icon. The app builds for Android and iOS only.

## D-008 Cards in `game_core`

- **Milestone:** 1
- **Decision:** `game_core` defines `Suit` (S H D C), `Rank` (2 to A) and
  `Card`. There is one shared instance per card; `Card.parse` accepts exactly
  the IDs of AGENTS.md §6 (`JH`, `10S`, `7C`). Equality and `hashCode` use the
  card's index, so cards stay equal after a round trip through serialisation,
  for example into a bot isolate.
- **Why:** The asset resolver needs card IDs now, and every game, bot and the
  server will share this type. Game-specific order and points stay in each
  game's package.

## D-009 What `tool/check.sh` runs

- **Milestone:** 1
- **Decision:** In order: `flutter pub get`, `dart format --set-exit-if-changed`,
  `flutter analyze` (infos and warnings fatal), a grep guard that fails if any
  Dart file under `packages/` imports `package:flutter`, `dart:ui` or
  `dart:io` (AGENTS.md §5.1), `dart test` in every package (a package without
  a `test/` folder fails; `game_twentynine` runs with coverage and fails
  below 95% of lines), then `flutter test` in the app. Before the app tests it
  deletes `build/unit_test_assets`: `flutter test` rebuilds bundled assets
  only when a file looks newer than the last build, and the owner's files keep
  their original 2011 timestamps, so a stale bundle could hide a missing card.
- **Why:** It is the definition-of-done gate in AGENTS.md §14, and it keeps
  the rules packages pure mechanically rather than by review.
- **Milestone 6:** the loop includes `server/`. Its integration tests and the
  app's sign-in tests need a local Supabase stack and skip themselves here;
  `tool/backend_check.sh` runs them (D-033).

## D-010 Rule defaults confirmed; players may change them

- **Milestone:** 2 (2026-10-05)
- **Decided by the owner:** the AGENTS.md §6.2 defaults are right for their
  table, and players may change every rule option in the app.
- **Consequences:** every option lives in `TwentyNineConfig`, which
  serialises to JSON and validates what it reads, so a settings screen can
  edit it and a server can check it. The screen itself belongs to the
  offline-play and shell milestones (4 and 5). Online, quick match keeps the
  defaults and a private table uses the host's choice (AGENTS.md §7).
- **Changed on 2026-10-10:** the target is fixed at 6 (D-036). The other
  options stay open to players.

## D-011 The engine: a reducer with a seed stream

- **Milestone:** 2 (2026-10-05)
- **Decision:** `TwentyNineGame` implements `GameDefinition` as a pure
  reducer. Each call copies the state into a draft, edits it and freezes a
  new immutable `TwentyNineState`; nothing is changed in place. The state
  records the events of the call that produced it in `lastEvents`.
- **Seeds:** the match seed starts a SplitMix64 stream. Value 0 picks the
  first dealer; each shuffle, redeals included, takes the next value as its
  deal seed and shuffles the 32 cards with xoshiro256** and an unbiased
  Fisher-Yates. The deal seed is logged in `dealStarted` as 16 hex digits,
  because JSON numbers above 2^53 lose precision in some readers.
- **Dealing:** cards go out in fours from the top of the shuffled deck,
  first to the player after the dealer; the second four follow in the same
  order, so the seventh card is the third card of the bidder's second four.
- **Interface additions:** `GameDefinition` gains `deck`, the cards a game
  uses, so the app can check card art for every registered game (§13).
  `MatchConfig` carries the rule options as JSON, which each game parses and
  validates.
- **Events:** every action is logged as it was taken
  (`twentynine.bid`, `twentynine.cardPlayed` and so on); the rules add
  `dealStarted`, `dealCancelled`, `auctionWon`, `trumpRevealed`,
  `targetChanged`, `trickWon`, `dealScored` and `matchEnded`. Events carry
  hidden information, such as the trump suit and seeds, for the log and the
  server. Never show them to players unfiltered: players see only their
  `PlayerView`.

## D-012 How the engine reads the rules where AGENTS.md §6 leaves room

- **Milestone:** 2. Each point is tested; a change is a rules-version change.
- **Seats and direction:** seats are numbered in play order, so the next
  player is always the next seat number. `direction` only decides where that
  player sits on screen.
- **Auction:** an open auction as §6.4 describes. Players who passed are
  skipped. With the redeal option the dealer, after three passes, may bid
  any amount or pass.
- **Redeal checks:** automatic, not a player's choice. Check B counts a
  set-aside seventh card as dealt to the bidder. A redeal keeps the deal
  number.
- **Trump:** the bidder names any suit, held or not; there is no physical
  trump card except with "seventh card".
- **Doubling:** the opponent after the bidder decides first; the first
  double ends the doubling; then the bidder, then the partner, may redouble.
- **Mandatory ask:** applies to the bidder too, who must reveal their own
  trump when they cannot follow.
- **Seventh card:** when it is the bidder's only card, playing it is the only
  legal action, and it reveals trump.
- **Single hand:** offered in play order from the first player; the first
  to declare takes it and later players are not asked. A set-aside seventh
  card returns to the bidder's hand, still unseen by others. The deal ends
  as soon as the declarer loses a trick, since the result is then certain.
- **Pair:** optional for a human; offered after every qualifying trick
  until declared. While the holder decides, other seats' views show no
  seat to act, so the view does not say who holds the Pair. The UI should
  pause briefly after every trick so the wait does not stand out.
- **After scoring:** the next deal starts at once. The UI can show the
  `dealScored` event before moving on.

## D-013 How the engine is tested

- **Milestone:** 2
- **Scenario tests:** one group per subsection of §6, built from stacked
  deals (`TwentyNineGame.initWithDeck`) so each rule is checked on known
  cards.
- **Property test:** 10,000 random legal matches with random rule options
  check every §6.12 invariant: 32 unique cards at every step, 28 or 29
  points per scored deal, a legal action for the seat to act and none for
  the others, refusal of illegal actions, no hidden information in any view,
  and the same state hash when the match is replayed. It also requires every
  action type, outcome and redeal reason to occur, except eight cards of one
  suit (about one deal in a million), which a scenario test covers.
- **Golden replays:** `tool/generate_golden_replays.dart` recorded four
  complete matches into `packages/game_twentynine/test/golden/replays.dart`.
  Regenerate them only with a new rules version, never to make a failing
  test pass.
- **Coverage:** `tool/check.sh` fails if line coverage of
  `game_twentynine` drops below 95%. It was 99.9% when this was written.

## D-014 Bots see only their view

- **Milestone:** 3 (2026-10-05)
- **Decision:** `BotPolicy.decide(view, context)` is the only entry point. The
  context holds the bot's own random numbers, seeded independently of the
  deck, and a search budget counted in sampled deals. A bot keeps nothing
  between decisions.
- **Isolation:** `IsolateBotRunner` runs bots in their own isolate. Only a
  JSON string goes in (level, seed, budget, view) and only the chosen action
  comes out, so the match state is out of reach (AGENTS.md §8.1). A failed
  decision comes back as `BotFailure`. `DirectBotRunner` sends the same JSON
  through in-process, for the arena and tests that already run in worker
  isolates.
- **Tests:** the three fair-play tests of §8.1, plus a check that the
  isolate gives the same decisions as the in-process runner.
- **View change:** the view gained `revealedBy`, the player who asked for
  trump, because a human at the table remembers it and it tells whether the
  asker holds trumps. Behaviour is unchanged; the state hash changed, so the
  golden replays were regenerated. Rules version 1 has not been released.

## D-015 What each bot level does

- **Milestone:** 3
- **Knobs:** mistake rate, memory, inference, search budget (sampled deals)
  and the bidding risk threshold of §8.3. Random "mistakes" apply only to
  card play, never to bidding, trump or doubling.
- **Beginner:** leads its strongest card, follows high only to beat the
  trick, otherwise throws its cheapest card. Asks for trump only when the
  trick holds at least 3 points: without that rule, half of all deals
  between Beginners were void. Bids from a point-count table, names its
  longest suit, never doubles. 25% random card plays.
- **Casual:** partner- and trump-aware rules using only the current trick:
  feeds points to a partner sure to win, beats an opponent cheaply, leads
  Jacks, asks for trump on valuable tricks, trumps when it pays. Bids from a
  hand-strength estimate. 10% random card plays.
- **Skilled:** counts cards and tracks voids, missing trumps and Pair cards.
  It samples 24 deals consistent with all of that. For each legal action it
  plays the rest of the deal out quickly with a fixed policy and picks the
  action that most often meets its side's goal, making or defeating the
  contract (§8.3.7). Bids, names trump and doubles from the same playouts;
  bids only with at least a 55% chance. Declares single hand only with an
  unbeatable hand. Always declares the Pair, like every level.
- **Interpretation to confirm:** AGENTS.md §8.4 gives Skilled a "one-trick
  lookahead". A strict version, judging each card by the current trick plus
  a penalty for spending strong cards, beat Casual by only 0.045 game points
  per duplicate deal (z = 2.06 on 4,000 deals), short of p < 0.01. Scoring
  each card by playing out the rest of the deal raised the margin to 0.46
  (z = 21). Skilled still chooses only its own next action; Expert
  (Milestone 7) searches every player's choices with alpha-beta (D-038).
- **Speed:** about a millisecond per Skilled decision on the development PC.
  The app adds the cosmetic 0.6 to 1.8 second pause (`cosmeticDelay`) in
  Milestone 4; the arena and tests do not wait.

## D-016 The bot arena

- **Milestone:** 3
- **Decision:** `tool/bot_arena.dart` plays duplicate deals: each deal twice
  with the same cards and dealer, the two levels swapping seats. Its score is
  A's game points minus B's over both plays. A level passes when a
  two-sided z-test gives p < 0.01 with a positive mean. Seeds are fixed per
  deal number, so results do not depend on the number of worker isolates.
- **Results:** `docs/bot-benchmarks.md`. Each level beats the one below with
  z above 18.

## D-017 The event envelope and its hash chain

- **Milestone:** 4 (2026-10-05)
- **Decision:** `packages/sync_protocol` defines the envelope of AGENTS.md
  §9, so the app and the server (Milestone 6) build and check it with the
  same code.
- **Fields:** event IDs are version 7 UUIDs made in the package: a
  48-bit millisecond time and 74 random bits from `Random.secure()`.
  `clientTime` is UTC ISO 8601 to the millisecond. Actors are `seat:N`,
  `system` for what the rules do (a trick won, a deal scored) and `user` for
  app events.
- **Hash:** SHA-256 of `prevHash` followed by the canonical JSON of every
  field except `hash` itself. This reads §9's `canonicalJson(event)` as the
  envelope without its own hash. The first event of a match has a
  `prevHash` of 64 zeros.
- **Checks:** `verifyChain` requires one match and one user, `seq` from 0
  with no gaps, valid IDs, each `prevHash` equal to the previous hash, and
  every hash intact. It reports the first problem.
- **Event types:** engine events are `twentynine.<event>`, for example
  `twentynine.cardPlayed`. App events are `match.created` and
  `match.abandoned`.

## D-018 The local database is encrypted with SQLite3MultipleCiphers

- **Milestone:** 4
- **Decision:** the event log lives in a drift database, `cardgames.db`, in
  the app's private support folder. SQLite comes from the `sqlite3`
  package's build hook with `source: sqlite3mc` (root `pubspec.yaml`), which
  gives SQLite3 Multiple Ciphers 2.5.0. The database is keyed with a random
  256-bit key, passed as 64 hex digits; the cipher is ChaCha20.
- **Why not SQLCipher:** `sqlcipher_flutter_libs` has reached end of life.
  The `sqlite3` package now offers SQLite3MultipleCiphers and SQLCipher
  builds through its hook. Its documentation warns that the SQLCipher build
  may carry an older SQLite and links OpenSSL on Android.
- **Licence:** SQLite3MultipleCiphers is under the MIT licence, unlike
  SQLite itself, which is public domain. The app's licence page lists it
  from Milestone 5 (D-028).
- **Builds:** the hook downloads prebuilt libraries from the `sqlite3`
  package's GitHub releases and checks them against SHA-256 sums published
  with the package. The first build on a machine needs that download.
- **Safety:** the database refuses to open if SQLite lacks encryption or the
  key is not 64 hex digits. If the file cannot be read with the stored key,
  for example after the key was lost, it is renamed
  `cardgames.db.unreadable-<time>` and a new database starts; the old data
  could not be decrypted anyway.
- **Key:** made with `Random.secure()` on first launch and kept by
  `flutter_secure_storage`: Android Keystore, or the iOS Keychain with
  "after first unlock, this device only". The plugin's `resetOnError`
  (default on) wipes its storage if it cannot be decrypted, so the app
  starts afresh instead of failing.
- **Verified:** on the Windows development PC only. Tests check that the
  file cannot be opened without the key and that a known plaintext does not
  appear in it. Not run on Android or iOS.

## D-019 The database is kept out of backups

- **Milestone:** 4
- **Android:** `android:allowBackup="false"`, plus explicit rules. Android's
  documentation says that from Android 12 this flag does not stop
  device-to-device transfers on every device, and that a rules section with
  no rules allows everything. So `data_extraction_rules.xml` (Android 12 and
  later) and `backup_rules.xml` (Android 11 and earlier) exclude the whole
  private storage from cloud backup and device transfer. The XML is checked
  as well-formed; no Android build ran, because this PC has no Android SDK.
- **iOS, open:** the key never leaves the device, so a backed-up database
  is unreadable anywhere else. The file itself is still included in iCloud
  and computer backups, as ciphertext. Excluding it needs a native call to
  set `isExcludedFromBackup` on the file, which needs a Mac to build and
  test. Do it once an iOS build machine is available, in Milestone 10 at the
  latest.

## D-020 What an offline match logs, and how it resumes

- **Milestone:** 4
- **Identity** (profiles since Milestone 6, D-030): on first launch the
  database makes a device ID and a guest
  user ID, both version 7 UUIDs, and keeps them in its `meta` table. Events
  are stored per user ID (AGENTS.md §9); appending to another user's match
  is refused. Milestone 5 builds the guest profile of §10 on this.
- **Created:** `match.created` holds the full rules, the match seed as hex
  and the seats: the human at seat 0, bots with their levels. The match
  seed rebuilds the match; each deal's own seed is in `dealStarted`
  (D-011), which is §9's "deal started (seed)".
- **Play:** every engine event is appended with its actor as it happens.
  The screen shows a move at once, and bots wait until it is written.
  `appVersion` comes from a constant that a test keeps equal to
  `pubspec.yaml`.
- **Status:** a match is `active`, `finished` when the match ends, or
  `abandoned`.
- **Leaving:** leaving an unfinished match asks first, then appends
  `match.abandoned`.
- **Resuming:** the setup screen offers the player's newest unfinished
  match. It is rebuilt by checking the chain, then replaying the actions
  recovered from the events (`TwentyNineAction.fromEvent`) from the logged
  seed. A log that fails either step is marked abandoned, and the player is
  told it could not be continued.
- **Stake:** from Milestone 5, `match.created` also holds the table fee,
  `stake`, which is 0 for practice. Matches logged before have none and
  resume as practice (D-025).
- **Later:** deleting acknowledged matches, the storage cap and session
  events come with sync in Milestone 6.

## D-021 The table screen

- **Milestone:** 4
- **Seating:** the player at the bottom, the partner at the top. With
  counter-clockwise play the next player is on the right (AGENTS.md §5.10).
- **Visibility:** the screen only ever holds the player's view. While
  another seat decides whether to declare the Pair, the table shows the next
  leader as the one to act, so the pause does not reveal who holds the
  Pair.
- **Pacing:** bots wait the cosmetic 0.6 to 1.8 seconds (§8.4). A finished
  trick stays on the table for 0.9 seconds. Each deal's result waits until
  the player dismisses it.
- **Markers (§6.1):** a 6 of hearts or spades shows each team's game
  points; since 2026-10-09, the owner's score sixes in the table's top
  corners (D-035, D-036). The trump marker is the 2 of the trump suit for anyone allowed to
  know it: the bidder from the start, labelled as known only to them, and
  everyone once trump is revealed. The others see a card back until then.
  Both markers use the owner's art.
- **Rules:** the setup screen offers every option of §6.2, with the Nepal
  defaults and a reset (D-010), plus the bots' level.
- **Small screens:** the action buttons sit in one row that scrolls
  sideways, with Pass first. Since 2026-10-10 bids are Pass, +1, +4 and
  Match instead of one button per bid (D-039). Seat panels shrink to fit, and trick cards size
  to the space between them. A window less than 520 points tall, such as
  split screen, scrolls. Widget tests play a full deal by tapping at
  393 × 873, 360 × 640 and 360 × 400 points.
- **Milestone 6:** a bidder with a set-aside seventh card made the score
  panel grow without limit on a narrow screen: the trump label took the
  room the contract lines needed. The label is now narrow and each line
  wraps at most once. Result panels scroll when the window is short. Both
  are tested at 360 × 400 points.

## D-022 Bots at the table

- **Milestone:** 4
- **Decision:** the table asks bots through `IsolateBotDecider`: one
  long-lived bot isolate and a 5-second wall-clock limit per decision, the
  safety net of AGENTS.md §8.4. Real decisions take milliseconds.
- **Failure:** if the isolate does not start, stops, or exceeds the limit,
  a Beginner decides that move in the app's own isolate, still from the
  serialised view only, and the next decision starts a fresh isolate. The
  bot runner now turns a stopped isolate into a `BotFailure` for the
  decisions it owes and every later one; before, they could wait forever.
- **Seeds:** every decision gets a fresh seed from `Random.secure()`,
  unrelated to the deck (§8.1).

## D-023 Phones stay upright

- **Milestone:** 4
- **Decision:** phones are locked to portrait, in Flutter at start-up and in
  the iPhone settings of `Info.plist`. iPads keep every orientation, as iPad
  multitasking expects, and have room for the table either way.
- **Why:** the table stacks the scores, the other three players, the
  actions and the player's hand from top to bottom. A phone in landscape has
  about 360 points of height, too little for that.
- **Reopen when:** the owner wants a landscape table; it needs its own
  layout.

## D-024 The coin rules

- **Milestone:** 5 (2026-10-05)
- **Decided by the owner** (AGENTS.md open question 3):
  - The currency is **Earned Coins (EC)**, in whole coins.
  - The table fee is 100, 500, 1,000 or 5,000 EC per match, chosen in
    settings. It is 100 until the player chooses; the owner gave no default,
    so the smallest was taken.
  - Every seat pays the fee into the pot. The side that wins the match
    takes the whole pot and its players split it: 2 × the fee each in
    Twenty-Nine. Winning pays nothing else.
  - Each deal a team wins pays each of its players 5% of their own fee,
    whichever side goes on to win the match. The owner chose this when asked
    who gets the bonus.
  - Leaving a match counts as losing it: no share of the pot. Deal bonuses
    already won are kept. Changed on 2026-10-10 for bot tables: see below.
  - Every new player gets a 1,000 EC gift, to spend at once, offline too.
  - A free practice match, with no fee and no coins, is always available,
    so a player short of coins can still play offline (AGENTS.md §1).
  - Rewarded ads pay 200 EC each, up to 20 a day (Milestone 8). Coin packs
    and their prices come later.
  - **No daily cap** on coins earned offline. AGENTS.md §11 asks for one
    because a tampered phone can fake matches; asked again, the owner kept
    no cap. See D-025 for the risk.
- **The owner's worked example:** at a 1,000 EC table, a team that wins 6
  deals and the match gets 2,000 + 6 × 50 = 2,300 EC back for its 1,000 EC
  fee; the other team gets 4 × 50 = 200 EC back. A test checks exactly this.
- **Who wins a deal** (needed for the bonus; AGENTS.md does not define it):
  the bidding team if it makes its contract, or the single-hand declarer's
  team if it takes all eight tricks; otherwise the other team. Nobody wins a
  void deal, and a cancelled deal is not a deal. This is
  `DealScored.winningTeam` in `game_twentynine`, which changes no rule, so
  `rulesVersion` stays 1.
- **Where:** every number is in `packages/sync_protocol/lib/src/economy.dart`,
  the one config file of AGENTS.md §11, shared by the app and the server.
  `CoinRules` derives the amounts from it. A test pins the owner's numbers,
  so changing one is a deliberate act; it is an "ask first" item (§16).
- **Games, penalties and refunds: approved by the owner on 2026-10-10.**
  These numbers are the owner's own (AGENTS.md §6.13 and §11):
  - **Pot:** with four people, all four fees, split among the winners.
    Against bots the pot counts as twice the player's fee, and bots never
    win or lose EC. Winning against bots therefore still pays 2 × the fee,
    as before.
  - **Loss penalty:** each losing player adds 25% of the match pot at match
    end: 0.5 × the fee against bots, 1 × the fee with four people. It is
    charged after the continue vote, and still applies if the vote ends the
    game after a lost match.
  - **Quitting against bots** returns a share of the pot, by the player's
    team score in the match at that moment: 50% from −3 to +3, 25% below
    −3, 75% above +3. At +4 that is 1.5 × the fee. Deal bonuses already won
    are kept, and there is no loss penalty.
  - **Quitting against people** gives the whole pot to everyone still
    playing, the quitter's partner included (Milestone 9).
  - **Tied game:** a game the continue vote ends with the match record level
    refunds every table fee of the game. Winnings and deal bonuses are kept;
    penalties are not refunded. The owner gave this answer on 2026-10-10,
    replacing "fees and penalties" in the first draft.
  - Beating bots earns nothing beyond what this record pays.
  - **Open** (AGENTS.md §17): the pot at a table mixing people and bots.
  - **Worked example, against bots at 1,000 EC:** a lost match in which the
    player's team won 4 deals moves −1,000 + 4 × 50 − 500 = −1,300 EC.
    Quitting at +4 after 2 deals won moves −1,000 + 2 × 50 + 1,500 =
    +600 EC.
- **Reopen when:** the owner changes a number, prices the coin packs,
  wants a cap, or settles the mixed-table pot.

## D-025 Coins in the event log, and the wallet

- **Milestone:** 5
- **Events:** a staked match logs `economy.entryFee` (`stake`, `seats`)
  right after `match.created`, and `economy.rewardPending` for each deal
  the player's team wins (`reason: dealWon`, `deal`) and for a won match
  (`reason: matchWon`, `winners`). A reward is written in the same append
  as the result that earned it. No event carries an amount (AGENTS.md
  §11): the app and the server work amounts out with the same
  `matchCoins` and `CoinRules`. A repeated reward counts once; a broken
  record earns nothing on the device. Practice matches log no economy
  events.
- **Wallet:** the confirmed balance comes from the server and is shown as
  "Not synced yet" until sync arrives in Milestone 6. Apart from it, the
  wallet shows what is pending: the gift, and each staked match with its
  fee, deals won and result. The player may spend confirmed plus pending
  coins, so a new player can join a table at once, offline. Starting a
  staked match checks this first.
- **Game-agnostic:** the wallet reads only economy events, so a new game
  adds no wallet code (AGENTS.md §5.9). `WalletRepository` has a local
  implementation over the event log and a fake for tests (§5.8).
- **One table at a time:** starting a match ends any unfinished one of the
  same game as abandoned, after the player confirms. A fee is never
  refunded. Changed in step 6b: starting a game ends the unfinished one,
  and quitting returns a share of the pot (D-037).
- **Changed in step 6b** (D-037): `economy.entryFee` also names `humans`,
  the people at the table; `matchWon` names the people on the winning side
  (1 against bots); `economy.penaltyPending` and two more rewards,
  `quitRefund` and `tieRefund`, exist.
- **For Milestone 6:**
  - The server credits the gift once per user, with reason `welcomeGift`
    and the user ID as the reference.
  - It replays each match and recomputes its coins with this code, never
    trusting the events' reward claims.
  - It refuses a fee the user could not have paid at that point. Changed in
    Milestone 6: it does not (D-032).
  - It marks the gift confirmed on the device.
- **Risk of no offline cap:** offline, the device chooses the deck seed and
  runs the bots. A modified app can deal itself strong hands and log bot
  moves of its own choosing. Such a log still replays cleanly, and the
  server would credit what those results earn. Coins have no cash value
  (§11), so the harm is to the coin economy and to coin sales, not to
  players' money. If abuse appears, the options are a daily cap, seeds
  issued by the server, or logging each bot decision's seed so the server
  can re-run it.

## D-026 Guest profile, settings and lobby

- **Milestone:** 5
- **Guest:** the guest ID made on first launch (D-020) is the profile. The
  lobby says "Playing as a guest" and the settings show the account; a
  widget test starts the app on an empty database and finds both, with the
  1,000 EC gift. A profiles table, for sign-in and linking, waited for
  Milestone 6, where its shape is known.
- **Settings:** a `settings` table keyed by user ID and key, so each user
  keeps their own choices. The table fee is the first; a saved value that
  is not a fee falls back to the default. The settings screen also shows
  the app version and the licences (D-028).
- **Lobby:** built from `gameEntriesProvider`, one entry per game: its
  rules, first route, name and subtitle. The rules registry
  (`GameRegistry`) is built from the same list, so a new game is one entry.
  The app bar holds the coins the player may spend, which opens the wallet,
  and a settings button.
- **Strings:** the currency's name and "EC" live in the ARB file, so they
  can be translated (AGENTS.md §5.10); the config file of D-024 holds the
  amounts. Amounts use the locale's digit grouping, as in 1,000 EC.
- **Table:** the app bar shows the table fee, or "Practice"; a deal's
  result shows the coins it earned, and a won match shows the share of the
  pot.

## D-027 Database migrations with drift's tool

- **Milestone:** 5
- **Decision:** schema version 2 adds the `settings` table. The migration
  uses drift's recommended workflow: `apps/mobile/build.yaml` names the
  database, and `dart run drift_dev make-migrations` (run in `apps/mobile`)
  keeps a snapshot of every version in `apps/mobile/drift_schemas/`,
  generates the `stepByStep` helper (`lib/data/local_database.steps.dart`)
  and the test helpers in `test/drift/`.
- **Tests:** `test/drift/local_database/migration_test.dart` checks that each
  upgrade gives exactly the snapshot's schema, and that version 1's events,
  matches and IDs survive the upgrade unchanged. As a check, removing the
  step made both tests fail.
- **Changing a table:** edit it, raise `schemaVersion`, run build_runner
  and make-migrations, write the new step, run the tests. A step that has
  shipped is never edited (AGENTS.md §16).

## D-028 Licences shown in the app

- **Milestone:** 5
- **Decision:** Settings, Licences opens Flutter's licence page, which
  lists every Dart package's licence by itself. SQLite3 Multiple Ciphers
  (D-018) is a native library that the `sqlite3` package's build hook
  downloads, so no Dart package carries its licence. Its MIT licence
  (Ulrich Telle), the `LICENSE` file at the `v2.5.0` tag, is bundled
  unchanged as `apps/mobile/assets/licenses/SQLite3MultipleCiphers.txt` and
  added to the licence page at start-up. A test checks the entry.
- **Still open:** whether the card back may be published (D-006).

## D-029 The backend: Supabase and the game server

- **Milestone:** 6 (2026-10-09)
- **Decision:** Supabase (project `ylvwsollcphtjvzvtpjq`, chosen by the
  owner) provides Auth and the Postgres database. The game server in
  `server/` is a Dart HTTP service (shelf) with three calls: upload a batch
  of a match's events, read the wallet, and merge a guest (D-031). The app
  talks to Supabase Auth and to the server, never to the tables.
- **Database** (`supabase/migrations/`): device profiles, matches, their
  uploaded events, the coin ledger, sign-up bonus claims and guest merges.
  Row-level security is on for every table. Players may read their own rows
  of the first four; nobody but the server reads the last two; the API's
  anonymous role reads nothing. Only the server writes: it connects with the
  database's `postgres` role, which owns the tables, so the policies do not
  bind it. It needs no service-role key.
- **Who is calling:** the server sends each access token to Supabase Auth's
  `/auth/v1/user`, which checks it and says whether the account is a guest
  and whether Google is linked. Answers are reused for 60 seconds per token.
- **Checks by replay:** the server replays each match with the shared
  engine from its logged seed. Every action must be legal, every event the
  engine produces must match the log, and every coin event must be exactly
  what the rules give (`server/lib/src/replay.dart`). Bots' choices are
  checked for legality only, because their seeds are not logged.
- **Hosting, open** (a check in AGENTS.md §17): the server is a container image
  of about 18 MB (`server/Dockerfile`), built and run against a local
  Supabase stack. A host that serves it over HTTPS is still to be chosen;
  Google Cloud Run fits, as Google sign-in already needs a Google Cloud
  project, but it needs billing set up, which is "ask first" (§16).
- **Verified:** server tests with a memory store; integration tests with a
  local Supabase stack in Docker: real tokens, the Postgres store and the
  row-level security (D-033); the container answering real tokens. **Not
  verified:** the real project (the migration is not applied there yet),
  any host, Google sign-in itself.

## D-030 Accounts on the device

- **Milestone:** 6
- **Profiles:** the database keeps one row per profile on the device: a
  guest or a Google account, the Supabase user it is bound to, its name and
  the balance the server last confirmed. The profile in use is
  `active_profile_id` in `meta`; events are kept apart by profile. Schema
  version 3 turned the first guest into the first profile.
- **Guest:** a new profile works offline at once. The first time it is
  online, it gets an anonymous Supabase account, silently.
- **Google sign-in:** native sign-in gives an ID token. The app first links
  it to the guest's own account (`linkIdentityWithIdToken`), which keeps its
  user ID and coins and earns the sign-up bonus. If that Google account
  already has a profile, Supabase refuses the link
  (`identity_already_exists`); the app then signs in to it, and the server
  merges the guest into it (D-032). The guest's progress is uploaded before
  either, and signing in needs a connection.
- **Sign-out:** uploads what it can, revokes the session, deletes its tokens
  and starts a new guest. Progress that could not be uploaded stays on the
  phone, encrypted, under its profile, and goes up when that account signs
  in again on this phone. Offline, the session cannot be revoked, but its
  tokens are still deleted.
- **Tokens:** sessions live only in secure storage, one per account. A
  session is dropped only when Supabase refuses its refresh token; a network
  failure keeps it, because a guest's anonymous account cannot be signed
  back into. A signed-in player plays offline on the saved session.
- **Clients:** `gotrue`, the pure-Dart Supabase Auth client, rather than
  `supabase_flutter`, which would bring shared preferences and other native
  plugins and keep tokens outside secure storage by default.
  `google_sign_in` 7 for the native flow. Behind `AuthRepository`, so Sign in
  with Apple (a check in AGENTS.md §17) can be added without touching features.
- **Configuration:** `--dart-define-from-file=env/dev.json`
  (docs/backend-setup.md). Without it the app is offline only and says so.
  The app refuses non-HTTPS URLs.
- **Sign-in before the game server** (2026-10-09, the owner set up Google
  sign-in first): accounts and sign-in need only Supabase. Without a game
  server the guest still gets its anonymous account and can sign in; the
  sign-up bonus waits for the server's first sight of the account, and
  signing in to an existing account merges nothing, because no server has
  seen the guest: its matches go up under the account later.

## D-031 Sync

- **Milestone:** 6
- **API:** `GET /health`, `POST /v1/sync`, `GET /v1/wallet` and
  `POST /v1/account/merge`; JSON, uploads gzipped; messages in
  `sync_protocol` so both sides share them.
- **Uploads** (AGENTS.md §9): per match, in `seq` order, up to 200 events
  a batch, from after the last `seq` the server acknowledged. The server
  holds each match's events, takes only the next ones, ignores repeats and
  answers with what it holds, so a lost answer, an interrupted batch or one
  that arrives out of order is simply sent again from there. A batch that
  breaks the hash chain, or a log that does not replay, rejects the match:
  it earns nothing and stays flagged, with its reason.
- **Settling:** once the server accepts or rejects a finished or abandoned
  match, the app deletes its events and keeps a summary for the wallet's
  history. Matches still being played go up and wait.
- **When:** at start, when the app returns to the foreground, after each
  match and after sign-in. A failure retries with exponential back-off from
  5 seconds to 10 minutes, with jitter. There is no connectivity plugin: a
  retry that works is how a regained connection is noticed. Background sync
  "where the OS allows" is not done yet; it needs a native plugin.
- **Open:** the storage cap of §9 (stop awarding pending coins when unsynced
  data grows too large) needs a number; with no offline cap (D-024) it
  matters more.
- **Step 6b** (D-037): a match whose earlier match in its game has not
  been accepted waits. The app's usual re-send of a finished match's last
  event makes the server look at it again.

## D-032 Coins on the server

- **Milestone:** 6
- **Ledger:** one row per credit or debit, unique by account, reason and
  reference, so nothing is credited twice. Reasons: `welcomeGift` (once per
  account), `googleSignupBonus`, `entryFee`, `dealWon` (per match and
  deal), `matchWon`, `mergedIn`, `mergedOut`; since step 6b also
  `lossPenalty`, `quitRefund` and `tieRefund` (per match), which a merge
  counts as play (D-037).
- **When:** the starting gift on an account's first call to the server. A
  match's coins when it is complete and replays cleanly: finished, or left
  (which counts as lost, D-024).
- **Google sign-up bonus, once ever** (owner, 2026-10-09): paid the first
  time the server sees a Google account. A SHA-256 hash of its Google
  subject ID is kept, apart from the account and kept even after the account
  is deleted, so the same Google account never earns it again. The ID itself
  is not kept. The privacy policy should say so.
- **Merging a guest into an existing account:** the account gains what the
  guest won in matches, never less than zero. The guest's starting gift does
  not move, so a fresh install cannot add a gift to an account. The guest's
  profiles and unfinished matches move to the account; the guest is closed
  and refuses further requests. A merge repeated after a lost answer
  changes nothing.
- **Fees are not refused** (changing D-025's plan): the phone checks that a
  fee can be paid; the server does not refuse a match for it. The same
  account offline on two phones could otherwise lose valid matches, and the
  replay already limits what a log can earn. A balance can therefore go
  below zero; the app then offers only practice.

## D-033 Testing the backend

- **Milestone:** 6
- **The fake server of AGENTS.md §14** is the real server code in memory:
  app tests run `SyncService` with a memory store, behind the app's
  `GameServer` interface, and the HTTP client is tested against the real
  HTTP handler. The memory store enforces the same rule as Postgres that a
  match's record exists before its events, after the Postgres tests caught
  the server writing them the other way round.
- **Logs:** sync tests upload logs that the app's own match controller
  wrote while playing, so the app and the server agree on every reward.
- **§9 cases:** duplicate upload, interrupted batch, out-of-order arrival,
  tampered chain and sync after sign-in from guest are each tested in the
  app and on the server.
- **Local Supabase:** `tool/backend_check.sh` starts a local Supabase stack
  in Docker (with Node.js), applies the migrations to a fresh database and
  runs the integration tests: real anonymous accounts and tokens, the
  Postgres store, row-level security as players see it, and the app's
  sign-in, refresh and sign-out against Supabase Auth.
- **Not tested:** Google sign-in (it needs real Google accounts and a
  device), the real Supabase project and any server host.

## D-034 Android builds with the pub cache on another drive

- **Milestone:** 6 (2026-10-09)
- **Found:** the owner installed Android Studio and the Android SDK on this
  PC, so Android builds could be tried for the first time. The project is
  on drive D: and Dart's pub cache, where Flutter compiles plugins from, is
  on C:. Kotlin's incremental compiler stores plugin sources as paths
  relative to `apps/mobile/android`, and no relative path crosses drives:
  `flutter build apk` failed in `:google_sign_in_android:compileDebugKotlin`
  with "this and base files have different roots".
- **Decision:** `kotlin.incremental=false` in
  `apps/mobile/android/gradle.properties`. The app's own Kotlin is a single
  small file and plugins compile once, so nothing is lost; it works
  wherever the project and the cache are.
- **Verified:** `flutter build apk --debug` (188 MB) and
  `flutter build apk --release` (67.4 MB, holding every processor type;
  signed with the debug key, D-007) succeed. Gradle installed SDK platforms
  35 and 36 and CMake 3.22.1 by itself on the first build. The release
  build warns that a package refers to the Cupertino icon font, which the
  app does not bundle; the app shows no Cupertino icons.
- **Still failing:** tools that list every task of the plugin projects,
  such as the VS Code Gradle extension's import or `gradlew tasks`, fail on
  the same drive mismatch, because Gradle itself cannot relate the two
  paths. Flutter's builds do not need them. To fix them, put the pub cache
  on the project's drive (the `PUB_CACHE` environment variable, then
  `flutter pub get`), or turn the Gradle extension off for this project.
- **Not verified:** running the app on the emulator (the one running did
  not answer adb), iOS (needs a Mac).

## D-035 Score sixes in the table's top corners

**Replaced in part by D-036** (2026-10-10): each team now has a fixed pair
of sixes, and a level score shows both. The art, its sizing and the `_v2`
file below still hold.

- **Asked by the owner** (2026-10-09): keep each team's score with the new
  art, `6_of_hearts_<x>_visible` for points won and
  `6_of_spades_<x>_visible` for points lost, where x is the number of
  points, shown in the two top corners of the table.
- **Files:** ten WebPs with transparency, 1 to 5 pips for each suit, each a
  six partly covered by a card back, in several shapes (from 441 × 857 to
  621 × 662 pixels). Five of hearts is named
  `6_of_hearts_5_visible_v2.webp`, the only file for it, so the resolver
  uses that name and the file stays as supplied (AGENTS.md §13). If the
  owner renames it, only `CardAssetResolver.scoreSix` changes; the asset
  test points to it.
- **Placement:** the player's team in the top-left corner of the table and
  the opponents in the top-right, level with the partner's seat. The score
  is also written underneath ("Us 3"), for screen readers and for scores
  the art cannot show. A marker is as wide as a side seat (80 to 130
  points); on a short table the art shrinks first, so the written score
  stays readable. Every shape is fitted whole into the same box, 1.25 times
  as tall as wide.
- **Scores with no file:** at zero the marker is a lone card back; at six or
  more points either way it is the whole six of hearts or spades from the
  faces. The setup screen allows a target from 1 to 20, so above six the
  whole six stands for any score from six on and the written score gives
  the number. Art for those scores would have to come from the owner.
- **The panel above the table** keeps the trump marker and the contract,
  and no longer the scores. It keeps its height during the auction, before
  the trump marker appears, so the table does not jump.
- **Tests:** the resolver's paths, including the `_v2` name and the range;
  every score six, the plain sixes of hearts and spades and the four 2s are
  declared in `pubspec.yaml` (before, only the 32 faces and the back were
  checked); each score six decodes and draws; the marker at zero, at 1 to 5
  either way and at six or more; its place in the corners; a 320 × 568
  phone.
- **Verified:** the table rendered off screen with the real art at
  393 × 873 and 320 × 568 points, and looked at. **Not verified:** a device
  or the emulator.

## D-036 The corner score display, and a fixed target

- **Milestone:** step 6a (2026-10-10), asked by the owner (AGENTS.md §6.1,
  §6.2, §15).
- **Fixed pairs:** the player's team keeps its points with 6♠ and 6♦ in the
  top-left corner, the opponents with 6♥ and 6♣ in the top-right. The
  red six counts points won, the black six points lost.
  - At 0 both sixes lie side by side, not overlapping, black at the table's
    edge and red toward the middle (6♠ 6♦ on the left, 6♥ 6♣ on the
    right, the owner's order).
  - At 1 to 5 either way the six of that sign shows that many pips, from
    `6_of_<suit>_<pips>_visible.webp` (D-035).
  - At 6 either way the match is over and the whole six shows.
- **Match cards:** beside the sixes, on the side toward the middle, a 5, 4,
  3 or 2 shows the team's net match record in the game at 1, 2, 3 or 4,
  in the corner's red suit when ahead and black when behind; nothing when
  level. The game ends after the match played with a 2 showing, so a
  record of 5 can only be the final one; the 2 stays. The owner chose this
  mapping on 2026-10-10.
- **One card, not two** (the owner, 2026-10-10, after seeing both corners
  show one): only one team shows the card. A match that takes the record
  away from level puts it with the winner, in red, if a team reached +6,
  or with the loser, in black, if a team reached -6. A match that brings
  the record back toward level leaves it where it is, one step lower;
  showing the other way would name the wrong team as leading. The choice
  is logged with each match, as `trailing` in `match.created`'s `series`
  (D-037), because a phone keeps only the current match of a game once
  the earlier ones are synced.
- **Art:** the covered sixes of diamonds and clubs were missing at first,
  so our team's points won and the opponents' points lost showed the
  labelled stand-in in debug builds. The owner supplied all ten on
  2026-10-10.
- **Labels:** the points stay written under the cards ("Us 3"). Screen
  readers hear one label per corner, such as "Us: 3 game points, 1 match
  ahead", not the cards' names.
- **Layout:** each corner takes what the partner's seat leaves (80 to 160
  points wide); its art shrinks first on a short table, so the label stays
  readable.
- **Target fixed at 6** (§6.2): the setup screen states it instead of
  offering a slider. `TwentyNineConfig.fixedTargetGamePoints` names it. The
  app refuses to start a match with another target and does not resume
  one; the server rejects such a log. The engine still replays any target,
  so `rulesVersion` stays 1.
- **Asset test:** it now also checks the 2s to 5s and plain sixes of every
  suit and the twenty covered sixes, 40 files besides the 33 the deck
  needs; the ten missing ones must be listed.
- **Verified:** widget tests for both pairs at 0, at 1 to 5 either way and
  at 6, the match cards, their side, the screen-reader label and both phone
  sizes; the table rendered off screen with the real art at 393 × 873 and
  320 × 568 points, and looked at. **Not verified:** a device or the
  emulator.

## D-037 Games against bots

- **Milestone:** step 6b (2026-10-10), asked by the owner (AGENTS.md §6.13,
  §7, §9, §11, §15). The numbers are in D-024.
- **Name:** a game, a series of matches at one table, is a *series* in code
  and in event types, because `gameId` in every envelope already names the
  card game.
- **What is logged:**
  - `match.created` holds `series`: the game's ID, the match's number in it
    from 1, the player's team's match record before it, and `trailing`,
    which side shows the match card (D-036). The server checks the record
    against its own count; `trailing` only decides the picture, so it is
    not checked.
  - After the match, unless it was the game's last: `series.vote` with
    `continue`.
  - Then, for a lost match at a fee, `economy.penaltyPending`: the penalty
    comes after the vote, as the owner asked, and applies either way.
  - If the game ends: `economy.rewardPending` with `tieRefund` and the
    number of matches when the record is level, then `series.ended` with
    the reason (`lastMatch`, `vote` or `quit`) and the record.
  - Quitting logs `match.abandoned` with the team's score, then
    `quitRefund` with that score at a fee, then `series.ended`. The quit
    match does not count in the record.
  - No event holds an amount (AGENTS.md §11).
- **The record** comes from logged match records. On the phone, from the
  match's own `series` field and its result. On the server, from its own
  records of the game's matches, never from the phone: each accepted match
  stores the record after it and whether the game goes on (migration
  `20261010000000_cardgames_series.sql`). A match is accepted only when the
  previous match of its game is accepted, from the same profile, at the
  same table (rules, seats and fee), with the game going on and the same
  record as the phone logged. One match may hold each place in a game, so a
  log cannot branch a game; a rejected match rejects the rest of its game.
- **The game ends** after the match played with a 2 showing (a record of 4
  either way before it; there is no vote after it), when the vote ends it,
  or on a quit. A tie is a game the vote ends with the record level; only
  then is the tie refund due, and the server checks that the game had
  exactly that many matches.
- **Playing on** starts the next match at once with the same rules, bots and
  fee. The phone first checks that the player can pay the next fee after
  the penalty; if not, nothing is logged and only "End game" works.
- **Leaving:** in a match, the player is asked and then quits. After a
  match, before the vote, leaving ends the game as a vote to stop. Starting
  a new game ends an unfinished one the same way. A match over and awaiting
  the vote stays unfinished: the app resumes it at the vote.
- **Older logs:** logs from before this step have no `series`, and their
  fees name no `humans`. The server rejects them and the phone shows them
  as nothing pending. The app is unreleased, so only development phones
  hold any.
- **Known gaps:**
  - If the player signs in to another account while a match waits for the
    vote, that match stays unfinished under the guest profile, and its
    penalty is never charged.
  - Quitting against people (Milestone 9) is in the rules (§11) but not
    built.
  - The mixed-table pot is open (AGENTS.md §17).
- **Verified:**
  - Shared rules: pots, penalties, quit shares, the tie refund, and the
    log format.
  - Server replay: the vote, the penalty, the last match, a tie, a quit
    with a false score.
  - Sync service: order, waiting, record, branching, a table change, an
    ended game, a rejected match, a tie refunded once.
  - Postgres, through `tool/backend_check.sh` against the local Supabase
    stack.
  - The app controller: play on, stop, the penalty, unaffordable play,
    a tie, resuming at the vote, the last match.
  - A two-match game synced to the in-process server.
  - Widget tests of the panels and the quit dialog. The vote and game-over
    panels were rendered off screen and looked at.
- **Not verified:** a device or the emulator, and the real Supabase project.
  The new migration still has to be applied there with the first one
  (docs/backend-setup.md, step 2).

## D-038 Bots 4 and 5: Expert and Master

- **Milestone:** 7 (2026-10-10). AGENTS.md §8.3 and §8.4.
- **Shared solver** (`packages/bots/lib/src/twentynine/search.dart`):
  - Alpha-beta over one deal with every hand known. The bidding side
    maximises and the other side minimises.
  - The value puts the contract's outcome first (made, void or failed)
    and card points only as a tie-breaker (§8.3.7).
  - A transposition table with Zobrist keys at trick boundaries.
  - Move ordering: the table's best move, then cards that win the trick
    (richest first), then the cheapest.
  - Equivalent cards are merged: cards next to each other in strength
    among the cards still out, and worth the same, count as one.
  - It searches to the end of the deal once 16 or fewer cards are left
    (about trick 4). Earlier it looks to the end of the current trick and
    scores that by quick playouts.
  - A deterministic node limit, not a clock, caps its work.
  - Tests check it against the engine. It offers exactly the engine's
    legal actions (400 positions, both ask-trump rules), and gives the
    same value as a brute-force search of the engine itself (60 endgames).
    The Pair is left out, because it moves the target rather than the
    points.
- **Beliefs** (`beliefs.dart`, §8.3.1):
  - The hard facts stay those of D-015: voids, a missing trump, the
    Pair's cards, the hidden seventh card.
  - Soft weights, for Master only:
    - A seat that bid is likelier to be strong, the more so the higher it
      bid; one that only passed is likelier to be weak.
    - A hidden trump is likelier to be a suit the bidder is long and
      strong in.
    - Weighted deals are drawn by importance resampling: four times as
      many are dealt as needed, and kept in proportion to their weight.
- **Exact endgame** (§8.3.6): with 12 or fewer cards left (from trick 5),
  if at most 2,000 deals are possible, all of them are listed and solved.
  Each listing also covers every possible trump where it is unknown.
  - At trick 4 (16 cards left), void suits sometimes bring the count
    under 2,000, but solving that many sixteen-card deals took up to 1.1
    seconds on the development PC. Hence the 12-card limit.
- **Expert** (PIMC, §8.3.4): 40 sampled deals per move, each solved; the
  action with the best average outcome wins, card points breaking ties.
  Asking for trump is worth the best card it allows. Monte Carlo bidding,
  trump and doubling, as Skilled does, on 96 deals.
- **Master** (ISMCTS, §8.3.5):
  - A single-observer tree over what the bot knows, 12,000 iterations
    per move.
  - Each iteration uses the next of 400 weighted deals, chooses moves
    legal in it by UCB1 with availability counts, adds one move, and
    plays out the rest with the Greedy policy.
  - Rewards: 1 for meeting the side's goal, 0 for failing, a half each
    for a void deal, and a little for card points.
  - With 16 or fewer cards left it solves 120 weighted deals instead.
    There alpha-beta reaches the end of the deal cheaply, and PIMC's
    weakness, assuming it will later know the hidden cards, matters least.
    Measured on 800 duplicate deals, this raised Master's margin over
    Expert from +0.080 to +0.104 game points per deal.
  - Monte Carlo bidding on 160 weighted deals.
  - The weighting is most of what Master gains: its doubles were followed
    by made contracts 35% to 38% of the time, against 62% to 65% for
    Expert's.
- **Knobs** (§8.4) added to `BotSettings`: the play method (`search`),
  bidding samples, soft beliefs on or off, the exact-endgame limit, and
  for Master when to switch to solving and how many deals. Levels still
  differ only in knobs, and see only their view.
- **Speed on the development PC** (8 cores, one decision at a time):
  - Expert: 2 to 25 ms per card play, at most about 165 ms.
  - Master: about 100 ms early in a deal, at most about 170 ms.
  - Bidding: under 10 ms for both.
  - A phone is several times slower, which brings Master to the 0.8
    seconds per move AGENTS.md suggests. The app's 5-second limit per
    decision (D-022) stays the safety net; no level comes near it.
- **Fair play:** the three fair-play tests and the isolate test of D-014
  cover both new levels at full budget. Every search draws only on the
  bot's own seed, so the same view, seed and budget give the same move.
- **The app** offers the five levels as chips that wrap on a narrow phone,
  with a line about each.
- **Results** (`docs/bot-benchmarks.md`, seed 2026): Expert beats
  Skilled by +0.135 game points per duplicate deal (z = 7.02, 4,000
  deals); Master beats Expert by +0.086 (z = 5.07, 4,000 deals) and Skilled
  by +0.291 (z = 10.76, 2,000 deals). Each level against itself is level:
  Expert -0.032 (p = 0.06), Master +0.013 (p = 0.67).

## D-039 Table motion, and bidding by +1, +4 and Match

- **Asked by the owner** (2026-10-10): animate dealing, throwing a card
  (swiping it up) and collecting a trick toward its winner; bid with +1,
  +4 and Match buttons instead of one button per bid. The owner will give
  the condition under which a player may match the highest bid.
- **Bidding:** Pass, **+1** and **+4** bid one or four above the highest
  bid. With no bid yet, +1 opens at the minimum (16) and +4 bids 19, four
  above the minimum less one. A raise past the maximum (29) is shown
  disabled; a dealer who must bid has only +1. Each button shows the bid
  it makes, as "+1 (17)".
- **Match** is shown, disabled, with a tooltip saying it is not available
  yet. Matching the highest bid is not a rule of AGENTS.md §6.4, where every
  bid must be higher, so it needs the owner's condition and a change to the
  rules engine: a new action, a new `rulesVersion` once version 1 is
  released, and replay on the server.
- **Dealing:** whenever the player's hand gains four or more new cards (a
  new deal, the second four, or a redeal), packets of four card backs fly
  from the dealer to each seat in turn, the first player first, 140 ms
  apart, each flying for 390 ms. The player's new cards slide up into the hand as their packet
  lands.
- **Throwing:** a playable card can be swiped up: it follows the finger
  and is played once pulled up 40% of its width or flicked; a short pull
  springs back. A tap still plays it. Every card played flies in from its
  player's side to its place on the table in 340 ms.
- **Collecting:** a finished trick's last card lands, the trick stays a
  moment so all four cards can be seen, then slides off to the winner's
  side and fades, in 1.3 seconds. The "trick to" label stays until the next
  card is played.
- **Slower, 2026-10-10:** the owner found the motion too fast; every
  duration grew by 30%, rounded to 10 ms. The figures above are the new
  ones; the player's new cards now slide in over 360 ms, 70 ms apart.
- **Less motion:** with the phone's setting to remove animations, cards
  appear where they go, there is no dealing to watch, and the last trick
  stays, dimmed, as before.
- **The end of a deal, in order** (the owner, 2026-10-10): the last trick
  goes to its winner, then the deal's result appears, then, once the
  player taps "Next deal", the next deal's cards are dealt. The engine
  deals the next deal in the same step that scores this one, so the
  controller keeps the player's view of the finished deal (its last trick
  added, the new scores) on screen until the player goes on, and holds
  the result back for 1.4 seconds (`dealEndPauseProvider`), the length of
  the trick's animation. Nobody plays meanwhile. At the end of a match the
  result comes first, then the match's own panel.
- **Bots are not slowed:** the animations are only drawn; play goes on
  with the existing pauses (D-021, D-022).
- **Tests:** the bid buttons for an opening, a raise, a raise past 29, a
  forced dealer and Match; swiping up plays, a short pull and a card not
  playable do not, and a tap still plays; a played card starting off the
  table and landing in its place; a finished trick shown, then faded at
  its winner; reduced motion; the dealing packets for both batches. The
  full deals played by tapping, on three screen sizes, pass with the new
  buttons and animations. The bidding row was rendered and checked at
  320 × 568 points.
- **Not verified:** how the motion looks and feels on a device or the
  emulator.

## D-040 Trump has power only from the reveal

- **Decided by the owner** (2026-10-10), settling a contradiction in
  AGENTS.md §6.9. One sentence counted trump-suit cards played earlier in
  the trick in which trump is revealed; the next said trump is valid only
  after the reveal, even in the same trick. The engine had followed the
  first. The owner chose the second.
- **Rule now:** a trump-suit card is a trump only if it is played after
  trump is revealed. In the trick in which trump is revealed, trump counts
  from the revealer's own card on: the card played right after asking, or
  the seventh card whose play reveals trump. Every earlier card of that
  trick is a plain card. §6.9 is reworded to say so.
- **The owner's story** (Left leads; the Player, who has no card of the
  suit led, plays a trump-suit card), now engine tests:
  1. Nobody reveals: the highest card of the suit led wins.
  2. The Player does not reveal; Right reveals and plays a lower trump:
     Right wins, whatever the ranks, because the Player's card went down
     before the reveal.
  3. The Player reveals and trumps; Right, with no card of the suit led
     either, plays a higher trump: Right wins.
  4. As 3, but Right plays a lower trump: the Player wins. This happens
     only when Right has no card of the suit led and holds nothing but
     trumps, or chooses to give up a low trump; nothing forces a player
     to trump once trump is revealed.
- **Where:** the engine's trick winner, the bots' simulator, the solver's
  positions (a new slot for where trump starts to count) and the Casual
  and Beginner bots' reading of a trick. The server replays with the
  engine, so it follows.
- **Rules version:** stays 1. Version 1 has not been released (D-014), so
  nothing played under the old reading needs to replay. Logs from
  development phones with such a trick would now be rejected. The golden
  replays were regenerated: the "variants" match had such a trick.
- **Arena after the correction** (800 duplicate deals each): Expert
  beats Skilled by +0.128 (p = 0.003) and Master beats Expert by +0.176
  (p = 0.000002).
- **Corrected by the owner** (2026-10-10, found in play): the rule above
  is only for a trump-suit card played on another suit. When trump itself
  is led, everyone who plays it is following suit, so the highest card of
  it wins, whenever trump was revealed: before the trick, during it, or
  never. Before the fix, a lower card of the suit played after a reveal
  in mid-trick beat a higher one led before it. The engine, the bots'
  simulator, solver and heuristics, and §6.9 now say so. One test of mine
  had taken the wrong reading: with diamonds led and trump, it gave the
  trick to a 7 played after the reveal; it now goes to the highest
  diamond.
- **Verified:** the four cases and the duty to follow suit as engine
  tests; the owner's bug as an engine test and a simulator test; a check
  of 71,940 tricks from 3,000 random matches against the rule written out
  again, over 8,000 of them revealed in mid-trick; the simulator on case 2; the simulator and the solver still match
  the engine in their randomised comparisons (D-038). The arena still ranks
  the levels: Expert beats Skilled by +0.134 (p = 0.002) and Master beats
  Expert by +0.106 (p = 0.003), on 800 duplicate deals each.

## D-041 The auction: two at a time, and the old bidder may match

- **Decided by the owner** (2026-10-10), replacing the open auction of
  AGENTS.md §6.4, which is rewritten:
  1. Bidding goes in the direction of the deal, from the first player.
  2. Only two players bid at a time.
  3. When one of them passes, the next player joins.
  4. The old bidder may match the new bidder's bid.
  5. The new bidder must raise or pass.
  6. The winner names trump.
- **Read into it:**
  - The old bidder is the one of the pair in the auction longer. After a
    pass, the one left is the old bidder against the newcomer.
  - The old bidder speaks first, opening the auction or answering after a
    pass when no bid has been made. With a bid made, the newcomer answers
    it first.
  - The old bidder may also raise. The rules only say they may match, and
    the +1 and +4 buttons are there for everyone.
  - A pass is final, as before.
  - `maxBid` ends the auction once the old bidder has matched it or
    passed, since nobody can go higher.
  - If the first three pass without a bid, the dealer must bid the
    minimum, or, with the redeal option, may pass too, which redeals.
- **Where:**
  - `AuctionPosition` in `game_twentynine` works out the pair, whose turn
    it is and the end by playing the calls through, so the state gained no
    field.
  - A new action, `MatchBid`, is logged as `twentynine.bidMatched` with
    the value matched. A match is kept in the calls like a bid of the same
    number: bids only rise, so the screen tells a match by a call the same
    as one before it ("Match 17").
- **Rules version** stays 1: version 1 is not released (D-014). Logs from
  development phones made under the open auction no longer replay on the
  server. The golden replays were regenerated; one now holds a match.
- **Bots:**
  - Every level bids up to its own limit. As the old bidder it matches
    rather than raises, which keeps the contract lowest.
  - It does not outbid a partner without a clearly better hand.
  - Their play is unchanged.
- **App:**
  - The Match button is enabled for the old bidder facing the new
    bidder's bid, and shows it ("Match (17)"). For everyone else it stays
    disabled, so the row of buttons does not move.
- **Tests:**
  - The pair and its turns.
  - Matching and raising by the old bidder; the new bidder may only raise
    or pass.
  - Joining after a pass, and the one left becoming the old bidder.
  - Opening with no bid yet, the winner, the new bidder winning.
  - `maxBid` matched or passed, the forced dealer and the redeal option.
  - The logged event and its replay.
  - The buttons and the "Match 17" label.
  - The engine's ten-thousand-match property tests pass with the new
    auction.
- **Arena** (800 duplicate deals each): Expert still beats Skilled
  (+0.116, p = 0.007) and Master beats Expert (+0.099, p = 0.005).

## D-042 The app icon

- **Asked by the owner** (2026-10-10): the app's icon is the owner's logo,
  `apps/mobile/assets/cards/Madhu Games Crowned Logo.png`, instead of
  Flutter's.
- **The logo:** a wide badge (1,536 × 1,024) on a transparent background.
  Its blue glow is fully transparent, so it does not show. An icon must be
  square and, on iOS, opaque.
- **Sources** (`apps/mobile/branding/`, made by
  `make_icon_sources.py`, outside the bundled assets):
  - `app_icon.png`: the whole badge on a navy background that fades to
    near black at the edges, like the card backs. Used for iOS, older
    Android.
  - `app_icon_foreground.png`: the badge alone, small enough that
    Android's round and squircle masks never cut it.
  - `app_icon_background.png`: the background alone, for Android's
    adaptive icon.
  - The logo itself is only read, never changed (AGENTS.md §13); its
    checksum was the same before and after.
- **Icons:** `flutter_launcher_icons` 0.14.4, a build-time dependency only,
  makes every size from those sources. Its settings are in `pubspec.yaml`.
  It replaced:
  - Android's launcher icons, adaptive ones included;
  - the iOS app icon set.
  It also made a Windows icon until the Windows version was removed the
  same day (D-007).
  Android 12 and later show the icon on the splash screen too.
- **Checked:**
  - The generated icon files are in place.
  - The full icon and a round Android mask were rendered and looked at;
    the whole badge shows.
  - **Not checked:** an icon on a device or the emulator's launcher.
- **Note:** the logo sits in `assets/cards/`, which the app bundles whole,
  so it adds 1.6 MB to the app though the app does not show it. Moving it
  next to the icon sources would save that; it was left where the owner
  put it.
