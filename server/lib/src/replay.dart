import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

/// What a match's log, as far as it has arrived, comes to.
sealed class ReplayOutcome {
  const ReplayOutcome();
}

/// Valid so far, but not over: more events are expected.
final class ReplayOpen extends ReplayOutcome {
  /// The log is a valid start of a match.
  const ReplayOpen();
}

/// How a complete match ended for the player, and where it left the game.
enum MatchOutcome {
  /// The player's side won.
  won,

  /// The player's side lost.
  lost,

  /// The player quit.
  quit,
}

/// Valid and complete: played to the end and voted on, or quit.
final class ReplayComplete extends ReplayOutcome {
  /// The match is over, ended as [outcome] and earned [coins]. It left the
  /// player's team at [recordAfter] in the game, which [continues] or not.
  const ReplayComplete(
    this.coins, {
    required this.outcome,
    required this.recordAfter,
    required this.continues,
  });

  /// What the match moves for the player, from the shared coin rules.
  final List<CoinEntry> coins;

  /// How the match ended for the player.
  final MatchOutcome outcome;

  /// The player's team's match record in the game after this match.
  final int recordAfter;

  /// Whether the game goes on to another match.
  final bool continues;
}

/// The log does not replay; the match earns nothing (AGENTS.md §9).
final class ReplayRejected extends ReplayOutcome {
  /// The log is refused for [reason].
  const ReplayRejected(this.reason);

  /// Why, in words for the flag on the match. Never personal data.
  final String reason;
}

/// Checks the logs of one game by replaying them with its rules.
abstract interface class MatchReplayer {
  /// The game, for example `twentynine`.
  String get gameId;

  /// The rules versions whose logs it can replay (AGENTS.md §5.7).
  Set<int> get rulesVersions;

  /// Replays [events], a match's log from `seq` 0 with an intact chain.
  ///
  /// The match's place in its game is the one `match.created` logs; the
  /// caller checks it against the server's records of the earlier matches
  /// before trusting the outcome (AGENTS.md §6.13).
  ReplayOutcome replay(List<EventEnvelope> events);
}

/// What must stay the same in every match of a game: everything
/// `match.created` logs except the seed and the match's place in the game
/// (AGENTS.md §6.13: the same rules, seats and table fee).
String tableKeyOf(Map<String, Object?> created) {
  final table = {...created}
    ..remove('seed')
    ..remove('series');
  return sha256.convert(utf8.encode(canonicalJson(table))).toString();
}

/// An event as compared: type, actor and payload.
typedef _Logged = ({String type, String actor, String payload});

_Logged _logged(String type, String actor, Map<String, Object?> payload) =>
    (type: type, actor: actor, payload: canonicalJson(payload));

/// Thrown inside a replay to refuse the log.
final class _Refused implements Exception {
  const _Refused(this.reason);
  final String reason;
}

/// Reads the log in order, checking that it holds what the rules produce.
final class _Cursor {
  _Cursor(this._envelopes)
    : _events = [
        for (final event in _envelopes)
          _logged(event.type, event.actor, event.payload),
      ];

  final List<EventEnvelope> _envelopes;
  final List<_Logged> _events;
  int _next = 0;

  bool get atEnd => _next >= _events.length;

  /// The next event, as compared.
  _Logged get peek => _events[_next];

  /// The next event, as logged.
  EventEnvelope get peekEnvelope => _envelopes[_next];

  /// Consumes [expected] if the log holds exactly those events next.
  ///
  /// Returns false if the log ends partway through them: the rest has not
  /// been uploaded yet. Throws [_Refused] if an event differs.
  bool expect(List<_Logged> expected) {
    for (final want in expected) {
      if (atEnd) return false;
      final got = _events[_next];
      if (got != want) {
        throw _Refused(
          'event $_next should be ${want.type} by ${want.actor}, '
          'not ${got.type} by ${got.actor}',
        );
      }
      _next++;
    }
    return true;
  }
}

/// Replays logs of Twenty-Nine played offline (AGENTS.md §6, §9).
///
/// A log must hold, in order: `match.created` with the rules, seed, stake,
/// seats and place in its game; the entry fee at a staked table; the
/// engine's events as the game makes them; and, after each step, exactly
/// the rewards the coin rules give the human player's team (docs/decisions.md
/// D-024, D-025). Every action must be legal. Bots' choices cannot be
/// checked beyond that: their seeds are not logged (D-029).
///
/// Then the end of the match in its game (AGENTS.md §6.13, D-037): after
/// the match played with a 2 showing, the penalty if it was lost and the
/// end of the game; otherwise the player's vote, the penalty, and, if the
/// vote ends the game, the refund of a tie and the end. A quit is
/// `match.abandoned` with the team's score, the refund it earns and the end
/// of the game.
final class TwentyNineReplayer implements MatchReplayer {
  /// Creates the replayer.
  const TwentyNineReplayer();

