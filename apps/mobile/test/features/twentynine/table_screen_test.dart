import 'package:bots/bots.dart';
import 'package:card_games/features/games/twentynine/offline_match.dart';
import 'package:card_games/features/games/twentynine/table_screen.dart';
import 'package:card_games/features/games/twentynine/widgets/table_widgets.dart';
import 'package:card_games/shared/cards/playing_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/pump_app.dart';

/// A table that always shows [table], and records the player's votes.
class _FixedTable extends OfflineMatchController {
  _FixedTable(this.table, [this.votes]);

  final TableState table;
  final List<bool>? votes;

  @override
  TableState? build() => table;

  @override
  Future<void> vote({required bool continueGame}) async =>
      votes?.add(continueGame);
}

const TwentyNineGame game = TwentyNineGame();
const Seat me = Seat(0);
const String seriesId = '0199c4a0-0000-7000-8000-0000000000e5';

/// A deal in which seat 0 wins the auction and calls the seventh card,
/// with the first lead still to come.
TwentyNineState seventhCardDeal() {
  var state = game.init(const TwentyNineConfig().toMatchConfig(), 11);
  while (state.phase != TwentyNinePhase.play) {
    final seat = state.turn!;
    final legal = game.legalActions(state, seat);
    state = game.apply(
      state,
      legal.firstWhere(
        (action) => switch (action) {
          Bid() => seat == me,
          Pass() => seat != me,
          CallSeventhCard() || NoDouble() || NoSingleHand() => true,
          _ => false,
        },
        orElse: () => legal.first,
      ),
    );
  }
  return state;
}

/// A finished match that the player's side won (or, if [won] is false,
/// lost): the first seed, counting from 1, whose seeded random play ends
/// that way.
TwentyNineState wonMatch({bool won = true}) {
  for (var seed = 1; ; seed++) {
    var state = game.init(const TwentyNineConfig().toMatchConfig(), seed);
    final random = Xoshiro256StarStar.seeded(seed);
    while (!state.isOver) {
      final legal = game.legalActions(state, state.turn!);
      state = game.apply(state, legal[random.nextBounded(legal.length)]);
    }
    if (game.result(state)!.winners.contains(me) == won) return state;
  }
}

