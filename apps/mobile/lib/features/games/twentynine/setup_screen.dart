import 'package:bots/bots.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../../app/routes.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/stake_setting.dart';
import 'offline_match.dart';

/// The choices for the next match. Kept while the app runs.
final class MatchSetup {
  /// Creates a setup: the Nepal table rules, Casual bots, and a match at
  /// the table fee by default.
  const MatchSetup({
    this.config = const TwentyNineConfig(),
    this.level = BotLevel.casual,
    this.practice = false,
  });

  /// The rules.
  final TwentyNineConfig config;

  /// The bots' skill.
  final BotLevel level;

  /// Whether the match is free practice rather than played at the table fee
  /// chosen in settings.
  final bool practice;
}

/// The player's choices for the next match.
final matchSetupProvider = NotifierProvider<MatchSetupNotifier, MatchSetup>(
  MatchSetupNotifier.new,
);

/// Holds [MatchSetup].
class MatchSetupNotifier extends Notifier<MatchSetup> {
  @override
  MatchSetup build() => const MatchSetup();

  /// Chooses the bots' skill.
  void setLevel(BotLevel level) => state = MatchSetup(
    config: state.config,
    level: level,
    practice: state.practice,
  );

  /// Changes the rules.
  void setConfig(TwentyNineConfig config) => state = MatchSetup(
    config: config,
    level: state.level,
    practice: state.practice,
  );

  /// Chooses between free practice and the table fee.
  void setPractice({required bool practice}) => state = MatchSetup(
    config: state.config,
    level: state.level,
    practice: practice,
  );
}

/// The player's newest unfinished Twenty-Nine match, if any.
final unfinishedMatchProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final log = await ref.watch(eventLogProvider.future);
  return log.unfinishedMatch(TwentyNineGame.gameId);
});

