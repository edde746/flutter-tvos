#!/usr/bin/env bash
# Assemble a minimal tarball containing only the artifacts consumer apps need:
# the tvOS + host Flutter.framework bundles, gen_snapshot, frontend_server
# snapshot, dart-sdk host binaries, flutter_patched_sdk, and engine snapshot
# binaries. Everything else (unit tests, .o intermediates, swiftshader, etc.)
# is left in ./out/ and not shipped.
#
# Usage: scripts/package.sh 3.41.6

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

VERSION="${1-}"
require_arg "$VERSION"

OUT_VERSION="${OUT_ROOT}/${VERSION}"
STAGE_DIR="${OUT_ROOT}/packages/stage-${VERSION}"
PKG_DIR="${OUT_ROOT}/packages"
TARBALL="${PKG_DIR}/flutter-tvos-${VERSION}.tar.gz"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$PKG_DIR"

# Source is relative to out/<version>/. The tarball nests everything under
# `out/<variant>/...` so consumers can extract somewhere and set
# FLUTTER_LOCAL_ENGINE to the extract dir — Flutter's Xcode build scripts
# look for `$FLUTTER_LOCAL_ENGINE/out/<variant>/` and find our layout
# unchanged.
ITEMS=(
  # Simulator (dev iteration)
  "tvos_debug_sim_unopt_arm64/Flutter.framework"
  "tvos_debug_sim_unopt_arm64/gen/flutter/lib/snapshot/vm_isolate_snapshot.bin"
  "tvos_debug_sim_unopt_arm64/gen/flutter/lib/snapshot/isolate_snapshot.bin"

  # Device AOT
  "tvos_release/Flutter.framework"
  "tvos_release/artifacts_arm64/gen_snapshot_arm64"
  "tvos_release/gen/flutter/lib/snapshot/vm_isolate_snapshot.bin"
  "tvos_release/gen/flutter/lib/snapshot/isolate_snapshot.bin"

  # Host tools to compile kernels + AOT snapshots on macOS.
  "host_release/dart-sdk/bin/dart"
  "host_release/dart-sdk/bin/dartaotruntime"
  "host_release/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot"
  "host_release/dart-sdk/lib"
  "host_release/dart-sdk/include"
  "host_release/dart-sdk/version"
  "host_release/flutter_patched_sdk"
  "host_release/clang_arm64/gen_snapshot"
)

missing=()
for item in "${ITEMS[@]}"; do
  src="${OUT_VERSION}/${item}"
  if [[ ! -e "$src" ]]; then
    missing+=("$item")
    continue
  fi
  dst="${STAGE_DIR}/out/${item}"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
done

if (( ${#missing[@]} > 0 )); then
  echo "error: missing build outputs — run build-engine.sh for all variants first:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "Staged $(du -sh "$STAGE_DIR" | awk '{print $1}') at $STAGE_DIR"
echo "Packaging → $TARBALL"
(cd "$PKG_DIR" && tar -czf "$TARBALL" -C "stage-${VERSION}" .)
rm -rf "$STAGE_DIR"

ls -lh "$TARBALL"
echo "Done. Upload with: gh release create v${VERSION} $TARBALL"
