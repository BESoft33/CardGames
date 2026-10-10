import 'package:game_core/game_core.dart';

/// Which way play passes round the table (AGENTS.md §6.2).
///
/// Seats are numbered in play order, so the rules never look at this. It
/// decides where the next player sits on screen: on the right when play is
/// counter-clockwise, on the left when clockwise.
enum PlayDirection {
  /// The next player sits on the right. The default.
  counterClockwise,

  /// The next player sits on the left.
  clockwise,
}

/// What a player who cannot follow suit may do while trump is hidden.
enum AskTrumpRule {
  /// The player may play any card, or ask for trump; after asking they must
  /// play a trump if they hold one. The default.
  optional,

  /// The player must ask for trump, and may then play any card.
  mandatory,
}

/// What happens when the first three players pass.
enum AllPassRule {
  /// The dealer must bid the minimum. The default.
  dealerMustBid,

  /// The dealer may pass too; if all four pass, the cards are redealt.
  redeal,
}

/// Every rule option of Twenty-Nine (AGENTS.md §6.2). The defaults are the
/// Nepal table rules, which the owner has confirmed.
final class TwentyNineConfig {
  /// Creates a config. Options left out take their default.
  const TwentyNineConfig({
    this.direction = PlayDirection.counterClockwise,
    this.minBid = 16,
    this.lastTrickPoint = true,
    this.askTrump = AskTrumpRule.optional,
    this.allPass = AllPassRule.dealerMustBid,
    this.pair = true,
    this.doubleRedouble = true,
    this.seventhCard = true,
    this.redealChecks = true,
    this.singleHand = false,
    this.targetGamePoints = 6,
  });

