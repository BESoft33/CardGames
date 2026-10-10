import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../app/backend_config.dart';
import '../../app/version.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_controller.dart';
import 'stake_setting.dart';

/// The player's settings: the table fee, their account and the app's
/// licences.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stake = ref.watch(stakeProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.settingsTableFee, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (stake != null) ...[
            SegmentedButton<int>(
              key: const ValueKey('table-fee'),
              showSelectedIcon: false,
              segments: [
                for (final fee in Economy.stakes)
                  ButtonSegment(
                    value: fee,
                    label: Text(
                      l10n.tableFeeChoice(fee),
                      key: ValueKey('table-fee-$fee'),
                    ),
                  ),
              ],
              selected: {stake},
              onSelectionChanged: (choice) =>
                  ref.read(stakeProvider.notifier).choose(choice.single),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsTableFeeHelp(stake, CoinRules.dealWon(stake)),
              key: const ValueKey('table-fee-help'),
            ),
          ] else
            const LinearProgressIndicator(),
          const SizedBox(height: 24),
          Text(l10n.settingsAccount, style: theme.textTheme.titleMedium),
          const _AccountSection(),
          const SizedBox(height: 16),
          Text(l10n.settingsAbout, style: theme.textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsVersion),
            trailing: const Text(appVersion),
          ),
          ListTile(
            key: const ValueKey('open-licences'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsLicences),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: appVersion,
            ),
          ),
        ],
      ),
    );
  }
}

/// Who is playing, with sign-in or sign-out, and how sync stands
/// (AGENTS.md §10).
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  bool _busy = false;

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final outcome = await ref
          .read(accountProvider.notifier)
          .signInWithGoogle();
      if (!mounted) return;
      // The account in use may have changed: sync it with its own
      // controller.
      unawaited(ref.read(accountProvider.notifier).sync());
      switch (outcome) {
        case SignedUp(:final bonus, :final bonusLater):
          _say(
            bonus > 0
                ? l10n.signInBonus(bonus)
                : bonusLater
                ? l10n.signInBonusLater
                : l10n.signInDone,
          );
        case SignedInExisting(:final coinsMoved):
          _say(coinsMoved > 0 ? l10n.signInMoved(coinsMoved) : l10n.signInDone);
        case SignInOffline():
          _say(l10n.signInOffline);
        case SignInCancelled():
          break;
      }
    } on Exception {
      if (mounted) _say(l10n.signInFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutBody),
        actions: [
          TextButton(
            key: const ValueKey('cancel-sign-out'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey('confirm-sign-out'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.signOutButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final unsynced = await ref.read(accountProvider.notifier).signOut();
      if (unsynced && mounted) _say(l10n.signOutUnsynced);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(backendConfigProvider);
    final account = ref.watch(accountProvider).value;
    final profile = account?.profile;
    if (profile == null) return const LinearProgressIndicator();
    final status = switch (account?.phase) {
      SyncPhase.idle when account?.lastSynced != null => l10n.syncSynced,
      SyncPhase.syncing => l10n.syncSyncing,
      SyncPhase.offline => l10n.syncOffline,
      SyncPhase.signedOutElsewhere => l10n.syncSignedOutElsewhere,
      SyncPhase.noServer => l10n.syncNoServer,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.isGuest) ...[
          ListTile(
            key: const ValueKey('account'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.settingsGuest),
            subtitle: Text(l10n.settingsGuestHelp),
          ),
          if (config.canSignInWithGoogle) ...[
            FilledButton.icon(
              key: const ValueKey('sign-in-google'),
              onPressed: _busy ? null : _signIn,
              icon: const Icon(Icons.login),
              label: Text(l10n.signInWithGoogle),
            ),
            const SizedBox(height: 4),
            Text(l10n.signInBonusNote(Economy.googleSignupBonus)),
          ] else
            Text(l10n.onlineUnavailable, key: const ValueKey('offline-only')),
        ] else ...[
          ListTile(
            key: const ValueKey('account'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(
              profile.displayName == null
                  ? l10n.signedInWithGoogle
                  : l10n.signedInAs(profile.displayName!),
            ),
            subtitle: Text(l10n.signedInHelp),
          ),
          OutlinedButton.icon(
            key: const ValueKey('sign-out'),
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: Text(l10n.signOutButton),
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: 8),
          Text(
            status,
            key: const ValueKey('sync-status'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
