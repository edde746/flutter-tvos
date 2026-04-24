#!/usr/bin/env bash
# Apply the patch series onto the gclient-synced source trees.
#
# Engine patches land at <sources>/<v>/ (the Flutter monorepo root) because
# they were format-patch'd from a worktree tracking the monorepo root and
# reference paths like `a/engine/src/flutter/...`.
# Dart/skia patches land inside their respective third_party/ git repos.
#
# Usage: scripts/apply-patches.sh 3.41.6

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

VERSION="${1-}"
require_arg "$VERSION"
load_sdk_lock "$VERSION"

apply_at() {
  local label="$1" patches="$2" cwd="$3"
  if [[ ! -d "$cwd/.git" ]]; then
    echo "error [$label]: $cwd is not a git repo — has fetch-sources.sh been run?" >&2
    exit 1
  fi
  if [[ ! -d "$patches" ]]; then
    echo "[$label] no patches dir at $patches — skipping"
    return
  fi
  local files=("$patches"/*.patch)
  if [[ ! -e "${files[0]}" ]]; then
    echo "[$label] no .patch files in $patches — skipping"
    return
  fi

  local count
  count="$(ls "$patches"/*.patch | wc -l | tr -d ' ')"
  echo "[$label] applying $count patches to $cwd"
  (
    cd "$cwd"
    git am --abort 2>/dev/null || true
    git am --3way "$patches"/*.patch
  )
}

apply_at engine   "$(patches_dir "$VERSION" engine)"   "$(sources_dir "$VERSION")"
apply_at dart     "$(patches_dir "$VERSION" dart)"     "$(dart_src_dir "$VERSION")"
apply_at skia     "$(patches_dir "$VERSION" skia)"     "$(skia_src_dir "$VERSION")"
apply_at perfetto "$(patches_dir "$VERSION" perfetto)" "$(perfetto_src_dir "$VERSION")"

echo
echo "Patches applied. Ready to build: scripts/build-engine.sh ${VERSION} <variant>"
