import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/debug/card_gallery_screen.dart';
import '../features/games/twentynine/setup_screen.dart';
import '../features/games/twentynine/table_screen.dart';
import '../features/lobby/lobby_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/wallet/wallet_screen.dart';
import 'routes.dart';

/// The app's router.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.lobby,
    routes: [
      GoRoute(
        path: AppRoutes.lobby,
        builder: (context, state) => const LobbyScreen(),
      ),
      GoRoute(
        path: AppRoutes.twentyNine,
        builder: (context, state) => const TwentyNineSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.twentyNineTable,
        builder: (context, state) => const TwentyNineTableScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.cardGallery,
          builder: (context, state) => const CardGalleryScreen(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
