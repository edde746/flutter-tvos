#!/usr/bin/env bash
# Common helpers sourced by the other scripts. Not executed directly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES_ROOT="${REPO_ROOT}/sources"
OUT_ROOT="${REPO_ROOT}/out"

require_arg() {
  if [[ -z "${1-}" ]]; then
    echo "error: version arg required (e.g. 3.41.6)" >&2
    exit 2
  fi
}

load_sdk_lock() {
  local version="$1"
  local lock="${REPO_ROOT}/versions/${version}/sdk.lock"
  if [[ ! -f "$lock" ]]; then
    echo "error: no sdk.lock at $lock" >&2
    exit 2
  fi
  # shellcheck disable=SC1090
  source "$lock"
}

# The top-level sources dir for a given version. With gclient name="." the
# Flutter monorepo syncs directly into here.
sources_dir() {
  local version="$1"
  # 2nd arg is legacy / ignored — kept for caller compatibility.
  echo "${SOURCES_ROOT}/${version}"
}

# Path to the engine source tree (git repo) within a synced version.
engine_src_dir() {
  local version="$1"
  echo "$(sources_dir "$version")/engine/src/flutter"
}

# Path to the dart SDK checkout (git repo).
dart_src_dir() {
  local version="$1"
  echo "$(engine_src_dir "$version")/third_party/dart"
}

# Path to the skia checkout (git repo).
skia_src_dir() {
  local version="$1"
  echo "$(engine_src_dir "$version")/third_party/skia"
}

patches_dir() {
  local version="$1"
  local component="$2"  # engine | dart | skia
  echo "${REPO_ROOT}/versions/${version}/patches/${component}"
}

ensure_depot_tools_on_path() {
  if command -v gclient >/dev/null 2>&1; then
    return
  fi
  local dt="${REPO_ROOT}/depot_tools"
  if [[ -d "$dt" ]]; then
    export PATH="$dt:$PATH"
  fi
}
