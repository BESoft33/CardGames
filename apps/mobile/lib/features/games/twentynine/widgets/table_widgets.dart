import 'dart:math' as math;

import 'package:bots/bots.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:material_ui/material_ui.dart' hide Card;

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/cards/card_asset_resolver.dart';
import '../../../../shared/cards/playing_card.dart';
import '../table_layout.dart';

/// Text on the green table.
const Color _onFelt = Colors.white;

/// The team of the viewer.
int _myTeam(TwentyNineView view) => TwentyNineRules.teamOf(view.seat);

/// Whether the player asked the phone for less motion: cards then appear
/// where they go, with no animation.
bool _still(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Just off the table on each side: where a card thrown from that seat comes
/// from, and where a trick won by it goes.
const Map<ScreenSide, Alignment> _edges = {
  ScreenSide.bottom: Alignment(0, 1.9),
  ScreenSide.top: Alignment(0, -1.9),
  ScreenSide.left: Alignment(-1.9, 0),
  ScreenSide.right: Alignment(1.9, 0),
};

String _seatName(BuildContext context, TwentyNineView view, Seat seat) =>
    seatName(
      AppLocalizations.of(context),
      seat,
      me: view.seat,
      direction: view.config.direction,
    );

/// A small rounded label.
class Badge29 extends StatelessWidget {
  /// Creates a badge with [label].
  const Badge29(this.label, {super.key, this.highlight = false});

  /// The text.
  final String label;

  /// Whether to draw it in the accent colour.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber.shade700 : Colors.black38,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: _onFelt, fontSize: 12)),
    );
  }
}

/// Trump marker and contract (AGENTS.md §6.1: a spare low card of the trump
/// suit marks trump). The scores are on the table, in each [TeamCorner].
class ContractPanel extends StatelessWidget {
  /// Creates the panel for [view]; [lastMatch] if the match is its game's
  /// last (AGENTS.md §6.13).
  const ContractPanel({required this.view, this.lastMatch = false, super.key});

  /// Whether the match is played with a 2 showing: its game's last.
  final bool lastMatch;

  /// The width of the trump marker's card.
  static const double _markerWidth = 28;

