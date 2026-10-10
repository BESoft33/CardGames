import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

/// Maps cards to the owner's card art in `assets/cards/`.
///
/// This is the only code that knows card asset paths (AGENTS.md §13). The
/// owner's files are PNGs named `<rank>_of_<suit>.png`, for example
/// `10_of_spades.png` or `ace_of_hearts.png`. Jacks, queens and kings are
/// the illustrated files with a `2` suffix, such as `jack_of_hearts2.png`.
/// The back is `back.png`. The score sixes are WebPs, described at
/// [scoreSix]. See `docs/decisions.md`, D-006 and D-036.
final class CardAssetResolver {
  /// Creates a resolver for the card art in [directory].
  const CardAssetResolver({this.directory = 'assets/cards'});

  /// The folder that holds the card art, as declared in `pubspec.yaml`.
  final String directory;

  /// The asset path of the face of [card], for example
  /// `assets/cards/10_of_spades.png`.
  String face(Card card) => '$directory/${_fileStem(card)}.png';

  /// The asset path of the card back.
  String get back => '$directory/back.png';

  /// The most pips a partly covered score six shows. At six the whole card
  /// shows, which is [face].
  static const int maxCoveredPips = 5;

  /// The asset path of the six of [suit] partly covered by a card back so
  /// that [pips] of its pips show, from 1 to [maxCoveredPips]: the score
  /// art of AGENTS.md §6.1. The owner's files are named
  /// `6_of_<suit>_<pips>_visible.webp`, for example
  /// `6_of_spades_3_visible.webp`; five of hearts is the file with a `_v2`
  /// suffix.
  String scoreSix(Suit suit, int pips) {
    if (pips < 1 || pips > maxCoveredPips) {
      throw ArgumentError.value(
        pips,
        'pips',
        'must be from 1 to $maxCoveredPips',
      );
    }
    final variant = suit == Suit.hearts && pips == maxCoveredPips ? '_v2' : '';
    return '$directory/6_of_${suit.name}_${pips}_visible$variant.webp';
  }

  static String _fileStem(Card card) {
    final rank = card.rank;
    final name = switch (rank) {
      Rank.jack || Rank.queen || Rank.king || Rank.ace => rank.name,
      _ => rank.symbol,
    };
    // The owner's court cards are the illustrated files with a 2 suffix.
    final variant = switch (rank) {
      Rank.jack || Rank.queen || Rank.king => '2',
      _ => '',
    };
    return '${name}_of_${card.suit.name}$variant';
  }
}

/// The [CardAssetResolver] that widgets use.
final cardAssetResolverProvider = Provider<CardAssetResolver>(
  (ref) => const CardAssetResolver(),
);
