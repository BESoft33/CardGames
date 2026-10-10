import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licence of SQLite3 Multiple Ciphers 2.5.0, the library that encrypts
/// the local database (docs/decisions.md D-018), as published with it.
const String sqlite3mcLicenseAsset =
    'assets/licenses/SQLite3MultipleCiphers.txt';

/// Adds to the app's licence page the licences that no Dart package
/// carries (docs/decisions.md D-028). Flutter lists the Dart packages' own
/// licences by itself.
void registerLicenses([AssetBundle? bundle]) {
  LicenseRegistry.addLicense(() async* {
    final text = await (bundle ?? rootBundle).loadString(sqlite3mcLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['SQLite3 Multiple Ciphers'], text);
  });
}
