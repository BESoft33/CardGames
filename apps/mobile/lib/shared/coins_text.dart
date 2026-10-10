import '../l10n/app_localizations.dart';

/// [amount] Earned Coins with its sign: "+1,000 EC", "−1,000 EC" or
/// "0 EC".
String signedCoins(AppLocalizations l10n, int amount) => amount > 0
    ? l10n.coinsGained(amount)
    : amount < 0
    ? l10n.coinsSpent(-amount)
    : l10n.coins(0);
