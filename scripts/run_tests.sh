#!/usr/bin/env bash
# run_tests.sh — auto-run nitro_type_coverage integration tests on all available platforms.
#
# Usage:
#   ./scripts/run_tests.sh              # auto-detect every available platform/device
#   ./scripts/run_tests.sh macos        # macOS only
#   ./scripts/run_tests.sh ios          # first connected iOS device/simulator
#   ./scripts/run_tests.sh android      # first connected Android device
#   ./scripts/run_tests.sh linux        # Linux desktop (if running on Linux)
#   ./scripts/run_tests.sh windows      # Windows desktop (if running on Windows)
#   ./scripts/run_tests.sh web          # Chrome (dart2wasm) — needs emsdk on PATH
#   ./scripts/run_tests.sh all          # every available platform + all connected devices
#
# Platform availability rules:
#   macOS   — available when running on Darwin
#   iOS     — available when running on Darwin and at least one iOS device/sim is connected
#   Android — available when at least one Android device/emulator is connected
#   Linux   — available when running on Linux
#   Windows — available when running on Windows
#   Web     — available when em++ (emsdk) is on PATH; runs under dart2wasm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$PLUGIN_DIR/example"
TEST_FILE="integration_test/type_coverage_test.dart"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[PASS]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()   { echo -e "${RED}[FAIL]${NC}  $*"; }
log_skip()  { echo -e "${CYAN}[SKIP]${NC}  $*"; }

# ── Host OS detection ─────────────────────────────────────────────────────────
HOST_OS="$(uname -s)"
is_darwin()  { [[ "$HOST_OS" == "Darwin" ]]; }
is_linux()   { [[ "$HOST_OS" == "Linux" ]]; }
is_windows() { [[ "$HOST_OS" == MINGW* || "$HOST_OS" == MSYS* || "$HOST_OS" == CYGWIN* ]]; }

# ── Ensure build_runner is up to date and sync platform files ─────────────────
regen() {
  # Once example/ has been built for iOS/macOS/Windows/Linux, CocoaPods and
  # Flutter tooling leave behind ephemeral symlink trees — critically,
  # example/ios/.symlinks/plugins/<name> (and its macOS equivalent) point
  # STRAIGHT BACK to the plugin root. build_runner's initial file-discovery
  # walk follows symlinks by default with no cycle detection, so on any
  # SECOND run (once these exist) it recurses forever: plugin root -> example
  # -> ios -> .symlinks -> plugin root -> ... burning CPU/memory indefinitely
  # with no error, no crash, and no log output (confirmed via `sample` on the
  # hung process: stuck in dart:io's AsyncDirectoryLister). These directories
  # are fully gitignored/untracked and get recreated by `flutter pub get` /
  # `pod install`, so removing them here is always safe.
  rm -rf "$EXAMPLE_DIR/ios/.symlinks" "$EXAMPLE_DIR/ios/Flutter/ephemeral" \
         "$EXAMPLE_DIR/macos/.symlinks" "$EXAMPLE_DIR/macos/Flutter/ephemeral" \
         "$EXAMPLE_DIR/windows/flutter/ephemeral" "$EXAMPLE_DIR/linux/flutter/ephemeral"

  log_info "Running build_runner in plugin root..."
  (cd "$PLUGIN_DIR" && flutter pub run build_runner build --delete-conflicting-outputs)
  log_ok "Code generation complete"

  if is_darwin; then
    log_info "Syncing generated files to Apple platform directories..."
    local GEN="$PLUGIN_DIR/lib/src/generated"
    # Swift bridge
    cp "$GEN/swift/nitro_type_coverage.bridge.g.swift" "$PLUGIN_DIR/ios/Classes/nitro_type_coverage.bridge.g.swift"
    cp "$GEN/swift/nitro_type_coverage.bridge.g.swift" "$PLUGIN_DIR/macos/Classes/nitro_type_coverage.bridge.g.swift"
    cp "$GEN/swift/nitro_type_coverage.bridge.g.swift" "$PLUGIN_DIR/macos/nitro_type_coverage/Sources/NitroTypeCoverage/nitro_type_coverage.bridge.g.swift"
    # ObjC++ bridge (includes _release symbols)
    cp "$GEN/cpp/nitro_type_coverage.bridge.g.cpp" "$PLUGIN_DIR/ios/Classes/nitro_type_coverage.bridge.g.mm"
    cp "$GEN/cpp/nitro_type_coverage.bridge.g.cpp" "$PLUGIN_DIR/macos/Classes/nitro_type_coverage.bridge.g.mm"
    cp "$GEN/cpp/nitro_type_coverage.bridge.g.h"   "$PLUGIN_DIR/ios/Classes/nitro_type_coverage.bridge.g.h"
    cp "$GEN/cpp/nitro_type_coverage.bridge.g.h"   "$PLUGIN_DIR/macos/Classes/nitro_type_coverage.bridge.g.h"
    log_ok "Apple platform sync complete"
  fi
}