  /// Reads a config written by [toJson]. Missing keys take their default.
  ///
  /// Throws a [FormatException] for an unknown key, a value of the wrong
  /// type, or a value outside the allowed range.
  factory TwentyNineConfig.fromJson(Map<String, Object?> json) {
    final unknown = json.keys.where((key) => !_keys.contains(key)).toList();
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown Twenty-Nine rule options: $unknown');
    }
    const defaults = TwentyNineConfig();
    final config = TwentyNineConfig(
      direction: _enumValue(
        json,
        'direction',
        PlayDirection.values,
        defaults.direction,
      ),
      minBid: _value(json, 'minBid', defaults.minBid),
      lastTrickPoint: _value(json, 'lastTrickPoint', defaults.lastTrickPoint),
      askTrump: _enumValue(
        json,
        'askTrump',
        AskTrumpRule.values,
        defaults.askTrump,
      ),
      allPass: _enumValue(
        json,
        'allPass',
        AllPassRule.values,
        defaults.allPass,
      ),
      pair: _value(json, 'pair', defaults.pair),
      doubleRedouble: _value(json, 'doubleRedouble', defaults.doubleRedouble),
      seventhCard: _value(json, 'seventhCard', defaults.seventhCard),
      redealChecks: _value(json, 'redealChecks', defaults.redealChecks),
      singleHand: _value(json, 'singleHand', defaults.singleHand),
      targetGamePoints: _value(
        json,
        'targetGamePoints',
        defaults.targetGamePoints,
      ),
    );
    final problem = config.problem;
    if (problem != null) throw FormatException(problem);
    return config;
  }

  /// Reads the rule options of [config].
  factory TwentyNineConfig.fromMatchConfig(MatchConfig config) =>
      TwentyNineConfig.fromJson(config.rules);

  static const Set<String> _keys = {
    'direction',
    'minBid',
    'lastTrickPoint',
    'askTrump',
    'allPass',
    'pair',
    'doubleRedouble',
    'seventhCard',
    'redealChecks',
    'singleHand',
    'targetGamePoints',
  };

  /// The bids a config may set as the minimum.
  static const List<int> allowedMinBids = [15, 16];

  /// The game points that end a match at every new table (AGENTS.md §6.2,
  /// fixed by the owner on 2026-10-10). The engine still replays logs with
  /// any target from [minTargetGamePoints] to [maxTargetGamePoints], so
  /// released logs replay (§5.7); the app and the server allow only this.
  static const int fixedTargetGamePoints = 6;

  /// The smallest number of game points that can end a match.
  static const int minTargetGamePoints = 1;

  /// The largest number of game points that can end a match.
  static const int maxTargetGamePoints = 20;

  /// Which way play passes round the table.
  final PlayDirection direction;

  /// The lowest bid: 16, or 15.
  final int minBid;

  /// Whether the last trick is worth a point, making 29 points in all.
  final bool lastTrickPoint;

  /// What a player who cannot follow suit may do while trump is hidden.
  final AskTrumpRule askTrump;

  /// What happens when the first three players pass.
  final AllPassRule allPass;

  /// Whether a player may declare the Pair (King and Queen of trump).
  final bool pair;

  /// Whether the opponents may double and the bidding team redouble.
  final bool doubleRedouble;

  /// Whether the bidder may call "seventh card" instead of naming trump.
  final bool seventhCard;

  /// Whether weak or lopsided deals are cancelled and redealt.
  final bool redealChecks;

  /// Whether a player may declare single hand.
  final bool singleHand;

  /// The game points a team needs to win, or lose at the negative value.
  final int targetGamePoints;

  /// The highest bid: 29 with the last-trick point, 28 without.
  int get maxBid => lastTrickPoint ? 29 : 28;

  /// What is wrong with this config, or null if it is valid.
  String? get problem {
    if (!allowedMinBids.contains(minBid)) {
      return 'minBid must be one of $allowedMinBids, not $minBid';
    }
    if (targetGamePoints < minTargetGamePoints ||
        targetGamePoints > maxTargetGamePoints) {
      return 'targetGamePoints must be from $minTargetGamePoints to '
          '$maxTargetGamePoints, not $targetGamePoints';
    }
    return null;
  }

  /// A copy with the given options changed.
  TwentyNineConfig copyWith({
    PlayDirection? direction,
    int? minBid,
    bool? lastTrickPoint,
    AskTrumpRule? askTrump,
    AllPassRule? allPass,
    bool? pair,
    bool? doubleRedouble,
    bool? seventhCard,
    bool? redealChecks,
    bool? singleHand,
    int? targetGamePoints,
  }) => TwentyNineConfig(
    direction: direction ?? this.direction,
    minBid: minBid ?? this.minBid,
    lastTrickPoint: lastTrickPoint ?? this.lastTrickPoint,
    askTrump: askTrump ?? this.askTrump,
    allPass: allPass ?? this.allPass,
    pair: pair ?? this.pair,
    doubleRedouble: doubleRedouble ?? this.doubleRedouble,
    seventhCard: seventhCard ?? this.seventhCard,
    redealChecks: redealChecks ?? this.redealChecks,
    singleHand: singleHand ?? this.singleHand,
    targetGamePoints: targetGamePoints ?? this.targetGamePoints,
  );

  /// The config as JSON, with every key present.
  Map<String, Object?> toJson() => {
    'direction': direction.name,
    'minBid': minBid,
    'lastTrickPoint': lastTrickPoint,
    'askTrump': askTrump.name,
    'allPass': allPass.name,
    'pair': pair,
    'doubleRedouble': doubleRedouble,
    'seventhCard': seventhCard,
    'redealChecks': redealChecks,
    'singleHand': singleHand,
    'targetGamePoints': targetGamePoints,
  };

  /// A [MatchConfig] that starts a match with these rules.
  MatchConfig toMatchConfig() => MatchConfig(rules: toJson());

  @override
  bool operator ==(Object other) =>
      other is TwentyNineConfig &&
      other.direction == direction &&
      other.minBid == minBid &&
      other.lastTrickPoint == lastTrickPoint &&
      other.askTrump == askTrump &&
      other.allPass == allPass &&
      other.pair == pair &&
      other.doubleRedouble == doubleRedouble &&
      other.seventhCard == seventhCard &&
      other.redealChecks == redealChecks &&
      other.singleHand == singleHand &&
      other.targetGamePoints == targetGamePoints;

  @override
  int get hashCode => Object.hash(
    direction,
    minBid,
    lastTrickPoint,
    askTrump,
    allPass,
    pair,
    doubleRedouble,
    seventhCard,
    redealChecks,
    singleHand,
    targetGamePoints,
  );

  @override
  String toString() => 'TwentyNineConfig(${toJson()})';

  static T _value<T>(Map<String, Object?> json, String key, T fallback) {
    if (!json.containsKey(key)) return fallback;
    final value = json[key];
    if (value is! T) {
      throw FormatException('Rule option $key must be a $T, not $value');
    }
    return value;
  }

  static T _enumValue<T extends Enum>(
    Map<String, Object?> json,
    String key,
    List<T> values,
    T fallback,
  ) {
    if (!json.containsKey(key)) return fallback;
    final name = json[key];
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException(
      'Rule option $key must be one of ${values.map((v) => v.name)}, '
      'not $name',
    );
  }
}
