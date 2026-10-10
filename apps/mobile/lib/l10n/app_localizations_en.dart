// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'card.games';

  @override
  String get lobbyHeading => 'Choose a game';

  @override
  String get gameTwentyNineName => 'Twenty-Nine';

  @override
  String get gameComingSoon => 'Coming soon';

  @override
  String cardFaceLabel(String rank, String suit) {
    return '$rank of $suit';
  }

  @override
  String get cardBackLabel => 'Face-down card';

  @override
  String rankName(String rank) {
    String _temp0 = intl.Intl.selectLogic(rank, {
      'two': 'Two',
      'three': 'Three',
      'four': 'Four',
      'five': 'Five',
      'six': 'Six',
      'seven': 'Seven',
      'eight': 'Eight',
      'nine': 'Nine',
      'ten': 'Ten',
      'jack': 'Jack',
      'queen': 'Queen',
      'king': 'King',
      'ace': 'Ace',
      'other': 'Unknown rank',
    });
    return '$_temp0';
  }

  @override
  String suitName(String suit) {
    String _temp0 = intl.Intl.selectLogic(suit, {
      'spades': 'Spades',
      'hearts': 'Hearts',
      'diamonds': 'Diamonds',
      'clubs': 'Clubs',
      'other': 'Unknown suit',
    });
    return '$_temp0';
  }

  @override
  String get missingCardAsset => 'Missing asset';

  @override
  String get debugCardGalleryTitle => 'Card assets';

  @override
  String get gameTwentyNineSubtitle => 'Against three computer players';

  @override
  String get setupTitle => 'New match';

  @override
  String get setupContinue => 'Continue your unfinished game';

  @override
  String get setupBotLevel => 'Computer players';

  @override
  String botLevelName(String level) {
    String _temp0 = intl.Intl.selectLogic(level, {
      'beginner': 'Beginner',
      'casual': 'Casual',
      'skilled': 'Skilled',
      'expert': 'Expert',
      'master': 'Master',
      'other': 'Bot',
    });
    return '$_temp0';
  }

  @override
  String botLevelHelp(String level) {
    String _temp0 = intl.Intl.selectLogic(level, {
      'beginner': 'Still learning, and makes mistakes.',
      'casual': 'Plays sensibly, but forgets earlier tricks.',
      'skilled': 'Counts every card played.',
      'expert': 'Works each deal out to the end.',
      'master': 'Also reads the bidding. The strongest.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get setupRules => 'Rules';

  @override
  String get setupResetRules => 'Use Nepal table rules';

  @override
  String get setupStart => 'Start match';

  @override
  String get ruleDirection => 'Play direction';

  @override
  String get ruleDirectionCounterClockwise => 'Counter-clockwise';

  @override
  String get ruleDirectionClockwise => 'Clockwise';

  @override
  String get ruleMinBid => 'Lowest bid';

  @override
  String get ruleLastTrickPoint => 'Last trick worth a point (29 in all)';

  @override
  String get ruleAskTrump => 'Cannot follow suit while trump is hidden';

  @override
  String get ruleAskTrumpOptional => 'May ask; must then trump';

  @override
  String get ruleAskTrumpMandatory => 'Must ask; may play anything';

  @override
  String get ruleAllPass => 'If the first three pass';

  @override
  String get ruleAllPassDealerMustBid => 'Dealer must bid';

  @override
  String get ruleAllPassRedeal => 'Redeal';

  @override
  String get rulePair => 'Pair (King and Queen of trump)';

  @override
  String get ruleDoubleRedouble => 'Double and redouble';

  @override
  String get ruleSeventhCard => 'Seventh card';

  @override
  String get ruleRedealChecks => 'Redeal weak or lopsided deals';

  @override
  String get ruleSingleHand => 'Single hand';

  @override
  String ruleTarget(int points) {
    return 'Game points to win: $points';
  }

  @override
  String get tableTitle => 'Twenty-Nine';

  @override
  String get seatYou => 'You';

  @override
  String get seatPartner => 'Partner';

  @override
  String get seatLeft => 'Left';

  @override
  String get seatRight => 'Right';

  @override
  String get dealerBadge => 'Dealer';

  @override
  String cardsInHand(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String get callPass => 'Pass';

  @override
  String callBid(int value) {
    return '$value';
  }

  @override
  String callMatch(int value) {
    return 'Match $value';
  }

  @override
  String raiseBid(int step, int bid) {
    return '+$step ($bid)';
  }

  @override
  String get matchBidButton => 'Match';

  @override
  String matchBid(int bid) {
    return 'Match ($bid)';
  }

  @override
  String bidButton(int value) {
    return 'Bid $value';
  }

  @override
  String get promptBid => 'Your bid';

  @override
  String get promptMustBid => 'Everyone passed: you must bid';

  @override
  String get promptChooseTrump => 'Choose trump. Only you will know it.';

  @override
  String get seventhCardButton => 'Seventh card';

  @override
  String get promptDouble => 'Double the stake?';

  @override
  String get doubleButton => 'Double';

  @override
  String get noDoubleButton => 'No double';

  @override
  String get promptRedouble => 'Your side was doubled. Redouble?';

  @override
  String get redoubleButton => 'Redouble';

  @override
  String get noRedoubleButton => 'No redouble';

  @override
  String get promptSingleHand =>
      'Play single hand? You must win all eight tricks alone.';

  @override
  String get singleHandButton => 'Single hand';

  @override
  String get noSingleHandButton => 'No';

  @override
  String get promptPair => 'You hold the King and Queen of trump.';

  @override
  String get declarePairButton => 'Declare Pair';

  @override
  String get notNowButton => 'Not now';

  @override
  String get askTrumpButton => 'Ask for trump';

  @override
  String get promptPlay => 'Your turn';

  @override
  String get promptMustTrump => 'Play a trump if you have one';

  @override
  String waitingFor(String seat) {
    return '$seat to play';
  }

  @override
  String get waiting => 'Waiting…';

  @override
  String get trumpLabel => 'Trump';

  @override
  String get trumpHidden => 'Hidden';

  @override
  String get trumpOnlyYou => 'Only you know';

  @override
  String get trumpNone => 'No trump';

  @override
  String contractLine(String seat, int value) {
    return '$seat bid $value';
  }

  @override
  String targetLine(int target) {
    return 'Target $target';
  }

  @override
  String stakeLine(int stake) {
    return 'Stake ×$stake';
  }

  @override
  String pointsLine(int us, int them) {
    return 'Card points: us $us, them $them';
  }

  @override
  String get scoreUs => 'Us';

  @override
  String get scoreThem => 'Them';

  @override
  String teamScore(String team, int score) {
    return '$team $score';
  }

  @override
  String matchesAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches ahead',
      one: '1 match ahead',
    );
    return '$_temp0';
  }

  @override
  String matchesBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches behind',
      one: '1 match behind',
    );
    return '$_temp0';
  }

  @override
  String get matchesLevel => 'level in matches';

  @override
  String teamCornerLabel(String team, int score, String standing) {
    return '$team: $score game points, $standing';
  }

  @override
  String singleHandBy(String seat) {
    return '$seat plays single hand';
  }

  @override
  String askedTrumpBy(String seat) {
    return '$seat asked for trump';
  }

  @override
  String get resultMade => 'Contract made';

  @override
  String get resultFailed => 'Contract failed';

  @override
  String get resultVoid => 'Deal void: trump was never revealed';

  @override
  String get resultSingleHandWon => 'Single hand won';

  @override
  String get resultSingleHandLost => 'Single hand lost';

  @override
  String resultChange(String team, String change) {
    return '$team $change';
  }

  @override
  String resultScores(int us, int them) {
    return 'Score: us $us, them $them';
  }

  @override
  String get nextDealButton => 'Next deal';

  @override
  String get finalResultButton => 'See the result';

  @override
  String get matchWon => 'Your team won the match';

  @override
  String get matchLost => 'Your team lost the match';

  @override
  String get newMatchButton => 'New match';

  @override
  String get lobbyButton => 'Lobby';

  @override
  String get leaveTitle => 'Quit this game?';

  @override
  String get leaveBody => 'The match stays unfinished and the game ends.';

  @override
  String quitRefundLine(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'You get $amountString EC back from the pot.';
  }

  @override
  String get leaveButton => 'Quit';

  @override
  String get stayButton => 'Stay';

  @override
  String get resultNoChange => 'No change in game points';

  @override
  String get resumeFailed => 'That match could not be continued.';

  @override
  String trickWonBy(String seat) {
    return '$seat won the trick';
  }

  @override
  String get setAsideLabel => 'Seventh card';

  @override
  String get doubledBadge => 'Doubled';

  @override
  String get redoubledBadge => 'Redoubled';

  @override
  String get pairBadge => 'Pair';

  @override
  String get singleHandBadge => 'Single hand';

  @override
  String bidderBadge(int value) {
    return 'Bid $value';
  }

  @override
  String get currencyName => 'Earned Coins';

  @override
  String coins(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString EC';
  }

  @override
  String coinsGained(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '+$amountString EC';
  }

  @override
  String coinsSpent(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '−$amountString EC';
  }

  @override
  String get lobbyGuest => 'Playing as a guest';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTableFee => 'Table fee';

  @override
  String tableFeeHelp(int fee, int deal, int pot, int penalty) {
    final intl.NumberFormat feeNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String feeString = feeNumberFormat.format(fee);
    final intl.NumberFormat dealNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dealString = dealNumberFormat.format(deal);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String potString = potNumberFormat.format(pot);
    final intl.NumberFormat penaltyNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String penaltyString = penaltyNumberFormat.format(penalty);

    return 'Each match costs $feeString EC. Every deal your team wins pays you $dealString EC, winning the match pays $potString EC, and losing it costs $penaltyString EC more.';
  }

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsGuest => 'Guest';

  @override
  String get settingsGuestHelp =>
      'Your matches and coins are kept on this phone.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLicences => 'Licences';

  @override
  String get setupStakes => 'Stakes';

  @override
  String tableFeeOption(int fee) {
    final intl.NumberFormat feeNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String feeString = feeNumberFormat.format(fee);

    return '$feeString EC table';
  }

  @override
  String get practiceOption => 'Practice';

  @override
  String get practiceHelp => 'No fee, and no coins to win.';

  @override
  String coinsYouHave(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'You have $amountString EC.';
  }

  @override
  String coinsShort(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'You have $amountString EC, not enough for this table. Play practice, or choose a smaller fee in Settings.';
  }

  @override
  String get changeTableFee => 'Change fee';

  @override
  String get newMatchTitle => 'Start a new game?';

  @override
  String get newMatchBody =>
      'Your unfinished game will end. A match in play counts as quit.';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get startButton => 'Start';

  @override
  String get notEnoughCoins => 'You don\'t have enough coins for this table.';

  @override
  String dealCoins(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'You earn $amountString EC.';
  }

  @override
  String matchCoins(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'You take $amountString EC from the pot.';
  }

  @override
  String matchPenalty(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Losing adds $amountString EC to the pot.';
  }

  @override
  String recordLine(String standing) {
    return 'Your team is $standing.';
  }

  @override
  String get playOnQuestion => 'Play the next match?';

  @override
  String get nextMatchButton => 'Next match';

  @override
  String get endGameButton => 'End game';

  @override
  String get gameWon => 'Your team won the game';

  @override
  String get gameLost => 'Your team lost the game';

  @override
  String get gameTied => 'The game is tied';

  @override
  String tieRefundLine(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Every fee of the game comes back: $amountString EC.';
  }

  @override
  String get newGameButton => 'New game';

  @override
  String get lastMatchLine => 'Last match of the game';

  @override
  String get walletSpendable => 'You can spend';

  @override
  String get walletConfirmed => 'Confirmed';

  @override
  String get walletNotSynced => 'Not synced yet';

  @override
  String get walletPending => 'Pending';

  @override
  String get walletPendingHelp =>
      'Coins earned on this phone stay pending until our server has checked your matches.';

  @override
  String get walletPendingList => 'Waiting for the server';

  @override
  String get walletGift => 'Starting gift';

  @override
  String walletMatchTitle(String game, int fee) {
    final intl.NumberFormat feeNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String feeString = feeNumberFormat.format(fee);

    return '$game, $feeString EC table';
  }

  @override
  String get walletMatchPlaying => 'In progress';

  @override
  String get walletMatchWon => 'Won';

  @override
  String get walletMatchLost => 'Lost';

  @override
  String get walletMatchLeft => 'Quit';

  @override
  String walletDealsWon(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deals won',
      one: '1 deal won',
      zero: 'no deals won',
    );
    return '$_temp0';
  }

  @override
  String walletMatchSummary(String result, String deals) {
    return '$result · $deals';
  }

  @override
  String get walletHowTitle => 'How to earn';

  @override
  String walletHowDeal(int percent) {
    return 'Every deal your team wins pays you $percent% of your table fee.';
  }

  @override
  String walletHowMatch(int fees) {
    return 'Win a match against bots and you take the pot: $fees times your fee.';
  }

  @override
  String walletHowLoss(int percent) {
    return 'Lose a match and you add $percent% of the pot.';
  }

  @override
  String get walletHowQuit =>
      'Quit a match and you get part of the pot back: more when your team is ahead.';

  @override
  String get walletHowTie =>
      'A game that ends level gives back every fee you paid in it.';

  @override
  String get walletHowPractice => 'Practice matches are free and pay nothing.';

  @override
  String get walletError =>
      'Your coins could not be read. Restart the app to try again.';

  @override
  String settingsTableFeeHelp(int fee, int deal) {
    final intl.NumberFormat feeNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String feeString = feeNumberFormat.format(fee);
    final intl.NumberFormat dealNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dealString = dealNumberFormat.format(deal);

    return 'Each match costs $feeString EC. Every deal your team wins pays you $dealString EC, and the winning side splits the pot.';
  }

  @override
  String tableFeeChoice(int fee) {
    final intl.NumberFormat feeNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String feeString = feeNumberFormat.format(fee);

    return '$feeString';
  }

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String signInBonusNote(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'First sign-up with Google: $amountString EC bonus.';
  }

  @override
  String signedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get signedInWithGoogle => 'Signed in with Google';

  @override
  String get signedInHelp =>
      'Your coins are kept on our server and follow you to your other phones.';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'You will play as a new guest on this phone. Sign in again any time to get back to your coins.';

  @override
  String get signOutUnsynced =>
      'Some of your progress has not been uploaded yet. It stays on this phone and uploads when you sign in again.';

  @override
  String signInBonus(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Welcome! Your $amountString EC sign-up bonus has been added.';
  }

  @override
  String get signInDone => 'Signed in.';

  @override
  String signInMoved(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Signed in. $amountString EC from your guest play were added.';
  }

  @override
  String get signInOffline =>
      'Signing in needs a connection. Try again when you are online.';

  @override
  String get signInFailed => 'Google sign-in did not work. Try again.';

  @override
  String get onlineUnavailable =>
      'Online features are not set up in this build. You can play offline.';

  @override
  String get syncSynced => 'Your progress is up to date.';

  @override
  String get syncSyncing => 'Uploading your progress…';

  @override
  String get syncOffline =>
      'Offline. Your progress is kept on this phone and uploads later.';

  @override
  String get syncSignedOutElsewhere =>
      'Your sign-in has ended. Sign in again to upload your progress.';

  @override
  String get walletHistory => 'Settled matches';

  @override
  String get walletMatchRejected => 'Rejected by the server';

  @override
  String walletMatchPractice(String game) {
    return '$game, practice';
  }

  @override
  String get signInBonusLater =>
      'Signed in. Your sign-up bonus is added when your coins first sync.';

  @override
  String get syncNoServer =>
      'Your progress is kept on this phone. Coins sync once the game server is set up.';
}
