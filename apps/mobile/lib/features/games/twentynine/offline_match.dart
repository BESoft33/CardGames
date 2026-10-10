import 'dart:async';

import 'package:bots/bots.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../../data/event_log.dart';
import '../../../data/local_database.dart';
import '../../../data/providers.dart';
import '../../../data/remote/providers.dart';
import '../../account/account_controller.dart';
import 'bot_players.dart';

/// What the table screen shows. It holds the player's view, never the full
/// state of the match, so the screen cannot show what the player may not
/// see (AGENTS.md §5.5).
final class TableState {
  /// Creates a table state.
  const TableState({
    required this.matchId,
    required this.view,
    required this.bots,
    this.stake = 0,
    this.series,
    this.record = 0,
    this.trailing = false,
    this.gameEnd,
    this.dealResult,
    this.matchEnded = false,
    this.botThinking = false,
  });

  /// The match being played.
  final String matchId;

  /// What the player sees.
  final TwentyNineView view;

  /// The bot level at each bot seat.
  final Map<Seat, BotLevel> bots;

  /// The table fee each seat paid, or 0 for a practice match.
  final int stake;

  /// The match's place in its game (AGENTS.md §6.13).
  final SeriesRef? series;

  /// The player's team's matches won minus matches lost in the game, this
  /// match included once it is over (AGENTS.md §6.13). The opponents'
  /// record is its negative.
  final int record;

  /// Whether the one match card showing [record] is on the side of the
  /// team behind, in its black suit, rather than the team ahead, in its
  /// red suit (AGENTS.md §6.1; [SeriesRef.trailing]).
  final bool trailing;

  /// Why the game ended, once it has.
  final SeriesEnd? gameEnd;

  /// A scored deal on screen that the player has not dismissed yet. Play
  /// waits for it, and [view] shows the deal it ended, its last trick
  /// going to the winner, until then.
  final DealScored? dealResult;

  /// Whether the match is over, though [view] may still show the end of
  /// its last deal.
  final bool matchEnded;

  /// Whether a bot is about to act.
  final bool botThinking;

  /// Whether the match is over and the player has to vote whether to play
  /// the next match of the game.
  bool get voting => view.phase == TwentyNinePhase.matchOver && gameEnd == null;
}

/// Thrown by [OfflineMatchController.start] and
/// [OfflineMatchController.vote] when the player cannot pay the table fee.
final class NotEnoughCoins implements Exception {
  /// The fee is [stake]; the player may spend [spendable].
  const NotEnoughCoins(this.stake, this.spendable);

  /// The table fee.
  final int stake;

  /// What the player may spend.
  final int spendable;

  @override
  String toString() =>
      'NotEnoughCoins: the fee is $stake, the player has $spendable';
}

/// Plays offline games of Twenty-Nine: the player in seat 0 against three
/// bots (AGENTS.md §7: offline play is one human with three bots), a match
/// at a time (§6.13). Every event is written to the event log before play
/// goes on.
final offlineMatchProvider =
    NotifierProvider<OfflineMatchController, TableState?>(
      OfflineMatchController.new,
    );

/// A match rebuilt from its log.
typedef _Rebuilt = ({
  TwentyNineState state,
  TwentyNineConfig config,
  Map<Seat, BotLevel> bots,
  int stake,
  SeriesRef series,
});

/// Runs the offline game behind [offlineMatchProvider].
class OfflineMatchController extends Notifier<TableState?> {
  /// The player's seat.
  static const Seat player = Seat(0);

  static const TwentyNineGame _game = TwentyNineGame();

  /// The player's team.
  static final int _team = TwentyNineRules.teamOf(player);

  TwentyNineState? _state;
  String? _matchId;
  TwentyNineConfig _config = const TwentyNineConfig();
  Map<Seat, BotLevel> _bots = const {};
  int _stake = 0;
  SeriesRef? _series;
  SeriesEnd? _gameEnd;
  DealScored? _dealResult;

  /// While a finished deal is shown: the player's view as that deal ended,
  /// in place of the next deal, which the engine has already dealt.
  TwentyNineView? _closing;

  /// Whether [_dealResult] is on screen yet. It waits for the last trick
  /// to go to its winner.
  bool _resultShown = false;
  bool _botsRunning = false;
  bool _botThinking = false;
  bool _trickJustEnded = false;
  bool _voting = false;

