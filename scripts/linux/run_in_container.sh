#!/usr/bin/env bash
# Runs inside the image. /src is the read-only host mount holding
# flutter_package/nitro_ecosystem and nitro_plugins/nitro_type_coverage; both
# are copied to /work (without build/ and .dart_tool/) so the path deps
# resolve and nothing Linux-specific lands in the host checkouts.
# FILTER (optional): --plain-name filter for the integration suite only.
set -euo pipefail
sync() { mkdir -p "/work/$1"; rsync -a --exclude build --exclude .dart_tool --exclude .symlinks --exclude ephemeral "/src/$1/" "/work/$1/"; }
sync flutter_package/nitro_ecosystem
sync nitro_plugins/nitro_type_coverage
ECO=/work/flutter_package/nitro_ecosystem
TC=/work/nitro_plugins/nitro_type_coverage

step() { echo; echo "══ $* ══"; }
step "pub get (workspace)"; (cd "$ECO" && flutter pub get)
for p in nitro_annotations nitrogen_cli; do step "$p: dart test"; (cd "$ECO/packages/$p" && dart test); done
for p in nitro_generator nitro; do step "$p: flutter test"; (cd "$ECO/packages/$p" && flutter test); done
step "benchmark example: flutter build linux"; (cd "$ECO/benchmark/example" && flutter build linux --no-pub)

if [ -n "${FILTER:-}" ]; then
  step "type coverage: integration suite on linux (filter: $FILTER)"
  (cd "$TC" && flutter pub get && cd example && flutter pub get && xvfb-run -a flutter test integration_test/type_coverage_test.dart -d linux --timeout 120s --plain-name "$FILTER")
else
  step "type coverage: scripts/run_tests.sh linux (regen + full integration suite)"
  (cd "$TC" && xvfb-run -a ./scripts/run_tests.sh linux)
fi
step "done"
