#!/usr/bin/env bash
# Linux check in a Docker container (colima on macOS): unit suites of every
# nitro package, the benchmark's Linux build, and this plugin's integration
# suite on Linux desktop under xvfb. Mirrors the CI Linux jobs.
#   scripts/linux_container_test.sh            # everything
#   scripts/linux_container_test.sh '§80'      # only that integration group
#   SRC=/path/holding/both/checkouts scripts/linux_container_test.sh   # other trees
set -euo pipefail
PLUGIN=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$PLUGIN/../.." && pwd)   # holds nitro_plugins/ and flutter_package/
VERSION=${FLUTTER_VERSION:-$(flutter --version 2>/dev/null | awk 'NR==1{print $2}')}
IMAGE="nitro-linux-test:${VERSION:-stable}"
docker build -q -t "$IMAGE" --build-arg "FLUTTER_VERSION=${VERSION:-stable}" "$PLUGIN/scripts/linux"
# /work persists build/ and .dart_tool/ between runs; the sources are re-synced each time.
docker run --rm -v "${SRC:-$ROOT}:/src:ro" -v nitro-linux-work:/work -v nitro-linux-pub-cache:/root/.pub-cache -e "FILTER=${1:-}" "$IMAGE" \
  bash /src/nitro_plugins/nitro_type_coverage/scripts/linux/run_in_container.sh
