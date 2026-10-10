/// Every number of the coin economy (AGENTS.md §11), in one place.
///
/// The app shows pending coins with these numbers and the server credits
/// coins with the same ones, so the two always agree. The owner set them on
/// 2026-10-05 (docs/decisions.md D-024); changing one is an "ask first"
/// decision (AGENTS.md §16). Players see the currency's name, Earned Coins
/// (EC), through the app's ARB strings, so it can be translated.
abstract final class Economy {
  /// The currency's code in the event log and the server's ledger.
  static const String currencyCode = 'EC';

  /// Given once to every new player, so they can join a table at once, even
  /// offline on first launch.
  static const int welcomeGift = 1000;

  /// Given when a player first signs up with Google: once per Google
  /// account, ever, even if that account is deleted and signs up again.
  /// Signing in to an account that already exists earns nothing.
  static const int googleSignupBonus = 2500;

  /// The table fees a player can choose in settings, per match, smallest
  /// first. Every seat at the table pays the same fee into the pot.
  static const List<int> stakes = [100, 500, 1000, 5000];

  /// The table fee until the player chooses another.
  static const int defaultStake = 100;

  /// After each deal a team wins, each of its players gets this percentage
  /// of their own fee, whoever goes on to win the match.
  static const int dealWonPercent = 5;

  /// Against bots the pot counts as this many of the player's fees; bots
  /// never win or lose coins. With people the pot is every seat's fee. The
  /// owner approved the numbers from here to [quitLevelBand] on 2026-10-10
  /// (docs/decisions.md D-024).
  static const int botPotFees = 2;

  /// Each losing player adds this percentage of the match pot at match end,
  /// after the continue vote.
  static const int lossPenaltyPercent = 25;

  /// Quitting against bots returns this percentage of the pot while the
  /// player's team score is within [quitLevelBand] of zero either way.
  static const int quitShareLevel = 50;

  /// Quitting against bots returns this percentage of the pot when the
  /// player's team score is below -[quitLevelBand].
  static const int quitShareBehind = 25;

  /// Quitting against bots returns this percentage of the pot when the
  /// player's team score is above [quitLevelBand].
  static const int quitShareAhead = 75;

  /// The score, either way, up to which quitting returns [quitShareLevel].
  static const int quitLevelBand = 3;

  /// Coins for one rewarded ad (Milestone 8).
  static const int adReward = 200;

  /// The most rewarded ads a player may watch in a day (Milestone 8).
  static const int adsPerDay = 20;

  /// The most coins a player may earn offline in a day, or null for no cap.
  ///
  /// AGENTS.md §11 asks for a cap, because a tampered phone can fake whole
  /// matches. The owner chose none, knowing that risk (D-024).
  static const int? offlineDailyCap = null;
}