Future<void> showTable(
  WidgetTester tester,
  TwentyNineView view, {
  int stake = 0,
  int record = 0,
  bool trailing = false,
  SeriesRef series = const SeriesRef.first(seriesId),
  SeriesEnd? gameEnd,
  List<bool>? votes,
  DealScored? dealResult,
  Size screen = const Size(1080, 2400),
  double pixelRatio = 2.75,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  // A provider scope keeps its first overrides, so start from nothing.
  await tester.pumpWidget(const SizedBox());
  final table = TableState(
    matchId: 'match',
    view: view,
    bots: {
      for (final index in [1, 2, 3]) Seat(index): BotLevel.casual,
    },
    stake: stake,
    series: series,
    record: record,
    trailing: trailing,
    gameEnd: gameEnd,
    dealResult: dealResult,
  );
  await pumpInApp(
    tester,
    const TwentyNineTableScreen(),
    overrides: [
      offlineMatchProvider.overrideWith(() => _FixedTable(table, votes)),
    ],
  );
  await tester.pump();
}

void main() {
  final state = seventhCardDeal();
  final seventh = state.seventhCard!;

  testWidgets('the bidder sees the set-aside seventh card, apart from the '
      'hand', (tester) async {
    expect(state.bidder, me);
    await showTable(tester, game.viewFor(state, me));

    final row = find.byKey(const ValueKey('own-seventh-card'));
    expect(row, findsOneWidget);
    final shown = tester.widget<PlayingCard>(
      find.descendant(of: row, matching: find.byType(PlayingCard)),
    );
    expect(shown.card, seventh);
    expect(find.byKey(ValueKey('hand-${seventh.id}')), findsNothing);
    expect(find.text('Only you know'), findsOneWidget);
  });

  testWidgets('the other players see only that a card is set aside', (
    tester,
  ) async {
    await showTable(tester, game.viewFor(state, const Seat(1)));

    expect(find.byKey(const ValueKey('own-seventh-card')), findsNothing);
    final faces = tester
        .widgetList<PlayingCard>(find.byType(PlayingCard))
        .map((card) => card.card)
        .whereType<Card>();
    expect(faces, isNot(contains(seventh)));
    expect(find.text('Only you know'), findsNothing);
  });

  group('the team corners (AGENTS.md §6.1)', () {
    testWidgets('sit in the two top corners of the table', (tester) async {
      await showTable(tester, game.viewFor(state, me));

      Rect at(String key) => tester.getRect(find.byKey(ValueKey(key)));
      final us = at('score-us');
      final them = at('score-them');
      final partner = at('seat-2');
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(us.left, lessThan(width * 0.1));
      expect(them.right, greaterThan(width * 0.9));
      expect(us.right, lessThanOrEqualTo(partner.left));
      expect(them.left, greaterThanOrEqualTo(partner.right));
      // On the table, level with the partner and above the opponents.
      expect(us.top, greaterThanOrEqualTo(at('trump-marker').bottom));
      expect(us.top, closeTo(partner.top, 1));
      expect(them.top, closeTo(partner.top, 1));
      expect(us.bottom, lessThanOrEqualTo(at('seat-3').top));
      expect(them.bottom, lessThanOrEqualTo(at('seat-1').top));
      expect(find.text('Us 0'), findsOneWidget);
      expect(find.text('Them 0'), findsOneWidget);
    });

    testWidgets("show each team's own score and record", (tester) async {
      final view = game.viewFor(wonMatch(), me);
      await showTable(tester, view, record: 2);

      for (final (key, label, team, pair, record) in [
        ('score-us', 'Us', 0, ScorePair.ours, 2),
        ('score-them', 'Them', 1, ScorePair.theirs, -2),
      ]) {
        final corner = tester.widget<TeamCorner>(find.byKey(ValueKey(key)));
        expect(corner.pair, pair);
        expect(corner.score, view.scores[team]);
        expect(corner.record, record);
        expect(find.text('$label ${view.scores[team]}'), findsOneWidget);
      }
    });

    testWidgets('fit a large phone with a match card showing', (tester) async {
      await showTable(tester, game.viewFor(state, me), record: -3);

      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.byKey(const ValueKey('match-card')), findsOneWidget);
    });

    testWidgets('one match card, in one corner (AGENTS.md §6.1)', (
      tester,
    ) async {
      Card? cardIn(String corner) {
        final card = find.descendant(
          of: find.byKey(ValueKey(corner)),
          matching: find.byKey(const ValueKey('match-card')),
        );
        return card.evaluate().isEmpty
            ? null
            : tester.widget<PlayingCard>(card).card;
      }

      for (final (record, trailing, ours, theirs) in [
        // Ahead after a +6: our red card; behind after their +6: theirs.
        (1, false, '5D', null),
        (-2, false, null, '4H'),
        // After a -6: the loser's black card.
        (1, true, null, '5C'),
        (-3, true, '3S', null),
        // Level: none.
        (0, false, null, null),
      ]) {
        await showTable(
          tester,
          game.viewFor(state, me),
          record: record,
          trailing: trailing,
        );
        expect(
          (cardIn('score-us'), cardIn('score-them')),
          (
            ours == null ? null : Card.parse(ours),
            theirs == null ? null : Card.parse(theirs),
          ),
          reason: 'record $record, trailing $trailing',
        );
      }
    });

    testWidgets('fit a small phone', (tester) async {
      // 320 × 568 points.
      await showTable(
        tester,
        game.viewFor(state, me),
        record: 4,
        screen: const Size(640, 1136),
        pixelRatio: 2,
      );

      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.byKey(const ValueKey('score-us')), findsOneWidget);
      expect(find.byKey(const ValueKey('score-them')), findsOneWidget);
    });
  });

  group('coins at the table (docs/decisions.md D-024)', () {
    DealScored scored({required int team, required DealOutcome outcome}) =>
        DealScored(
          outcome: outcome,
          team: team,
          delta: 1,
          stake: 1,
          target: 16,
          teamPoints: const [18, 11],
          scores: const [1, 0],
        );

    testWidgets('the app bar shows the table fee, or practice', (tester) async {
      await showTable(tester, game.viewFor(state, me), stake: 1000);
      expect(find.text('1,000 EC table'), findsOneWidget);
      await showTable(tester, game.viewFor(state, me));
      expect(find.text('Practice'), findsOneWidget);
    });

    testWidgets("a deal the player's team won shows what it earns", (
      tester,
    ) async {
      final view = game.viewFor(state, me);
      await showTable(
        tester,
        view,
        stake: 1000,
        dealResult: scored(team: 0, outcome: DealOutcome.contractMade),
      );
      expect(find.byKey(const ValueKey('deal-result')), findsOneWidget);
      expect(find.text('You earn 50 EC.'), findsOneWidget);

      // Setting the bidders also wins the deal.
      await showTable(
        tester,
        view,
        stake: 500,
        dealResult: scored(team: 1, outcome: DealOutcome.contractFailed),
      );
      expect(find.text('You earn 25 EC.'), findsOneWidget);

      await showTable(
        tester,
        view,
        stake: 1000,
        dealResult: scored(team: 1, outcome: DealOutcome.contractMade),
      );
      expect(find.byKey(const ValueKey('deal-coins')), findsNothing);

      await showTable(
        tester,
        view,
        dealResult: scored(team: 0, outcome: DealOutcome.contractMade),
      );
      expect(
        find.byKey(const ValueKey('deal-coins')),
        findsNothing,
        reason: 'practice pays nothing',
      );
    });

    testWidgets('a deal result with its coins fits a short window', (
      tester,
    ) async {
      // 360 × 400 points, as in split screen: the panel scrolls.
      await showTable(
        tester,
        game.viewFor(state, me),
        stake: 1000,
        dealResult: scored(team: 0, outcome: DealOutcome.contractMade),
        screen: const Size(720, 800),
        pixelRatio: 2,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.text('You earn 50 EC.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('next-deal')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('winning a staked match shows the share of the pot', (
      tester,
    ) async {
      final view = game.viewFor(wonMatch(), me);
      await showTable(tester, view, stake: 1000);
      expect(find.byKey(const ValueKey('match-result')), findsOneWidget);
      expect(find.text('You take 2,000 EC from the pot.'), findsOneWidget);
      await showTable(tester, view);
      expect(find.byKey(const ValueKey('match-coins')), findsNothing);
    });
  });

  group('games (AGENTS.md §6.13)', () {
    testWidgets('after a match the player votes to play on or stop', (
      tester,
    ) async {
      final votes = <bool>[];
      await showTable(
        tester,
        game.viewFor(wonMatch(), me),
        stake: 100,
        record: 1,
        votes: votes,
      );
      expect(find.text('Your team won the match'), findsOneWidget);
      expect(find.text('You take 200 EC from the pot.'), findsOneWidget);
      expect(find.text('Your team is 1 match ahead.'), findsOneWidget);
      expect(find.text('Play the next match?'), findsOneWidget);
      expect(find.byKey(const ValueKey('game-result')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('next-match')));
      await tester.tap(find.byKey(const ValueKey('end-game')));
      expect(votes, [true, false]);
    });

    testWidgets('a lost match at a table fee shows the penalty', (
      tester,
    ) async {
      await showTable(
        tester,
        game.viewFor(wonMatch(won: false), me),
        stake: 1000,
        record: -1,
      );
      expect(find.text('Your team lost the match'), findsOneWidget);
      expect(find.text('Losing adds 500 EC to the pot.'), findsOneWidget);
      expect(find.text('Your team is 1 match behind.'), findsOneWidget);
    });

    testWidgets('a game ended level shows the refund of its fees', (
      tester,
    ) async {
      await showTable(
        tester,
        game.viewFor(wonMatch(), me),
        stake: 100,
        series: const SeriesRef(id: seriesId, match: 4, record: -1),
        gameEnd: SeriesEnd.vote,
      );
      expect(find.text('The game is tied'), findsOneWidget);
      expect(
        find.text('Every fee of the game comes back: 400 EC.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('new-game')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-match')), findsNothing);
    });

    testWidgets('a game ended ahead or behind says so, with no refund', (
      tester,
    ) async {
      for (final (record, title) in [
        (2, 'Your team won the game'),
        (-3, 'Your team lost the game'),
      ]) {
        await showTable(
          tester,
          game.viewFor(wonMatch(won: record > 0), me),
          stake: 100,
          record: record,
          gameEnd: SeriesEnd.lastMatch,
        );
        expect(find.text(title), findsOneWidget);
        expect(find.byKey(const ValueKey('tie-refund')), findsNothing);
      }
    });

    testWidgets('the last match of a game says so', (tester) async {
      await showTable(
        tester,
        game.viewFor(state, me),
        series: const SeriesRef(id: seriesId, match: 5, record: -4),
        record: -4,
      );
      expect(find.text('Last match of the game'), findsOneWidget);
    });

    testWidgets('quitting says what part of the pot comes back', (
      tester,
    ) async {
      await showTable(tester, game.viewFor(state, me), stake: 1000);
      await tester.tap(find.byKey(const ValueKey('leave-table')));
      await tester.pumpAndSettle();
      expect(find.text('Quit this game?'), findsOneWidget);
      // Level at 0 points: half of the 2,000 EC pot.
      expect(find.text('You get 1,000 EC back from the pot.'), findsOneWidget);
    });
  });
}
