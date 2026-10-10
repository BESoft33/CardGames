import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// The bid values among [actions].
List<int> bids(List<TwentyNineAction> actions) => [
  for (final action in actions)
    if (action is Bid) action.value,
];

List<int> range(int from, int to) => [for (var v = from; v <= to; v++) v];

void main() {
  group('the auction (AGENTS.md §6.4)', () {
    test('the first player speaks first and may bid 16 to 29 or pass', () {
      final table = Table.deal(dealer: 2);
      expect(table.turn, const Seat(3));
      expect(bids(table.legal()), range(16, 29));
      expect(table.legal().whereType<Pass>(), hasLength(1));
    });

    test('players bid on their first four cards only', () {
      final table = Table.deal();
      for (final hand in table.state.hands) {
        expect(hand, hasLength(4));
      }
      expect(table.view(0).hand, hasLength(4));
    });

    test('only two players bid at a time: first the first player and the '
        'next', () {
      final table = Table.deal()..act(const Bid(Seat(0), 16));
      expect(table.turn, const Seat(1));
      expect(bids(table.legal()), range(17, 29));
      expect(table.legal().whereType<MatchBid>(), isEmpty);
      for (final seat in [2, 3]) {
        expect(table.legal(seat), isEmpty, reason: 'seat $seat waits');
      }
      expect(
        () => table.act(const Bid(Seat(1), 16)),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('the old bidder may match the new bidder\'s bid; the new bidder '
        'must raise or pass', () {
      final table = Table.deal()
        ..actAll(const [Bid(Seat(0), 16), Bid(Seat(1), 17)]);
      expect(table.turn, const Seat(0));
      expect(table.legal(), contains(const MatchBid(Seat(0), 17)));
      expect(bids(table.legal()), range(18, 29), reason: 'or raise');
      table.act(const MatchBid(Seat(0), 17));
      expect(table.state.highBid, 17);
      expect(table.state.highBidder, const Seat(0));
      expect(table.turn, const Seat(1));
      expect(table.legal().whereType<MatchBid>(), isEmpty);
      expect(bids(table.legal()), range(18, 29));
      expect(
        () => table.act(const MatchBid(Seat(1), 17)),
        throwsA(isA<IllegalActionException>()),
      );
      table.act(const Bid(Seat(1), 18));
      expect(table.legal(), contains(const MatchBid(Seat(0), 18)));
    });

    test('when one of the pair passes, the next player joins against the '
        'one left', () {
      final table = Table.deal()
        ..actAll(const [Bid(Seat(0), 16), Pass(Seat(1))]);
      expect(table.turn, const Seat(2), reason: 'seat 2 joins and must raise');
      expect(bids(table.legal()), range(17, 29));
      expect(table.legal().whereType<MatchBid>(), isEmpty);
      table.act(const Bid(Seat(2), 17));
      expect(table.turn, const Seat(0));
      expect(
        table.legal(),
        contains(const MatchBid(Seat(0), 17)),
        reason: 'seat 0 is the old bidder',
      );
      expect(table.state.hasPassed(const Seat(1)), isTrue);
    });

    test('the one left after the old bidder passes is the old bidder now', () {
      final table = Table.deal()
        ..actAll(const [Bid(Seat(0), 16), Bid(Seat(1), 17), Pass(Seat(0))]);
      expect(table.turn, const Seat(2));
      table.act(const Bid(Seat(2), 18));
      expect(table.turn, const Seat(1));
      expect(table.legal(), contains(const MatchBid(Seat(1), 18)));
    });

    test('with no bid yet, the one left opens', () {
      final table = Table.deal()..act(const Pass(Seat(0)));
      expect(table.turn, const Seat(1));
      expect(bids(table.legal()), range(16, 29));
      table.act(const Pass(Seat(1)));
      expect(table.turn, const Seat(2));
      table.act(const Bid(Seat(2), 16));
      expect(table.turn, const Seat(3), reason: 'seat 3 joins and must raise');
      expect(bids(table.legal()), range(17, 29));
    });

    test('the last player standing wins and names trump', () {
      final table = Table.deal()
        ..actAll(const [
          Bid(Seat(0), 16),
          Bid(Seat(1), 17),
          MatchBid(Seat(0), 17),
          Pass(Seat(1)),
          Pass(Seat(2)),
          Bid(Seat(3), 18),
          MatchBid(Seat(0), 18),
          Pass(Seat(3)),
        ]);
      expect(table.state.bidder, const Seat(0));
      expect(table.state.contract, 18);
      expect(table.state.target, 18);
      expect(table.state.phase, TwentyNinePhase.chooseTrump);
      expect(table.turn, const Seat(0));
      final won = table.eventsOf<AuctionWon>().single;
      expect((won.bidder, won.contract), (const Seat(0), 18));
      expect(table.state.calls.map((c) => c.toString()), [
        'seat:0 16',
        'seat:1 17',
        'seat:0 17',
        'seat:1 pass',
        'seat:2 pass',
        'seat:3 18',
        'seat:0 18',
        'seat:3 pass',
      ]);
    });

    test('the new bidder wins when the old bidder passes last', () {
      final table = Table.deal()
        ..actAll(const [
          Pass(Seat(0)),
          Pass(Seat(1)),
          Bid(Seat(2), 16),
          Bid(Seat(3), 17),
          Pass(Seat(2)),
        ]);
      expect((table.state.bidder, table.state.contract), (const Seat(3), 17));
    });

    test(
      '29 ends the auction once the old bidder has matched it or passed',
      () {
        final matched = Table.deal()
          ..actAll(const [Bid(Seat(0), 16), Bid(Seat(1), 29)]);
        expect(matched.legal(), const [MatchBid(Seat(0), 29), Pass(Seat(0))]);
        matched.act(const MatchBid(Seat(0), 29));
        expect(
          (matched.state.bidder, matched.state.contract),
          (const Seat(0), 29),
        );

        final passed = Table.deal()
          ..actAll(const [Bid(Seat(0), 16), Bid(Seat(1), 29), Pass(Seat(0))]);
        expect(
          (passed.state.bidder, passed.state.contract),
          (const Seat(1), 29),
          reason: 'nobody left can go higher',
        );

        final opened = Table.deal()..act(const Bid(Seat(0), 29));
        expect(
          (opened.state.bidder, opened.state.contract),
          (const Seat(0), 29),
        );
        expect(opened.state.phase, TwentyNinePhase.chooseTrump);
      },
    );

    test('if the first three pass, the dealer must bid the minimum', () {
      final table = Table.deal()
        ..actAll(const [Pass(Seat(0)), Pass(Seat(1)), Pass(Seat(2))]);
      expect(table.turn, const Seat(3));
      expect(table.legal(), [const Bid(Seat(3), 16)]);
      expect(
        () => table.act(const Pass(Seat(3))),
        throwsA(isA<IllegalActionException>()),
      );
      table.act(const Bid(Seat(3), 16));
      expect(table.state.bidder, const Seat(3));
      expect(table.state.contract, 16);
    });

    group('with the redeal option for all passes', () {
      final config = testConfig.copyWith(allPass: AllPassRule.redeal);

      test('the dealer may bid any amount or pass', () {
        final table = Table.deal(config: config)
          ..actAll(const [Pass(Seat(0)), Pass(Seat(1)), Pass(Seat(2))]);
        expect(bids(table.legal()), range(16, 29));
        expect(table.legal().last, const Pass(Seat(3)));
        table.act(const Bid(Seat(3), 21));
        expect(table.state.bidder, const Seat(3));
        expect(table.state.contract, 21);
      });

      test('four passes cancel the deal and the same dealer redeals', () {
        final table = Table.deal(config: config)
          ..actAll(const [
            Pass(Seat(0)),
            Pass(Seat(1)),
            Pass(Seat(2)),
            Pass(Seat(3)),
          ]);
        expect(
          table.eventsOf<DealCancelled>().single.reason,
          DealCancelReason.allPassed,
        );
        expect(table.state.dealer, const Seat(3));
        expect(table.state.dealNumber, 1);
        expect(table.state.phase, TwentyNinePhase.auction);
        expect(table.state.calls, isEmpty);
        expect(table.turn, const Seat(0));
        expect(table.eventsOf<DealStarted>(), hasLength(2));
      });
    });

    test('only the seat to act has legal actions', () {
      final table = Table.deal();
      expect(table.legal(0), isNotEmpty);
      for (final seat in [1, 2, 3]) {
        expect(table.legal(seat), isEmpty);
      }
      expect(
        () => table.act(const Bid(Seat(2), 16)),
        throwsA(
          isA<IllegalActionException>().having(
            (e) => e.reason,
            'reason',
            contains('turn'),
          ),
        ),
      );
    });

    test('actions of the wrong phase are refused', () {
      final table = Table.deal();
      expect(
        () => table.act(const ChooseTrump(Seat(0), Suit.hearts)),
        throwsA(isA<IllegalActionException>()),
      );
      expect(
        () => table.act(PlayCard(const Seat(0), table.state.hands[0].first)),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('bids, matches and passes are logged as events', () {
      final table = Table.deal()
        ..actAll(const [
          Bid(Seat(0), 16),
          Bid(Seat(1), 17),
          MatchBid(Seat(0), 17),
          Pass(Seat(1)),
        ]);
      final taken = table.eventsOf<ActionTaken>();
      expect(taken.map((e) => e.type), [
        'twentynine.bid',
        'twentynine.bid',
        'twentynine.bidMatched',
        'twentynine.passed',
      ]);
      expect(taken[2].payload, {'value': 17});
      expect(
        TwentyNineAction.fromEvent('twentynine.bidMatched', 'seat:0', const {
          'value': 17,
        }),
        const MatchBid(Seat(0), 17),
      );
      expect(taken.first.actor, const Seat(0));
      expect(taken.first.payload, {'value': 16});
      expect(taken.first.toJson(), {
        'type': 'twentynine.bid',
        'actor': 'seat:0',
        'payload': {'value': 16},
      });
    });
  });
}
