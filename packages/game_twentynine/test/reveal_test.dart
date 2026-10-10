import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Who wins [plays] by AGENTS.md §6.9, written out again here so the
/// engine is checked against it: a trump-suit card is a trump only from
/// position [trumpFrom] of the trick on, the first card played once trump
/// was revealed, unless trump itself was led, when every card of it counts;
/// with no trump among those, the highest card of the suit led wins.
Seat expectedWinner(List<TrickPlay> plays, Suit? trump, int trumpFrom) {
  final led = plays.first.card.suit;
  var best = 0;
  var bestValue = -1;
  for (var i = 0; i < plays.length; i++) {
    final card = plays[i].card;
    final power = TwentyNineRules.power(card.rank);
    final value = card.suit == trump && (i >= trumpFrom || led == trump)
        ? 100 + power
        : card.suit == led
        ? power
        : -1;
    if (value > bestValue) {
      best = i;
      bestValue = value;
    }
  }
  return plays[best].seat;
}

void main() {
  test('every trick of thousands of random matches goes to the player the '
      'rule names, reveals during the trick included', () {
    final rng = Xoshiro256StarStar.seeded(2910);
    var tricks = 0;
    var revealedDuring = 0;
    var earlyTrumpBeaten = 0;
    var trumpLedAndRevealed = 0;
    for (var match = 0; match < 3000; match++) {
      final config = switch (match % 3) {
        0 => testConfig,
        1 => testConfig.copyWith(askTrump: AskTrumpRule.mandatory),
        _ => testConfig.copyWith(seventhCard: true, singleHand: true),
      };
      var state = Table.game.init(config.toMatchConfig(), rng.nextInt64());
      // Where in the current trick trump took power, or null while hidden.
      int? trumpFrom;
      while (!state.isOver) {
        final before = state;
        final action = randomAction(
          Table.game.legalActions(state, state.turn!),
          rng,
        );
        state = Table.game.apply(state, action);
        final revealedNow = state.lastEvents.any((e) => e is TrumpRevealed);
        if (revealedNow) trumpFrom = before.trick.length;
        // A new deal, started by the same action, hides trump again, but
        // only after the trick that ended the last one is checked.
        final newDeal = state.lastEvents.any((e) => e is DealStarted);
        final won = state.lastEvents.whereType<TrickWon>().firstOrNull;
        if (won == null) {
          if (newDeal) trumpFrom = null;
          continue;
        }
        // The finished trick, from the state before the next deal starts.
        final plays = [
          ...before.trick,
          if (action is PlayCard) TrickPlay(action.seat, action.card),
        ];
        final single = before.singleHandDeclarer != null;
        final trump = single || trumpFrom == null ? null : before.trumpSuit;
        final from = trumpFrom ?? plays.length;
        expect(
          won.winner,
          expectedWinner(plays, trump, from),
          reason:
              'match $match, trick ${won.trickNumber}: $plays, '
              'trump $trump from card $from',
        );
        tricks++;
        if (from > 0 && from < plays.length) {
          revealedDuring++;
          final early = plays
              .take(from)
              .any(
                (play) =>
                    play.card.suit == trump &&
                    play.card.suit != plays.first.card.suit,
              );
          if (plays.first.card.suit == trump) trumpLedAndRevealed++;
          if (early) earlyTrumpBeaten++;
        }
        // From the next trick on, trump counts from its first card.
        if (trumpFrom != null) trumpFrom = 0;
        if (newDeal) trumpFrom = null;
      }
    }
    expect(tricks, greaterThan(50000));
    expect(revealedDuring, greaterThan(1000), reason: 'reveals mid-trick');
    expect(
      earlyTrumpBeaten,
      greaterThan(50),
      reason: 'tricks where a trump-suit card went down before the reveal',
    );
    expect(
      trumpLedAndRevealed,
      greaterThan(50),
      reason: 'tricks where trump was led and revealed during the trick',
    );
  });

  // With diamonds as trump: Right leads 8D before anyone knows it is
  // trump, Partner follows with JD, Left asks, has no diamond and plays a
  // heart, and the Player follows with 7D. Everyone followed suit.
  test('when trump is led, the highest card of it wins, not the last', () {
    final table = Table.deal(
      dealer: 0,
      hands: const {
        1: '8D AD 10D KD AC 10C KC QC',
        2: 'JD QD 9C 8C 7C JC 7S 8S',
        3: 'JH 9H AH 10H KH QH 8H 7H',
        0: '7D 9D JS 9S AS 10S KS QS',
      },
    )..startPlay(suit: 'D');
    expect(table.turn, const Seat(1), reason: 'Right leads');
    table.play('8D JD');
    table.ask();
    table.play('7H 7D');
    expect(
      table.eventsOf<TrickWon>().single.winner,
      const Seat(2),
      reason: "Partner's JD is the highest diamond, the suit led",
    );
  });

  // The owner's bug report (2026-10-10): the Player leads a high trump-suit
  // card while trump is hidden; Right, with none of the suit, reveals it;
  // the others follow with lower cards of the suit. The highest card of the
  // suit led wins: when the suit led is trump, everyone is following suit,
  // whenever trump was revealed.
  test('when trump is led, the highest card of it wins, revealed before, '
      'during or never', () {
    final table = Table.deal(
      hands: const {
        0: 'JH 7H AS 10S KS QS 8S 7S',
        1: 'JC 9C AC 10C KC QC 8C 7C',
        2: '9H 8H JD 9D AD 10D KD QD',
        3: 'AH 10H KH QH JS 9S 8D 7D',
      },
    )..startPlay(suit: 'H');
    expect((table.bidder, table.turn), (const Seat(0), const Seat(0)));
    table.play('JH');
    table.ask();
    expect(table.state.revealedBy, const Seat(1));
    table.play('7C 9H AH');
    expect(
      table.eventsOf<TrickWon>().single.winner,
      const Seat(0),
      reason:
          'JH is the highest heart; 9H and AH came after the reveal but '
          'only followed suit',
    );
  });
}
