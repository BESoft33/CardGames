# Missing card assets

Card art comes only from the owner (AGENTS.md §13). The files listed under
"Missing" are needed but are not in `apps/mobile/assets/cards/`. Debug builds
show a labelled stand-in for each one. Do not ship a release while the list
has entries.

The owner's faces are PNGs named `<rank>_of_<suit>.png`, the back is
`back.png` and the score sixes are WebPs named
`6_of_<suit>_<pips>_visible.webp` (see `docs/decisions.md`, D-006 and
D-035). Add a missing file under the
name listed here, or say which name you used; only `CardAssetResolver`
changes.

The asset test in `apps/mobile` fails if this list and the folder disagree,
so keep it exact: one `- assets/cards/<file>` line per missing file.

## Missing

Nothing. Every file Twenty-Nine needs is present. The covered sixes of
diamonds and clubs, the last ones missing, came on 2026-10-10.

## Supplied but not required

The table also uses, and the asset test also checks, the 2s to 5s of every
suit (the trump marker and the match cards), the four plain sixes, and the
covered sixes of every suit (AGENTS.md §6.1 and §13). The jokers and
`ace_of_spades2.png` are not used. `Madhu Games Crowned Logo.png` is the
app icon's source (docs/decisions.md D-042), not card art.
