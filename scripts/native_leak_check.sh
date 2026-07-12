#!/usr/bin/env bash
# native_leak_check.sh — compile the REAL generated bridge + Linux impl with
# AddressSanitizer/LeakSanitizer and pound the sync dispatch paths.
#
# Any leak LSan reports at exit is a genuine leak in the generated dispatch
# or the hand-written impl — the harness plays Dart's role byte-for-byte
# (frees Dart-owned returns via <lib>_nitro_free, allocates callback returns
# via <lib>_nitro_alloc), and there is no Flutter/Dart VM noise to suppress.
#
# Runs on Linux (LeakSanitizer) and macOS (ASan; use `leaks` for LSan-level
# detail there). Usage: ./scripts/native_leak_check.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
GEN="$PLUGIN_DIR/lib/src/generated/cpp"
OUT_DIR="${TMPDIR:-/tmp}/nitro_native_leak_check"
mkdir -p "$OUT_DIR"

CXX="${CXX:-clang++}"

# dart_api_dl.c satisfies the Dart_* symbol references in the bridge; the
# harness never initializes it — sync paths don't touch Dart ports.
# (It lives in src/, its headers in src/native/ — same layout src/CMakeLists.txt uses.)
# C file → C standard; -std=c++17 with -x c is a hard error on Linux clang.
"$CXX" -std=c11 -g -fsanitize=address -fno-omit-frame-pointer \
  -I"$GEN" \
  -I"$PLUGIN_DIR/src/native" \
  -x c "$PLUGIN_DIR/src/dart_api_dl.c" -c -o "$OUT_DIR/dart_api_dl.o"

"$CXX" -std=c++17 -g -fsanitize=address -fno-omit-frame-pointer \
  -I"$GEN" \
  -I"$PLUGIN_DIR/src/native" \
  "$GEN/nitro_type_coverage.bridge.g.cpp" \
  "$PLUGIN_DIR/linux/src/HybridNitroTypeCoverage.cpp" \
  "$SCRIPT_DIR/native_leak_check/main.cpp" \
  "$OUT_DIR/dart_api_dl.o" \
  -pthread \
  -o "$OUT_DIR/native_leak_check"

# detect_leaks is on by default under Linux ASan; be explicit so the intent
# survives environment differences. macOS ASan has no LSan — the run still
# catches use-after-free/overflows there.
if [[ "$(uname -s)" == "Linux" ]]; then
  export ASAN_OPTIONS="detect_leaks=1:${ASAN_OPTIONS:-}"
fi

"$OUT_DIR/native_leak_check"
echo "[PASS] native leak check clean"