/// Where the player sets up a match of Twenty-Nine against bots: the bots'
/// skill and every rule option (AGENTS.md §6.2).
class TwentyNineSetupScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const TwentyNineSetupScreen({super.key});

  @override
  ConsumerState<TwentyNineSetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<TwentyNineSetupScreen> {
  bool _busy = false;

  /// Starts a match at [stake], 0 for practice. An unfinished match would
  /// count as lost, so the player confirms that first.
  Future<void> _start(
    MatchSetup setup,
    int stake, {
    required bool hasUnfinished,
  }) async {
    if (hasUnfinished && !await _confirmNewMatch()) return;
    if (!mounted) return;
    final message = AppLocalizations.of(context).notEnoughCoins;
    setState(() => _busy = true);
    try {
      await ref
          .read(offlineMatchProvider.notifier)
          .start(setup.config, setup.level, stake: stake);
      if (mounted) context.go(AppRoutes.twentyNineTable);
    } on NotEnoughCoins {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmNewMatch() async {
    final l10n = AppLocalizations.of(context);
    final start = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newMatchTitle),
        content: Text(l10n.newMatchBody),
        actions: [
          TextButton(
            key: const ValueKey('cancel-new-match'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey('confirm-new-match'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.startButton),
          ),
        ],
      ),
    );
    return start ?? false;
  }

  Future<void> _resume(String matchId) async {
    setState(() => _busy = true);
    final message = AppLocalizations.of(context).resumeFailed;
    try {
      final resumed = await ref
          .read(offlineMatchProvider.notifier)
          .resume(matchId);
      if (!mounted) return;
      if (resumed) {
        context.go(AppRoutes.twentyNineTable);
      } else {
        ref.invalidate(unfinishedMatchProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(matchSetupProvider);
    final notifier = ref.read(matchSetupProvider.notifier);
    final config = setup.config;
    final unfinished = ref.watch(unfinishedMatchProvider).value;
    void set(TwentyNineConfig changed) => notifier.setConfig(changed);
    final theme = Theme.of(context);
    final stake = ref.watch(stakeProvider).value;
    final wallet = ref.watch(walletProvider).value;
    // Ready once the fee and the coins are known. A player who cannot pay
    // the fee can still practise.
    final ready = stake != null && wallet != null;
    final affordable = ready && wallet.canPay(stake);
    final practice = setup.practice || !affordable;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (unfinished != null) ...[
            FilledButton.tonalIcon(
              key: const ValueKey('continue-match'),
              onPressed: _busy ? null : () => _resume(unfinished),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.setupContinue),
            ),
            const SizedBox(height: 16),
          ],
          Text(l10n.setupStakes, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (ready) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  enabled: affordable,
                  label: Text(
                    l10n.tableFeeOption(stake),
                    key: const ValueKey('stakes-table'),
                  ),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    l10n.practiceOption,
                    key: const ValueKey('stakes-practice'),
                  ),
                ),
              ],
              selected: {practice},
              onSelectionChanged: (choice) =>
                  notifier.setPractice(practice: choice.single),
            ),
            const SizedBox(height: 8),
            Text(
              practice
                  ? l10n.practiceHelp
                  : l10n.tableFeeHelp(
                      stake,
                      CoinRules.dealWon(stake),
                      CoinRules.matchWon(
                        stake,
                        seats: TwentyNineRules.seatCount,
                        humans: 1,
                        winners: 1,
                      ),
                      CoinRules.lossPenalty(
                        stake,
                        seats: TwentyNineRules.seatCount,
                        humans: 1,
                      ),
                    ),
              key: const ValueKey('stakes-help'),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    affordable
                        ? l10n.coinsYouHave(wallet.spendable)
                        : l10n.coinsShort(wallet.spendable),
                    key: const ValueKey('stakes-balance'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const ValueKey('change-table-fee'),
                  onPressed: () => context.push(AppRoutes.settings),
                  child: Text(l10n.changeTableFee),
                ),
              ],
            ),
          ] else
            const LinearProgressIndicator(),
          const SizedBox(height: 24),
          Text(l10n.setupBotLevel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // Chips, not segments: five levels wrap onto a second line on a
          // narrow phone.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final level in BotLevel.values)
                ChoiceChip(
                  key: ValueKey('level-${level.name}'),
                  label: Text(l10n.botLevelName(level.name)),
                  selected: setup.level == level,
                  onSelected: (_) => notifier.setLevel(level),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.botLevelHelp(setup.level.name),
            key: const ValueKey('level-help'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.setupRules,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const ValueKey('reset-rules'),
                onPressed: () => set(const TwentyNineConfig()),
                child: Text(l10n.setupResetRules),
              ),
            ],
          ),
          _Choice<PlayDirection>(
            title: l10n.ruleDirection,
            selected: config.direction,
            options: {
              PlayDirection.counterClockwise:
                  l10n.ruleDirectionCounterClockwise,
              PlayDirection.clockwise: l10n.ruleDirectionClockwise,
            },
            onChanged: (value) => set(config.copyWith(direction: value)),
          ),
          _Choice<int>(
            title: l10n.ruleMinBid,
            selected: config.minBid,
            options: {
              for (final bid in TwentyNineConfig.allowedMinBids) bid: '$bid',
            },
            onChanged: (value) => set(config.copyWith(minBid: value)),
          ),
          _Choice<AskTrumpRule>(
            title: l10n.ruleAskTrump,
            selected: config.askTrump,
            options: {
              AskTrumpRule.optional: l10n.ruleAskTrumpOptional,
              AskTrumpRule.mandatory: l10n.ruleAskTrumpMandatory,
            },
            onChanged: (value) => set(config.copyWith(askTrump: value)),
          ),
          _Choice<AllPassRule>(
            title: l10n.ruleAllPass,
            selected: config.allPass,
            options: {
              AllPassRule.dealerMustBid: l10n.ruleAllPassDealerMustBid,
              AllPassRule.redeal: l10n.ruleAllPassRedeal,
            },
            onChanged: (value) => set(config.copyWith(allPass: value)),
          ),
          SwitchListTile(
            key: const ValueKey('rule-last-trick-point'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.ruleLastTrickPoint),
            value: config.lastTrickPoint,
            onChanged: (value) => set(config.copyWith(lastTrickPoint: value)),
          ),
          SwitchListTile(
            key: const ValueKey('rule-pair'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.rulePair),
            value: config.pair,
            onChanged: (value) => set(config.copyWith(pair: value)),
          ),
          SwitchListTile(
            key: const ValueKey('rule-double'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.ruleDoubleRedouble),
            value: config.doubleRedouble,
            onChanged: (value) => set(config.copyWith(doubleRedouble: value)),
          ),
          SwitchListTile(
            key: const ValueKey('rule-seventh-card'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.ruleSeventhCard),
            value: config.seventhCard,
            onChanged: (value) => set(config.copyWith(seventhCard: value)),
          ),
          SwitchListTile(
            key: const ValueKey('rule-redeal-checks'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.ruleRedealChecks),
            value: config.redealChecks,
            onChanged: (value) => set(config.copyWith(redealChecks: value)),
          ),
          SwitchListTile(
            key: const ValueKey('rule-single-hand'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.ruleSingleHand),
            value: config.singleHand,
            onChanged: (value) => set(config.copyWith(singleHand: value)),
          ),
          const SizedBox(height: 8),
          // Fixed (AGENTS.md §6.2), so it is stated, not offered.
          Text(
            l10n.ruleTarget(TwentyNineConfig.fixedTargetGamePoints),
            key: const ValueKey('rule-target'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('start-match'),
            onPressed: _busy || !ready
                ? null
                : () => _start(
                    setup,
                    practice ? 0 : stake,
                    hasUnfinished: unfinished != null,
                  ),
            child: Text(l10n.setupStart),
          ),
        ],
      ),
    );
  }
}

/// A rule option with a few labelled choices.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String title;
  final T selected;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title),
          const SizedBox(height: 4),
          SegmentedButton<T>(
            segments: [
              for (final MapEntry(key: value, value: label) in options.entries)
                ButtonSegment(value: value, label: Text(label)),
            ],
            selected: {selected},
            onSelectionChanged: (choice) => onChanged(choice.single),
          ),
        ],
      ),
    );
  }
}
