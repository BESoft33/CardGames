import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

/// Envelopes for [events], each a type and payload, in one match. Only the
/// type and payload matter to the coin rules.
List<EventEnvelope> log(List<(String, Map<String, Object?>)> events) {
  var prevHash = genesisHash;
  return [
    for (final (seq, (type, payload)) in events.indexed)
      () {
        final event = EventEnvelope.next(
          eventId: uuidV7(),
          matchId: 'm',
          seq: seq,
          type: type,
          actor: Actors.system,
          payload: payload,
          clientTime: DateTime.utc(2026, 10, 5),
          userId: 'u',
          deviceId: 'd',
          gameId: 'twentynine',
          rulesVersion: 1,
          appVersion: 'test',
          prevHash: prevHash,
        );
        prevHash = event.hash;
        return event;
      }(),
  ];
}

/// The fee of a table of [seats] with [humans] people: one, against bots,
/// unless given.
(String, Map<String, Object?>) fee(
  int stake, {
  int seats = 4,
  int humans = 1,
}) => (
  EventTypes.entryFee,
  EconomyPayloads.entryFee(stake: stake, seats: seats, humans: humans),
);

(String, Map<String, Object?>) dealWon(int deal) =>
    (EventTypes.rewardPending, EconomyPayloads.dealWon(deal));

(String, Map<String, Object?>) matchWon({int winners = 1}) =>
    (EventTypes.rewardPending, EconomyPayloads.matchWon(winners: winners));

(String, Map<String, Object?>) penalty() =>
    (EventTypes.penaltyPending, EconomyPayloads.lossPenalty());

(String, Map<String, Object?>) quit(int score) =>
    (EventTypes.rewardPending, EconomyPayloads.quitRefund(score: score));

(String, Map<String, Object?>) tie(int matches) =>
    (EventTypes.rewardPending, EconomyPayloads.tieRefund(matches: matches));

int total(List<CoinEntry> entries) =>
    entries.fold(0, (sum, entry) => sum + entry.amount);

