#!/usr/bin/env bash
# Collect the variants consumer apps need into a single tarball for a GitHub Release.
#
# Usage: scripts/package.sh 3.41.6

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

VERSION="${1-}"
require_arg "$VERSION"

OUT_VERSION="${OUT_ROOT}/${VERSION}"
PKG_DIR="${OUT_ROOT}/packages"
mkdir -p "$PKG_DIR"

REQUIRED=(
  "tvos_debug_sim_unopt_arm64/Flutter.framework"
  "tvos_release/Flutter.framework"
  "tvos_release/artifacts_arm64/gen_snapshot_arm64"
  "tvos_release/gen/flutter/lib/snapshot/vm_isolate_snapshot.bin"
  "host_release/dart-sdk/bin/dartaotruntime"
  "host_release/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot"
  "host_release/flutter_patched_sdk"
)

missing=()
for item in "${REQUIRED[@]}"; do
  [[ -e "${OUT_VERSION}/${item}" ]] || missing+=("$item")
done
if (( ${#missing[@]} > 0 )); then
  echo "error: missing build outputs (did you run build-engine.sh for all variants?):" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

TARBALL="${PKG_DIR}/flutter-tvos-${VERSION}.tar.gz"
echo "Packaging → $TARBALL"
(cd "${OUT_ROOT}" && tar -czf "$TARBALL" "${VERSION}/tvos_debug_sim_unopt_arm64" "${VERSION}/tvos_release" "${VERSION}/host_release")
echo "Done. Upload $TARBALL to a GitHub Release tagged v${VERSION}."
