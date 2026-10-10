import 'package:bots/src/twentynine/cards.dart';
import 'package:bots/src/twentynine/sim.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

const TwentyNineGame game = TwentyNineGame();

/// A simulation of [state] with every hand known.
Sim simOf(TwentyNineState state) {
  final config = state.config;
  return Sim(
    hands: [for (final hand in state.hands) C29.maskOf(hand)],
    trump: state.trumpSuit!.index,
    revealed: state.trumpRevealed,
    bidder: state.bidder!.index,
    leader: state.trickLeader!.index,
    declarer: state.singleHandDeclarer?.index ?? -1,
    seventh: state.seventhCardSetAside ? C29.index(state.seventhCard!) : -1,
    dutyToTrump: config.askTrump == AskTrumpRule.optional,
    mustAsk: config.askTrump == AskTrumpRule.mandatory,
    lastTrickPoint: config.lastTrickPoint,
  );
}

void main() {
  test('C29 card arithmetic matches the rules', () {
    for (final card in TwentyNineRules.deck) {
      final index = C29.index(card);
      expect(C29.card(index), card);
      expect(C29.points(index), TwentyNineRules.points(card));
      expect(C29.power(index), TwentyNineRules.power(card.rank));
      expect(C29.suitOf(index), card.suit.index);
    }
    expect(C29.count(0xFFFFFFFF), 32);
    expect(C29.pointsOf(0xFFFFFFFF), 28);
    final hearts = C29.maskOf(
      TwentyNineRules.deck.where((c) => c.suit == Suit.hearts),
    );
    expect(C29.card(C29.strongest(hearts, 1)), Card.parse('JH'));
    expect(C29.card(C29.weakest(hearts, 1)), Card.parse('7H'));
    expect(C29.card(C29.cheapest(hearts)), Card.parse('7H'));
    expect(C29.card(C29.richest(hearts)), Card.parse('JH'));
    expect(C29.strongest(hearts, 0), -1);
    expect(C29.cheapest(0), -1);
  });

  test('plays deals exactly as the engine does', () {
    final random = Xoshiro256StarStar.seeded(3);
    final seen = <String>{};
    for (var seed = 0; seed < 400; seed++) {
      final config = TwentyNineConfig(
        redealChecks: false,
        seventhCard: random.nextBounded(2) == 0,
        lastTrickPoint: random.nextBounded(2) == 0,
        singleHand: random.nextBounded(4) == 0,
        askTrump: AskTrumpRule.values[random.nextBounded(2)],
      );
      var state = game.init(config.toMatchConfig(), seed);
      while (state.phase != TwentyNinePhase.play) {
        final legal = game.legalActions(state, state.turn!);
        state = game.apply(state, legal[random.nextBounded(legal.length)]);
      }
      final sim = simOf(state);
      final deal = state.dealNumber;
      if (state.singleHandDeclarer != null) seen.add('single hand');
      if (state.seventhCardSetAside) seen.add('seventh card');
      while (state.dealNumber == deal && !state.isOver) {
        final seat = state.turn!;
        if (state.phase == TwentyNinePhase.pair) {
          state = game.apply(state, NoPair(seat));
          continue;
        }
        expect(sim.turn, seat.index, reason: 'seed $seed');
        final hidden = !sim.revealed;
        final card = Greedy.choose(sim, seat.index);
        if (hidden && sim.revealed) {
          state = game.apply(state, AskTrump(seat));
          seen.add('ask');
        }
        state = game.apply(state, PlayCard(seat, C29.card(card)));
        sim.play(seat.index, card);
        if (state.dealNumber == deal && !state.isOver) {
          expect(sim.points, state.cardPoints, reason: 'seed $seed');
          expect(sim.trickLength, state.trick.length, reason: 'seed $seed');
          expect(sim.leader, state.trickLeader!.index, reason: 'seed $seed');
          expect(sim.revealed, state.trumpRevealed, reason: 'seed $seed');
        }
      }
      final scored = state.lastEvents.whereType<DealScored>().single;
      expect(sim.points, scored.teamPoints, reason: 'seed $seed');
    }
    expect(seen, containsAll(['single hand', 'seventh card', 'ask']));
  });

  test('a whole deal played out uses all 32 cards and 28 or 29 points', () {
    final random = Xoshiro256StarStar.seeded(4);
    for (var i = 0; i < 300; i++) {
      final deck = List.of(TwentyNineRules.deck);
      shuffleInPlace(deck, random);
      final hands = [
        for (var seat = 0; seat < 4; seat++)
          C29.maskOf(deck.sublist(seat * 8, seat * 8 + 8)),
      ];
      final sim = Sim(
        hands: hands,
        trump: random.nextBounded(4),
        revealed: false,
        bidder: random.nextBounded(4),
        leader: random.nextBounded(4),
        lastTrickPoint: i.isEven,
      )..playOut();
      expect(sim.played, 0xFFFFFFFF);
      expect(sim.points[0] + sim.points[1], i.isEven ? 29 : 28);
      expect(sim.hands, everyElement(0));
    }
  });

  test('a trump played before the reveal is a plain card in the simulation '
      'too (AGENTS.md §6.9)', () {
    // Hearts are trump; seat 3 leads KS; seat 0 discards AH without
    // asking; seat 1 asks and plays 7H; seat 2 follows with 7S.
    int mask(String ids) =>
        C29.maskOf([for (final id in ids.split(' ')) Card.parse(id)]);
    final sim = Sim(
      hands: [
        mask('AH 10H 9C 7C 8C 10C JC QC'),
        mask('JH 9H 7H 8H JD QD KD AC'),
        mask('JS 9S QS 8S 7S KH QH KC'),
        mask('AS 10S KS 7D 8D 9D 10D AD'),
      ],
      trump: Suit.hearts.index,
      revealed: false,
      bidder: 0,
      leader: 3,
    );
    sim
      ..play(3, C29.index(Card.parse('KS')))
      ..play(0, C29.index(Card.parse('AH')))
      ..ask(1)
      ..play(1, C29.index(Card.parse('7H')))
      ..play(2, C29.index(Card.parse('7S')));
    expect(sim.lastWinner, 1);
  });

  test('when trump is led, the highest card of it wins in the simulation '
      'too, whenever trump is revealed', () {
    // Hearts are trump; seat 0 leads JH while trump is hidden; seat 1, with
    // no heart, asks and plays a club; seats 2 and 3 follow with 9H, AH.
    int mask(String ids) =>
        C29.maskOf([for (final id in ids.split(' ')) Card.parse(id)]);
    final sim = Sim(
      hands: [
        mask('JH 7H AS 10S KS QS 8S 7S'),
        mask('JC 9C AC 10C KC QC 8C 7C'),
        mask('9H 8H JD 9D AD 10D KD QD'),
        mask('AH 10H KH QH JS 9S 8D 7D'),
      ],
      trump: Suit.hearts.index,
      revealed: false,
      bidder: 0,
      leader: 0,
    );
    sim
      ..play(0, C29.index(Card.parse('JH')))
      ..ask(1)
      ..play(1, C29.index(Card.parse('7C')))
      ..play(2, C29.index(Card.parse('9H')))
      ..play(3, C29.index(Card.parse('AH')));
    expect(sim.lastWinner, 0);
  });
}
