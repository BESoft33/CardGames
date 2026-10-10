import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/providers.dart';
import 'package:card_games/data/wallet.dart';
import 'package:card_games/features/wallet/wallet_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/pump_app.dart';

Future<void> showWallet(WidgetTester tester, WalletRepository wallet) async {
  await pumpInApp(
    tester,
    const WalletScreen(),
    overrides: [walletRepositoryProvider.overrideWith((ref) async => wallet)],
  );
  await tester.pumpAndSettle();
}

/// The text of the widget with [key].
String textOf(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .map((text) => text.data)
    .join(' | ');

PendingMatch match(
  String id, {
  required MatchStatus status,
  required List<CoinEntry> entries,
}) => PendingMatch(
  matchId: id,
  gameId: 'twentynine',
  status: status,
  startedAt: DateTime.utc(2026, 10, 5),
  entries: entries,
);

void main() {
  testWidgets('shows what the player can spend, with confirmed and pending '
      'apart (AGENTS.md §11)', (tester) async {
    await showWallet(
      tester,
      FakeWalletRepository(
        Wallet(
          pending: [
            match(
              'won',
              status: MatchStatus.finished,
              entries: const [
                CoinEntry(CoinReason.entryFee, -1000),
                CoinEntry(CoinReason.dealWon, 50, deal: 1),
                CoinEntry(CoinReason.dealWon, 50, deal: 4),
                CoinEntry(CoinReason.matchWon, 2000),
              ],
            ),
            const PendingGift(),
          ],
        ),
      ),
    );

    expect(textOf(tester, 'wallet-spendable'), '2,100 EC');
    expect(textOf(tester, 'wallet-confirmed'), 'Confirmed | Not synced yet');
    expect(textOf(tester, 'wallet-pending'), 'Pending | +2,100 EC');

    final won = find.byKey(const ValueKey('pending-won'));
    expect(
      find.descendant(
        of: won,
        matching: find.text('Twenty-Nine, 1,000 EC table'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: won, matching: find.text('Won · 2 deals won')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: won, matching: find.text('+1,100 EC')),
      findsOneWidget,
    );
    final gift = find.byKey(const ValueKey('pending-gift'));
    expect(
      find.descendant(of: gift, matching: find.text('Starting gift')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gift, matching: find.text('+1,000 EC')),
      findsOneWidget,
    );
  });

  testWidgets('names each match by how it stands', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    addTearDown(tester.view.reset);
    await showWallet(
      tester,
      FakeWalletRepository(
        Wallet(
          confirmed: 1000,
          pending: [
            match(
              'playing',
              status: MatchStatus.active,
              entries: const [CoinEntry(CoinReason.entryFee, -100)],
            ),
            match(
              'left',
              status: MatchStatus.abandoned,
              entries: const [
                CoinEntry(CoinReason.entryFee, -500),
                CoinEntry(CoinReason.dealWon, 25, deal: 2),
              ],
            ),
            match(
              'lost',
              status: MatchStatus.finished,
              entries: const [CoinEntry(CoinReason.entryFee, -100)],
            ),
          ],
        ),
      ),
    );

    expect(textOf(tester, 'wallet-spendable'), '325 EC');
    expect(textOf(tester, 'wallet-confirmed'), 'Confirmed | 1,000 EC');
    expect(textOf(tester, 'wallet-pending'), 'Pending | −675 EC');
    expect(find.text('In progress · no deals won'), findsOneWidget);
    expect(find.text('Quit · 1 deal won'), findsOneWidget);
    expect(find.text('Lost · no deals won'), findsOneWidget);
    expect(find.text('−475 EC'), findsOneWidget);
    expect(
      find.text(
        'Every deal your team wins pays you 5% of your table fee.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('says so when the coins cannot be read', (tester) async {
    await pumpInApp(
      tester,
      const WalletScreen(),
      overrides: [
        walletRepositoryProvider.overrideWith(
          (ref) async => throw StateError('the database is gone'),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Your coins could not be read. Restart the app to try again.'),
      findsOneWidget,
    );
  });
}
