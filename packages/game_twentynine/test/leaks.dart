import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

/// Every card the player in [viewer] may see in [state]: their hand, the
/// cards played, and the seventh card if revealed or theirs.
Set<Card> visibleCards(TwentyNineState state, Seat viewer) => {
  ...state.hands[viewer.index],
  for (final trick in state.tricks)
    for (final play in trick.plays) play.card,
  for (final play in state.trick) play.card,
  if (state.seventhCard case final seventh?)
    if (state.trumpRevealed || state.bidder == viewer) seventh,
};

/// What the view of [viewer] shows that it must not, or null if nothing
/// (AGENTS.md §6.12 and §8.1): another hand, an undealt card, the seed, or
/// a hidden trump.
String? leakIn(TwentyNineState state, Seat viewer) {
  final json = const TwentyNineGame().viewFor(state, viewer).toJson();
  final text = canonicalJson(json);
  final allowed = visibleCards(state, viewer);
  for (final card in TwentyNineRules.deck) {
    if (!allowed.contains(card) && text.contains('"${card.id}"')) {
      return '${card.id} is visible to ${viewer.id}';
    }
  }
  if (text.contains(seedToHex(state.matchSeed))) return 'the match seed';
  final dealSeed = state.dealSeed;
  if (dealSeed != null && text.contains(seedToHex(dealSeed))) {
    return 'the deal seed';
  }
  final trump = json['trump']! as Map<String, Object?>;
  if (!state.trumpRevealed && state.bidder != viewer && trump['suit'] != null) {
    return 'the hidden trump';
  }
  return null;
}