# ── Device discovery helpers ──────────────────────────────────────────────────

# Returns newline-separated device IDs for a given platform keyword (case-insensitive).
# `flutter devices` lines look like:
#   iPhone 16 (mobile) • ABC-123-UDID • ios • com.apple.CoreSimulator...
# The ID is the SECOND bullet-separated column — `awk '{print $1}'` would
# yield "iPhone"/"sdk" (the first word of the display name), which only
# worked by accident through flutter's substring device matching.
_devices_for() {
  local keyword="$1"
  flutter devices 2>/dev/null \
    | grep -i "$keyword" \
    | awk -F'•' 'NF >= 3 { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' \
    | grep -v '^$' \
    || true
}

android_devices() { _devices_for 'android'; }
ios_devices()     { _devices_for 'ios'; }

# A private log file for one run.
#
# NOT a bare `mktemp .../nitro_test_XXXXXX.log`: six X's is a small namespace,
# and once a long session has littered $TMPDIR with these, macOS mktemp gives
# up with "File exists". The variable then held an EMPTY path, `tee ""` failed,
# and pipefail reported a PASSING step as FAILED. Widen the template and fail
# loudly rather than silently mis-reporting.
new_log_file() {
  local f
  f="$(mktemp "${TMPDIR:-/tmp}/nitro_test_XXXXXXXXXXXX.log" 2>/dev/null)" || f=""
  if [[ -z "$f" ]]; then
    f="${TMPDIR:-/tmp}/nitro_test_$$_${RANDOM}_${RANDOM}.log"
    : > "$f" || { log_err "cannot create a log file in ${TMPDIR:-/tmp}"; return 1; }
  fi
  printf '%s' "$f"
}

# ── Run tests on a single device/platform ─────────────────────────────────────
# Usage: run_on_device <label> [device_id_or_platform_flag]
run_on_device() {
  local label="$1"
  local target="${2:-$label}"
  local log_file
  log_file="$(new_log_file)"

  log_info "Running integration tests on: $label"

  # --timeout: a single hung test (e.g. a stream that never emits) fails in
  # 2 minutes instead of hanging the whole CI job until its 45-60 min limit.
  if (cd "$EXAMPLE_DIR" && flutter test "$TEST_FILE" -d "$target" --timeout 120s 2>&1) | tee "$log_file"; then
    log_ok "PASSED — $label"
    rm -f "$log_file"
    return 0
  else
    log_err "FAILED — $label"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  FAILURE DIGEST — $label"
    echo "════════════════════════════════════════════════════════════════"
    # Print only failing test names, exception messages, and error lines.
    grep -E '^\s*(✗|EXCEPTION|The following|#[0-9]+|TimeoutException|Error:|error:|Expected:|Actual:|Test failed\.)' "$log_file" \
      | head -60 || true
    # Also print the last 20 lines for context.
    echo ""
    echo "--- last 20 lines of output ---"
    tail -20 "$log_file"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    rm -f "$log_file"
    return 1
  fi
}

