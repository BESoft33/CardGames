#!/usr/bin/env bash
# The gate every change must pass before it is reported as done
# (AGENTS.md §4 and §14): dependencies, formatting, analysis, the
# pure-Dart guard for packages/, every test suite, and the coverage minimum.
#
# Usage: tool/check.sh   (from any directory)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

current='setup'
trap 'printf "\ncheck.sh: FAILED during: %s\n" "$current" >&2' ERR

step() {
  current="$1"
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\ncheck.sh: FAILED: %s\n' "$1" >&2
  trap - ERR
  exit 1
}

for tool in flutter dart; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH"
done

# Minimum line coverage per package, in percent (AGENTS.md §14).
min_coverage() {
  case "$1" in
    game_twentynine) echo 95 ;;
    *) echo 0 ;;
  esac
}

step 'Resolve dependencies'
flutter pub get

step 'Format'
dart format --output=none --set-exit-if-changed .

step 'Analyze'
flutter analyze --fatal-infos --fatal-warnings

step 'Pure Dart guard: nothing under packages/ imports Flutter, dart:ui or dart:io'
if grep -rnE --include='*.dart' \
  "^[[:space:]]*(import|export)[[:space:]]+['\"](package:flutter|dart:ui|dart:io)" \
  packages; then
  fail 'a file under packages/ imports Flutter, dart:ui or dart:io (AGENTS.md §5.1)'
fi

step 'Dart package tests'
for dir in packages/*/ server/; do
  [ -f "$dir/pubspec.yaml" ] || continue
  [ -d "$dir/test" ] || fail "$dir has no tests"
  name="$(basename "$dir")"
  minimum="$(min_coverage "$name")"
  printf -- '--- %s\n' "$dir"
  if [ "$minimum" -gt 0 ]; then
    (cd "$dir" && dart run coverage:test_with_coverage)
    awk -F'[:,]' -v min="$minimum" -v name="$name" '
      /^DA:/ { lines++; if ($3 > 0) hit++ }
      END {
        pct = lines ? 100 * hit / lines : 0
        printf "%s line coverage: %.2f%% (%d of %d lines; minimum %d%%)\n", name, pct, hit, lines, min
        exit pct < min
      }' "$dir/coverage/lcov.info" ||
      fail "$name line coverage is below $minimum%"
  else
    (cd "$dir" && dart test)
  fi
done

step 'Flutter app tests'
# flutter test reuses its bundled assets unless a file looks newer than the
# last build. Owner files keep old timestamps, so a stale bundle could hide a
# missing card. Rebuild it every time.
rm -rf apps/mobile/build/unit_test_assets
(cd apps/mobile && flutter test)

trap - ERR
printf '\ncheck.sh: all checks passed\n'