  static const TwentyNineGame _game = TwentyNineGame();

  @override
  String get gameId => _game.id;

  @override
  Set<int> get rulesVersions => {_game.rulesVersion};

  @override
  ReplayOutcome replay(List<EventEnvelope> events) {
    final cursor = _Cursor(events);
    try {
      if (cursor.atEnd) return const ReplayOpen();
      final created = cursor.peek;
      if (created.type != EventTypes.matchCreated ||
          created.actor != Actors.user) {
        return const ReplayRejected(
          'the log does not start with match.created',
        );
      }
      final setup = _Setup.parse(events.first.payload);
      cursor.expect([created]);
      var state = _game.init(setup.config.toMatchConfig(), setup.seed);
      final opening = [
        if (setup.stake > 0)
          _logged(
            EventTypes.entryFee,
            Actors.user,
            EconomyPayloads.entryFee(
              stake: setup.stake,
              seats: TwentyNineRules.seatCount,
              humans: 1,
            ),
          ),
        ..._engineEvents(state.lastEvents),
      ];
      if (!cursor.expect(opening)) return const ReplayOpen();
      while (!cursor.atEnd && !state.isOver) {
        final next = cursor.peek;
        if (next.type == EventTypes.matchAbandoned) {
          return _quit(cursor, events, setup, state);
        }
        final action = TwentyNineAction.fromEvent(
          next.type,
          next.actor,
          cursor.peekEnvelope.payload,
        );
        if (action == null) {
          return ReplayRejected('unexpected event ${next.type}');
        }
        final after = _game.apply(state, action);
        final step = [
          ..._engineEvents(after.lastEvents),
          ..._rewards(setup, state, after.lastEvents),
        ];
        if (!cursor.expect(step)) return const ReplayOpen();
        state = after;
      }
      return state.isOver
          ? _end(cursor, events, setup, state)
          : const ReplayOpen();
    } on _Refused catch (refused) {
      return ReplayRejected(refused.reason);
    } on IllegalActionException catch (illegal) {
      return ReplayRejected('illegal action: ${illegal.reason}');
    } on FormatException catch (bad) {
      return ReplayRejected('malformed event: ${bad.message}');
    }
  }

  /// The rest of a log after `match.abandoned`: the player quit.
  static ReplayOutcome _quit(
    _Cursor cursor,
    List<EventEnvelope> events,
    _Setup setup,
    TwentyNineState state,
  ) {
    final score = state.scores[TwentyNineRules.teamOf(setup.human)];
    final tail = [
      _logged(
        EventTypes.matchAbandoned,
        Actors.user,
        SeriesPayloads.abandoned(score: score),
      ),
      if (setup.stake > 0)
        _logged(
          EventTypes.rewardPending,
          Actors.system,
          EconomyPayloads.quitRefund(score: score),
        ),
      _logged(
        EventTypes.seriesEnded,
        Actors.user,
        SeriesPayloads.ended(SeriesEnd.quit, record: setup.series.record),
      ),
    ];
    if (!cursor.expect(tail)) return const ReplayOpen();
    if (!cursor.atEnd) {
      return const ReplayRejected('events follow the end of the game');
    }
    return ReplayComplete(
      matchCoins(events),
      outcome: MatchOutcome.quit,
      recordAfter: setup.series.record,
      continues: false,
    );
  }

