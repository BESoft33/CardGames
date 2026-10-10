import 'package:game_core/game_core.dart';

/// A computer player (AGENTS.md §8).
///
/// [decide] is the only entry point. Its only inputs are the [PlayerView] of
/// the bot's seat and a [BotContext]: the bot's own random numbers and a
/// search budget. A bot never sees the full state of a match.
abstract interface class BotPolicy<V extends PlayerView, A extends GameAction> {
  /// Picks one of the legal actions in [view].
  A decide(V view, BotContext context);
}

/// What a bot gets besides its view (AGENTS.md §8.1).
final class BotContext {
  /// Creates a context.
  BotContext({required this.random, required this.budget});

  /// A context whose random numbers start from [seed].
  ///
  /// The seed must come from the bot's own source, never from the deck.
  factory BotContext.seeded(int seed, {required int budget}) =>
      BotContext(random: Xoshiro256StarStar.seeded(seed), budget: budget);

  /// The bot's own random numbers.
  final Xoshiro256StarStar random;

  /// How much a searching bot may search: sampled deals for each option
  /// it weighs (Skilled, Expert), or search iterations (Master). Counted
  /// rather than timed, so results are reproducible.
  final int budget;
}

/// How much of a deal a bot keeps in mind.
enum BotMemory {
  /// Only its own cards and what the rules force it to look at.
  none,

  /// The current trick and the trump, nothing earlier.
  currentTrick,

  /// Every card played in the deal.
  wholeDeal,
}

/// How a bot chooses its card plays (AGENTS.md §8.4).
enum BotSearch {
  /// Fixed rules, no search.
  rules,

  /// Each legal action tried in sampled deals, then played out quickly.
  lookahead,

  /// Perfect Information Monte Carlo: each sampled deal solved with
  /// alpha-beta, the best action on average chosen (§8.3.4).
  pimc,

  /// Information Set Monte Carlo Tree Search (§8.3.5).
  ismcts,
}

/// The knobs that set a bot's strength (AGENTS.md §8.4). Levels differ only
/// in these; no level ever sees more than its view.
final class BotSettings {
  /// Creates settings.
  const BotSettings({
    required this.mistakePercent,
    required this.memory,
    required this.inference,
    required this.searchBudget,
    this.riskThreshold = 0.5,
    this.search = BotSearch.rules,
    this.biddingSamples = 0,
    this.beliefs = false,
    this.exactLimit = 0,
    this.solveCards = 0,
    this.solveSamples = 0,
  });

  /// The share of card plays, in percent, chosen at random among the legal
  /// ones.
  final int mistakePercent;

  /// How much of the deal the bot remembers.
  final BotMemory memory;

  /// Whether the bot works out voids and missing trumps from what was
  /// played.
  final bool inference;

  /// The default [BotContext.budget]; 0 for a bot that does not search.
  final int searchBudget;

  /// The chance of making a bid that a searching bot needs before it bids
  /// (AGENTS.md §8.3).
  final double riskThreshold;

  /// How the bot chooses its card plays when it searches.
  final BotSearch search;

  /// Sampled deals for bidding, naming trump and doubling; 0 for the
  /// context's budget.
  final int biddingSamples;

  /// Whether the auction and the bidder's likely trump weigh the sampled
  /// deals (soft inference, AGENTS.md §8.3.1).
  final bool beliefs;

  /// Up to how many possible deals the bot plays the end of a deal
  /// exactly, every one of them solved (AGENTS.md §8.3.6); 0 for never.
  final int exactLimit;

  /// For a tree-searching bot: with this many cards or fewer left to play,
  /// when alpha-beta reaches the end of the deal cheaply, it solves
  /// [solveSamples] sampled deals instead of searching its tree; 0 for
  /// never.
  final int solveCards;

  /// Sampled deals solved once [solveCards] is reached.
  final int solveSamples;
}

/// The skill levels (AGENTS.md §8.4).
enum BotLevel {
  /// A few fixed rules; bids from a point-count table; 25% random plays.
  beginner(
    BotSettings(
      mistakePercent: 25,
      memory: BotMemory.none,
      inference: false,
      searchBudget: 0,
    ),
  ),

  /// Partner- and trump-aware heuristics, remembering only the current trick
  /// and the trump; 10% random plays.
  casual(
    BotSettings(
      mistakePercent: 10,
      memory: BotMemory.currentTrick,
      inference: false,
      searchBudget: 0,
    ),
  ),

  /// Card counting and void tracking, a one-move lookahead scored by quick
  /// playouts of the rest of the deal in sampled deals, and Monte Carlo
  /// bidding; no random plays.
  skilled(
    BotSettings(
      mistakePercent: 0,
      memory: BotMemory.wholeDeal,
      inference: true,
      searchBudget: 24,
      riskThreshold: 0.55,
      search: BotSearch.lookahead,
    ),
  ),

  /// Perfect Information Monte Carlo: 40 sampled deals per move, each
  /// solved with alpha-beta, to the end of the deal from about trick 4;
  /// every possible deal solved once 2,000 or fewer remain; Monte Carlo
  /// bidding.
  expert(
    BotSettings(
      mistakePercent: 0,
      memory: BotMemory.wholeDeal,
      inference: true,
      searchBudget: 40,
      riskThreshold: 0.55,
      search: BotSearch.pimc,
      biddingSamples: 96,
      exactLimit: 2000,
    ),
  ),

  /// Information Set Monte Carlo Tree Search over deals weighted by what
  /// the auction says, the same exact endgame, and Monte Carlo bidding on
  /// weighted deals.
  master(
    BotSettings(
      mistakePercent: 0,
      memory: BotMemory.wholeDeal,
      inference: true,
      searchBudget: 12000,
      riskThreshold: 0.55,
      search: BotSearch.ismcts,
      biddingSamples: 160,
      beliefs: true,
      exactLimit: 2000,
      solveCards: 16,
      solveSamples: 120,
    ),
  );

  const BotLevel(this.settings);

  /// The level's knobs.
  final BotSettings settings;
}
