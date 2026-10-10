import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

const TwentyNineGame game = TwentyNineGame();

/// IDs as the app makes them: version 7 UUIDs.
const String profileOne = '0199c4a0-0000-7000-8000-0000000000a1';
const String deviceOne = '0199c4a0-0000-7000-8000-0000000000d1';

/// The game of a match logged without one given.
const String seriesOne = '0199c4a0-0000-7000-8000-0000000000e1';

/// An event before it has its place in a chain.
typedef Raw = ({String type, String actor, Map<String, Object?> payload});

Raw raw(String type, String actor, [Map<String, Object?> payload = const {}]) =>
    (type: type, actor: actor, payload: payload);

/// The events of a match played offline, as the app logs them: the human
/// at seat 0 chooses random legal actions from [seed], and so do the bots.
///
/// The match has place [series] in its game: the first of a new game unless
/// given. At its end the player votes [continueGame], unless it is the
/// game's last match; null leaves the vote to come.
///
/// Stops after [actions] actions if given, and then quits if [abandon].
List<Raw> playMatch({
  int seed = 1,
  int stake = 100,
  int? actions,
  bool abandon = false,
  SeriesRef series = const SeriesRef.first(seriesOne),
  bool? continueGame = false,
}) {
  final random = Xoshiro256StarStar.seeded(seed);
  const config = TwentyNineConfig();
  var state = game.init(config.toMatchConfig(), seed);
  List<Raw> logged(List<TwentyNineEvent> events) => [
    for (final event in events)
      raw(event.type, event.actor?.id ?? Actors.system, event.payload),
  ];
  final log = <Raw>[
    raw(EventTypes.matchCreated, Actors.user, {
      'rules': config.toJson(),
      'seed': seedToHex(seed),
      'stake': stake,
      'seats': [
        {'seat': 0, 'player': 'human'},
        for (final seat in [1, 2, 3])
          {'seat': seat, 'player': 'bot', 'level': 'casual'},
      ],
      'series': series.toJson(),
    }),
    if (stake > 0)
      raw(
        EventTypes.entryFee,
        Actors.user,
        EconomyPayloads.entryFee(stake: stake, seats: 4, humans: 1),
      ),
    ...logged(state.lastEvents),
  ];
  var count = 0;
  while (!state.isOver && (actions == null || count < actions)) {
    final legal = game.legalActions(state, state.turn!);
    final next = game.apply(state, legal[random.nextBounded(legal.length)]);
    log.addAll(logged(next.lastEvents));
    if (stake > 0) {
      for (final event in next.lastEvents) {
        if (event is DealScored && event.winningTeam == 0) {
          log.add(
            raw(
              EventTypes.rewardPending,
              Actors.system,
              EconomyPayloads.dealWon(state.dealNumber),
            ),
          );
        } else if (event is MatchEnded && event.winningTeam == 0) {
          log.add(
            raw(
              EventTypes.rewardPending,
              Actors.system,
              EconomyPayloads.matchWon(winners: 1),
            ),
          );
        }
      }
    }
    state = next;
    count++;
  }
  if (abandon && !state.isOver) {
    final score = state.scores[0];
    log.addAll([
      raw(
        EventTypes.matchAbandoned,
        Actors.user,
        SeriesPayloads.abandoned(score: score),
      ),
      if (stake > 0)
        raw(
          EventTypes.rewardPending,
          Actors.system,
          EconomyPayloads.quitRefund(score: score),
        ),
      raw(
        EventTypes.seriesEnded,
        Actors.user,
        SeriesPayloads.ended(SeriesEnd.quit, record: series.record),
      ),
    ]);
  } else if (state.isOver) {
    log.addAll(
      matchEnd(
        series: series,
        won: state.winningTeam == 0,
        stake: stake,
        continueGame: continueGame,
      ),
    );
  }
  return log;
}

/// What the app logs after a match in place [series] that the player's
/// side [won] or not: the vote [continueGame] (none after the game's last
/// match, nor if null), the penalty for a loss, and the end of the game
/// with a tie's refund if it ends level (AGENTS.md §6.13, §11).
List<Raw> matchEnd({
  required SeriesRef series,
  required bool won,
  required int stake,
  bool? continueGame,
}) {
  final record = series.recordAfter(won: won);
  final penalty = [
    if (stake > 0 && !won)
      raw(
        EventTypes.penaltyPending,
        Actors.system,
        EconomyPayloads.lossPenalty(),
      ),
  ];
  if (series.isLastMatch) {
    return [
      ...penalty,
      raw(
        EventTypes.seriesEnded,
        Actors.user,
        SeriesPayloads.ended(SeriesEnd.lastMatch, record: record),
      ),
    ];
  }
  if (continueGame == null) return const [];
  return [
    raw(
      EventTypes.seriesVote,
      Actors.user,
      SeriesPayloads.vote(continueGame: continueGame),
    ),
    ...penalty,
    if (!continueGame) ...[
      if (stake > 0 && record == 0)
        raw(
          EventTypes.rewardPending,
          Actors.system,
          EconomyPayloads.tieRefund(matches: series.match),
        ),
      raw(
        EventTypes.seriesEnded,
        Actors.user,
        SeriesPayloads.ended(SeriesEnd.vote, record: record),
      ),
    ],
  ];
}

/// Whether the human's side won the match [events] log.
bool wonIn(List<Raw> events) =>
    events
        .lastWhere((e) => e.type == 'twentynine.matchEnded')
        .payload['winningTeam'] ==
    0;

/// [events] chained as envelopes of [matchId], logged by [profileId].
List<EventEnvelope> chain(
  List<Raw> events, {
  String matchId = '0199c4a0-0000-7000-8000-000000000001',
  String profileId = profileOne,
  String deviceId = deviceOne,
  int rulesVersion = 1,
}) {
  var prevHash = genesisHash;
  final envelopes = <EventEnvelope>[];
  for (final (seq, event) in events.indexed) {
    final envelope = EventEnvelope.next(
      eventId: uuidV7(),
      matchId: matchId,
      seq: seq,
      type: event.type,
      actor: event.actor,
      payload: event.payload,
      clientTime: DateTime.utc(2026, 10, 9),
      userId: profileId,
      deviceId: deviceId,
      gameId: 'twentynine',
      rulesVersion: rulesVersion,
      appVersion: 'test',
      prevHash: prevHash,
    );
    envelopes.add(envelope);
    prevHash = envelope.hash;
  }
  return envelopes;
}

/// The coins the human's side earns from [events]: the fee, a bonus per
/// deal won, the share of the pot or the penalty, and any refund, from the
/// shared rules.
int coinsOf(List<Raw> events) =>
    matchCoins(chain(events)).fold(0, (sum, entry) => sum + entry.amount);

/// A seed whose random match the human's side wins (or, if [won] is
/// false, loses).
int seedWhere({required bool won, int stake = 100}) {
  for (var seed = 1; ; seed++) {
    if (wonIn(playMatch(seed: seed, stake: stake)) == won) return seed;
  }
}
