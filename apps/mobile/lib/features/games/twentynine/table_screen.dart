import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:sync_protocol/sync_protocol.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/cards/playing_card.dart';
import 'offline_match.dart';
import 'table_layout.dart';
import 'widgets/table_widgets.dart';

/// The least height the table needs below the app bar. A shorter window,
/// such as split screen, scrolls the table rather than crushing it.
const double _minTableHeight = 520;

Widget _fitHeight(BoxConstraints box, Widget table) =>
    box.maxHeight >= _minTableHeight
    ? table
    : SingleChildScrollView(
        child: SizedBox(height: _minTableHeight, child: table),
      );

/// The table of an offline match: the player at the bottom, the partner at
/// the top and the opponents left and right in play order (AGENTS.md §5.10).
class TwentyNineTableScreen extends ConsumerWidget {
  /// Creates the screen.
  const TwentyNineTableScreen({super.key});

  /// Asks before quitting a match in play, saying what quitting returns
  /// (docs/decisions.md D-024).
  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    TableState table,
  ) async {
    final l10n = AppLocalizations.of(context);
    final score = table.view.scores[TwentyNineRules.teamOf(table.view.seat)];
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.leaveBody),
            if (table.stake > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.quitRefundLine(
                  CoinRules.quitRefund(
                    table.stake,
                    seats: TwentyNineRules.seatCount,
                    humans: 1,
                    score: score,
                  ),
                ),
                key: const ValueKey('quit-refund'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('stay'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.stayButton),
          ),
          FilledButton(
            key: const ValueKey('leave'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.leaveButton),
          ),
        ],
      ),
    );
    if (leave != true) return;
    await ref.read(offlineMatchProvider.notifier).leave();
    if (context.mounted) context.go(AppRoutes.lobby);
  }

  /// Leaves the table: a match in play is quit once the player confirms;
  /// after a match, before the vote, leaving ends the game (AGENTS.md
  /// §6.13); after the game, the table is simply left.
  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    TableState table,
  ) async {
    if (table.gameEnd != null) {
      context.go(AppRoutes.lobby);
    } else if (table.voting) {
      await ref.read(offlineMatchProvider.notifier).leave();
      if (context.mounted) context.go(AppRoutes.lobby);
    } else {
      await _confirmLeave(context, ref, table);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final table = ref.watch(offlineMatchProvider);
    if (table == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tableTitle)),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.twentyNine),
            child: Text(l10n.newGameButton),
          ),
        ),
      );
    }
    final view = table.view;
    final controller = ref.read(offlineMatchProvider.notifier);
    final over = view.phase == TwentyNinePhase.matchOver;
    final mine = TwentyNineRules.teamOf(view.seat);
    // While a Pair decision is pending the view names nobody; the next
    // leader is shown instead so the wait gives nothing away.
    final acting = view.turn ?? (over ? null : view.trickLeader);
    Seat seatOn(ScreenSide side) =>
        [
          for (var i = 0; i < TwentyNineRules.seatCount; i++) Seat(i),
        ].firstWhere(
          (seat) =>
              sideOf(seat, me: view.seat, direction: view.config.direction) ==
              side,
        );
    // A seat panel shrinks to fit where space is short, rather than
    // overflowing the table on a small screen.
    Widget seatPanel(ScreenSide side) {
      final seat = seatOn(side);
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: SeatPanel(
          view: view,
          seat: seat,
          active: seat == acting,
          level: table.bots[seat],
        ),
      );
    }

    final playing =
        view.phase == TwentyNinePhase.play && view.isMyTurn && !over;
    final playable = {
      for (final action in view.legalActions)
        if (action is PlayCard) action.card,
    };

    return PopScope(
      canPop: table.gameEnd != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, ref, table);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tableTitle),
          leading: IconButton(
            key: const ValueKey('leave-table'),
            icon: const Icon(Icons.close),
            tooltip: l10n.leaveButton,
            onPressed: () => _leave(context, ref, table),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  table.stake > 0
                      ? l10n.tableFeeOption(table.stake)
                      : l10n.practiceOption,
                  key: const ValueKey('table-stake'),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, box) => _fitHeight(
                box,
                Column(
                  children: [
                    ContractPanel(
                      view: view,
                      lastMatch: table.series?.isLastMatch ?? false,
                    ),
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0xFF1E7A3C), Color(0xFF0F4D24)],
                            radius: 1.1,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth / 6).clamp(
                              44.0,
                              72.0,
                            );
                            // The side seats get a fixed share, so long names
                            // and badges wrap instead of squeezing the trick.
                            final sideWidth = (constraints.maxWidth * 0.24)
                                .clamp(80.0, 130.0);
                            // Each team's corner takes what the partner's
                            // seat leaves. Where space is short its art
                            // shrinks first, so the points underneath stay
                            // readable.
                            final cornerWidth =
                                ((constraints.maxWidth - 16 - sideWidth * 1.6) /
                                        2)
                                    .clamp(sideWidth, 160.0);
                            final artWidth =
                                ((constraints.maxHeight * 0.3 - 24) /
                                        TeamCorner.artHeight(1))
                                    .clamp(40.0, cornerWidth);
                            // One match card, in one corner: the team ahead's
                            // in red, or the team behind's in black.
                            final ourCard =
                                table.record != 0 &&
                                (table.record > 0) != table.trailing;
                            Widget corner(ScorePair pair) {
                              final team = pair == ScorePair.ours
                                  ? mine
                                  : 1 - mine;
                              return SizedBox(
                                width: cornerWidth,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: pair.atStart
                                      ? AlignmentDirectional.topStart
                                      : AlignmentDirectional.topEnd,
                                  child: TeamCorner(
                                    key: ValueKey(
                                      pair == ScorePair.ours
                                          ? 'score-us'
                                          : 'score-them',
                                    ),
                                    pair: pair,
                                    team: pair == ScorePair.ours
                                        ? l10n.scoreUs
                                        : l10n.scoreThem,
                                    score: view.scores[team],
                                    record: pair == ScorePair.ours
                                        ? table.record
                                        : -table.record,
                                    holdsCard: pair == ScorePair.ours
                                        ? ourCard
                                        : table.record != 0 && !ourCard,
                                    width: artWidth,
                                  ),
                                ),
                              );
                            }

                            final felt = Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  // The partner, with each team's sixes and
                                  // match card in the two top corners
                                  // (AGENTS.md §6.1): the player's team on
                                  // the left.
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: constraints.maxHeight * 0.3,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        corner(ScorePair.ours),
                                        Expanded(
                                          child: Center(
                                            heightFactor: 1,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: sideWidth * 1.6,
                                              ),
                                              child: seatPanel(ScreenSide.top),
                                            ),
                                          ),
                                        ),
                                        corner(ScorePair.theirs),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: sideWidth,
                                          child: seatPanel(ScreenSide.left),
                                        ),
                                        Expanded(
                                          child: TrickArea(
                                            view: view,
                                            cardWidth: cardWidth,
                                          ),
                                        ),
                                        SizedBox(
                                          width: sideWidth,
                                          child: seatPanel(ScreenSide.right),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                            // The dealing flies over the whole table.
                            return Stack(
                              children: [
                                felt,
                                Positioned.fill(
                                  child: DealSweep(
                                    view: view,
                                    cardWidth: cardWidth,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    ActionPanel(
                      view: view,
                      onAction: controller.act,
                      waitingFor: acting == view.seat ? null : acting,
                    ),
                    if (view.trumpSuit != null &&
                        view.seventhCardSetAside &&
                        view.bidder == view.seat &&
                        view.seventhCard != null)
                      Row(
                        key: const ValueKey('own-seventh-card'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.setAsideLabel),
                          const SizedBox(width: 6),
                          PlayingCard.face(view.seventhCard!, width: 24),
                        ],
                      ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: HandView(
                          cards: sortedHand(view.hand),
                          playable: playable,
                          arrivalDelay: DealSweep.arrival(view),
                          onPlay: playing
                              ? (card) =>
                                    controller.act(PlayCard(view.seat, card))
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (table.dealResult case final result?)
              _ResultPanel(
                view: view,
                result: result,
                stake: table.stake,
                matchEnded: table.matchEnded,
                onDismiss: controller.dismissDealResult,
              )
            else if (over)
              _MatchOverPanel(
                table: table,
                onVote: (continueGame) async {
                  final message = l10n.notEnoughCoins;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await controller.vote(continueGame: continueGame);
                  } on NotEnoughCoins {
                    messenger.showSnackBar(SnackBar(content: Text(message)));
                  }
                },
                onNewGame: () async {
                  await controller.leave();
                  if (context.mounted) context.go(AppRoutes.twentyNine);
                },
                onLobby: () async {
                  await controller.leave();
                  if (context.mounted) context.go(AppRoutes.lobby);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A panel over the table, with a dimmed background.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              // Scrolls in a short window, such as split screen.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.view,
    required this.result,
    required this.stake,
    required this.matchEnded,
    required this.onDismiss,
  });

  final TwentyNineView view;
  final DealScored result;

  /// The table fee, or 0 in practice.
  final int stake;

  /// Whether the deal ended the match.
  final bool matchEnded;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final mine = TwentyNineRules.teamOf(view.seat);
    final title = switch (result.outcome) {
      DealOutcome.contractMade => l10n.resultMade,
      DealOutcome.contractFailed => l10n.resultFailed,
      DealOutcome.voided => l10n.resultVoid,
      DealOutcome.singleHandWon => l10n.resultSingleHandWon,
      DealOutcome.singleHandLost => l10n.resultSingleHandLost,
    };
    final team = result.team == mine ? l10n.scoreUs : l10n.scoreThem;
    final delta = result.delta;
    final change = delta == 0
        ? l10n.resultNoChange
        : l10n.resultChange(team, delta > 0 ? '+$delta' : '$delta');
    final over = matchEnded || view.phase == TwentyNinePhase.matchOver;
    return _Overlay(
      children: [
        Text(
          title,
          key: const ValueKey('deal-result'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (result.outcome != DealOutcome.singleHandWon &&
            result.outcome != DealOutcome.singleHandLost)
          Text(
            l10n.pointsLine(
              result.teamPoints[mine],
              result.teamPoints[1 - mine],
            ),
          ),
        if (result.target case final target?) Text(l10n.targetLine(target)),
        Text(change, style: textTheme.titleMedium),
        Text(l10n.resultScores(result.scores[mine], result.scores[1 - mine])),
        if (stake > 0 && result.winningTeam == mine)
          Text(
            l10n.dealCoins(CoinRules.dealWon(stake)),
            key: const ValueKey('deal-coins'),
            style: textTheme.titleSmall,
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('next-deal'),
          onPressed: onDismiss,
          child: Text(over ? l10n.finalResultButton : l10n.nextDealButton),
        ),
      ],
    );
  }
}

/// After a match: its result and coins, then the vote whether to play on
/// (AGENTS.md §6.13), or the game's result once it has ended.
class _MatchOverPanel extends StatelessWidget {
  const _MatchOverPanel({
    required this.table,
    required this.onVote,
    required this.onNewGame,
    required this.onLobby,
  });

  final TableState table;
  final ValueChanged<bool> onVote;
  final VoidCallback onNewGame;
  final VoidCallback onLobby;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final view = table.view;
    final stake = table.stake;
    final mine = TwentyNineRules.teamOf(view.seat);
    final won = view.winningTeam == mine;
    final record = table.record;
    final standing = record > 0
        ? l10n.matchesAhead(record)
        : record < 0
        ? l10n.matchesBehind(-record)
        : l10n.matchesLevel;
    final gameOver = table.gameEnd != null;
    final matches = table.series?.match ?? 1;
    return _Overlay(
      children: [
        if (gameOver)
          Text(
            record > 0
                ? l10n.gameWon
                : record < 0
                ? l10n.gameLost
                : l10n.gameTied,
            key: const ValueKey('game-result'),
            style: textTheme.titleLarge,
          ),
        Text(
          won ? l10n.matchWon : l10n.matchLost,
          key: const ValueKey('match-result'),
          style: gameOver ? textTheme.titleMedium : textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.resultScores(view.scores[mine], view.scores[1 - mine])),
        if (stake > 0 && won)
          Text(
            l10n.matchCoins(
              CoinRules.matchWon(
                stake,
                seats: TwentyNineRules.seatCount,
                humans: 1,
                winners: 1,
              ),
            ),
            key: const ValueKey('match-coins'),
            style: textTheme.titleSmall,
          ),
        if (stake > 0 && !won)
          Text(
            l10n.matchPenalty(
              CoinRules.lossPenalty(
                stake,
                seats: TwentyNineRules.seatCount,
                humans: 1,
              ),
            ),
            key: const ValueKey('match-penalty'),
            style: textTheme.titleSmall,
          ),
        Text(l10n.recordLine(standing), key: const ValueKey('game-record')),
        if (gameOver && stake > 0 && record == 0)
          Text(
            l10n.tieRefundLine(CoinRules.tieRefund(stake, matches: matches)),
            key: const ValueKey('tie-refund'),
            style: textTheme.titleSmall,
          ),
        const SizedBox(height: 16),
        if (gameOver)
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('new-game'),
                onPressed: onNewGame,
                child: Text(l10n.newGameButton),
              ),
              OutlinedButton(
                key: const ValueKey('to-lobby'),
                onPressed: onLobby,
                child: Text(l10n.lobbyButton),
              ),
            ],
          )
        else ...[
          Text(l10n.playOnQuestion, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('next-match'),
                onPressed: () => onVote(true),
                child: Text(l10n.nextMatchButton),
              ),
              OutlinedButton(
                key: const ValueKey('end-game'),
                onPressed: () => onVote(false),
                child: Text(l10n.endGameButton),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
