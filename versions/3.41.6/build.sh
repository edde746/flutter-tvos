#!/usr/bin/env bash
# Build one variant of the 3.41.6 tvOS engine.
# Expects sources synced via scripts/fetch-sources.sh and patched via
# scripts/apply-patches.sh.
#
# Usage: versions/3.41.6/build.sh <variant>
# or:    scripts/build-engine.sh 3.41.6 <variant>
#
# Variants:
#   tvos_debug_sim_unopt_arm64  — sim dev
#   tvos_debug_unopt            — device debug (tvOS blocks JIT RX — academic)
#   tvos_release                — device / TestFlight AOT (needs host_release too)
#   host_release                — macOS host tools (frontend_server, gen_snapshot)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/_common.sh"
ensure_depot_tools_on_path

VERSION=3.41.6
VARIANT="${1-}"
if [[ -z "$VARIANT" ]]; then
  echo "error: variant arg required" >&2
  exit 2
fi

# gclient syncs Flutter's monorepo root into sources/<v>/. Engine source tree
# is at engine/src (gn's repo root), with flutter/ nested inside.
MONO_ROOT="$(sources_dir "$VERSION")"
ENGINE_SRC="${MONO_ROOT}/engine/src"
if [[ ! -d "$ENGINE_SRC/flutter" ]]; then
  echo "error: engine source missing at $ENGINE_SRC/flutter — run fetch-sources.sh first" >&2
  exit 1
fi

OUT_DIR="${OUT_ROOT}/${VERSION}/${VARIANT}"
mkdir -p "$(dirname "$OUT_DIR")"

gn_args_for_variant() {
  case "$1" in
    tvos_debug_sim_unopt_arm64)
      echo "--tvos --tvos-simulator --simulator-cpu=arm64 --unoptimized --no-lto --runtime-mode=debug"
      ;;
    tvos_debug_unopt)
      echo "--tvos --unoptimized --no-lto --runtime-mode=debug"
      ;;
    tvos_release)
      echo "--tvos --no-lto --runtime-mode=release"
      ;;
    host_release)
      echo "--no-lto --runtime-mode=release"
      ;;
    *)
      echo ""; return 1 ;;
  esac
}

gn_flags="$(gn_args_for_variant "$VARIANT")" || { echo "error: unknown variant $VARIANT" >&2; exit 2; }

cd "$ENGINE_SRC"

echo "[gn] $ENGINE_SRC → $gn_flags"
# shellcheck disable=SC2086
./flutter/tools/gn $gn_flags

# Figure out which out/* dir gn just populated.
gn_out="$(ls -td out/*/ 2>/dev/null | head -1)"
gn_out="${gn_out%/}"
if [[ -z "$gn_out" || ! -f "$gn_out/args.gn" ]]; then
  echo "error: couldn't locate fresh gn output dir under $ENGINE_SRC/out/" >&2
  exit 1
fi
echo "[gn] output dir: $gn_out"

# Our patched Dart has a different SDK hash than the prebuilt dart-sdk
# snapshot's expectation. Without this flag the VM refuses to load kernels
# compiled against our patched SDK.
if ! grep -q '^verify_sdk_hash = false' "$gn_out/args.gn"; then
  echo 'verify_sdk_hash = false' >> "$gn_out/args.gn"
  ./flutter/third_party/gn/gn gen "$gn_out"
fi

echo "[ninja] -C $gn_out flutter"
ninja -C "$gn_out" flutter

# Promote to the canonical out/<version>/<variant>/ so package.sh knows where
# to look regardless of how the gn output dir was named.
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
rsync -a --delete "$gn_out/" "$OUT_DIR/"

echo
echo "Built ${VARIANT} → $OUT_DIR"
