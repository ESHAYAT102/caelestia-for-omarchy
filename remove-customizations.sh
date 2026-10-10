#!/bin/bash

set -euo pipefail

STATE="$HOME/.local/state/caelestia-mode"

if command -v caelestia-off >/dev/null 2>&1; then
  caelestia-off || true
fi

if [[ -f $STATE/bindings.pre-caelestia.lua ]]; then
  cp -a "$STATE/bindings.pre-caelestia.lua" "$HOME/.config/hypr/bindings.lua"
fi

rm -f "$HOME/.local/bin/caelestia-mode" \
      "$HOME/.local/bin/caelestia-on" \
      "$HOME/.local/bin/caelestia-off" \
      "$HOME/.local/bin/caelestia-confetti" \
      "$HOME/.local/bin/caelestia-workspace-layout-toggle" \
      "$HOME/.local/bin/caelestia-clipboard-toggle"
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/50-caelestia-scheme"
rm -rf "$STATE"
hyprctl reload >/dev/null

printf 'Removed custom Caelestia integration files. The private build remains installed.\n'
