import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Name of the app, shown in the lobby app bar and the task switcher.
  ///
  /// In en, this message translates to:
  /// **'card.games'**
  String get appTitle;

  /// Heading above the list of games in the lobby.
  ///
  /// In en, this message translates to:
  /// **'Choose a game'**
  String get lobbyHeading;

  /// Name of the card game 29.
  ///
  /// In en, this message translates to:
  /// **'Twenty-Nine'**
  String get gameTwentyNineName;

  /// Shown under a game that cannot be played yet.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get gameComingSoon;

  /// Name of a face-up card for screen readers, for example 'Jack of Hearts'.
  ///
  /// In en, this message translates to:
  /// **'{rank} of {suit}'**
  String cardFaceLabel(String rank, String suit);

  /// Name of a face-down card for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Face-down card'**
  String get cardBackLabel;

  /// Name of a card rank. The key is the rank's code name.
  ///
  /// In en, this message translates to:
  /// **'{rank, select, two{Two} three{Three} four{Four} five{Five} six{Six} seven{Seven} eight{Eight} nine{Nine} ten{Ten} jack{Jack} queen{Queen} king{King} ace{Ace} other{Unknown rank}}'**
  String rankName(String rank);

  /// Name of a card suit. The key is the suit's code name.
  ///
  /// In en, this message translates to:
  /// **'{suit, select, spades{Spades} hearts{Hearts} diamonds{Diamonds} clubs{Clubs} other{Unknown suit}}'**
  String suitName(String suit);

  /// Debug builds only: label on the stand-in for card art the owner has not supplied yet.
  ///
  /// In en, this message translates to:
  /// **'Missing asset'**
  String get missingCardAsset;

  /// Debug builds only: title of the screen that shows every card image.
  ///
  /// In en, this message translates to:
  /// **'Card assets'**
  String get debugCardGalleryTitle;

  /// Lobby: what you play in Twenty-Nine for now.
  ///
  /// In en, this message translates to:
  /// **'Against three computer players'**
  String get gameTwentyNineSubtitle;

  /// Title of the screen where a Twenty-Nine match is set up.
  ///
  /// In en, this message translates to:
  /// **'New match'**
  String get setupTitle;

  /// Button that goes back to the game the player left unfinished.
  ///
  /// In en, this message translates to:
  /// **'Continue your unfinished game'**
  String get setupContinue;

  /// Heading above the choice of bot skill.
  ///
  /// In en, this message translates to:
  /// **'Computer players'**
  String get setupBotLevel;

  /// Name of a bot skill level. The key is the level code name.
  ///
  /// In en, this message translates to:
  /// **'{level, select, beginner{Beginner} casual{Casual} skilled{Skilled} expert{Expert} master{Master} other{Bot}}'**
  String botLevelName(String level);

  /// One line about a bot skill level, under the level choice. The key is the level code name.
  ///
  /// In en, this message translates to:
  /// **'{level, select, beginner{Still learning, and makes mistakes.} casual{Plays sensibly, but forgets earlier tricks.} skilled{Counts every card played.} expert{Works each deal out to the end.} master{Also reads the bidding. The strongest.} other{}}'**
  String botLevelHelp(String level);

  /// Heading of the rule options.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get setupRules;

  /// Button that resets every rule option to the defaults.
  ///
  /// In en, this message translates to:
  /// **'Use Nepal table rules'**
  String get setupResetRules;

  /// Button that starts the match.
  ///
  /// In en, this message translates to:
  /// **'Start match'**
  String get setupStart;

  /// Rule option: which way play passes.
  ///
  /// In en, this message translates to:
  /// **'Play direction'**
  String get ruleDirection;

  /// Play passes to the right.
  ///
  /// In en, this message translates to:
  /// **'Counter-clockwise'**
  String get ruleDirectionCounterClockwise;

  /// Play passes to the left.
  ///
  /// In en, this message translates to:
  /// **'Clockwise'**
  String get ruleDirectionClockwise;

  /// Rule option: the lowest bid allowed.
  ///
  /// In en, this message translates to:
  /// **'Lowest bid'**
  String get ruleMinBid;

  /// Rule option.
  ///
  /// In en, this message translates to:
  /// **'Last trick worth a point (29 in all)'**
  String get ruleLastTrickPoint;

  /// Rule option heading: what a player who cannot follow suit may do.
  ///
  /// In en, this message translates to:
  /// **'Cannot follow suit while trump is hidden'**
  String get ruleAskTrump;

  /// Asking for trump is optional; after asking, the player must play a trump if they hold one.
  ///
  /// In en, this message translates to:
  /// **'May ask; must then trump'**
  String get ruleAskTrumpOptional;

  /// Asking for trump is required; afterwards any card may be played.
  ///
  /// In en, this message translates to:
  /// **'Must ask; may play anything'**
  String get ruleAskTrumpMandatory;

  /// Rule option heading.
  ///
  /// In en, this message translates to:
  /// **'If the first three pass'**
  String get ruleAllPass;

  /// The dealer must bid the minimum.
  ///
  /// In en, this message translates to:
  /// **'Dealer must bid'**
  String get ruleAllPassDealerMustBid;

  /// The cards are dealt again.
  ///
  /// In en, this message translates to:
  /// **'Redeal'**
  String get ruleAllPassRedeal;

  /// Rule option.
  ///
  /// In en, this message translates to:
  /// **'Pair (King and Queen of trump)'**
  String get rulePair;

  /// Rule option.
  ///
  /// In en, this message translates to:
  /// **'Double and redouble'**
  String get ruleDoubleRedouble;

  /// Rule option: the bidder may make their seventh card the trump.
  ///
  /// In en, this message translates to:
  /// **'Seventh card'**
  String get ruleSeventhCard;

  /// Rule option.
  ///
  /// In en, this message translates to:
  /// **'Redeal weak or lopsided deals'**
  String get ruleRedealChecks;

  /// Rule option: a player may try to win all eight tricks alone.
  ///
  /// In en, this message translates to:
  /// **'Single hand'**
  String get ruleSingleHand;

  /// Rule option with its current value.
  ///
  /// In en, this message translates to:
  /// **'Game points to win: {points}'**
  String ruleTarget(int points);

  /// Title of the table screen.
  ///
  /// In en, this message translates to:
  /// **'Twenty-Nine'**
  String get tableTitle;

  /// The player's own seat.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get seatYou;

  /// The seat opposite the player.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get seatPartner;

  /// The opponent on the player's left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get seatLeft;

  /// The opponent on the player's right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get seatRight;

  /// Marks the dealer's seat.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get dealerBadge;

  /// How many cards a player holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 card} other{{count} cards}}'**
  String cardsInHand(int count);

  /// A pass in the auction.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get callPass;

  /// A bid in the auction, shown on the seat.
  ///
  /// In en, this message translates to:
  /// **'{value}'**
  String callBid(int value);

  /// A player matched a bid of {value}, shown under their name, for example 'Match 17'.
  ///
  /// In en, this message translates to:
  /// **'Match {value}'**
  String callMatch(int value);

  /// A button that bids {step} above the highest bid, showing the bid it makes, for example '+1 (17)'.
  ///
  /// In en, this message translates to:
  /// **'+{step} ({bid})'**
  String raiseBid(int step, int bid);

  /// The Match button while the player may not match: only the old bidder may (AGENTS.md §6.4).
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get matchBidButton;

  /// A button that matches the new bidder's bid, showing it, for example 'Match (17)'.
  ///
  /// In en, this message translates to:
  /// **'Match ({bid})'**
  String matchBid(int bid);

  /// Button to bid a value.
  ///
  /// In en, this message translates to:
  /// **'Bid {value}'**
  String bidButton(int value);

  /// Prompt when it is the player's turn in the auction.
  ///
  /// In en, this message translates to:
  /// **'Your bid'**
  String get promptBid;

  /// Prompt when the dealer is forced to bid.
  ///
  /// In en, this message translates to:
  /// **'Everyone passed: you must bid'**
  String get promptMustBid;

  /// Prompt for the bidder to choose trump.
  ///
  /// In en, this message translates to:
  /// **'Choose trump. Only you will know it.'**
  String get promptChooseTrump;

  /// Button to make the seventh card the trump.
  ///
  /// In en, this message translates to:
  /// **'Seventh card'**
  String get seventhCardButton;

  /// Prompt for an opponent of the bidder.
  ///
  /// In en, this message translates to:
  /// **'Double the stake?'**
  String get promptDouble;

  /// Button to double.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get doubleButton;

  /// Button to decline doubling.
  ///
  /// In en, this message translates to:
  /// **'No double'**
  String get noDoubleButton;

  /// Prompt for the bidder or partner.
  ///
  /// In en, this message translates to:
  /// **'Your side was doubled. Redouble?'**
  String get promptRedouble;

  /// Button to redouble.
  ///
  /// In en, this message translates to:
  /// **'Redouble'**
  String get redoubleButton;

  /// Button to decline redoubling.
  ///
  /// In en, this message translates to:
  /// **'No redouble'**
  String get noRedoubleButton;

  /// Prompt during the single-hand window.
  ///
  /// In en, this message translates to:
  /// **'Play single hand? You must win all eight tricks alone.'**
  String get promptSingleHand;

  /// Button to declare single hand.
  ///
  /// In en, this message translates to:
  /// **'Single hand'**
  String get singleHandButton;

  /// Button to decline single hand.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noSingleHandButton;

  /// Prompt when the player may declare the Pair.
  ///
  /// In en, this message translates to:
  /// **'You hold the King and Queen of trump.'**
  String get promptPair;

  /// Button to declare the Pair.
  ///
  /// In en, this message translates to:
  /// **'Declare Pair'**
  String get declarePairButton;

  /// Button to decline the Pair for now.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNowButton;

  /// Button to ask for the hidden trump.
  ///
  /// In en, this message translates to:
  /// **'Ask for trump'**
  String get askTrumpButton;

  /// Prompt when the player must play a card.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get promptPlay;

  /// Prompt after asking for trump.
  ///
  /// In en, this message translates to:
  /// **'Play a trump if you have one'**
  String get promptMustTrump;

  /// Who the table is waiting for.
  ///
  /// In en, this message translates to:
  /// **'{seat} to play'**
  String waitingFor(String seat);

  /// When the table waits for an unnamed player.
  ///
  /// In en, this message translates to:
  /// **'Waiting…'**
  String get waiting;

  /// Label of the trump marker.
  ///
  /// In en, this message translates to:
  /// **'Trump'**
  String get trumpLabel;

  /// The trump has not been revealed.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get trumpHidden;

  /// The bidder's own hidden trump.
  ///
  /// In en, this message translates to:
  /// **'Only you know'**
  String get trumpOnlyYou;

  /// There is no trump in a single-hand deal.
  ///
  /// In en, this message translates to:
  /// **'No trump'**
  String get trumpNone;

  /// Who won the auction and with what bid.
  ///
  /// In en, this message translates to:
  /// **'{seat} bid {value}'**
  String contractLine(String seat, int value);

  /// Points the bidding side needs.
  ///
  /// In en, this message translates to:
  /// **'Target {target}'**
  String targetLine(int target);

  /// The stake when it is above 1.
  ///
  /// In en, this message translates to:
  /// **'Stake ×{stake}'**
  String stakeLine(int stake);

  /// Card points won so far in the deal.
  ///
  /// In en, this message translates to:
  /// **'Card points: us {us}, them {them}'**
  String pointsLine(int us, int them);

  /// The player's team in the score.
  ///
  /// In en, this message translates to:
  /// **'Us'**
  String get scoreUs;

  /// The other team in the score.
  ///
  /// In en, this message translates to:
  /// **'Them'**
  String get scoreThem;

  /// A team's game points under its score card, for example 'Us 3'.
  ///
  /// In en, this message translates to:
  /// **'{team} {score}'**
  String teamScore(String team, int score);

  /// A team's record in the game when it has won more matches than it lost.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match ahead} other{{count} matches ahead}}'**
  String matchesAhead(int count);

  /// A team's record in the game when it has lost more matches than it won.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match behind} other{{count} matches behind}}'**
  String matchesBehind(int count);

  /// A team's record in the game when it has won as many matches as it lost.
  ///
  /// In en, this message translates to:
  /// **'level in matches'**
  String get matchesLevel;

  /// What screen readers say for a team's corner of the table, for example 'Us: 3 game points, 1 match ahead'.
  ///
  /// In en, this message translates to:
  /// **'{team}: {score} game points, {standing}'**
  String teamCornerLabel(String team, int score, String standing);

  /// Shown during a single-hand deal.
  ///
  /// In en, this message translates to:
  /// **'{seat} plays single hand'**
  String singleHandBy(String seat);

  /// Shown in the trick where trump was revealed.
  ///
  /// In en, this message translates to:
  /// **'{seat} asked for trump'**
  String askedTrumpBy(String seat);

  /// Deal result title.
  ///
  /// In en, this message translates to:
  /// **'Contract made'**
  String get resultMade;

  /// Deal result title.
  ///
  /// In en, this message translates to:
  /// **'Contract failed'**
  String get resultFailed;

  /// Deal result title.
  ///
  /// In en, this message translates to:
  /// **'Deal void: trump was never revealed'**
  String get resultVoid;

  /// Deal result title.
  ///
  /// In en, this message translates to:
  /// **'Single hand won'**
  String get resultSingleHandWon;

  /// Deal result title.
  ///
  /// In en, this message translates to:
  /// **'Single hand lost'**
  String get resultSingleHandLost;

  /// The change in a team's game points, for example 'Us +1'.
  ///
  /// In en, this message translates to:
  /// **'{team} {change}'**
  String resultChange(String team, String change);

  /// Game points after the deal.
  ///
  /// In en, this message translates to:
  /// **'Score: us {us}, them {them}'**
  String resultScores(int us, int them);

  /// Button that dismisses a deal result.
  ///
  /// In en, this message translates to:
  /// **'Next deal'**
  String get nextDealButton;

  /// Button shown after the last deal.
  ///
  /// In en, this message translates to:
  /// **'See the result'**
  String get finalResultButton;

  /// Match result.
  ///
  /// In en, this message translates to:
  /// **'Your team won the match'**
  String get matchWon;

  /// Match result.
  ///
  /// In en, this message translates to:
  /// **'Your team lost the match'**
  String get matchLost;

  /// Button to set up another match.
  ///
  /// In en, this message translates to:
  /// **'New match'**
  String get newMatchButton;

  /// Button back to the lobby.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get lobbyButton;

  /// Title of the dialog shown when the player leaves a match in play.
  ///
  /// In en, this message translates to:
  /// **'Quit this game?'**
  String get leaveTitle;

  /// Body of the dialog shown when the player leaves a match in play.
  ///
  /// In en, this message translates to:
  /// **'The match stays unfinished and the game ends.'**
  String get leaveBody;

  /// In the quit dialog, what quitting now returns.
  ///
  /// In en, this message translates to:
  /// **'You get {amount} EC back from the pot.'**
  String quitRefundLine(int amount);

  /// Button that quits the game in the leave dialog.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get leaveButton;

  /// Cancels leaving.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stayButton;

  /// Shown when a deal changes no score.
  ///
  /// In en, this message translates to:
  /// **'No change in game points'**
  String get resultNoChange;

  /// Shown when an unfinished match cannot be resumed.
  ///
  /// In en, this message translates to:
  /// **'That match could not be continued.'**
  String get resumeFailed;

  /// Under the last finished trick.
  ///
  /// In en, this message translates to:
  /// **'{seat} won the trick'**
  String trickWonBy(String seat);

  /// Label of the bidder's set-aside seventh card.
  ///
  /// In en, this message translates to:
  /// **'Seventh card'**
  String get setAsideLabel;

  /// Badge on the seat that doubled.
  ///
  /// In en, this message translates to:
  /// **'Doubled'**
  String get doubledBadge;

  /// Badge on the seat that redoubled.
  ///
  /// In en, this message translates to:
  /// **'Redoubled'**
  String get redoubledBadge;

  /// Badge on the seat that declared the Pair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get pairBadge;

  /// Badge on the single-hand declarer.
  ///
  /// In en, this message translates to:
  /// **'Single hand'**
  String get singleHandBadge;

  /// Badge on the seat that won the auction.
  ///
  /// In en, this message translates to:
  /// **'Bid {value}'**
  String bidderBadge(int value);

  /// Name of the in-app currency, shortened to EC.
  ///
  /// In en, this message translates to:
  /// **'Earned Coins'**
  String get currencyName;

  /// An amount of Earned Coins.
  ///
  /// In en, this message translates to:
  /// **'{amount} EC'**
  String coins(int amount);

  /// Earned Coins received.
  ///
  /// In en, this message translates to:
  /// **'+{amount} EC'**
  String coinsGained(int amount);

  /// Earned Coins paid out.
  ///
  /// In en, this message translates to:
  /// **'−{amount} EC'**
  String coinsSpent(int amount);

  /// Lobby line saying the player has not signed in.
  ///
  /// In en, this message translates to:
  /// **'Playing as a guest'**
  String get lobbyGuest;

  /// Title of the settings screen and tooltip of its button.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings heading: the fee to join a match.
  ///
  /// In en, this message translates to:
  /// **'Table fee'**
  String get settingsTableFee;

  /// What a match at the table fee costs and pays.
  ///
  /// In en, this message translates to:
  /// **'Each match costs {fee} EC. Every deal your team wins pays you {deal} EC, winning the match pays {pot} EC, and losing it costs {penalty} EC more.'**
  String tableFeeHelp(int fee, int deal, int pot, int penalty);

  /// Settings heading: the player's account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// The account of a player who has not signed in.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get settingsGuest;

  /// Where a guest's progress is kept.
  ///
  /// In en, this message translates to:
  /// **'Your matches and coins are kept on this phone.'**
  String get settingsGuestHelp;

  /// Settings heading: about the app.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Label of the app's version number.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Opens the licences of the software the app uses.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get settingsLicences;

  /// Setup heading: play for coins or for practice.
  ///
  /// In en, this message translates to:
  /// **'Stakes'**
  String get setupStakes;

  /// Choice to play at the table fee chosen in settings.
  ///
  /// In en, this message translates to:
  /// **'{fee} EC table'**
  String tableFeeOption(int fee);

  /// Choice to play a free match with no coins.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practiceOption;

  /// What a practice match costs and pays.
  ///
  /// In en, this message translates to:
  /// **'No fee, and no coins to win.'**
  String get practiceHelp;

  /// How many coins the player may spend.
  ///
  /// In en, this message translates to:
  /// **'You have {amount} EC.'**
  String coinsYouHave(int amount);

  /// Shown when the player cannot pay the table fee: how many coins they have, and what they can do.
  ///
  /// In en, this message translates to:
  /// **'You have {amount} EC, not enough for this table. Play practice, or choose a smaller fee in Settings.'**
  String coinsShort(int amount);

  /// Opens the settings to change the table fee.
  ///
  /// In en, this message translates to:
  /// **'Change fee'**
  String get changeTableFee;

  /// Title of the dialog shown before a new game ends an unfinished one.
  ///
  /// In en, this message translates to:
  /// **'Start a new game?'**
  String get newMatchTitle;

  /// Body of the dialog shown before a new game ends an unfinished one.
  ///
  /// In en, this message translates to:
  /// **'Your unfinished game will end. A match in play counts as quit.'**
  String get newMatchBody;

  /// Button that closes a dialog without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Button that starts a new match after a warning.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startButton;

  /// Shown when a match could not start for lack of coins.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have enough coins for this table.'**
  String get notEnoughCoins;

  /// Coins the player earns for a deal their team won.
  ///
  /// In en, this message translates to:
  /// **'You earn {amount} EC.'**
  String dealCoins(int amount);

  /// Coins the player takes for winning the match.
  ///
  /// In en, this message translates to:
  /// **'You take {amount} EC from the pot.'**
  String matchCoins(int amount);

  /// After a lost match at a table fee, the penalty.
  ///
  /// In en, this message translates to:
  /// **'Losing adds {amount} EC to the pot.'**
  String matchPenalty(int amount);

  /// The player's team's record in the game, for example 'Your team is 1 match ahead.'
  ///
  /// In en, this message translates to:
  /// **'Your team is {standing}.'**
  String recordLine(String standing);

  /// After a match, asks whether to play on in the game.
  ///
  /// In en, this message translates to:
  /// **'Play the next match?'**
  String get playOnQuestion;

  /// Votes to play the next match of the game.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatchButton;

  /// Votes to end the game.
  ///
  /// In en, this message translates to:
  /// **'End game'**
  String get endGameButton;

  /// Title when the game ends with the player's team ahead.
  ///
  /// In en, this message translates to:
  /// **'Your team won the game'**
  String get gameWon;

  /// Title when the game ends with the player's team behind.
  ///
  /// In en, this message translates to:
  /// **'Your team lost the game'**
  String get gameLost;

  /// Title when the game ends level.
  ///
  /// In en, this message translates to:
  /// **'The game is tied'**
  String get gameTied;

  /// After a tied game at a table fee, the refund.
  ///
  /// In en, this message translates to:
  /// **'Every fee of the game comes back: {amount} EC.'**
  String tieRefundLine(int amount);

  /// Starts a new game after one has ended.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGameButton;

  /// Shown during the match played with a 2 showing.
  ///
  /// In en, this message translates to:
  /// **'Last match of the game'**
  String get lastMatchLine;

  /// Label under the number of coins the player may spend.
  ///
  /// In en, this message translates to:
  /// **'You can spend'**
  String get walletSpendable;

  /// Label of the balance the server has confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get walletConfirmed;

  /// Shown instead of a balance the server has never confirmed.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get walletNotSynced;

  /// Label of the coins that wait for the server.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get walletPending;

  /// Explains pending coins.
  ///
  /// In en, this message translates to:
  /// **'Coins earned on this phone stay pending until our server has checked your matches.'**
  String get walletPendingHelp;

  /// Heading of the list of pending coins.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the server'**
  String get walletPendingList;

  /// The coins every new player gets.
  ///
  /// In en, this message translates to:
  /// **'Starting gift'**
  String get walletGift;

  /// A staked match in the wallet: the game and its table fee.
  ///
  /// In en, this message translates to:
  /// **'{game}, {fee} EC table'**
  String walletMatchTitle(String game, int fee);

  /// A match still being played.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get walletMatchPlaying;

  /// A match the player's side won.
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get walletMatchWon;

  /// A match the player's side lost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get walletMatchLost;

  /// A match the player quit, in the wallet.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get walletMatchLeft;

  /// How many deals the player's team won in a match.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no deals won} =1{1 deal won} other{{count} deals won}}'**
  String walletDealsWon(int count);

  /// A match's result and the deals won, for example 'Won · 6 deals won'.
  ///
  /// In en, this message translates to:
  /// **'{result} · {deals}'**
  String walletMatchSummary(String result, String deals);

  /// Heading of the ways to earn coins.
  ///
  /// In en, this message translates to:
  /// **'How to earn'**
  String get walletHowTitle;

  /// How deals won pay.
  ///
  /// In en, this message translates to:
  /// **'Every deal your team wins pays you {percent}% of your table fee.'**
  String walletHowDeal(int percent);

  /// How winning a match pays.
  ///
  /// In en, this message translates to:
  /// **'Win a match against bots and you take the pot: {fees} times your fee.'**
  String walletHowMatch(int fees);

  /// How losing a match costs.
  ///
  /// In en, this message translates to:
  /// **'Lose a match and you add {percent}% of the pot.'**
  String walletHowLoss(int percent);

  /// How quitting a match pays.
  ///
  /// In en, this message translates to:
  /// **'Quit a match and you get part of the pot back: more when your team is ahead.'**
  String get walletHowQuit;

  /// How a tied game pays.
  ///
  /// In en, this message translates to:
  /// **'A game that ends level gives back every fee you paid in it.'**
  String get walletHowTie;

  /// Practice matches move no coins.
  ///
  /// In en, this message translates to:
  /// **'Practice matches are free and pay nothing.'**
  String get walletHowPractice;

  /// Shown when the wallet cannot be read from the phone.
  ///
  /// In en, this message translates to:
  /// **'Your coins could not be read. Restart the app to try again.'**
  String get walletError;

  /// What the chosen table fee means, for any game.
  ///
  /// In en, this message translates to:
  /// **'Each match costs {fee} EC. Every deal your team wins pays you {deal} EC, and the winning side splits the pot.'**
  String settingsTableFeeHelp(int fee, int deal);

  /// A table fee on the settings buttons, without the currency.
  ///
  /// In en, this message translates to:
  /// **'{fee}'**
  String tableFeeChoice(int fee);

  /// Button that starts Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// The one-off bonus for signing up with Google.
  ///
  /// In en, this message translates to:
  /// **'First sign-up with Google: {amount} EC bonus.'**
  String signInBonusNote(int amount);

  /// The signed-in account, by its Google name.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInAs(String name);

  /// The signed-in account, when Google gave no name.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google'**
  String get signedInWithGoogle;

  /// What signing in does.
  ///
  /// In en, this message translates to:
  /// **'Your coins are kept on our server and follow you to your other phones.'**
  String get signedInHelp;

  /// Button that signs out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutButton;

  /// Title of the dialog before signing out.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// What signing out does.
  ///
  /// In en, this message translates to:
  /// **'You will play as a new guest on this phone. Sign in again any time to get back to your coins.'**
  String get signOutBody;

  /// Shown after signing out with progress not yet uploaded.
  ///
  /// In en, this message translates to:
  /// **'Some of your progress has not been uploaded yet. It stays on this phone and uploads when you sign in again.'**
  String get signOutUnsynced;

  /// Shown after a first sign-up with Google.
  ///
  /// In en, this message translates to:
  /// **'Welcome! Your {amount} EC sign-up bonus has been added.'**
  String signInBonus(int amount);

  /// Shown after signing in, with nothing more to say.
  ///
  /// In en, this message translates to:
  /// **'Signed in.'**
  String get signInDone;

  /// Shown after signing in to an existing account, with the coins the guest brought.
  ///
  /// In en, this message translates to:
  /// **'Signed in. {amount} EC from your guest play were added.'**
  String signInMoved(int amount);

  /// Shown when sign-in cannot reach the server.
  ///
  /// In en, this message translates to:
  /// **'Signing in needs a connection. Try again when you are online.'**
  String get signInOffline;

  /// Shown when Google sign-in fails.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in did not work. Try again.'**
  String get signInFailed;

  /// Shown in a build without online services.
  ///
  /// In en, this message translates to:
  /// **'Online features are not set up in this build. You can play offline.'**
  String get onlineUnavailable;

  /// Sync status: everything is uploaded.
  ///
  /// In en, this message translates to:
  /// **'Your progress is up to date.'**
  String get syncSynced;

  /// Sync status: uploading now.
  ///
  /// In en, this message translates to:
  /// **'Uploading your progress…'**
  String get syncSyncing;

  /// Sync status: the server could not be reached.
  ///
  /// In en, this message translates to:
  /// **'Offline. Your progress is kept on this phone and uploads later.'**
  String get syncOffline;

  /// Sync status: the session ended.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in has ended. Sign in again to upload your progress.'**
  String get syncSignedOutElsewhere;

  /// Heading of the matches the server has settled.
  ///
  /// In en, this message translates to:
  /// **'Settled matches'**
  String get walletHistory;

  /// A match whose log the server could not check.
  ///
  /// In en, this message translates to:
  /// **'Rejected by the server'**
  String get walletMatchRejected;

  /// A settled practice match.
  ///
  /// In en, this message translates to:
  /// **'{game}, practice'**
  String walletMatchPractice(String game);

  /// Shown after a first sign-up in a build without the game server yet.
  ///
  /// In en, this message translates to:
  /// **'Signed in. Your sign-up bonus is added when your coins first sync.'**
  String get signInBonusLater;

  /// Sync status: accounts work, but the game server is not set up yet.
  ///
  /// In en, this message translates to:
  /// **'Your progress is kept on this phone. Coins sync once the game server is set up.'**
  String get syncNoServer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
