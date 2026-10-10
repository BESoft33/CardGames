import 'package:material_ui/material_ui.dart';

/// The app's light and dark themes.
abstract final class AppTheme {
  /// Card-table green.
  static const Color _seed = Color(0xFF1B5E20);

  /// The light theme.
  static ThemeData light() =>
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed));

  /// The dark theme.
  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );
}
