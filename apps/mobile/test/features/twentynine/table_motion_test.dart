import 'package:card_games/features/games/twentynine/widgets/table_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:material_ui/material_ui.dart' hide Card;

import '../../helpers/pump_app.dart';

const TwentyNineGame game = TwentyNineGame();

/// A first deal, with [calls] made in turn from the first player.
TwentyNineState auction(List<int?> calls, {int seed = 3}) {
  var state = game.init(
    const TwentyNineConfig(redealChecks: false).toMatchConfig(),
    seed,
  );
  for (final call in calls) {
    final seat = state.turn!;
    state = game.apply(state, call == null ? Pass(seat) : Bid(seat, call));
  }
  return state;
}

/// The first trick of a deal: everyone passes to the dealer, who names
/// spades; nobody doubles.
TwentyNineState firstTrick({int seed = 3}) {
  var state = auction([null, null, null], seed: seed);
  while (state.phase != TwentyNinePhase.play) {
    final legal = game.legalActions(state, state.turn!);
    state = game.apply(
      state,
      legal.firstWhere(
        (a) => a is Bid || a is ChooseTrump || a is NoDouble || a is NoRedouble,
        orElse: () => legal.first,
      ),
    );
  }
  return state;
}

/// The trick buttons of the auction, by key, for the seat to act.
Future<List<TwentyNineAction>> showBids(
  WidgetTester tester,
  TwentyNineState state,
) async {
  final chosen = <TwentyNineAction>[];
  await pumpInApp(
    tester,
    ActionPanel(
      view: game.viewFor(state, state.turn!),
      onAction: chosen.add,
      waitingFor: null,
    ),
  );
  return chosen;
}

String labelOf(WidgetTester tester, String key) {
  final button = find.byKey(ValueKey(key));
  return tester
      .widget<Text>(find.descendant(of: button, matching: find.byType(Text)))
      .data!;
}

bool enabled(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.byKey(ValueKey(key))).onPressed != null;

