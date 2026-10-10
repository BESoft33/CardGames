import 'package:bots/bots.dart';
import 'package:card_games/app/app.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/identity.dart';
import 'package:card_games/data/providers.dart';
import 'package:card_games/data/settings_store.dart';
import 'package:card_games/features/games/twentynine/bot_players.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Bots that decide at once, in this isolate, with no pauses. A finished
/// deal's result waits [dealEnd] for its last trick to be shown.
List<Override> instantBots({Duration dealEnd = Duration.zero}) => [
  botDeciderProvider.overrideWithValue(
    (view, level, seed) async =>
        const DirectBotRunner().decide(view, level, seed),
  ),
  botDelayProvider.overrideWithValue(() async {}),
  trickPauseProvider.overrideWithValue(Duration.zero),
  dealEndPauseProvider.overrideWithValue(dealEnd),
];

/// Storage in memory, and [instantBots]. The wallet is read from [log], as
/// in the app; the profile in use is [log]'s user unless [accounts] says
/// otherwise. Logs of other profiles are made as asked for.
List<Override> memoryOverrides(
  EventLog log, {
  SettingsStore? settings,
  AccountStore? accounts,
  Duration dealEnd = Duration.zero,
}) {
  final store = accounts ?? MemoryAccountStore(guestId: log.identity.userId);
  final logs = <String, EventLog>{log.identity.userId: log};
  return [
    eventLogProvider.overrideWith((ref) async => log),
    settingsStoreProvider.overrideWith(
      (ref) async => settings ?? MemorySettingsStore(),
    ),
    accountStoreProvider.overrideWith((ref) async => store),
    profileLogsProvider.overrideWith(
      (ref) async =>
          (String profileId) => logs.putIfAbsent(
            profileId,
            () => MemoryEventLog(
              identity: LocalIdentity(
                deviceId: log.identity.deviceId,
                userId: profileId,
              ),
            ),
          ),
    ),
    ...instantBots(dealEnd: dealEnd),
  ];
}

/// The whole app, keeping its events in [log] and its settings in
/// [settings].
Widget testApp(EventLog log, {SettingsStore? settings}) => ProviderScope(
  overrides: memoryOverrides(log, settings: settings),
  child: const CardGamesApp(),
);
