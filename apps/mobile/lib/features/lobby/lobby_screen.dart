import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/games.dart';
import '../../app/routes.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_controller.dart';

/// Where the player picks a game, with their coins and settings at hand.
/// The games come from the game registry (AGENTS.md §5.9).
class LobbyScreen extends ConsumerWidget {
  /// Creates the lobby.
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(accountProvider).value?.profile;
    final who = profile == null || profile.isGuest
        ? l10n.lobbyGuest
        : profile.displayName == null
        ? l10n.signedInWithGoogle
        : l10n.signedInAs(profile.displayName!);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          const _CoinsButton(),
          IconButton(
            key: const ValueKey('open-settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push(AppRoutes.settings),
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.style_outlined),
              tooltip: l10n.debugCardGalleryTitle,
              onPressed: () => context.push(AppRoutes.cardGallery),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  who,
                  key: const ValueKey('lobby-account'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.lobbyHeading, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final entry in ref.watch(gameEntriesProvider))
            Card(
              child: ListTile(
                key: ValueKey('game-${entry.game.id}'),
                title: Text(entry.name(l10n)),
                subtitle: Text(entry.subtitle(l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(entry.route),
              ),
            ),
        ],
      ),
    );
  }
}

/// The coins the player may spend; opens the wallet.
class _CoinsButton extends ConsumerWidget {
  const _CoinsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider).value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        key: const ValueKey('wallet-chip'),
        avatar: const Icon(Icons.toll_outlined, size: 18),
        label: wallet == null
            ? const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.coins(wallet.spendable)),
        tooltip: l10n.currencyName,
        onPressed: () => context.push(AppRoutes.wallet),
      ),
    );
  }
}