void main() {
  group('bidding with +1, +4 and Match', () {
    testWidgets('the first call opens at the minimum, or four above it', (
      tester,
    ) async {
      final chosen = await showBids(tester, auction(const []));
      expect(labelOf(tester, 'bid-plus-1'), '+1 (16)');
      expect(labelOf(tester, 'bid-plus-4'), '+4 (19)');
      expect(find.byKey(const ValueKey('pass')), findsOneWidget);
      expect(find.byKey(const ValueKey('bid-16')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('bid-plus-4')));
      await tester.tap(find.byKey(const ValueKey('bid-plus-1')));
      final seat = auction(const []).turn!;
      expect(chosen, [Bid(seat, 19), Bid(seat, 16)]);
    });

    testWidgets('raises go above the highest bid', (tester) async {
      await showBids(tester, auction(const [17]));
      expect(labelOf(tester, 'bid-plus-1'), '+1 (18)');
      expect(labelOf(tester, 'bid-plus-4'), '+4 (21)');
      expect(enabled(tester, 'bid-plus-4'), isTrue);
    });

    testWidgets('a raise past 29 is disabled', (tester) async {
      await showBids(tester, auction(const [26]));
      expect(labelOf(tester, 'bid-plus-4'), '+4 (30)');
      expect(enabled(tester, 'bid-plus-4'), isFalse);
      expect(enabled(tester, 'bid-plus-1'), isTrue);
    });

    testWidgets('a dealer who must bid has only +1, at the minimum', (
      tester,
    ) async {
      await showBids(tester, auction(const [null, null, null]));
      expect(find.byKey(const ValueKey('pass')), findsNothing);
      expect(labelOf(tester, 'bid-plus-1'), '+1 (16)');
      expect(enabled(tester, 'bid-plus-1'), isTrue);
      expect(enabled(tester, 'bid-plus-4'), isFalse);
    });

    testWidgets('the new bidder cannot match; it must raise or pass', (
      tester,
    ) async {
      await showBids(tester, auction(const [17]));
      expect(labelOf(tester, 'bid-match'), 'Match');
      expect(enabled(tester, 'bid-match'), isFalse);
    });

    testWidgets('a seat that matched says so', (tester) async {
      var state = auction(const [16, 17]);
      final old = state.turn!;
      state = game.apply(state, MatchBid(old, 17));
      await pumpInApp(
        tester,
        SeatPanel(
          view: game.viewFor(state, const Seat(0)),
          seat: old,
          active: false,
        ),
      );
      expect(find.text('Match 17'), findsOneWidget);
    });

    testWidgets("the old bidder may match the new bidder's bid", (
      tester,
    ) async {
      final state = auction(const [16, 17]);
      final chosen = await showBids(tester, state);
      expect(labelOf(tester, 'bid-match'), 'Match (17)');
      expect(enabled(tester, 'bid-match'), isTrue);
      await tester.tap(find.byKey(const ValueKey('bid-match')));
      expect(chosen, [MatchBid(state.turn!, 17)]);
    });
  });

  group('throwing a card by swiping it up', () {
    Future<List<Card>> showHand(WidgetTester tester) async {
      final played = <Card>[];
      await pumpInApp(
        tester,
        SizedBox(
          width: 360,
          child: HandView(
            cards: [Card.parse('JS'), Card.parse('9H')],
            playable: {Card.parse('JS')},
            onPlay: played.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return played;
    }

    testWidgets('a swipe up plays a playable card', (tester) async {
      final played = await showHand(tester);
      await tester.drag(
        find.byKey(const ValueKey('hand-JS')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(played, [Card.parse('JS')]);
    });

    testWidgets('a short pull springs back; a card not playable stays', (
      tester,
    ) async {
      final played = await showHand(tester);
      await tester.timedDrag(
        find.byKey(const ValueKey('hand-JS')),
        // Past the touch slop, so not a tap, but short of a throw.
        const Offset(0, -26),
        const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('hand-9H')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(played, isEmpty);
    });

    testWidgets('a tap still plays', (tester) async {
      final played = await showHand(tester);
      await tester.tap(find.byKey(const ValueKey('hand-JS')));
      expect(played, [Card.parse('JS')]);
    });
  });

  group('cards on the table', () {
    Future<void> showTrick(
      WidgetTester tester,
      TwentyNineState state, {
      bool still = false,
    }) => pumpInApp(
      tester,
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: SizedBox(
          width: 300,
          height: 300,
          child: TrickArea(
            view: game.viewFor(state, const Seat(0)),
            cardWidth: 60,
          ),
        ),
      ),
    );

    TwentyNineState led() {
      for (var seed = 3; ; seed++) {
        var state = firstTrick(seed: seed);
        if (state.turn != const Seat(2)) continue;
        state = game.apply(state, game.legalActions(state, state.turn!).first);
        return state;
      }
    }

    testWidgets('a played card flies in from its player', (tester) async {
      final state = led();
      final card = state.trick.single.card;
      await showTrick(tester, state);
      final area = tester.getRect(find.byType(TrickArea));
      final start = tester.getCenter(find.byKey(ValueKey('table-${card.id}')));
      expect(start.dy, lessThan(area.top), reason: 'above the table: partner');
      await tester.pumpAndSettle();
      final end = tester.getCenter(find.byKey(ValueKey('table-${card.id}')));
      expect(end.dy, greaterThan(area.top));
      expect(end.dy, lessThan(area.center.dy), reason: 'in the top place');
    });

    testWidgets('a finished trick goes to its winner and fades', (
      tester,
    ) async {
      var state = led();
      while (state.tricks.isEmpty) {
        state = game.apply(state, game.legalActions(state, state.turn!).first);
      }
      final trick = state.tricks.single;
      await showTrick(tester, state);
      expect(
        find.text(
          'Trick to ${['You', 'Right', 'Partner', 'Left'][trick.winner.index]}',
        ),
        findsNothing,
      );
      await tester.pump(TrickArea.collectTime * 0.4);
      final held = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(ValueKey('table-${trick.plays.first.card.id}')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(held.opacity, 1, reason: 'the trick shows a moment first');
      await tester.pumpAndSettle();
      for (final play in trick.plays) {
        final faded = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey('table-${play.card.id}')),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(faded.opacity, 0);
      }
    });

    testWidgets('with less motion, cards just appear and the last trick '
        'stays', (tester) async {
      var state = led();
      final first = state.trick.single.card;
      await showTrick(tester, state, still: true);
      final area = tester.getRect(find.byType(TrickArea));
      expect(
        tester.getCenter(find.byKey(ValueKey('table-${first.id}'))).dy,
        greaterThan(area.top),
      );
      while (state.tricks.isEmpty) {
        state = game.apply(state, game.legalActions(state, state.turn!).first);
      }
      await showTrick(tester, state, still: true);
      await tester.pumpAndSettle();
      final dimmed = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(ValueKey('table-${first.id}')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(dimmed.opacity, 0.7);
    });
  });

  group('dealing', () {
    Future<void> showDeal(
      WidgetTester tester,
      TwentyNineState state, {
      bool still = false,
    }) => pumpInApp(
      tester,
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: SizedBox(
          width: 360,
          height: 400,
          child: DealSweep(
            view: game.viewFor(state, const Seat(0)),
            cardWidth: 60,
          ),
        ),
      ),
    );

    testWidgets('a new deal sends a packet of cards to each seat in turn', (
      tester,
    ) async {
      await showDeal(tester, auction(const []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const ValueKey('deal-packet-0')), findsOneWidget);
      await tester.pump(DealSweep.stagger * 3);
      expect(find.byKey(const ValueKey('deal-packet-3')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('deal-packet-3')), findsNothing);
    });

    testWidgets('the second four cards are dealt the same way', (tester) async {
      final before = auction(const [null, null, null, 16]);
      final after = firstTrick();
      await showDeal(tester, before);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('deal-packet-0')), findsNothing);
      await showDeal(tester, after);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const ValueKey('deal-packet-0')), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('with less motion there is no dealing to watch', (
      tester,
    ) async {
      await showDeal(tester, auction(const []), still: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const ValueKey('deal-packet-0')), findsNothing);
    });
  });
}
