#!/bin/bash
#
# Full update: resync Caelestia from the pinned upstream commit, import all
# configs from the dotfiles repository, reinstall units/bridges/configs and
# reapply this integration (payload + setup),
# exactly like a fresh install. Run remotely with:
#   curl -fsSL https://raw.githubusercontent.com/ESHAYAT102/caelestia-for-omarchy/main/scripts/update.sh | sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$ROOT/install.sh" --yes "$@"