  /// What the player sees.
  final TwentyNineView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine = _myTeam(view);
    final bidder = view.bidder;
    final contract = view.contract;
    final target = view.target;
    final lines = <String>[
      if (lastMatch) l10n.lastMatchLine,
      if (view.singleHandDeclarer case final declarer?)
        l10n.singleHandBy(_seatName(context, view, declarer))
      else if (bidder != null && contract != null)
        l10n.contractLine(_seatName(context, view, bidder), contract),
      if (target != null && view.singleHandDeclarer == null)
        l10n.targetLine(target),
      if (view.stake > 1) l10n.stakeLine(view.stake),
      if (view.phase == TwentyNinePhase.play ||
          view.phase == TwentyNinePhase.pair)
        l10n.pointsLine(view.cardPoints[mine], view.cardPoints[1 - mine]),
    ];
    return Container(
      // As tall as the trump marker and a line of its label, so the table
      // does not move when the marker appears after the auction.
      constraints: const BoxConstraints(
        minHeight: _markerWidth / PlayingCard.aspectRatio + 36,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _TrumpMarker(view: view),
          const SizedBox(width: 12),
          // Each line may wrap once; the panel never grows taller than
          // that, however narrow the screen or large the text.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(line, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pair of sixes a team keeps its score with, in a top corner of the
/// table, and the suits of its match cards (AGENTS.md §6.1): the red suit
/// counts what the team is ahead, the black suit what it is behind.
enum ScorePair {
  /// The player's team: 6♠ and 6♦, top left.
  ours(black: Suit.spades, red: Suit.diamonds, atStart: true),

  /// The opponents: 6♥ and 6♣, top right.
  theirs(black: Suit.clubs, red: Suit.hearts, atStart: false);

  const ScorePair({
    required this.black,
    required this.red,
    required this.atStart,
  });

  /// The suit for points lost and matches behind.
  final Suit black;

  /// The suit for points won and matches ahead.
  final Suit red;

  /// Whether the corner is at the start of the row, the left in English.
  final bool atStart;

  /// The suit that shows [count], which is ahead when positive.
  Suit suitFor(int count) => count > 0 ? red : black;
}

/// The match card for a team's net match [record] in the game (AGENTS.md
/// §6.13): 5 at one match ahead or behind, 4 at two, 3 at three and 2 at
/// four, in the suit of [pair] for that sign. None when level. The game
/// ends after the match played with a 2 showing, so the 2 also stands for a
/// record one beyond it.
Card? matchCard(ScorePair pair, int record) {
  if (record == 0) return null;
  final rank = switch (record.abs()) {
    1 => Rank.five,
    2 => Rank.four,
    3 => Rank.three,
    _ => Rank.two,
  };
  return Card(rank, pair.suitFor(record));
}

/// A team's corner of the table (AGENTS.md §6.1): its pair of sixes for
/// the game points of this match, its match card for the record in the
/// game, and the points written underneath.
///
/// At 0 both sixes lie side by side. At 1 to 5 points either way, the six
/// of that sign shows that many pips from the owner's art; at 6 or more,
/// the whole six. The match card sits on the side toward the middle.
class TeamCorner extends ConsumerWidget {
  /// Creates the corner of [team], which keeps score with [pair].
  const TeamCorner({
    required this.pair,
    required this.team,
    required this.score,
    required this.record,
    required this.width,
    this.holdsCard = true,
    super.key,
  });

  /// The team's sixes and suits.
  final ScorePair pair;

  /// The team's name: Us or Them.
  final String team;

  /// The team's game points in the match.
  final int score;

  /// The team's matches won minus matches lost in the game.
  final int record;

  /// Whether this corner shows the game's one match card (AGENTS.md §6.1):
  /// only one team does, the other shows none.
  final bool holdsCard;

  /// The width of the corner.
  final double width;

  /// The share of [width] the sixes take; the match card has the rest.
  static const double sixesFactor = 0.7;

  /// The height of the sixes' box as a multiple of its width. The owner's
  /// score art comes in several shapes; each is fitted whole into it.
  static const double heightFactor = 1.25;

  /// The width of a whole six on its own, as a share of the sixes' box:
  /// about the size of the six in the covered art.
  static const double sixFactor = 0.6;

  /// The space between cards, in points.
  static const double gap = 4;

  /// The height of the corner's art, for [width].
  static double artHeight(double width) => width * sixesFactor * heightFactor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sixesWidth = width * sixesFactor;
    final cardWidth = width - sixesWidth - gap;
    final pips = score.abs();
    final Widget sixes;
    if (pips == 0) {
      // Black at the table's edge, red toward the middle.
      final each = (sixesWidth - gap) / 2;
      final black = PlayingCard.face(Card(Rank.six, pair.black), width: each);
      final red = PlayingCard.face(Card(Rank.six, pair.red), width: each);
      sixes = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: pair.atStart
            ? [black, const SizedBox(width: gap), red]
            : [red, const SizedBox(width: gap), black],
      );
    } else if (pips > CardAssetResolver.maxCoveredPips) {
      sixes = PlayingCard.face(
        Card(Rank.six, pair.suitFor(score)),
        width: sixesWidth * sixFactor,
      );
    } else {
      final path = ref
          .watch(cardAssetResolverProvider)
          .scoreSix(pair.suitFor(score), pips);
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
      sixes = Image.asset(
        path,
        fit: BoxFit.contain,
        cacheWidth: (sixesWidth * pixelRatio).round(),
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) =>
            MissingCardAsset(path: path),
      );
    }
    final card = holdsCard ? matchCard(pair, record) : null;
    final cards = [
      SizedBox(
        key: const ValueKey('sixes'),
        width: sixesWidth,
        height: artHeight(width),
        child: Center(child: sixes),
      ),
      const SizedBox(width: gap),
      SizedBox(
        width: cardWidth,
        child: card == null
            ? null
            : PlayingCard.face(
                card,
                width: cardWidth,
                key: const ValueKey('match-card'),
              ),
      ),
    ];
    final String standing;
    if (record > 0) {
      standing = l10n.matchesAhead(record);
    } else if (record < 0) {
      standing = l10n.matchesBehind(-record);
    } else {
      standing = l10n.matchesLevel;
    }
    // One label for screen readers; the cards' own names would mislead.
    return Semantics(
      label: l10n.teamCornerLabel(team, score, standing),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pair.atStart ? cards : cards.reversed.toList(),
          ),
          Badge29(l10n.teamScore(team, score)),
        ],
      ),
    );
  }
}

