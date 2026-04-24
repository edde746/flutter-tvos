#!/usr/bin/env bash
# Delegates to the version-specific build.sh, which knows the right gn args
# for that Flutter release. Output: ./out/<version>/<variant>/.
#
# Usage: scripts/build-engine.sh 3.41.6 tvos_release

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

VERSION="${1-}"
VARIANT="${2-}"
require_arg "$VERSION"
if [[ -z "$VARIANT" ]]; then
  echo "error: variant arg required (e.g. tvos_release, tvos_debug_sim_unopt_arm64, host_release)" >&2
  exit 2
fi

VBUILD="${REPO_ROOT}/versions/${VERSION}/build.sh"
if [[ ! -x "$VBUILD" ]]; then
  echo "error: no executable build.sh for version ${VERSION} at $VBUILD" >&2
  exit 2
fi

exec "$VBUILD" "$VARIANT"
