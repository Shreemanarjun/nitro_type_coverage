#!/usr/bin/env bash
# @NitroEntryPoint with the app process KILLED: every scenario force-stops /
# terminates the example app first, starts jobs purely from the OS side, and
# reads what the Dart entries persisted — without ever opening the UI.
#
#   scripts/bg_native_check.sh android [serial]      # default: first adb device
#   scripts/bg_native_check.sh ios [udid]            # default: booted simulator
#   scripts/bg_native_check.sh all
#
# The example app must be installed (flutter install -d <device> from example/).
# Scenarios (each with the app killed first):
#   single   one job, fresh process                  → 1 line persisted
#   burst    5 jobs of the same entry in a row        → 5 lines, each once
#   mixed    fast + slow + failing entries together   → fast first, slow last,
#            the failing one reported (log) and not blocking the others
#   url      (android) the VIEW intent path, same as iOS's URL scheme
set -uo pipefail
PKG=nitro.nitro_type_coverage_example
IOS_BUNDLE=nitro.nitroTypeCoverageExample
PASS=0; FAIL=0
ok()   { echo "  [PASS] $*"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
wait_for() { # wait_for <seconds> <cmd...> : until cmd succeeds
  local n=$(( $1 * 5 )); shift
  for _ in $(seq 1 "$n"); do "$@" >/dev/null 2>&1 && return 0; sleep 0.2; done
  return 1
}
wait_lines() { # wait_lines <counter-fn> <count> <seconds> : re-evaluates the counter each tick
  local n=$(( $3 * 5 ))
  for _ in $(seq 1 "$n"); do [ "$($1)" -ge "$2" ] && return 0; sleep 0.2; done
  return 1
}

# ───────────────────────────── Android ────────────────────────────────────
android() {
  local S=${1:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}
  [ -n "$S" ] || { echo "no android device"; return 1; }
  local A="adb -s $S"
  a() { $A "$@"; }
  a_cat() { a shell run-as $PKG sh -c "'for f in \$(ls code_cache/nitro_bg_lines 2>/dev/null | sort); do cat code_cache/nitro_bg_lines/\$f; echo; done'"; }
  a_lines() { a_cat | grep -c .; }
  kill_app() { a shell am force-stop $PKG; sleep 0.5; a shell run-as $PKG rm -rf code_cache/nitro_bg_result.txt code_cache/nitro_bg_lines; }
  fire() { # fire <entry> <text> [broadcast|url]
    if [ "${3:-broadcast}" = url ]; then
      a shell am start -W -a android.intent.action.VIEW -d "nitrobg://run?entry=$1\&text=$2" >/dev/null
    else
      a shell am broadcast -a nitro.BG_JOB -n $PKG/.NitroBgJobReceiver --es entry "$1" --es text "$2" >/dev/null
    fi
  }
  echo "── Android ($S): app killed before every scenario ──"
  [ "$(a shell pm list packages | grep -c "$PKG")" = 1 ] || { bad "example app not installed on $S"; return; }
  a logcat -c

  kill_app; fire bgPersist single
  if wait_for 20 a shell run-as $PKG ls code_cache/nitro_bg_result.txt; then
    ok "single: $(a shell run-as $PKG cat code_cache/nitro_bg_result.txt) (process was started for the job: $(a shell pidof $PKG | wc -w | tr -d ' ') pid)"
  else bad "single: no result within 20s"; fi

  kill_app; for i in 1 2 3 4 5; do fire bgAppend "burst-$i"; done
  if wait_lines a_lines 5 30; then
    local dup=$(a_cat | cut -d' ' -f1 | sort | uniq -d | wc -l | tr -d ' ')
    [ "$(a_lines)" = 5 ] && [ "$dup" = 0 ] && ok "burst: 5 jobs → 5 lines, none twice" || bad "burst: $(a_lines) lines, $dup duplicates"
  else bad "burst: only $(a_lines)/5 lines within 30s"; fi

  kill_app; fire bgSlowAppend slow; fire bgFailAppend boom; fire bgAppend fast
  if wait_lines a_lines 3 30; then
    local L; L=$(a_cat)
    local F; F=$(echo "$L" | grep -n '^fast @' | cut -d: -f1); local W; W=$(echo "$L" | grep -n '^slow @' | cut -d: -f1)
    [ -n "$F" ] && [ -n "$W" ] && [ "$F" -lt "$W" ] && echo "$L" | grep -q '^boom failing' && ok "mixed: fast before slow, failing one ran and did not block them" || bad "mixed: unexpected order: $(echo "$L" | tr '\n' '|')"
    a logcat -d 2>/dev/null | grep -q "NitroBgJob: bgFailAppend job .* done: Bad state: bgFailAppend: boom" && ok "mixed: failure text reached the native onDone callback" || bad "mixed: no onDone error for bgFailAppend in logcat"
    a logcat -d 2>/dev/null | grep -q "Nitro *: background job .* failed: Bad state" && ok "mixed: failure also logged under the Nitro tag" || bad "mixed: no Nitro failure log line"
  else bad "mixed: only $(a_lines)/3 lines within 30s"; fi

  kill_app; fire bgAppend from-url url
  wait_lines a_lines 1 20 && ok "url: VIEW intent with the app killed → $(a_cat)" || bad "url: nothing persisted"
  a shell am force-stop $PKG
}

# ───────────────────────────── iOS ────────────────────────────────────────
ios() {
  local U=${1:-booted}
  local C; C=$(xcrun simctl get_app_container "$U" $IOS_BUNDLE data 2>/dev/null) || { bad "example app not installed on $U"; return; }
  i_cat() { ls "$C/tmp/nitro_bg_lines"/*.txt 2>/dev/null | sort | while read -r f; do cat "$f"; echo; done; }
  i_lines() { i_cat | grep -c .; }
  kill_app() { xcrun simctl terminate "$U" $IOS_BUNDLE 2>/dev/null; sleep 0.5; rm -rf "$C/tmp/nitro_bg_result.txt" "$C/tmp/nitro_bg_lines"; }
  fire() { xcrun simctl openurl "$U" "nitrobg://run?entry=$1&text=$2"; }
  echo "── iOS ($U): app terminated before every scenario (a URL open relaunches it; the job runs in a headless engine) ──"
  local T0; T0=$(date +%H:%M:%S)

  kill_app; fire bgPersist single
  wait_for 20 test -f "$C/tmp/nitro_bg_result.txt" && ok "single: $(cat "$C/tmp/nitro_bg_result.txt")" || bad "single: no result within 20s"

  kill_app; for i in 1 2 3 4 5; do fire bgAppend "burst-$i"; done
  if wait_lines i_lines 5 30; then
    local dup; dup=$(i_cat | cut -d' ' -f1 | sort | uniq -d | wc -l | tr -d ' ')
    [ "$(i_lines)" = 5 ] && [ "$dup" = 0 ] && ok "burst: 5 jobs → 5 lines, none twice" || bad "burst: $(i_lines) lines, $dup duplicates"
  else bad "burst: only $(i_lines)/5 lines within 30s"; fi

  kill_app; fire bgSlowAppend slow; fire bgFailAppend boom; fire bgAppend fast
  if wait_lines i_lines 3 30; then
    local L; L=$(i_cat); local F; F=$(echo "$L" | grep -n '^fast @' | cut -d: -f1); local W; W=$(echo "$L" | grep -n '^slow @' | cut -d: -f1)
    [ -n "$F" ] && [ -n "$W" ] && [ "$F" -lt "$W" ] && echo "$L" | grep -q '^boom failing' && ok "mixed: fast before slow, failing one ran and did not block them" || bad "mixed: unexpected order: $(echo "$L" | tr '\n' '|')"
    xcrun simctl spawn "$U" log show --start "$(date +%Y-%m-%d) $T0" --predicate 'process == "Runner"' 2>/dev/null | grep -q "NitroBgJob: bgFailAppend job .* done: Bad state: bgFailAppend: boom" && ok "mixed: failure text reached the native onDone callback" || bad "mixed: no onDone error for bgFailAppend in the log"
  else bad "mixed: only $(i_lines)/3 lines within 30s"; fi
  xcrun simctl terminate "$U" $IOS_BUNDLE 2>/dev/null
}

case "${1:-all}" in
  android) android "${2:-}" ;;
  ios) ios "${2:-}" ;;
  all) android ""; ios "" ;;
  *) echo "usage: $0 android|ios|all [device]"; exit 2 ;;
esac
echo "── $PASS passed, $FAIL failed ──"
[ "$FAIL" = 0 ]