class _TrumpMarker extends StatelessWidget {
  const _TrumpMarker({required this.view});

  final TwentyNineView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget card;
    final String label;
    final suit = view.trumpSuit;
    if (view.singleHandDeclarer != null) {
      return Text(l10n.trumpNone);
    } else if (view.trumpMode == TrumpMode.none) {
      return const SizedBox.shrink();
    } else if (suit != null) {
      card = PlayingCard.face(
        Card(Rank.two, suit),
        width: ContractPanel._markerWidth,
      );
      label = view.trumpRevealed ? l10n.trumpLabel : l10n.trumpOnlyYou;
    } else {
      card = const PlayingCard.back(width: ContractPanel._markerWidth);
      label = l10n.trumpHidden;
    }
    return Column(
      key: const ValueKey('trump-marker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        // Narrow, so the contract lines beside it keep their room.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 72),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Another player's seat: name, bot level, cards held, and what they have
/// said or done this deal.
class SeatPanel extends StatelessWidget {
  /// Creates the panel for [seat].
  const SeatPanel({
    required this.view,
    required this.seat,
    required this.active,
    this.level,
    super.key,
  });

  /// What the player sees.
  final TwentyNineView view;

  /// The seat shown.
  final Seat seat;

  /// Whether the table is waiting for this seat.
  final bool active;

  /// The bot level at this seat, if a bot sits here.
  final BotLevel? level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _seatName(context, view, seat);
    final level = this.level;
    final calls = view.calls;
    final call = view.phase == TwentyNinePhase.auction
        ? calls.where((c) => c.seat == seat).lastOrNull
        : null;
    // Bids only ever rise, so a bid the same as one before it is a match.
    final matched =
        call?.bid != null &&
        calls
            .take(calls.lastIndexOf(call!))
            .any((earlier) => earlier.bid == call.bid);
    final badges = <Badge29>[
      if (view.dealer == seat) Badge29(l10n.dealerBadge),
      if (call != null)
        Badge29(
          call.bid == null
              ? l10n.callPass
              : matched
              ? l10n.callMatch(call.bid!)
              : l10n.callBid(call.bid!),
        ),
      if (view.bidder == seat && view.contract != null)
        Badge29(l10n.bidderBadge(view.contract!), highlight: true),
      if (view.doubledBy == seat) Badge29(l10n.doubledBadge),
      if (view.redoubledBy == seat) Badge29(l10n.redoubledBadge),
      if (view.singleHandDeclarer == seat)
        Badge29(l10n.singleHandBadge, highlight: true),
      if (view.pairBy == seat) Badge29(l10n.pairBadge, highlight: true),
    ];
    return Container(
      key: ValueKey('seat-${seat.index}'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? Colors.amber : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _onFelt, fontWeight: FontWeight.bold),
          ),
          if (level != null)
            Text(
              l10n.botLevelName(level.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _onFelt, fontSize: 12),
            ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              const PlayingCard.back(width: 18),
              Text(
                l10n.cardsInHand(view.handSizes[seat.index]),
                style: const TextStyle(color: _onFelt, fontSize: 12),
              ),
              if (view.bidder == seat && view.seventhCardSetAside)
                Tooltip(
                  message: l10n.setAsideLabel,
                  child: const PlayingCard.back(width: 18),
                ),
            ],
          ),
          if (badges.isNotEmpty)
            Wrap(alignment: WrapAlignment.center, children: badges),
        ],
      ),
    );
  }
}

/// The cards on the table: the current trick, or the last finished one,
/// each card placed toward the seat that played it.
///
/// A card played flies in from its player's side. A finished trick stays a
/// moment, then slides off to the side of the seat that won it and fades.
/// With less motion asked for, cards simply appear, and the last trick
/// stays, dimmed, until the next one starts.
class TrickArea extends StatelessWidget {
  /// Creates the area for [view].
  const TrickArea({required this.view, required this.cardWidth, super.key});

  /// What the player sees.
  final TwentyNineView view;

  /// The width of each card.
  final double cardWidth;

