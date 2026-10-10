-- Games: series of matches at one table (AGENTS.md §6.13; docs/decisions.md
-- D-037). The server records each match's place in its game and, once it
-- accepts the match, the match record it leaves and whether the game goes
-- on. The next match of the game is checked against these, never against
-- what a device says.

alter table public.matches
  add column series_id uuid,
  add column series_match integer check (series_match >= 1),
  add column table_key text,
  add column record_after integer,
  add column series_continues boolean;

-- One match per place in a game: a log cannot branch a game in two.
create unique index matches_series_place_idx
  on public.matches (series_id, series_match)
  where series_id is not null;
