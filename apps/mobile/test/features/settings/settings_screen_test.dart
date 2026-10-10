import 'package:card_games/app/licenses.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/providers.dart';
import 'package:card_games/data/settings_store.dart';
import 'package:card_games/features/settings/settings_screen.dart';
import 'package:card_games/features/settings/stake_setting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_app.dart';

Future<void> showSettings(WidgetTester tester, SettingsStore store) async {
  await pumpInApp(
    tester,
    const SettingsScreen(),
    overrides: memoryOverrides(MemoryEventLog(), settings: store),
  );
  await tester.pumpAndSettle();
}

String help(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('table-fee-help'))).data!;

void main() {
  testWidgets('the table fee starts at 100 EC and the choice is kept', (
    tester,
  ) async {
    final store = MemorySettingsStore();
    await showSettings(tester, store);
    expect(
      tester
          .widget<SegmentedButton<int>>(find.byKey(const ValueKey('table-fee')))
          .selected,
      {100},
    );
    expect(
      help(tester),
      'Each match costs 100 EC. Every deal your team wins pays you 5 EC, '
      'and the winning side splits the pot.',
    );

    await tester.tap(find.byKey(const ValueKey('table-fee-1000')));
    await tester.pumpAndSettle();
    expect(store.values, {'stake': '1000'});
    expect(help(tester), startsWith('Each match costs 1,000 EC. '));
    expect(help(tester), contains('pays you 50 EC'));
  });

  testWidgets('a saved fee is shown; one that is not a fee is ignored', (
    tester,
  ) async {
    await showSettings(tester, MemorySettingsStore({'stake': '5000'}));
    expect(help(tester), startsWith('Each match costs 5,000 EC. '));

    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWith(
          (ref) async => MemorySettingsStore({'stake': '42'}),
        ),
      ],
    );
    expect(await container.read(stakeProvider.future), 100);
    await expectLater(
      container.read(stakeProvider.notifier).choose(42),
      throwsArgumentError,
    );
  });

  testWidgets('shows the guest account and the app version', (tester) async {
    await showSettings(tester, MemorySettingsStore());
    expect(find.text('Guest'), findsOneWidget);
    expect(
      find.text('Your matches and coins are kept on this phone.'),
      findsOneWidget,
    );
    expect(find.text('0.1.0+1'), findsOneWidget);
  });

  group('licences', () {
    tearDown(LicenseRegistry.reset);

    test('include SQLite3 Multiple Ciphers, which encrypts the database '
        '(docs/decisions.md D-028)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      LicenseRegistry.reset();
      registerLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      final sqlite3mc = entries.singleWhere(
        (entry) => entry.packages.contains('SQLite3 Multiple Ciphers'),
      );
      final text = sqlite3mc.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('MIT License'));
      expect(text, contains('Copyright (c) 2019-2026 Ulrich Telle'));
    });

    testWidgets('open from the settings', (tester) async {
      await showSettings(tester, MemorySettingsStore());
      await tester.tap(find.byKey(const ValueKey('open-licences')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