# ── Per-platform runners (availability-gated) ─────────────────────────────────

run_macos() {
  if ! is_darwin; then
    log_skip "macOS — not running on Darwin, skipping."
    return 0
  fi
  TOTAL=$((TOTAL + 1))
  run_on_device "macOS" "macos" || FAILURES=$((FAILURES + 1))
}

run_ios() {
  if ! is_darwin; then
    log_skip "iOS — not running on Darwin, skipping."
    return 0
  fi
  local devs
  devs=$(ios_devices)
  if [[ -z "$devs" ]]; then
    log_skip "iOS — no iOS devices/simulators connected."
    return 0
  fi
  # Run on first available iOS device/simulator.
  local first
  first=$(echo "$devs" | head -1)
  TOTAL=$((TOTAL + 1))
  run_on_device "iOS ($first)" "$first" || FAILURES=$((FAILURES + 1))
}

run_android() {
  local devs
  devs=$(android_devices)
  if [[ -z "$devs" ]]; then
    log_skip "Android — no devices/emulators connected."
    return 0
  fi
  local first
  first=$(echo "$devs" | head -1)
  TOTAL=$((TOTAL + 1))
  run_on_device "Android ($first)" "$first" || FAILURES=$((FAILURES + 1))
}

run_all_android() {
  local devs
  devs=$(android_devices)
  if [[ -z "$devs" ]]; then
    log_skip "Android — no devices/emulators connected."
    return 0
  fi
  while IFS= read -r dev; do
    TOTAL=$((TOTAL + 1))
    run_on_device "Android ($dev)" "$dev" || FAILURES=$((FAILURES + 1))
  done <<< "$devs"
}

run_linux() {
  if ! is_linux; then
    log_skip "Linux — not running on Linux, skipping."
    return 0
  fi
  TOTAL=$((TOTAL + 1))
  run_on_device "Linux" "linux" || FAILURES=$((FAILURES + 1))
}

run_windows() {
  if ! is_windows; then
    log_skip "Windows — not running on Windows, skipping."
    return 0
  fi
  TOTAL=$((TOTAL + 1))
  run_on_device "Windows" "windows" || FAILURES=$((FAILURES + 1))
}

# Runs an arbitrary command with the same pass/fail digest as run_on_device.
run_logged() {
  local label="$1"; shift
  local log_file
  log_file="$(new_log_file)"
  log_info "Running: $label"
  if ("$@" 2>&1) | tee "$log_file"; then
    log_ok "PASSED — $label"
    rm -f "$log_file"
    return 0
  fi
  log_err "FAILED — $label"
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  FAILURE DIGEST — $label"
  echo "════════════════════════════════════════════════════════════════"
  grep -E '^\s*(✗|EXCEPTION|The following|#[0-9]+|TimeoutException|Error:|error:|Expected:|Actual:|Test failed\.)' "$log_file" | head -60 || true
  echo ""
  echo "--- last 20 lines of output ---"
  tail -20 "$log_file"
  echo "════════════════════════════════════════════════════════════════"
  echo ""
  rm -f "$log_file"
  return 1
}

# `flutter drive` on web talks WebDriver, so a driver must be listening on
# 4444 — without one it fails with "Unable to start a WebDriver session".
# Started here rather than in each CI job so local and CI runs are identical.
CHROMEDRIVER_PID=""
_stop_chromedriver() {
  if [[ -n "$CHROMEDRIVER_PID" ]]; then
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
    CHROMEDRIVER_PID=""
  fi
}
trap _stop_chromedriver EXIT

