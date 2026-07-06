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
#   ./scripts/run_tests.sh all          # every available platform + all connected devices
#
# Platform availability rules:
#   macOS   — available when running on Darwin
#   iOS     — available when running on Darwin and at least one iOS device/sim is connected
#   Android — available when at least one Android device/emulator is connected
#   Linux   — available when running on Linux
#   Windows — available when running on Windows

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
  (cd "$PLUGIN_DIR" && dart run build_runner build --delete-conflicting-outputs)
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
_devices_for() {
  local keyword="$1"
  flutter devices 2>/dev/null \
    | grep -i "$keyword" \
    | awk '{print $1}' \
    | grep -v '^$' \
    || true
}

android_devices() { _devices_for 'android'; }
ios_devices()     { _devices_for 'ios'; }

# ── Run tests on a single device/platform ─────────────────────────────────────
# Usage: run_on_device <label> [device_id_or_platform_flag]
run_on_device() {
  local label="$1"
  local target="${2:-$label}"
  local log_file
  log_file="$(mktemp "${TMPDIR:-/tmp}/nitro_test_XXXXXX.log")"

  log_info "Running integration tests on: $label"

  if (cd "$EXAMPLE_DIR" && flutter test "$TEST_FILE" -d "$target" 2>&1) | tee "$log_file"; then
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

  all)
    run_macos
    run_ios
    run_all_android
    run_linux
    run_windows
    ;;

  auto|*)
    log_info "Auto-detecting available targets..."
    run_macos
    run_ios
    run_android
    run_linux
    run_windows
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
