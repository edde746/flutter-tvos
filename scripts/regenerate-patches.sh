#!/usr/bin/env bash
# Capture the current state of ./sources/<version>/ back into
# versions/<version>/patches/ as a fresh git-format-patch series.
#
# Workflow:
#   1. scripts/fetch-sources.sh <v>
#   2. scripts/apply-patches.sh <v>
#   3. Edit freely inside ./sources/<v>/{…}. Commit your changes inside those
#      source git repos (one commit per logical change).
#   4. Run THIS script.
#   5. `git diff` in flutter-tvos to review the regenerated patches and commit.
#
# DO NOT hand-edit versions/*/patches/*.patch. They are generated.
#
# Usage: scripts/regenerate-patches.sh 3.41.6

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

VERSION="${1-}"
require_arg "$VERSION"
load_sdk_lock "$VERSION"

regen() {
  local label="$1" base_ref="$2" cwd="$3" out="$4"

  if [[ ! -d "$cwd/.git" ]]; then
    echo "[$label] no sources at $cwd — skipping"
    return
  fi

  (
    cd "$cwd"
    if ! git cat-file -e "$base_ref" 2>/dev/null; then
      echo "error [$label]: base ref '$base_ref' unknown in $cwd. Has sdk.lock drifted from DEPS?" >&2
      exit 1
    fi
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "error [$label]: $cwd has uncommitted changes. Commit them in the source repo first." >&2
      exit 1
    fi
  )

  echo "[$label] regenerating patches from $base_ref..HEAD in $cwd"
  rm -rf "$out"
  mkdir -p "$out"
  (cd "$cwd" && git format-patch --no-stat --no-signature "$base_ref..HEAD" -o "$out")

  if ! compgen -G "$out/*.patch" > /dev/null; then
    echo "[$label] no patches produced — source is identical to base"
    rmdir "$out" 2>/dev/null || true
  else
    echo "[$label] wrote $(ls "$out"/*.patch | wc -l | tr -d ' ') patches"
  fi
}

regen engine "${ENGINE_COMMIT:-$ENGINE_REF}" "$(sources_dir "$VERSION")"    "$(patches_dir "$VERSION" engine)"
regen dart   "$DART_COMMIT"                    "$(dart_src_dir "$VERSION")"  "$(patches_dir "$VERSION" dart)"
regen skia   "$SKIA_COMMIT"                    "$(skia_src_dir "$VERSION")"  "$(patches_dir "$VERSION" skia)"

echo
echo "Patches regenerated. Review: git -C ${REPO_ROOT} diff versions/${VERSION}/patches/"
