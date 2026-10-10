-- card.games backend, Milestone 6 (docs/decisions.md D-029 to D-032).
--
-- Only the game server writes these tables: it connects as the table owner,
-- so row-level security does not apply to it. Players, through the
-- Supabase API, may read their own rows and nothing else (AGENTS.md §12).
-- The app itself talks to the game server, not to these tables.

-- A device-local profile (AGENTS.md §10), bound to the account that first
-- uploaded from it. A merged guest's profiles move to the account it
-- joined.
create table public.profiles (
  profile_id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  device_id uuid not null,
  created_at timestamptz not null default now()
);
create index profiles_user_id_idx on public.profiles (user_id);

-- One row per uploaded match: how far its log is held, and where the
-- server stands on it (AGENTS.md §9).
create table public.matches (
  match_id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  profile_id uuid not null references public.profiles (profile_id) on delete cascade,
  game_id text not null,
  rules_version integer not null,
  last_seq integer not null check (last_seq >= -1),
  last_hash text not null,
  status text not null check (status in ('open', 'accepted', 'rejected')),
  reject_reason text,
  coins bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index matches_user_id_idx on public.matches (user_id);

-- The uploaded event logs, exactly as the device wrote them: the canonical
-- JSON of each envelope, whose hash chain the server checks.
create table public.match_events (
  event_id uuid primary key,
  match_id uuid not null references public.matches (match_id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  seq integer not null check (seq >= 0),
  envelope text not null,
  received_at timestamptz not null default now(),
  unique (match_id, seq)
);
create index match_events_user_id_idx on public.match_events (user_id);

-- The coin ledger (AGENTS.md §11): append-only. The unique key means
-- nothing is ever credited twice. The balance is the sum of delta.
create table public.wallet_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  delta bigint not null,
  reason text not null,
  ref_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, reason, ref_id)
);

-- Google accounts that have had the sign-up bonus. Kept after an account
-- is deleted, so the bonus is paid once per Google account, ever. Only a
-- SHA-256 hash of the Google subject ID is kept (D-032).
create table public.signup_bonus_claims (
  provider text not null,
  subject_hash text not null check (length(subject_hash) = 64),
  claimed_at timestamptz not null default now(),
  primary key (provider, subject_hash)
);

-- Guest accounts merged into a signed-in account (AGENTS.md §10). Kept
-- after the guest is deleted, so it can never be merged twice.
create table public.account_merges (
  from_user_id uuid primary key,
  to_user_id uuid not null references auth.users (id) on delete cascade,
  coins bigint not null,
  merged_at timestamptz not null default now()
);

create view public.wallet_balances with (security_invoker = true) as
  select user_id, sum(delta)::bigint as balance
  from public.wallet_ledger
  group by user_id;

-- Row-level security on every table (AGENTS.md §12).
alter table public.profiles enable row level security;
alter table public.matches enable row level security;
alter table public.match_events enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.signup_bonus_claims enable row level security;
alter table public.account_merges enable row level security;

create policy "Players read their own profiles"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players read their own matches"
  on public.matches for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players read their own match events"
  on public.match_events for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players read their own ledger"
  on public.wallet_ledger for select to authenticated
  using ((select auth.uid()) = user_id);
-- signup_bonus_claims and account_merges have no policies: only the server
-- reads them.

-- Grants as a second line: the Supabase API roles may only read, and
-- guests of the API (anon) may not even do that.
revoke all on public.profiles, public.matches, public.match_events,
  public.wallet_ledger, public.signup_bonus_claims, public.account_merges,
  public.wallet_balances
  from anon, authenticated;
grant select on public.profiles, public.matches, public.match_events,
  public.wallet_ledger, public.wallet_balances
  to authenticated;
