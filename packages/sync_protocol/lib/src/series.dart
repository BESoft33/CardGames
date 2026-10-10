import 'uuid.dart';

/// The rules of a game: a series of matches at one table, with the same
/// rules, seats and fee (AGENTS.md §6.13). In code a game of matches is a
/// series, because `gameId` already names the card game.
abstract final class SeriesRules {
  /// The match record, either way, at which the 2 shows. The match played
  /// then is the game's last.
  static const int lastMatchRecord = 4;

  /// Whether a match that starts with the player's team at [recordBefore]
  /// is the last of its game.
  static bool isLastMatch(int recordBefore) =>
      recordBefore.abs() >= lastMatchRecord;
}

/// Why a game ended.
enum SeriesEnd {
  /// The match played with a 2 showing is over.
  lastMatch,

  /// The continue vote ended it.
  vote,

  /// The player quit during a match.
  quit,
}

/// Where a match stands in its game, as `match.created` logs it under
/// `series`.
final class SeriesRef {
  /// Match number [match] of game [id], which the logging player's team
  /// starts at [record], with the match card on the [trailing] team's side
  /// or the leading team's.
  const SeriesRef({
    required this.id,
    required this.match,
    required this.record,
    this.trailing = false,
  });

  /// The first match of game [id].
  const SeriesRef.first(this.id) : match = 1, record = 0, trailing = false;

  /// Reads `series` from the payload of `match.created`.
  ///
  /// Throws a [FormatException] if it is missing or impossible: the record
  /// is the player's team's matches won minus matches lost so far, so it
  /// can be no larger than the matches played, has their parity, and stops
  /// at [SeriesRules.lastMatchRecord].
  factory SeriesRef.fromCreated(Map<String, Object?> payload) {
    if (payload['series']
        case {
          'id': final String id,
          'match': final int match,
          'record': final int record,
        }
        when isUuid(id) &&
            match >= 1 &&
            record.abs() <= match - 1 &&
            record.abs() <= SeriesRules.lastMatchRecord &&
            (match - 1 - record).isEven) {
      final trailing = (payload['series']! as Map)['trailing'] ?? false;
      if (trailing is bool) {
        return SeriesRef(
          id: id,
          match: match,
          record: record,
          trailing: trailing && record != 0,
        );
      }
    }
    throw FormatException('match.created has no valid game: $payload');
  }

  /// The game.
  final String id;

  /// This match's number in the game, from 1.
  final int match;

  /// The logging player's team's matches won minus matches lost in the
  /// game before this match.
  final int record;

  /// Whether the match card showing [record] is on the side of the team
  /// behind, in its black suit, rather than the team ahead, in its red
  /// suit (AGENTS.md §6.1). Only one team shows it.
  final bool trailing;

  /// Whether this match is the game's last: it is played with a 2 showing.
  bool get isLastMatch => SeriesRules.isLastMatch(record);

  /// The record once this match ends, which the player's side [won] or not.
  int recordAfter({required bool won}) => record + (won ? 1 : -1);

  /// Where the match card goes once this match ends, which the player's
  /// side [won] or not, and which ended when a team reached the minus
  /// target ([endedByLoss]) rather than the target (AGENTS.md §6.13). A
  /// match that takes the record away from level puts it with the loser,
  /// in black, when it ended with a loss, and with the winner, in red,
  /// otherwise; one that brings the record back toward level leaves the
  /// card where it is, one step lower; at level there is no card.
  bool trailingAfter({required bool won, required bool endedByLoss}) {
    final after = recordAfter(won: won);
    if (after == 0) return false;
    return after.abs() > record.abs() ? endedByLoss : trailing;
  }

  /// The match after this one, which the player's side [won] or not; see
  /// [trailingAfter] for [endedByLoss].
  SeriesRef next({required bool won, required bool endedByLoss}) => SeriesRef(
    id: id,
    match: match + 1,
    record: recordAfter(won: won),
    trailing: trailingAfter(won: won, endedByLoss: endedByLoss),
  );

  /// The value of `series` in `match.created`.
  Map<String, Object?> toJson() => {
    'id': id,
    'match': match,
    'record': record,
    'trailing': trailing,
  };

  @override
  bool operator ==(Object other) =>
      other is SeriesRef &&
      other.id == id &&
      other.match == match &&
      other.record == record &&
      other.trailing == trailing;

  @override
  int get hashCode => Object.hash(id, match, record, trailing);

  @override
  String toString() =>
      'SeriesRef($id, match $match, record $record'
      '${trailing ? ', card with the trailing team' : ''})';
}

/// The payloads of the game events. Like every event, they carry no amount.
abstract final class SeriesPayloads {
  /// The user voted to play the next match ([continueGame]) or to end the
  /// game.
  static Map<String, Object?> vote({required bool continueGame}) => {
    'continue': continueGame,
  };

  /// The game ended for [reason], with the user's team at [record].
  static Map<String, Object?> ended(SeriesEnd reason, {required int record}) =>
      {'reason': reason.name, 'record': record};

  /// The user quit the match with their team at [score] game points.
  static Map<String, Object?> abandoned({required int score}) => {
    'score': score,
  };
}
