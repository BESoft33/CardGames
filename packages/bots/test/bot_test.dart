import 'package:bots/bots.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A level's knobs without random mistakes, to test its rules directly.
TwentyNineBot steady(BotLevel level) {
  final s = level.settings;
  return TwentyNineBot.withSettings(
    BotSettings(
      mistakePercent: 0,
      memory: s.memory,
      inference: s.inference,
      searchBudget: s.searchBudget,
    ),
  );
}

TwentyNineAction decide(
  TwentyNineBot bot,
  TwentyNineState state, {
  int seed = 7,
  int? budget,
}) {
  final view = game.viewFor(state, state.turn!);
  return bot.decide(
    view,
    BotContext.seeded(seed, budget: budget ?? bot.settings.searchBudget),
  );
}

void main() {
  test('bots of every level finish whole matches', () {
    const runner = DirectBotRunner();
    final tables = [
      for (final level in BotLevel.values) List.filled(4, level),
      [BotLevel.skilled, BotLevel.casual, BotLevel.beginner, BotLevel.casual],
    ];
    final random = Xoshiro256StarStar.seeded(5);
    for (final table in tables) {
      for (var match = 0; match < 3; match++) {
        var state = game.init(
          const TwentyNineConfig().toMatchConfig(),
          random.nextInt64(),
        );
        var decisions = 0;
        while (!state.isOver) {
          final seat = state.turn!;
          final view = game.viewFor(state, seat);
          state = game.apply(
            state,
            runner.decide(view, table[seat.index], random.nextInt64()),
          );
          decisions++;
          expect(decisions, lessThan(5000), reason: '$table never ends');
        }
        expect(game.result(state), isNotNull);
      }
    }
  });

  test('the same view, seed and budget always give the same decision', () {
    final random = Xoshiro256StarStar.seeded(6);
    for (var i = 0; i < 80; i++) {
      final position = randomPosition(random);
      final view = game.viewFor(position.state, position.seat);
      final seed = random.nextInt64();
      for (final level in BotLevel.values) {
        final bot = TwentyNineBot(level);
        final budget = level.settings.searchBudget;
        expect(
          bot.decide(view, BotContext.seeded(seed, budget: budget)),
          bot.decide(view, BotContext.seeded(seed, budget: budget)),
        );
      }
    }
  });

  test('every level declares a Pair when offered (AGENTS.md §8.3)', () {
    final offered = applyAll(
      dealHands({
        0: 'JS 9S JH 9H 7D 8D 7C 8C',
        1: 'KH QH AS 10S 9D 10D AC 10C',
        2: 'KS QS 8S 7S JD AD KD QD',
        3: 'AH 10H 8H 7H JC 9C KC QC',
      }),
      [
        const Bid(Seat(0), 16),
        const Pass(Seat(1)),
        const Pass(Seat(2)),
        const Pass(Seat(3)),
        const ChooseTrump(Seat(0), Suit.hearts),
        const NoDouble(Seat(1)),
        const NoDouble(Seat(3)),
        PlayCard(const Seat(0), Card.parse('7C')),
        PlayCard(const Seat(1), Card.parse('10C')),
        const AskTrump(Seat(2)),
        PlayCard(const Seat(2), Card.parse('7S')),
        PlayCard(const Seat(3), Card.parse('JC')),
      ],
    );
    expect(offered.phase, TwentyNinePhase.pair);
    for (final level in BotLevel.values) {
      expect(decide(TwentyNineBot(level), offered), const DeclarePair(Seat(1)));
    }
  });

  test(
    'only the levels that count cards declare an unbeatable single hand',
    () {
      final window = applyAll(
        dealHands({
          0: 'KS QS 8S 7S KH QH 8H 7H',
          1: 'JS 9S AS 10S JH 9H AH 10H',
          2: 'JD 9D AD 10D KD QD 8D 7D',
          3: 'JC 9C AC 10C KC QC 8C 7C',
        }, config: fixedDealConfig.copyWith(singleHand: true)),
        const [
          Bid(Seat(0), 16),
          Pass(Seat(1)),
          Pass(Seat(2)),
          Pass(Seat(3)),
          ChooseTrump(Seat(0), Suit.clubs),
          NoDouble(Seat(1)),
          NoDouble(Seat(3)),
          NoSingleHand(Seat(0)),
        ],
      );
      expect(window.turn, const Seat(1));
      for (final level in [
        BotLevel.skilled,
        BotLevel.expert,
        BotLevel.master,
      ]) {
        expect(
          decide(TwentyNineBot(level), window),
          const DeclareSingleHand(Seat(1)),
        );
      }
      for (final level in [BotLevel.beginner, BotLevel.casual]) {
        expect(
          decide(TwentyNineBot(level), window),
          const NoSingleHand(Seat(1)),
        );
      }
    },
  );

  group('bidding', () {
    test('a hand without points passes at every level', () {
      final auction = dealHands({0: '7S 8H QD KC'});
      for (final level in BotLevel.values) {
        expect(decide(TwentyNineBot(level), auction), const Pass(Seat(0)));
      }
    });

    test('a strong hand bids at every level', () {
      final auction = dealHands({0: 'JH 9H AH 10H'});
      for (final level in BotLevel.values) {
        expect(decide(TwentyNineBot(level), auction), const Bid(Seat(0), 16));
      }
    });

    test('a fair hand does not outbid the partner', () {
      final auction = applyAll(
        dealHands({0: 'JH 9H AH 10H', 2: 'JS 7S 10D 8D'}),
        const [Bid(Seat(0), 16), Pass(Seat(1))],
      );
      for (final level in [BotLevel.beginner, BotLevel.casual]) {
        expect(decide(TwentyNineBot(level), auction), const Pass(Seat(2)));
      }
    });

    test('the bidder names a suit it is strong in', () {
      final bid = applyAll(dealHands({0: 'JH 9H AH 7S'}), const [
        Bid(Seat(0), 16),
        Pass(Seat(1)),
        Pass(Seat(2)),
        Pass(Seat(3)),
      ]);
      for (final level in BotLevel.values) {
        expect(
          decide(TwentyNineBot(level), bid),
          const ChooseTrump(Seat(0), Suit.hearts),
          reason: level.name,
        );
      }
    });
  });

  group('card play', () {
    test('Casual feeds points to a partner winning with a Jack', () {
      final state = playCards(
        forcedDealerPlays(
          dealHands({3: 'JS', 0: '7S', 1: 'AS 8S'}, dealer: 2),
          Suit.clubs,
        ),
        'JS 7S',
      );
      expect(state.turn, const Seat(1));
      expect(
        decide(steady(BotLevel.casual), state),
        PlayCard(const Seat(1), Card.parse('AS')),
      );
    });

    test('Skilled wins a valuable trick cheaply as the last player', () {
      final state = playCards(
        forcedDealerPlays(
          dealHands({3: 'AH', 0: '7H JH', 1: '10H', 2: '9H KH'}, dealer: 2),
          Suit.clubs,
        ),
        'AH 7H 10H',
      );
      expect(state.turn, const Seat(2));
      expect(
        decide(TwentyNineBot(BotLevel.skilled), state),
        PlayCard(const Seat(2), Card.parse('9H')),
      );
    });

    test('Skilled feeds points to a partner whose card cannot be beaten', () {
      final state = playCards(
        forcedDealerPlays(
          dealHands({3: '7H', 0: 'JH', 1: '8H', 2: '9H QH'}, dealer: 2),
          Suit.clubs,
        ),
        '7H JH 8H',
      );
      expect(
        decide(TwentyNineBot(BotLevel.skilled), state),
        PlayCard(const Seat(2), Card.parse('9H')),
      );
    });

    test('Beginner asks for trump only for a trick worth a Jack', () {
      TwentyNineState voidAfter(String lead) => playCards(
        forcedDealerPlays(
          dealHands({3: lead, 0: 'JH 9H AH 10H JD 9D AD 10D'}, dealer: 2),
          Suit.clubs,
        ),
        lead,
      );
      final cheap = voidAfter('7S');
      expect(cheap.turn, const Seat(0));
      expect(
        game.legalActions(cheap, cheap.turn!),
        contains(const AskTrump(Seat(0))),
      );
      expect(decide(steady(BotLevel.beginner), cheap), isA<PlayCard>());
      final rich = voidAfter('JS');
      expect(decide(steady(BotLevel.beginner), rich), const AskTrump(Seat(0)));
    });

    test('the mistake knob plays any legal action at random', () {
      final state = playCards(
        forcedDealerPlays(dealHands({3: '7S'}, dealer: 2), Suit.clubs),
        '7S',
      );
      final legal = game.legalActions(state, state.turn!);
      const reckless = TwentyNineBot.withSettings(
        BotSettings(
          mistakePercent: 100,
          memory: BotMemory.none,
          inference: false,
          searchBudget: 0,
        ),
      );
      final chosen = {
        for (var seed = 0; seed < 300; seed++)
          decide(reckless, state, seed: seed),
      };
      expect(chosen, containsAll(legal));
      final careful = {
        for (var seed = 0; seed < 50; seed++)
          decide(steady(BotLevel.beginner), state, seed: seed),
      };
      expect(careful, hasLength(1));
    });
  });
}