  @override
  TableState? build() => null;

  /// Starts a new game with [config], each bot playing at [level]
  /// (AGENTS.md §6.13).
  ///
  /// At a [stake] of one of [Economy.stakes] the player pays that table fee
  /// for each match and wins, loses and gets back coins as D-024 says; 0 is
  /// free practice. Any unfinished game ends first: a match in play is
  /// quit, and one awaiting the vote ends the game.
  ///
  /// Throws [NotEnoughCoins] if the player cannot pay the fee, and an
  /// [ArgumentError] if [stake] is neither 0 nor a table fee, or [config]
  /// has another target than the fixed one (AGENTS.md §6.2).
  Future<void> start(
    TwentyNineConfig config,
    BotLevel level, {
    int stake = 0,
  }) async {
    if (stake != 0 && !CoinRules.isStake(stake)) {
      throw ArgumentError.value(stake, 'stake', 'Not a table fee');
    }
    if (config.targetGamePoints != TwentyNineConfig.fixedTargetGamePoints) {
      throw ArgumentError.value(
        config.targetGamePoints,
        'config',
        'The target is fixed at ${TwentyNineConfig.fixedTargetGamePoints}',
      );
    }
    final log = await ref.read(eventLogProvider.future);
    if (stake > 0) {
      final wallet = await (await ref.read(walletRepositoryProvider.future))
          .load();
      if (!wallet.canPay(stake)) throw NotEnoughCoins(stake, wallet.spendable);
    }
    _stop();
    await _endUnfinished(log);
    await _create(
      log,
      config,
      {
        for (final index in [1, 2, 3]) Seat(index): level,
      },
      stake,
      SeriesRef.first(uuidV7()),
    );
  }

  /// Logs and starts the match of a game at [series].
  Future<void> _create(
    EventLog log,
    TwentyNineConfig config,
    Map<Seat, BotLevel> bots,
    int stake,
    SeriesRef series,
  ) async {
    final seed = secureSeed();
    final matchId = uuidV7();
    final first = _game.init(config.toMatchConfig(), seed);
    await log.append(
      matchId,
      [
        NewEvent(EventTypes.matchCreated, Actors.user, {
          'rules': config.toJson(),
          'seed': seedToHex(seed),
          'stake': stake,
          'seats': [
            {'seat': player.index, 'player': 'human'},
            for (final MapEntry(key: seat, value: level) in bots.entries)
              {'seat': seat.index, 'player': 'bot', 'level': level.name},
          ],
          'series': series.toJson(),
        }),
        if (stake > 0)
          NewEvent(
            EventTypes.entryFee,
            Actors.user,
            EconomyPayloads.entryFee(
              stake: stake,
              seats: TwentyNineRules.seatCount,
              humans: 1,
            ),
          ),
        ..._logged(first.lastEvents),
      ],
      gameId: _game.id,
      rulesVersion: _game.rulesVersion,
    );
    if (!ref.mounted) return;
    ref.invalidate(walletProvider);
    _reset(matchId, (
      state: first,
      config: config,
      bots: bots,
      stake: stake,
      series: series,
    ));
    unawaited(_runBots());
  }

  /// Continues [matchId] from the event log: in play, or over and awaiting
  /// the vote. Returns false, and closes the match, if its log cannot be
  /// replayed or its game has moved on.
  Future<bool> resume(String matchId) async {
    final log = await ref.read(eventLogProvider.future);
    final events = await log.events(matchId);
    final rebuilt = _replay(events);
    if (rebuilt == null) {
      await log.setStatus(matchId, _closedStatus(events));
      if (ref.mounted) ref.invalidate(walletProvider);
      return false;
    }
    if (!ref.mounted) return false;
    _reset(matchId, rebuilt);
    unawaited(_runBots());
    return true;
  }

