#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$HOME/.local/share/caelestia-shell"

[[ -d $PREFIX/qs ]] || {
  printf 'Caelestia is not installed. Run ./install.sh first.\n' >&2
  exit 1
}

"$ROOT/setup.sh"
printf 'Updated Caelestia configuration and integration files without rebuilding.\n'