void main() {
  group('the economy config (AGENTS.md §11, docs/decisions.md D-024)', () {
    test('holds the owner\'s numbers', () {
      expect(Economy.currencyCode, 'EC');
      expect(Economy.welcomeGift, 1000);
      expect(Economy.googleSignupBonus, 2500);
      expect(Economy.stakes, [100, 500, 1000, 5000]);
      expect(Economy.dealWonPercent, 5);
      expect(Economy.adReward, 200);
      expect(Economy.adsPerDay, 20);
      expect(Economy.offlineDailyCap, isNull, reason: 'the owner chose no cap');
    });

    test("holds the owner's numbers of 2026-10-10", () {
      expect(Economy.botPotFees, 2);
      expect(Economy.lossPenaltyPercent, 25);
      expect(
        (
          Economy.quitShareBehind,
          Economy.quitShareLevel,
          Economy.quitShareAhead,
        ),
        (25, 50, 75),
      );
      expect(Economy.quitLevelBand, 3);
    });

    test('every fee gives whole coins, and the defaults make sense', () {
      for (final stake in Economy.stakes) {
        expect(stake * Economy.dealWonPercent % 100, 0, reason: '$stake');
        final pot = CoinRules.pot(stake, seats: 4, humans: 1);
        for (final percent in [
          Economy.lossPenaltyPercent,
          Economy.quitShareBehind,
          Economy.quitShareLevel,
          Economy.quitShareAhead,
        ]) {
          expect(pot * percent % 100, 0, reason: '$stake at $percent%');
        }
      }
      expect(Economy.stakes, orderedEquals([...Economy.stakes]..sort()));
      expect(Economy.stakes.toSet(), hasLength(Economy.stakes.length));
      expect(Economy.stakes, contains(Economy.defaultStake));
      expect(
        Economy.welcomeGift,
        greaterThanOrEqualTo(Economy.stakes.first),
        reason: 'a new player can join a table at once',
      );
    });
  });

  group('CoinRules', () {
    test('a deal won pays 5% of the fee', () {
      expect(
        [for (final s in Economy.stakes) CoinRules.dealWon(s)],
        [5, 25, 50, 250],
      );
    });

    test('with four people the pot is every fee, split among the winners', () {
      expect(CoinRules.pot(1000, seats: 4, humans: 4), 4000);
      expect(CoinRules.matchWon(1000, seats: 4, humans: 4, winners: 2), 2000);
    });

    test('against bots the pot is twice the fee, all the winner\'s', () {
      expect(CoinRules.pot(1000, seats: 4, humans: 1), 2000);
      expect(CoinRules.matchWon(1000, seats: 4, humans: 1, winners: 1), 2000);
    });

    test('the pot of a table mixing people and bots is not decided', () {
      expect(
        () => CoinRules.pot(100, seats: 4, humans: 2),
        throwsUnsupportedError,
      );
    });

    test('a loss adds 25% of the pot', () {
      expect(CoinRules.lossPenalty(1000, seats: 4, humans: 1), 500);
      expect(CoinRules.lossPenalty(1000, seats: 4, humans: 4), 1000);
    });

    test('quitting against bots returns a share of the pot by score', () {
      int refund(int score) =>
          CoinRules.quitRefund(1000, seats: 4, humans: 1, score: score);
      expect(
        [for (var s = -5; s <= 5; s++) refund(s)],
        [
          500, 500, // below -3: 25% of 2,000
          1000, 1000, 1000, 1000, 1000, 1000, 1000, // -3 to +3: 50%
          1500, 1500, // above +3: 75%
        ],
      );
      expect(refund(4), 1500, reason: "the owner's example: 1.5 × the fee");
    });

    test('quitting against people returns nothing to the one who quits', () {
      expect(CoinRules.quitRefund(1000, seats: 4, humans: 4, score: 5), 0);
    });

    test('a tied game returns every fee of the game', () {
      expect(CoinRules.tieRefund(500, matches: 4), 2000);
    });

    test('only the listed fees are stakes', () {
      expect(CoinRules.isStake(1000), isTrue);
      expect(CoinRules.isStake(0), isFalse);
      expect(CoinRules.isStake(999), isFalse);
    });
  });

  group('matchCoins', () {
    test('the owner\'s example: 1,000 EC table, 6 deals to 4, match won', () {
      final winner = matchCoins(
        log([
          fee(1000),
          for (final deal in [1, 3, 4, 6, 7, 9]) dealWon(deal),
          matchWon(),
        ]),
      );
      expect(winner.first, const CoinEntry(CoinReason.entryFee, -1000));
      expect(
        winner
            .where((e) => e.reason == CoinReason.dealWon)
            .map((e) => e.amount),
        List.filled(6, 50),
      );
      expect(winner.last, const CoinEntry(CoinReason.matchWon, 2000));
      expect(total(winner) + 1000, 2300, reason: 'paid back after the fee');

      final loser = matchCoins(
        log([
          fee(1000),
          for (final deal in [2, 5, 8, 10]) dealWon(deal),
        ]),
      );
      expect(total(loser) + 1000, 200, reason: 'the losers keep deal bonuses');
    });

    test('a practice match, with no economy events, moves nothing', () {
      expect(matchCoins(const []), isEmpty);
      expect(
        matchCoins(
          log([
            (EventTypes.matchCreated, {'stake': 0}),
          ]),
        ),
        isEmpty,
      );
    });

    test('a match quit early keeps the deals already won, with a refund', () {
      final left = matchCoins(
        log([
          fee(500),
          dealWon(1),
          (EventTypes.matchAbandoned, SeriesPayloads.abandoned(score: -4)),
          quit(-4),
        ]),
      );
      expect(left, const [
        CoinEntry(CoinReason.entryFee, -500),
        CoinEntry(CoinReason.dealWon, 25, deal: 1),
        CoinEntry(CoinReason.quitRefund, 250),
      ]);
    });

    test('a lost match adds the penalty, after the vote', () {
      final lost = matchCoins(
        log([
          fee(1000),
          for (final deal in [2, 5, 8, 10]) dealWon(deal),
          (EventTypes.seriesVote, SeriesPayloads.vote(continueGame: true)),
          penalty(),
        ]),
      );
      expect(lost.last, const CoinEntry(CoinReason.lossPenalty, -500));
      expect(total(lost), -1300, reason: 'the worked example in D-024');
    });

    test('a tied game returns every fee of the game', () {
      final last = matchCoins(log([fee(100), matchWon(), tie(4)]));
      expect(last, const [
        CoinEntry(CoinReason.entryFee, -100),
        CoinEntry(CoinReason.matchWon, 200),
        CoinEntry(CoinReason.tieRefund, 400),
      ]);
    });

    test('skips other events and counts a repeated reward once', () {
      final entries = matchCoins(
        log([
          (EventTypes.matchCreated, {'stake': 100}),
          fee(100),
          ('twentynine.cardPlayed', {'card': 'JH'}),
          dealWon(2),
          dealWon(2),
          matchWon(),
          matchWon(),
          penalty(),
          penalty(),
        ]),
      );
      expect(entries, const [
        CoinEntry(CoinReason.entryFee, -100),
        CoinEntry(CoinReason.dealWon, 5, deal: 2),
        CoinEntry(CoinReason.matchWon, 200),
        CoinEntry(CoinReason.lossPenalty, -50),
      ]);
    });

    test('ignores any amount an event carries', () {
      final entries = matchCoins(
        log([
          (
            EventTypes.entryFee,
            {'stake': 100, 'seats': 4, 'humans': 1, 'amount': -1},
          ),
          (
            EventTypes.rewardPending,
            {'reason': 'matchWon', 'winners': 1, 'amount': 1000000},
          ),
        ]),
      );
      expect(total(entries), 100);
    });

    test('rejects a broken economy log', () {
      void check(List<(String, Map<String, Object?>)> events) =>
          expect(() => matchCoins(log(events)), throwsFormatException);

      check([dealWon(1)]);
      check([fee(999)]);
      check([fee(100, seats: 1)]);
      check([fee(100), fee(100)]);
      check([
        fee(100),
        (EventTypes.rewardPending, {'reason': 'jackpot'}),
      ]);
      check([fee(100), dealWon(0)]);
      check([fee(100), matchWon(winners: 2)]);
      check([fee(100, humans: 2)]);
      check([fee(100, humans: 0)]);
      check([penalty()]);
      check([
        fee(100),
        (EventTypes.penaltyPending, {'reason': 'matchWon'}),
      ]);
      check([fee(100), tie(0)]);
      check([
        fee(100),
        (EventTypes.rewardPending, {'reason': 'quitRefund'}),
      ]);
      check([
        (EventTypes.entryFee, {'stake': '100', 'seats': 4, 'humans': 1}),
      ]);
      check([
        (EventTypes.entryFee, {'stake': 100, 'seats': 4}),
      ]);
    });
  });

  test('the economy event types sit apart from the game events', () {
    expect(EventTypes.entryFee, 'economy.entryFee');
    expect(EventTypes.rewardPending, 'economy.rewardPending');
    expect(EventTypes.penaltyPending, 'economy.penaltyPending');
  });
}