  /// The match recorded in [events], or null if the log is broken, does
  /// not replay, or goes on past the match into its game's vote or end.
  _Rebuilt? _replay(List<EventEnvelope> events) {
    if (events.isEmpty || verifyChain(events) != null) return null;
    final created = events.first;
    if (created.type != EventTypes.matchCreated) return null;
    try {
      final payload = created.payload;
      final config = TwentyNineConfig.fromJson(
        payload['rules']! as Map<String, Object?>,
      );
      final stake = (payload['stake'] as int?) ?? 0;
      if (stake != 0 && !CoinRules.isStake(stake)) return null;
      // The server refuses any other target (AGENTS.md §6.2).
      if (config.targetGamePoints != TwentyNineConfig.fixedTargetGamePoints) {
        return null;
      }
      final series = SeriesRef.fromCreated(payload);
      var state = _game.init(
        config.toMatchConfig(),
        seedFromHex(payload['seed']! as String),
      );
      final seats = (payload['seats']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final bots = <Seat, BotLevel>{
        for (final seat in seats)
          if (seat['player'] == 'bot')
            Seat(seat['seat']! as int): BotLevel.values.byName(
              seat['level']! as String,
            ),
      };
      for (final event in events.skip(1)) {
        if (const {
          EventTypes.matchAbandoned,
          EventTypes.seriesVote,
          EventTypes.seriesEnded,
        }.contains(event.type)) {
          return null;
        }
        final action = TwentyNineAction.fromEvent(
          event.type,
          event.actor,
          event.payload,
        );
        if (action != null) state = _game.apply(state, action);
      }
      // The last match of a game ends it with no vote to wait for.
      if (state.isOver && series.isLastMatch) return null;
      return (
        state: state,
        config: config,
        bots: bots,
        stake: stake,
        series: series,
      );
    } on Object {
      return null;
    }
  }

  /// The status for a match [events] logs that cannot be continued.
  static MatchStatus _closedStatus(List<EventEnvelope> events) {
    final types = {for (final event in events) event.type};
    return types.contains(EventTypes.seriesVote) &&
            !types.contains(EventTypes.matchAbandoned)
        ? MatchStatus.finished
        : MatchStatus.abandoned;
  }

  /// The player takes [action]. Ignored unless it is one of the player's
  /// legal actions right now.
  Future<void> act(TwentyNineAction action) async {
    final state = _state;
    if (state == null ||
        _dealResult != null ||
        !_game.legalActions(state, player).contains(action)) {
      return;
    }
    await _apply(action);
    if (ref.mounted) unawaited(_runBots());
  }

  /// The player has seen the result of the last deal; play goes on, and
  /// the next deal's cards are dealt on screen.
  void dismissDealResult() {
    if (_dealResult == null || !_resultShown) return;
    _dealResult = null;
    _resultShown = false;
    _closing = null;
    _publish();
    unawaited(_runBots());
  }

  /// After a match, the player votes whether to play the next match of the
  /// game ([continueGame]) or to end the game (AGENTS.md §6.13). The vote
  /// comes before a lost match's penalty, which applies either way (§11).
  /// Playing on starts the next match at once.
  ///
  /// Throws [NotEnoughCoins], logging nothing, if the player could not pay
  /// the next fee after the penalty. Ignored unless a vote is due.
  Future<void> vote({required bool continueGame}) async {
    final state = _state;
    final matchId = _matchId;
    final series = _series;
    if (_voting ||
        state == null ||
        matchId == null ||
        series == null ||
        !state.isOver ||
        _gameEnd != null) {
      return;
    }
    _voting = true;
    try {
      final won = state.winningTeam == _team;
      final log = await ref.read(eventLogProvider.future);
      if (continueGame && _stake > 0) {
        final penalty = won
            ? 0
            : CoinRules.lossPenalty(
                _stake,
                seats: TwentyNineRules.seatCount,
                humans: 1,
              );
        final wallet = await (await ref.read(walletRepositoryProvider.future))
            .load();
        final left = wallet.spendable - penalty;
        if (left < _stake) throw NotEnoughCoins(_stake, left);
      }
      if (!ref.mounted || !identical(_state, state)) return;
      await log.append(
        matchId,
        _matchEnd(
          series: series,
          won: won,
          stake: _stake,
          continueGame: continueGame,
        ),
        gameId: _game.id,
        rulesVersion: _game.rulesVersion,
      );
      await log.setStatus(matchId, MatchStatus.finished);
      if (ref.mounted) ref.invalidate(walletProvider);
      _requestSync();
      if (!ref.mounted || !identical(_state, state)) return;
      if (continueGame) {
        await _create(
          log,
          _config,
          _bots,
          _stake,
          series.next(won: won, endedByLoss: _endedByLoss(state)),
        );
      } else {
        _gameEnd = SeriesEnd.vote;
        _publish();
      }
    } finally {
      _voting = false;
    }
  }

  /// Leaves the table. A match in play is quit, which ends the game and
  /// returns a share of the pot (D-024); a match awaiting the vote ends the
  /// game as a vote to stop would.
  Future<void> leave() async {
    final log = await ref.read(eventLogProvider.future);
    final state = _state;
    final matchId = _matchId;
    final series = _series;
    final stake = _stake;
    final ended = _gameEnd != null;
    _stop();
    if (ref.mounted) this.state = null;
    if (state == null || matchId == null || series == null || ended) return;
    await _close(log, matchId, state, series, stake);
  }

  /// Ends the game of [matchId], which stands at [state]: a match in play
  /// is quit; a finished one ends the game without playing on.
  Future<void> _close(
    EventLog log,
    String matchId,
    TwentyNineState state,
    SeriesRef series,
    int stake,
  ) async {
    final over = state.isOver;
    await log.append(
      matchId,
      over
          ? _matchEnd(
              series: series,
              won: state.winningTeam == _team,
              stake: stake,
              continueGame: false,
            )
          : _quit(series: series, score: state.scores[_team], stake: stake),
      gameId: _game.id,
      rulesVersion: _game.rulesVersion,
    );
    await log.setStatus(
      matchId,
      over ? MatchStatus.finished : MatchStatus.abandoned,
    );
    if (ref.mounted) ref.invalidate(walletProvider);
    _requestSync();
  }

  /// Ends the player's unfinished games of this card game: one account
  /// plays at one table at a time (AGENTS.md §7).
  Future<void> _endUnfinished(EventLog log) async {
    final seen = <String>{};
    for (;;) {
      final previous = await log.unfinishedMatch(_game.id);
      if (previous == null || !seen.add(previous)) return;
      final events = await log.events(previous);
      final rebuilt = _replay(events);
      if (rebuilt == null) {
        await log.setStatus(previous, _closedStatus(events));
      } else {
        await _close(
          log,
          previous,
          rebuilt.state,
          rebuilt.series,
          rebuilt.stake,
        );
      }
    }
  }

  /// What a match at [series] logs once it is over, which the player's
  /// side [won] or not (AGENTS.md §6.13, §11): the vote [continueGame],
  /// unless the match was the game's last; the penalty for a loss; and, if
  /// the game ends, a tie's refund and the end.
  static List<NewEvent> _matchEnd({
    required SeriesRef series,
    required bool won,
    required int stake,
    bool? continueGame,
  }) {
    final record = series.recordAfter(won: won);
    final penalty = [
      if (stake > 0 && !won)
        NewEvent(
          EventTypes.penaltyPending,
          Actors.system,
          EconomyPayloads.lossPenalty(),
        ),
    ];
    if (series.isLastMatch) {
      return [
        ...penalty,
        NewEvent(
          EventTypes.seriesEnded,
          Actors.user,
          SeriesPayloads.ended(SeriesEnd.lastMatch, record: record),
        ),
      ];
    }
    final goOn = continueGame ?? false;
    return [
      NewEvent(
        EventTypes.seriesVote,
        Actors.user,
        SeriesPayloads.vote(continueGame: goOn),
      ),
      ...penalty,
      if (!goOn) ...[
        if (stake > 0 && record == 0)
          NewEvent(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.tieRefund(matches: series.match),
          ),
        NewEvent(
          EventTypes.seriesEnded,
          Actors.user,
          SeriesPayloads.ended(SeriesEnd.vote, record: record),
        ),
      ],
    ];
  }

  /// What quitting a match at [series] logs, with the player's team at
  /// [score]: the score, the share of the pot it returns, and the end of
  /// the game. The quit match does not count in the record.
  static List<NewEvent> _quit({
    required SeriesRef series,
    required int score,
    required int stake,
  }) => [
    NewEvent(
      EventTypes.matchAbandoned,
      Actors.user,
      SeriesPayloads.abandoned(score: score),
    ),
    if (stake > 0)
      NewEvent(
        EventTypes.rewardPending,
        Actors.system,
        EconomyPayloads.quitRefund(score: score),
      ),
    NewEvent(
      EventTypes.seriesEnded,
      Actors.user,
      SeriesPayloads.ended(SeriesEnd.quit, record: series.record),
    ),
  ];

  /// Forgets the current match, so bots and pending moves for it stop.
  void _stop() {
    _state = null;
    _matchId = null;
    _series = null;
    _gameEnd = null;
    _dealResult = null;
    _closing = null;
    _resultShown = false;
  }

  void _reset(String matchId, _Rebuilt match) {
    _matchId = matchId;
    _state = match.state;
    _config = match.config;
    _bots = match.bots;
    _stake = match.stake;
    _series = match.series;
    _gameEnd = null;
    _dealResult = null;
    _closing = null;
    _resultShown = false;
    _trickJustEnded = false;
    _publish();
  }

  Future<void> _apply(TwentyNineAction action) async {
    final log = await ref.read(eventLogProvider.future);
    final matchId = _matchId;
    final current = _state;
    final series = _series;
    // Checked again after the wait: a quick second tap must not play twice.
    if (!ref.mounted ||
        matchId == null ||
        current == null ||
        series == null ||
        !_game.legalActions(current, action.seat).contains(action)) {
      return;
    }
    final next = _game.apply(current, action);
    _state = next;
    TrickWon? won;
    for (final event in next.lastEvents) {
      if (event is TrickWon) won = event;
      if (event is DealScored) {
        // The engine has dealt the next deal already. The table keeps
        // showing this one, its last trick going to the winner, then its
        // result; the new cards come once the player goes on.
        _dealResult = event;
        _closing = won != null && action is PlayCard
            ? _closingView(current, action, won, event)
            : null;
        _resultShown = false;
        _showResultAfterPause(next);
      }
    }
    _trickJustEnded = next.lastEvents.any((event) => event is TrickWon);
    // The match played with a 2 showing ends its game with it: no vote.
    final ending = next.isOver && series.isLastMatch
        ? _matchEnd(
            series: series,
            won: next.winningTeam == _team,
            stake: _stake,
          )
        : const <NewEvent>[];
    if (ending.isNotEmpty) _gameEnd = SeriesEnd.lastMatch;
    _publish();
    final rewards = _rewards(current, next.lastEvents);
    // Written even if the screen has gone: the log must match what was
    // played. Rewards go in the same write as the deal that earned them.
    await log.append(
      matchId,
      [..._logged(next.lastEvents), ...rewards, ...ending],
      gameId: _game.id,
      rulesVersion: _game.rulesVersion,
    );
    if (ending.isNotEmpty) await log.setStatus(matchId, MatchStatus.finished);
    if ((rewards.isNotEmpty || next.isOver) && ref.mounted) {
      ref.invalidate(walletProvider);
    }
    if (next.isOver) _requestSync();
  }

  /// Shows the result of the deal that ended in [scoredAt] once its last
  /// trick has gone to its winner, or at once if there is nothing to show.
  void _showResultAfterPause(TwentyNineState scoredAt) {
    final pause = ref.read(dealEndPauseProvider);
    if (pause <= Duration.zero || _closing == null) {
      _resultShown = true;
      return;
    }
    unawaited(
      Future<void>.delayed(pause, () {
        if (!ref.mounted || !identical(_state, scoredAt)) return;
        if (_dealResult == null || _resultShown) return;
        _resultShown = true;
        _publish();
      }),
    );
  }

  /// The player's view of the deal that [last] ended, as it would look
  /// before the next deal: the last trick finished and won, the scores
  /// [scored] gives.
  static TwentyNineView _closingView(
    TwentyNineState before,
    PlayCard last,
    TrickWon won,
    DealScored scored,
  ) {
    final view = _game.viewFor(before, player);
    final sizes = List.of(view.handSizes);
    if (sizes[last.seat.index] > 0) sizes[last.seat.index]--;
    return TwentyNineView(
      seat: view.seat,
      config: view.config,
      dealNumber: view.dealNumber,
      dealer: view.dealer,
      scores: scored.scores,
      phase: view.phase,
      turn: null,
      legalActions: const [],
      winningTeam: view.winningTeam,
      hand: [
        for (final card in view.hand)
          if (card != last.card) card,
      ],
      handSizes: sizes,
      calls: view.calls,
      highBid: view.highBid,
      highBidder: view.highBidder,
      bidder: view.bidder,
      contract: view.contract,
      target: view.target,
      trumpMode: view.trumpMode,
      trumpRevealed: view.trumpRevealed,
      trumpSuit: view.trumpSuit,
      seventhCard: view.seventhCard,
      seventhCardSetAside: view.seventhCardSetAside,
      revealTrick: view.revealTrick,
      revealedBy: view.revealedBy,
      doubledBy: view.doubledBy,
      redoubledBy: view.redoubledBy,
      stake: view.stake,
      singleHandDeclarer: view.singleHandDeclarer,
      tricks: [
        ...view.tricks,
        Trick(
          leader: view.trickLeader ?? last.seat,
          plays: [...view.trick, TrickPlay(last.seat, last.card)],
          winner: won.winner,
          points: won.points,
        ),
      ],
      trickLeader: won.winner,
      trick: const [],
      mustTrump: null,
      pairBy: view.pairBy,
      cardPoints: scored.teamPoints,
    );
  }

  /// Uploads the match now that it has ended (AGENTS.md §9), in a build with
  /// online services.
  void _requestSync() {
    if (ref.mounted && ref.read(authRepositoryProvider) != null) {
      unawaited(ref.read(accountProvider.notifier).sync());
    }
  }

  /// The rewards [events] earn the player at a staked table: one for each
  /// deal their team won and one for winning the match (D-024). None in
  /// practice.
  List<NewEvent> _rewards(
    TwentyNineState before,
    List<TwentyNineEvent> events,
  ) {
    if (_stake == 0) return const [];
    return [
      for (final event in events)
        if (event is DealScored && event.winningTeam == _team)
          NewEvent(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.dealWon(before.dealNumber),
          )
        else if (event is MatchEnded && event.winningTeam == _team)
          // Bots never win coins: the player takes the whole pot.
          NewEvent(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.matchWon(winners: 1),
          ),
    ];
  }

  Future<void> _runBots() async {
    if (_botsRunning) return;
    _botsRunning = true;
    try {
      for (;;) {
        final state = _state;
        if (state == null || state.isOver || _dealResult != null) break;
        final seat = state.turn!;
        final level = _bots[seat];
        if (level == null) break;
        _botThinking = true;
        _publish();
        if (_trickJustEnded) {
          _trickJustEnded = false;
          final pause = ref.read(trickPauseProvider);
          if (pause > Duration.zero) await Future<void>.delayed(pause);
          if (!ref.mounted) return;
        }
        await ref.read(botDelayProvider)();
        if (!ref.mounted || !identical(_state, state)) break;
        final action = await ref.read(botDeciderProvider)(
          _game.viewFor(state, seat),
          level,
          secureSeed(),
        );
        if (!ref.mounted || !identical(_state, state)) break;
        await _apply(action);
        if (!ref.mounted) return;
      }
    } finally {
      _botsRunning = false;
      _botThinking = false;
      _publish();
    }
  }

  void _publish() {
    final state = _state;
    final matchId = _matchId;
    final series = _series;
    if (!ref.mounted || state == null || matchId == null || series == null) {
      return;
    }
    this.state = TableState(
      matchId: matchId,
      view: _closing ?? _game.viewFor(state, player),
      bots: _bots,
      stake: _stake,
      series: series,
      record: state.isOver
          ? series.recordAfter(won: state.winningTeam == _team)
          : series.record,
      trailing: state.isOver
          ? series.trailingAfter(
              won: state.winningTeam == _team,
              endedByLoss: _endedByLoss(state),
            )
          : series.trailing,
      gameEnd: _gameEnd,
      dealResult: _resultShown ? _dealResult : null,
      matchEnded: state.isOver,
      botThinking: _botThinking,
    );
  }

  /// Whether the match [state] ended because a team reached minus the
  /// target, rather than because one reached the target (AGENTS.md §6.11).
  static bool _endedByLoss(TwentyNineState state) =>
      state.scores[1 - state.winningTeam!] <= -state.config.targetGamePoints;

  static List<NewEvent> _logged(List<TwentyNineEvent> events) => [
    for (final event in events)
      NewEvent(event.type, event.actor?.id ?? Actors.system, event.payload),
  ];
}