  /// How long a played card takes to land.
  static const Duration throwTime = Duration(milliseconds: 340);

  /// How long a finished trick takes: the last card lands, the trick
  /// stays a moment, then goes to its winner.
  static const Duration collectTime = Duration(milliseconds: 1300);

  static const Map<ScreenSide, Alignment> _places = {
    ScreenSide.bottom: Alignment(0, 0.75),
    ScreenSide.top: Alignment(0, -0.75),
    ScreenSide.left: Alignment(-0.75, 0),
    ScreenSide.right: Alignment(0.75, 0),
  };

  ScreenSide _side(Seat seat) =>
      sideOf(seat, me: view.seat, direction: view.config.direction);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final still = _still(context);
    final showingLast =
        view.trick.isEmpty &&
        view.tricks.isNotEmpty &&
        view.phase != TwentyNinePhase.auction;
    final plays = view.trick.isNotEmpty
        ? view.trick
        : showingLast
        ? view.tricks.last.plays
        : const <TrickPlay>[];
    final asker = view.revealedBy;
    final askedHere =
        asker != null &&
        view.revealTrick == view.tricks.length &&
        view.trick.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _fit(constraints);
        Widget card(TrickPlay play) => PlayingCard.face(
          play.card,
          width: width,
          key: ValueKey('table-${play.card.id}'),
        );
        return Stack(
          // Cards fly in from, and off to, beyond the area.
          clipBehavior: Clip.none,
          children: [
            for (final (i, play) in plays.indexed)
              if (still)
                Align(
                  alignment: _places[_side(play.seat)]!,
                  child: Opacity(
                    opacity: showingLast ? 0.7 : 1,
                    child: card(play),
                  ),
                )
              else if (showingLast)
                _collected(
                  play,
                  card(play),
                  last: i == plays.length - 1,
                  winner: view.tricks.last.winner,
                )
              else
                TweenAnimationBuilder<double>(
                  key: ValueKey('throw-${play.card.id}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: throwTime,
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Align(
                    alignment: Alignment.lerp(
                      _edges[_side(play.seat)],
                      _places[_side(play.seat)],
                      t,
                    )!,
                    child: child,
                  ),
                  child: card(play),
                ),
            if (showingLast)
              Align(
                child: Badge29(
                  l10n.trickWonBy(
                    _seatName(context, view, view.tricks.last.winner),
                  ),
                ),
              )
            else if (askedHere)
              Align(
                child: Badge29(
                  l10n.askedTrumpBy(_seatName(context, view, asker)),
                ),
              ),
          ],
        );
      },
    );
  }

  /// A card of the finished trick: the [last] one lands first, then the
  /// trick waits and goes to [winner]'s side, fading.
  Widget _collected(
    TrickPlay play,
    Widget card, {
    required bool last,
    required Seat winner,
  }) {
    final place = _places[_side(play.seat)]!;
    final from = _edges[_side(play.seat)]!;
    final to = _edges[_side(winner)]!;
    return TweenAnimationBuilder<double>(
      key: ValueKey('collect-${play.card.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: collectTime,
      builder: (context, t, child) {
        final landing = Curves.easeOutCubic.transform(
          (t / 0.25).clamp(0.0, 1.0),
        );
        final going = Curves.easeIn.transform(
          ((t - 0.5) / 0.5).clamp(0.0, 1.0),
        );
        final at = last ? Alignment.lerp(from, place, landing)! : place;
        return Align(
          alignment: Alignment.lerp(at, to, going)!,
          child: Opacity(opacity: 1 - going, child: child),
        );
      },
      child: card,
    );
  }

  /// The card width for an area of [constraints]: no wider than
  /// [cardWidth], and small enough that the four places of a trick barely
  /// overlap.
  double _fit(BoxConstraints constraints) => math.max(
    32,
    math.min(
      cardWidth,
      math.min(
        constraints.maxWidth / 3.5,
        constraints.maxHeight * PlayingCard.aspectRatio / 2.2,
      ),
    ),
  );
}

/// The player's cards, overlapping, strongest first in each suit. When it
/// is the player's turn to play, the playable cards are raised and the rest
/// dimmed.
class HandView extends StatelessWidget {
  /// Creates the hand.
  const HandView({
    required this.cards,
    required this.playable,
    required this.onPlay,
    this.arrivalDelay = Duration.zero,
    super.key,
  });

