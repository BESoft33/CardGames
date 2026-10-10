import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../app/games.dart';
import '../../data/event_log.dart';
import '../../data/local_database.dart';
import '../../data/providers.dart';
import '../../data/wallet.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/coins_text.dart';

/// The player's Earned Coins: what they may spend, what the server has
/// confirmed and what waits for it, shown apart (AGENTS.md §11).
class WalletScreen extends ConsumerWidget {
  /// Creates the screen.
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.currencyName)),
      body: ref
          .watch(walletProvider)
          .when(
            data: (wallet) => _WalletBody(wallet: wallet),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.walletError, textAlign: TextAlign.center),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final confirmed = wallet.confirmed;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  l10n.coins(wallet.spendable),
                  key: const ValueKey('wallet-spendable'),
                  style: theme.textTheme.headlineMedium,
                ),
                Text(l10n.walletSpendable),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        key: const ValueKey('wallet-confirmed'),
                        label: l10n.walletConfirmed,
                        value: confirmed == null
                            ? l10n.walletNotSynced
                            : l10n.coins(confirmed),
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        key: const ValueKey('wallet-pending'),
                        label: l10n.walletPending,
                        value: signedCoins(l10n, wallet.pendingTotal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.walletPendingHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        Text(l10n.walletPendingList, style: theme.textTheme.titleMedium),
        for (final item in wallet.pending) _PendingTile(item: item),
        if (wallet.history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.walletHistory, style: theme.textTheme.titleMedium),
          for (final match in wallet.history) _SettledTile(match: match),
        ],
        const SizedBox(height: 24),
        Text(l10n.walletHowTitle, style: theme.textTheme.titleMedium),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.emoji_events_outlined),
          title: Text(l10n.walletHowDeal(Economy.dealWonPercent)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(l10n.walletHowMatch(Economy.botPotFees)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.trending_down),
          title: Text(l10n.walletHowLoss(Economy.lossPenaltyPercent)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: Text(l10n.walletHowQuit),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.balance),
          title: Text(l10n.walletHowTie),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.school_outlined),
          title: Text(l10n.walletHowPractice),
        ),
      ],
    );
  }
}

/// A label with a figure under it.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A match the server has settled.
class _SettledTile extends ConsumerWidget {
  const _SettledTile({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entry = ref
        .watch(gameEntriesProvider)
        .where((entry) => entry.game.id == match.gameId)
        .firstOrNull;
    final game = entry?.name(l10n) ?? match.gameId;
    return ListTile(
      key: ValueKey('settled-${match.matchId}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        match.result == SettledResult.rejected
            ? Icons.report_outlined
            : Icons.check_circle_outline,
      ),
      title: Text(
        match.stake == 0
            ? l10n.walletMatchPractice(game)
            : l10n.walletMatchTitle(game, match.stake),
      ),
      subtitle: Text(switch (match.result) {
        SettledResult.won => l10n.walletMatchWon,
        SettledResult.lost => l10n.walletMatchLost,
        SettledResult.left => l10n.walletMatchLeft,
        SettledResult.rejected => l10n.walletMatchRejected,
        SettledResult.practice => l10n.practiceOption,
      }),
      trailing: Text(
        signedCoins(l10n, match.coins),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// One line of pending coins: the gift, or a staked match.
class _PendingTile extends ConsumerWidget {
  const _PendingTile({required this.item});

  final PendingCoins item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final amount = Text(
      signedCoins(l10n, item.amount),
      style: Theme.of(context).textTheme.titleSmall,
    );
    switch (item) {
      case PendingGift():
        return ListTile(
          key: const ValueKey('pending-gift'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.card_giftcard_outlined),
          title: Text(l10n.walletGift),
          trailing: amount,
        );
      case final PendingMatch match:
        final entry = ref
            .watch(gameEntriesProvider)
            .where((entry) => entry.game.id == match.gameId)
            .firstOrNull;
        final result = switch (match.status) {
          MatchStatus.active => l10n.walletMatchPlaying,
          MatchStatus.abandoned => l10n.walletMatchLeft,
          MatchStatus.finished =>
            match.won ? l10n.walletMatchWon : l10n.walletMatchLost,
        };
        return ListTile(
          key: ValueKey('pending-${match.matchId}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.style_outlined),
          title: Text(
            l10n.walletMatchTitle(
              entry?.name(l10n) ?? match.gameId,
              match.stake,
            ),
          ),
          subtitle: Text(
            l10n.walletMatchSummary(
              result,
              l10n.walletDealsWon(match.dealsWon),
            ),
          ),
          trailing: amount,
        );
    }
  }
}
