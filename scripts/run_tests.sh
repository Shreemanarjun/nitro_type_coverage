#!/usr/bin/env bash
# run_tests.sh — auto-run nitro_type_coverage integration tests on macOS and Android.
#
# Usage:
#   ./scripts/run_tests.sh            # auto-detect connected devices
#   ./scripts/run_tests.sh macos      # macOS only
#   ./scripts/run_tests.sh android    # first connected Android device only
#   ./scripts/run_tests.sh all        # macOS + all connected Android devices

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
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[PASS]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()   { echo -e "${RED}[FAIL]${NC}  $*"; }

# ── Ensure build_runner is up to date and sync platform files ─────────────────
regen() {
  log_info "Running build_runner in plugin root..."
  (cd "$PLUGIN_DIR" && dart run build_runner build --delete-conflicting-outputs)
  log_ok "Code generation complete"

  log_info "Syncing generated files to platform directories..."
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
  log_ok "Platform sync complete"
}

# ── Run tests on a single device/platform ─────────────────────────────────────
run_on_device() {
  local platform="$1"
  local device_id="${2:-}"
  local label="${device_id:-$platform}"

  log_info "Running integration tests on: $label"

  local args=("flutter" "test" "$TEST_FILE")
  if [[ -n "$device_id" ]]; then
    args+=("-d" "$device_id")
  else
    args+=("-d" "$platform")
  fi

  if (cd "$EXAMPLE_DIR" && "${args[@]}" 2>&1); then
    log_ok "PASSED — $label"
    return 0
  else
    log_err "FAILED — $label"
    return 1
  fi
}

# ── Collect connected Android device IDs ──────────────────────────────────────
android_devices() {
  flutter devices 2>/dev/null \
    | grep -i 'android' \
    | awk '{print $1}' \
    | grep -v '^$' \
    || true
}

# ── Main ──────────────────────────────────────────────────────────────────────
MODE="${1:-auto}"
FAILURES=0
TOTAL=0

# Regenerate bridge files before testing.
regen

case "$MODE" in
  macos)
    TOTAL=$((TOTAL + 1))
    run_on_device macos || FAILURES=$((FAILURES + 1))
    ;;

  android)
    DEVICES=$(android_devices)
    if [[ -z "$DEVICES" ]]; then
      log_warn "No Android devices connected. Skipping Android tests."
    else
      FIRST=$(echo "$DEVICES" | head -1)
      TOTAL=$((TOTAL + 1))
      run_on_device "" "$FIRST" || FAILURES=$((FAILURES + 1))
    fi
    ;;

  all)
    # macOS
    TOTAL=$((TOTAL + 1))
    run_on_device macos || FAILURES=$((FAILURES + 1))

    # All connected Android devices
    DEVICES=$(android_devices)
    if [[ -z "$DEVICES" ]]; then
      log_warn "No Android devices found."
    else
      while IFS= read -r dev; do
        TOTAL=$((TOTAL + 1))
        run_on_device "" "$dev" || FAILURES=$((FAILURES + 1))
      done <<< "$DEVICES"
    fi
    ;;

  auto|*)
    # macOS is always available; Android only if devices are connected.
    log_info "Auto-detecting available targets..."

    TOTAL=$((TOTAL + 1))
    run_on_device macos || FAILURES=$((FAILURES + 1))

    DEVICES=$(android_devices)
    if [[ -z "$DEVICES" ]]; then
      log_warn "No Android devices connected — skipping Android."
    else
      while IFS= read -r dev; do
        TOTAL=$((TOTAL + 1))
        run_on_device "" "$dev" || FAILURES=$((FAILURES + 1))
      done <<< "$DEVICES"
    fi
    ;;
esac

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ $FAILURES -eq 0 ]]; then
  log_ok "All $TOTAL target(s) passed."
  exit 0
else
  log_err "$FAILURES / $TOTAL target(s) failed."
  exit 1
fi