  /// How long a newly dealt card waits before it slides into the hand, so
  /// that it arrives with the dealing on the table.
  final Duration arrivalDelay;

  /// The cards, in display order.
  final List<Card> cards;

  /// The cards the player may play now.
  final Set<Card> playable;

  /// Called with a playable card the player taps or swipes up; null when
  /// the player cannot play now.
  final ValueChanged<Card>? onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = cards.length;
        final cardWidth = (width / (1 + 0.5 * (count - 1).clamp(0, 7))).clamp(
          40.0,
          80.0,
        );
        final step = count > 1
            ? ((width - cardWidth) / (count - 1)).clamp(0.0, cardWidth * 0.9)
            : 0.0;
        final total = cardWidth + step * (count - 1);
        final left = (width - total) / 2;
        const lift = 12.0;
        final height = cardWidth / PlayingCard.aspectRatio + lift;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (var i = 0; i < count; i++)
                Positioned(
                  // Keyed by card, so a card keeps its place in the tree
                  // when others come and go.
                  key: ValueKey('slot-${cards[i].id}'),
                  left: left + i * step,
                  top: onPlay != null && playable.contains(cards[i]) ? 0 : lift,
                  child: _HandCard(
                    card: cards[i],
                    index: i,
                    width: cardWidth,
                    enabled: playable.contains(cards[i]),
                    onPlay: onPlay,
                    arrivalDelay: arrivalDelay,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A card in the hand. A playable card is played by a tap, or thrown by
/// swiping it up: it follows the finger and goes once pulled far enough or
/// flicked. A newly dealt card slides up into place.
class _HandCard extends StatefulWidget {
  const _HandCard({
    required this.card,
    required this.index,
    required this.width,
    required this.enabled,
    required this.onPlay,
    required this.arrivalDelay,
  });

  final Card card;
  final int index;
  final double width;
  final bool enabled;
  final ValueChanged<Card>? onPlay;
  final Duration arrivalDelay;

  /// How long a dealt card takes to slide in, and the gap between cards.
  static const Duration arrival = Duration(milliseconds: 360);
  static const Duration stagger = Duration(milliseconds: 70);

  @override
  State<_HandCard> createState() => _HandCardState();
}

class _HandCardState extends State<_HandCard> {
  double _drag = 0;

  void _play() {
    setState(() => _drag = 0);
    widget.onPlay?.call(widget.card);
  }

  @override
  Widget build(BuildContext context) {
    final canPlay = widget.onPlay != null && widget.enabled;
    final card = GestureDetector(
      key: ValueKey('hand-${widget.card.id}'),
      onTap: canPlay ? _play : null,
      onVerticalDragUpdate: canPlay
          ? (details) =>
                setState(() => _drag = math.min(0, _drag + details.delta.dy))
          : null,
      onVerticalDragEnd: canPlay
          ? (details) {
              final flicked = (details.primaryVelocity ?? 0) < -500;
              if (flicked || _drag < -widget.width * 0.4) {
                _play();
              } else {
                setState(() => _drag = 0);
              }
            }
          : null,
      onVerticalDragCancel: canPlay ? () => setState(() => _drag = 0) : null,
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Opacity(
          opacity: widget.onPlay != null && !widget.enabled ? 0.45 : 1,
          child: PlayingCard.face(widget.card, width: widget.width),
        ),
      ),
    );
    if (_still(context)) return card;
    final wait =
        widget.arrivalDelay.inMilliseconds +
        widget.index * _HandCard.stagger.inMilliseconds;
    final slide = _HandCard.arrival.inMilliseconds;
    // Outside the card's gesture detector, so taps follow the card.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: wait + slide),
      builder: (context, t, child) {
        final shown = Curves.easeOutCubic.transform(
          ((t * (wait + slide) - wait) / slide).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: shown,
          child: Transform.translate(
            offset: Offset(0, (1 - shown) * 40),
            child: child,
          ),
        );
      },
      child: card,
    );
  }
}

/// Packets of four card backs flying from the dealer to each seat in turn,
/// the first player first, whenever a batch of cards is dealt (AGENTS.md
/// §6.3). Purely for the look of play: it starts when the player's hand
/// gains four or more new cards, and never takes touches.
class DealSweep extends StatefulWidget {
  /// Creates the dealing for [view], with cards [cardWidth] wide.
  const DealSweep({required this.view, required this.cardWidth, super.key});

