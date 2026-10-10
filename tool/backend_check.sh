#!/usr/bin/env bash
# Checks the backend against a local Supabase stack in Docker
# (docs/decisions.md D-029): applies supabase/migrations to a fresh local
# database, then runs the server tests, including the integration tests
# that use real Supabase Auth tokens, the Postgres store and row-level
# security. tool/check.sh skips those; this script needs Docker and Node.
#
# Usage: tool/backend_check.sh   (from any directory)
# The local stack is started if it is not running; stop it with
#   npx supabase stop
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

supabase() { npx --yes supabase@2.119.0 "$@"; }

if ! supabase status >/dev/null 2>&1; then
  printf '\n==> Start the local Supabase stack\n'
  supabase start -x realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor
fi

printf '\n==> Apply the migrations to a fresh local database\n'
supabase db reset

printf '\n==> Server tests against the local stack\n'
# Only local, well-known development keys are read here, never the real
# project's.
eval "$(supabase status -o json | python -c '
import json, sys
d = json.load(sys.stdin)
for name, key in [("DATABASE_URL", "DB_URL"), ("SUPABASE_URL", "API_URL"),
                  ("SUPABASE_KEY", "ANON_KEY"), ("SUPABASE_SERVICE_KEY", "SERVICE_ROLE_KEY")]:
    print(f"export CARDGAMES_TEST_{name}={d[key]}")
')"
(cd server && dart test)

printf '\n==> App sign-in against the local stack\n'
(cd apps/mobile && flutter test test/remote)

printf '\nbackend_check.sh: all checks passed\n'
