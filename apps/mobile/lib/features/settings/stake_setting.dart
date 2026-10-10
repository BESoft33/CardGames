import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../data/providers.dart';

/// The table fee the player chose in settings: one of [Economy.stakes],
/// [Economy.defaultStake] until they choose (docs/decisions.md D-024).
final stakeProvider = AsyncNotifierProvider<StakeSetting, int>(
  StakeSetting.new,
);

/// Reads and saves the table fee.
class StakeSetting extends AsyncNotifier<int> {
  /// The settings key.
  static const String key = 'stake';

  @override
  Future<int> build() async {
    final store = await ref.watch(settingsStoreProvider.future);
    final saved = int.tryParse(await store.read(key) ?? '');
    return saved != null && CoinRules.isStake(saved)
        ? saved
        : Economy.defaultStake;
  }

  /// Saves [stake] as the table fee.
  ///
  /// Throws an [ArgumentError] unless it is one of [Economy.stakes].
  Future<void> choose(int stake) async {
    if (!CoinRules.isStake(stake)) {
      throw ArgumentError.value(stake, 'stake', 'Not a table fee');
    }
    final store = await ref.read(settingsStoreProvider.future);
    await store.write(key, '$stake');
    if (ref.mounted) state = AsyncData(stake);
  }
}
