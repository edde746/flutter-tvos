#!/usr/bin/env bash
# Sync the Flutter monorepo + all its engine deps (dart, skia, prebuilts,
# toolchains) into ./sources/<version>/ using gclient.
#
# Requires depot_tools. If `gclient` isn't on PATH, a checkout is cloned into
# ./depot_tools/ and used transparently (gitignored).
#
# Usage: scripts/fetch-sources.sh 3.41.6

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

VERSION="${1-}"
require_arg "$VERSION"
load_sdk_lock "$VERSION"

ensure_depot_tools() {
  if command -v gclient >/dev/null 2>&1; then
    return
  fi
  local dt="${REPO_ROOT}/depot_tools"
  if [[ ! -d "$dt" ]]; then
    echo "[depot_tools] not on PATH — cloning into $dt"
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$dt"
  fi
  export PATH="$dt:$PATH"
}

ensure_depot_tools

SRC_ROOT="$(sources_dir "$VERSION" engine)"
# With `name: "."` in .gclient, the Flutter monorepo clones directly into
# SRC_ROOT. Everything (engine sources, dart/skia, prebuilts) lives under it.
mkdir -p "$SRC_ROOT"

GCLIENT_FILE="$SRC_ROOT/.gclient"
if [[ ! -f "$GCLIENT_FILE" ]]; then
  echo "[gclient] writing $GCLIENT_FILE"
  cat > "$GCLIENT_FILE" <<EOF
solutions = [
  {
    "managed": False,
    "name": ".",
    "url": "${ENGINE_REPO}",
    "deps_file": "DEPS",
    "custom_deps": {},
    "safesync_url": "",
  },
]
EOF
fi

# `--revision .@<sha>` pins the top-level solution; gclient resolves dart,
# skia, prebuilts from the DEPS at that commit.
echo "[gclient] syncing $SRC_ROOT at ${ENGINE_COMMIT:-$ENGINE_REF}"
(
  cd "$SRC_ROOT"
  gclient sync --revision ".@${ENGINE_COMMIT:-$ENGINE_REF}" --no-history --with_tags
)

echo
echo "Sources synced into $SRC_ROOT"
echo "Next: scripts/apply-patches.sh ${VERSION}"
