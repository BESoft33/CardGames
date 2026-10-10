import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'licenses.dart';

/// Starts the app, upright on phones: the table puts the player at the
/// bottom and the partner at the top (docs/decisions.md D-023). iPads that
/// allow multitasking rotate anyway, and have room to.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerLicenses();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: CardGamesApp()));
}
