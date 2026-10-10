import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/remote/providers.dart';
import '../features/account/account_controller.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

/// The root widget.
class CardGamesApp extends ConsumerWidget {
  /// Creates the root widget.
  const CardGamesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Not AppLocalizations.localizationsDelegates: the generated list holds
      // the delegates of the framework's legacy Material library, and
      // material_ui widgets read material_ui's own localizations.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => _SyncTriggers(child: child!),
    );
  }
}

/// Uploads progress when the app starts and whenever it comes back to the
/// foreground (AGENTS.md §9). Matches ask for a sync when they end.
class _SyncTriggers extends ConsumerStatefulWidget {
  const _SyncTriggers({required this.child});

  final Widget child;

  @override
  ConsumerState<_SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<_SyncTriggers> {
  late final AppLifecycleListener _lifecycle;

  void _sync() {
    if (ref.read(authRepositoryProvider) != null) {
      unawaited(ref.read(accountProvider.notifier).sync());
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