  /// The rest of a log after the match is over: the vote, the penalty, and
  /// the end of the game if it ends (AGENTS.md §6.13, §11).
  static ReplayOutcome _end(
    _Cursor cursor,
    List<EventEnvelope> events,
    _Setup setup,
    TwentyNineState state,
  ) {
    final series = setup.series;
    final won = state.winningTeam == TwentyNineRules.teamOf(setup.human);
    final record = series.recordAfter(won: won);
    final staked = setup.stake > 0;
    final penalty = [
      if (staked && !won)
        _logged(
          EventTypes.penaltyPending,
          Actors.system,
          EconomyPayloads.lossPenalty(),
        ),
    ];
    final bool continues;
    final List<_Logged> tail;
    if (series.isLastMatch) {
      continues = false;
      tail = [
        ...penalty,
        _logged(
          EventTypes.seriesEnded,
          Actors.user,
          SeriesPayloads.ended(SeriesEnd.lastMatch, record: record),
        ),
      ];
    } else {
      if (cursor.atEnd) return const ReplayOpen();
      final vote = cursor.peek;
      final choice = cursor.peekEnvelope.payload['continue'];
      if (vote.type != EventTypes.seriesVote || choice is! bool) {
        throw _Refused(
          'the match should be followed by series.vote, not ${vote.type}',
        );
      }
      continues = choice;
      tail = [
        _logged(
          EventTypes.seriesVote,
          Actors.user,
          SeriesPayloads.vote(continueGame: choice),
        ),
        ...penalty,
        if (!choice) ...[
          if (staked && record == 0)
            _logged(
              EventTypes.rewardPending,
              Actors.system,
              EconomyPayloads.tieRefund(matches: series.match),
            ),
          _logged(
            EventTypes.seriesEnded,
            Actors.user,
            SeriesPayloads.ended(SeriesEnd.vote, record: record),
          ),
        ],
      ];
    }
    if (!cursor.expect(tail)) return const ReplayOpen();
    if (!cursor.atEnd) {
      return ReplayRejected(
        continues
            ? 'events follow the vote to play on'
            : 'events follow the end of the game',
      );
    }
    return ReplayComplete(
      matchCoins(events),
      outcome: won ? MatchOutcome.won : MatchOutcome.lost,
      recordAfter: record,
      continues: continues,
    );
  }

  static List<_Logged> _engineEvents(List<TwentyNineEvent> events) => [
    for (final event in events)
      _logged(event.type, event.actor?.id ?? Actors.system, event.payload),
  ];

  /// The rewards one step earns the human player's team at a staked table.
  /// The app logs the same (`OfflineMatchController`).
  static List<_Logged> _rewards(
    _Setup setup,
    TwentyNineState before,
    List<TwentyNineEvent> events,
  ) {
    if (setup.stake == 0) return const [];
    final team = TwentyNineRules.teamOf(setup.human);
    return [
      for (final event in events)
        if (event is DealScored && event.winningTeam == team)
          _logged(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.dealWon(before.dealNumber),
          )
        else if (event is MatchEnded && event.winningTeam == team)
          // Bots never win coins: the player takes the whole pot.
          _logged(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.matchWon(winners: 1),
          ),
    ];
  }
}

/// What `match.created` says about the match.
final class _Setup {
  _Setup(this.config, this.seed, this.stake, this.human, this.series);

  /// Reads the payload of `match.created`. Matches logged before stakes
  /// existed were free practice.
  factory _Setup.parse(Map<String, Object?> payload) {
    final rules = payload['rules'];
    final seed = payload['seed'];
    final stake = payload['stake'] ?? 0;
    final seats = payload['seats'];
    if (rules is! Map<String, Object?> || seed is! String) {
      throw const _Refused('match.created lacks its rules or seed');
    }
    if (stake is! int || (stake != 0 && !CoinRules.isStake(stake))) {
      throw const _Refused('match.created names no table fee');
    }
    if (seats is! List<Object?> || seats.length != TwentyNineRules.seatCount) {
      throw const _Refused('match.created lacks its four seats');
    }
    Seat? human;
    final seen = <int>{};
    for (final entry in seats) {
      if (entry case {'seat': final int index, 'player': final String player}
          when index >= 0 && index < TwentyNineRules.seatCount) {
        if (!seen.add(index)) throw const _Refused('a seat is listed twice');
        switch (player) {
          case 'human' when human == null:
            human = Seat(index);
          case 'bot' when entry['level'] is String:
            break;
          default:
            throw const _Refused('a seat is neither the player nor a bot');
        }
      } else {
        throw const _Refused('a seat is malformed');
      }
    }
    if (human == null) throw const _Refused('no seat is the player');
    final SeriesRef series;
    try {
      series = SeriesRef.fromCreated(payload);
    } on FormatException {
      throw const _Refused('match.created has no valid place in a game');
    }
    final config = TwentyNineConfig.fromJson(rules);
    if (config.targetGamePoints != TwentyNineConfig.fixedTargetGamePoints) {
      throw const _Refused(
        'the target is fixed at ${TwentyNineConfig.fixedTargetGamePoints}',
      );
    }
    return _Setup(config, seedFromHex(seed), stake, human, series);
  }

  final TwentyNineConfig config;
  final int seed;
  final int stake;
  final Seat human;
  final SeriesRef series;
}