  /// What the player sees.
  final TwentyNineView view;

  /// The width of a card on the table.
  final double cardWidth;

  /// The gap between packets, and how long one flies.
  static const Duration stagger = Duration(milliseconds: 140);
  static const Duration flight = Duration(milliseconds: 390);

  /// How long after a batch starts the player's own packet lands.
  static Duration arrival(TwentyNineView view) {
    final turn = (view.seat.index - view.firstPlayer.index) % 4;
    return stagger * turn + flight * 0.7;
  }

  @override
  State<DealSweep> createState() => _DealSweepState();
}

class _DealSweepState extends State<DealSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DealSweep.stagger * 3 + DealSweep.flight,
  );

  @override
  void initState() {
    super.initState();
    final view = widget.view;
    // A new match opens on the first deal, before anyone has called.
    if (view.phase == TwentyNinePhase.auction && view.calls.isEmpty) {
      _start();
    }
  }

  @override
  void didUpdateWidget(DealSweep old) {
    super.didUpdateWidget(old);
    final before = old.view.hand.toSet();
    final added = widget.view.hand.where((card) => !before.contains(card));
    if (added.length >= 4) _start();
  }

  void _start() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_still(context)) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    ScreenSide side(Seat seat) =>
        sideOf(seat, me: view.seat, direction: view.config.direction);
    const targets = {
      ScreenSide.bottom: Alignment(0, 1.3),
      ScreenSide.top: Alignment(0, -0.85),
      ScreenSide.left: Alignment(-0.9, 0),
      ScreenSide.right: Alignment(0.9, 0),
    };
    const sources = {
      ScreenSide.bottom: Alignment.bottomCenter,
      ScreenSide.top: Alignment.topCenter,
      ScreenSide.left: Alignment.centerLeft,
      ScreenSide.right: Alignment.centerRight,
    };
    final total = _controller.duration!.inMilliseconds;
    final stagger = DealSweep.stagger.inMilliseconds;
    final flight = DealSweep.flight.inMilliseconds;
    final width = widget.cardWidth * 0.6;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.isAnimating) return const SizedBox.shrink();
          final now = _controller.value * total;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var turn = 0; turn < 4; turn++)
                if (now >= turn * stagger && now <= turn * stagger + flight)
                  () {
                    final seat = Seat((view.firstPlayer.index + turn) % 4);
                    final t = Curves.easeOutCubic.transform(
                      (now - turn * stagger) / flight,
                    );
                    return Align(
                      key: ValueKey('deal-packet-$turn'),
                      alignment: Alignment.lerp(
                        sources[side(view.dealer)],
                        targets[side(seat)],
                        t,
                      )!,
                      child: Opacity(
                        opacity: t < 0.8 ? 1 : (1 - t) * 5,
                        child: Transform.rotate(
                          angle: (1 - t) * 0.6,
                          child: SizedBox(
                            width: width + 6,
                            height: width / PlayingCard.aspectRatio + 6,
                            child: Stack(
                              children: [
                                for (var i = 0; i < 4; i++)
                                  Positioned(
                                    left: i * 2.0,
                                    top: i * 2.0,
                                    child: PlayingCard.back(width: width),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
            ],
          );
        },
      ),
    );
  }
}

/// The player's choices when it is their turn, other than playing a card:
/// bids, trump, doubling, single hand, the Pair, asking for trump.
class ActionPanel extends StatelessWidget {
  /// Creates the panel.
  const ActionPanel({
    required this.view,
    required this.onAction,
    required this.waitingFor,
    super.key,
  });

  /// What the player sees.
  final TwentyNineView view;

  /// Called with the action the player chooses.
  final ValueChanged<TwentyNineAction> onAction;

  /// The seat the table is waiting for, if it is not the player.
  final Seat? waitingFor;

  static const Map<Suit, String> _symbols = {
    Suit.spades: '♠',
    Suit.hearts: '♥',
    Suit.diamonds: '♦',
    Suit.clubs: '♣',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (!view.isMyTurn) {
      final waiting = waitingFor;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          waiting == null
              ? l10n.waiting
              : l10n.waitingFor(_seatName(context, view, waiting)),
          key: const ValueKey('waiting'),
          style: textTheme.bodyLarge,
        ),
      );
    }
    final legal = view.legalActions;
    // A null action shows the button disabled.
    Widget button(TwentyNineAction? action, String key, String label) =>
        Padding(
          padding: const EdgeInsets.all(3),
          child: OutlinedButton(
            key: ValueKey(key),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: action == null ? null : () => onAction(action),
            child: Text(label),
          ),
        );
    final String prompt;
    final buttons = <Widget>[];
    switch (view.phase) {
      case TwentyNinePhase.auction:
        prompt = legal.length == 1 ? l10n.promptMustBid : l10n.promptBid;
        if (legal.contains(Pass(view.seat))) {
          buttons.add(button(Pass(view.seat), 'pass', l10n.callPass));
        }
        // One or four above the highest bid; with none yet, +1 opens at
        // the minimum. A raise past the maximum is disabled.
        final base = view.highBid ?? view.config.minBid - 1;
        for (final step in const [1, 4]) {
          final bid = Bid(view.seat, base + step);
          buttons.add(
            button(
              legal.contains(bid) ? bid : null,
              'bid-plus-$step',
              l10n.raiseBid(step, base + step),
            ),
          );
        }
        // Only the old bidder may match, facing the new bidder's bid
        // (AGENTS.md §6.4); for the new bidder it stays disabled.
        final match = legal.whereType<MatchBid>().firstOrNull;
        buttons.add(
          button(
            match,
            'bid-match',
            match == null ? l10n.matchBidButton : l10n.matchBid(match.value),
          ),
        );
      case TwentyNinePhase.chooseTrump:
        prompt = l10n.promptChooseTrump;
        for (final action in legal) {
          switch (action) {
            case ChooseTrump(:final suit):
              buttons.add(
                button(
                  action,
                  'trump-${suit.letter}',
                  '${_symbols[suit]} ${l10n.suitName(suit.name)}',
                ),
              );
            case CallSeventhCard():
              buttons.add(
                button(action, 'seventh-card', l10n.seventhCardButton),
              );
            default:
          }
        }
      case TwentyNinePhase.doubling:
        prompt = l10n.promptDouble;
        buttons
          ..add(button(Double(view.seat), 'double', l10n.doubleButton))
          ..add(button(NoDouble(view.seat), 'no-double', l10n.noDoubleButton));
      case TwentyNinePhase.redoubling:
        prompt = l10n.promptRedouble;
        buttons
          ..add(button(Redouble(view.seat), 'redouble', l10n.redoubleButton))
          ..add(
            button(NoRedouble(view.seat), 'no-redouble', l10n.noRedoubleButton),
          );
      case TwentyNinePhase.singleHand:
        prompt = l10n.promptSingleHand;
        buttons
          ..add(
            button(
              DeclareSingleHand(view.seat),
              'single-hand',
              l10n.singleHandButton,
            ),
          )
          ..add(
            button(
              NoSingleHand(view.seat),
              'no-single-hand',
              l10n.noSingleHandButton,
            ),
          );
      case TwentyNinePhase.pair:
        prompt = l10n.promptPair;
        buttons
          ..add(
            button(
              DeclarePair(view.seat),
              'declare-pair',
              l10n.declarePairButton,
            ),
          )
          ..add(button(NoPair(view.seat), 'no-pair', l10n.notNowButton));
      case TwentyNinePhase.play:
        prompt = view.mustTrump == view.seat
            ? l10n.promptMustTrump
            : l10n.promptPlay;
        if (legal.contains(AskTrump(view.seat))) {
          buttons.add(
            button(AskTrump(view.seat), 'ask-trump', l10n.askTrumpButton),
          );
        }
      case TwentyNinePhase.matchOver:
        prompt = '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prompt,
            key: const ValueKey('prompt'),
            style: textTheme.titleMedium,
          ),
          // One row that scrolls sideways, so a long list of bids does
          // not push the table off a small screen.
          if (buttons.isNotEmpty)
            SingleChildScrollView(
              key: const ValueKey('action-buttons'),
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
            ),
        ],
      ),
    );
  }
}