_ensure_chromedriver() {
  # Already listening (a dev's own session, or a CI step that started it) —
  # leave it alone; it is not ours to kill.
  if curl -s --max-time 2 http://localhost:4444/status >/dev/null 2>&1; then
    log_info "chromedriver already listening on 4444"
    return 0
  fi
  if ! command -v chromedriver >/dev/null 2>&1; then
    log_warn "chromedriver not on PATH — cannot drive the web integration suite."
    return 1
  fi
  chromedriver --port=4444 >/dev/null 2>&1 &
  CHROMEDRIVER_PID=$!
  for _ in $(seq 1 20); do
    if curl -s --max-time 2 http://localhost:4444/status >/dev/null 2>&1; then
      log_ok "chromedriver ready on 4444 (pid $CHROMEDRIVER_PID)"
      return 0
    fi
    sleep 1
  done
  log_err "chromedriver did not become ready on 4444"
  _stop_chromedriver
  return 1
}

_web_drive() {
  cd "$EXAMPLE_DIR" || return 1
  # `-d chrome`, NOT `-d web-server`: the latter never launches a browser and
  # the run reports success having executed nothing. The EXTENDED driver is
  # equally load-bearing — the plain integration_test_driver has no WebDriver
  # handshake and also reports a vacuous pass.
  #
  # `--wasm` is mandatory, not a preference: the suite contains int64 min/max
  # literals that dart2js cannot even compile (53-bit ints).
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$TEST_FILE" \
    -d chrome --wasm \
    --web-browser-flag=--headless=new \
    --web-browser-flag=--no-sandbox
}

_web_unit() {
  cd "$PLUGIN_DIR" || return 1
  flutter pub run test test/nitro_type_coverage_web_test.dart -p chrome "$@"
}

run_web() {
  if ! command -v em++ >/dev/null 2>&1; then
    log_skip "Web — em++ not on PATH (source emsdk_env.sh), skipping."
    return 0
  fi

  # The WASM module is a build artifact — rebuild it so the tests exercise the
  # C++ actually in the tree, not a stale checked-in binary.
  TOTAL=$((TOTAL + 1))
  if ! run_logged "Web (em++ build)" bash "$PLUGIN_DIR/web/build_web.sh"; then
    FAILURES=$((FAILURES + 1))
    log_warn "Web — module build failed, skipping the web test runs."
    return 0
  fi

  # Both compilers: they diverge at the js_interop boundary (dart2js `.toDart`
  # is a cast, dart2wasm's is a copy; dart2js ints are 53-bit), so a green run
  # under one says nothing about the other.
  TOTAL=$((TOTAL + 1))
  run_logged "Web browser suite (dart2js)" _web_unit || FAILURES=$((FAILURES + 1))
  TOTAL=$((TOTAL + 1))
  run_logged "Web browser suite (dart2wasm)" _web_unit -c dart2wasm || FAILURES=$((FAILURES + 1))

  # The package:test runs above need only Chrome; the integration suite also
  # needs a WebDriver server.
  if _ensure_chromedriver; then
    TOTAL=$((TOTAL + 1))
    run_logged "Web integration suite (chrome · dart2wasm)" _web_drive || FAILURES=$((FAILURES + 1))
    _stop_chromedriver
  else
    log_skip "Web integration suite — no chromedriver on 4444."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
MODE="${1:-auto}"
FAILURES=0
TOTAL=0

regen

echo ""
log_info "Mode: $MODE  |  Host: $HOST_OS"
echo ""

case "$MODE" in
  macos)
    run_macos
    ;;

  ios)
    run_ios
    ;;

  android)
    run_android
    ;;

  linux)
    run_linux
    ;;

  windows)
    run_windows
    ;;

  web)
    run_web
    ;;

  all)
    run_macos
    run_ios
    run_all_android
    run_linux
    run_windows
    run_web
    ;;

  auto|*)
    log_info "Auto-detecting available targets..."
    run_macos
    run_ios
    run_android
    run_linux
    run_windows
    run_web
    ;;
esac

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ $TOTAL -eq 0 ]]; then
  log_warn "No targets were available to test on this host."
  exit 0
elif [[ $FAILURES -eq 0 ]]; then
  log_ok "All $TOTAL target(s) passed."
  exit 0
else
  log_err "$FAILURES / $TOTAL target(s) failed."
  exit 1
fi
