#!/bin/bash

set -euo pipefail

# Session-env recovery (see install.sh): the installer can run without the
# interactive shell's environment, and caelestia-on needs IPC + hyprctl.
: "${OMARCHY_PATH:=/usr/share/omarchy}"
export OMARCHY_PATH
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  _wl=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | head -n1)
  [[ -n ${_wl:-} ]] && export WAYLAND_DISPLAY=${_wl##*/}
fi
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  _hs=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}"/hypr/ 2>/dev/null | head -n1)
  [[ -n ${_hs:-} ]] && export HYPRLAND_INSTANCE_SIGNATURE=$_hs
fi
unset _wl _hs

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$HOME/.local/share/caelestia-shell"
QSDIR="$PREFIX/qs"
STATE="$HOME/.local/state/caelestia-mode"

install_payload() {
  local src="$1" dst="$2" mode="${3:-644}"
  install -Dm"$mode" "$src" "$dst"
}

[[ -d $QSDIR ]] || {
  printf 'Caelestia is not built yet. Run ./install.sh first.\n' >&2
  exit 1
}

mkdir -p "$STATE" "$HOME/.local/bin" "$HOME/.config/caelestia" "$HOME/.config/omarchy/bridges/caelestia" "$HOME/.config/omarchy/plugins/thepiratefox.nullbar" "$HOME/.config/systemd/user"

for file in "$ROOT"/payload/bin/*; do
  install_payload "$file" "$HOME/.local/bin/$(basename "$file")" 755
done

for file in "$ROOT"/payload/bridges/caelestia/* "$ROOT"/bridges/caelestia/*; do
  install_payload "$file" "$HOME/.config/omarchy/bridges/caelestia/$(basename "$file")" 755
done

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT/payload/qs/"}"
  install_payload "$file" "$QSDIR/$rel"
done < <(find "$ROOT/payload/qs" -type f -print0)

# Retired payload overrides: files the payload used to ship under these paths
# but no longer does (renamed upstream or folded back). cmake --install and the
# loop above only add/overwrite, so without this a stale copy lingers in the
# prefix and can shadow the replacement (e.g. the old AppItem.qml vs items/).
for retired in \
  "modules/launcher/AppItem.qml" \
; do
  rm -f "$QSDIR/$retired"
done

merge_json_preserving_user() {
  local src="$1" dst="$2"
  if [[ -f $dst ]]; then
    local tmp
    tmp="$(mktemp)"
    sed "s#/home/esh#$HOME#g" "$src" > "$tmp.src"
    python3 - "$tmp.src" "$dst" <<'PY' > "$tmp.merged"
import json, sys
with open(sys.argv[1]) as f:
    base = json.load(f)
try:
    with open(sys.argv[2]) as f:
        user = json.load(f)
except (OSError, ValueError):
    user = {}
def merge(b, u):
    if isinstance(b, dict) and isinstance(u, dict):
        out = dict(b)
        for k, v in u.items():
            out[k] = merge(b[k], v) if k in b else v
        return out
    return u
json.dump(merge(base, user), open(sys.argv[1] + ".tmp", "w"), indent=4)
with open(sys.argv[1] + ".tmp") as f:
    sys.stdout.write(f.read())
PY
    mv "$tmp.merged" "$dst"
    rm -f "$tmp.src" "$tmp.src.tmp" "$tmp.merged" "$tmp"
  else
    sed "s#/home/esh#$HOME#g" "$src" > "$dst"
  fi
}

merge_json_preserving_user "$ROOT/payload/config/caelestia/shell.json" "$HOME/.config/caelestia/shell.json"
merge_json_preserving_user "$ROOT/payload/config/caelestia/shell-tokens.json" "$HOME/.config/caelestia/shell-tokens.json"

if [[ ! -d $PREFIX/cli-src/.git ]]; then
  git clone -q "${CAELESTIA_CLI_REPO:-https://github.com/caelestia-dots/cli.git}" "$PREFIX/cli-src"
fi
python -m venv "$PREFIX/cli-venv"
"$PREFIX/cli-venv/bin/pip" install --quiet "$PREFIX/cli-src"

install_payload "$ROOT/systemd/user/caelestia-shell.service" "$HOME/.config/systemd/user/caelestia-shell.service"
install_payload "$ROOT/thepiratefox.nullbar/manifest.json" "$HOME/.config/omarchy/plugins/thepiratefox.nullbar/manifest.json"
install_payload "$ROOT/thepiratefox.nullbar/Bar.qml" "$HOME/.config/omarchy/plugins/thepiratefox.nullbar/Bar.qml"

if [[ -f $HOME/.config/hypr/bindings.lua && ! -f $STATE/bindings.pre-caelestia.lua ]]; then
  cp -a "$HOME/.config/hypr/bindings.lua" "$STATE/bindings.pre-caelestia.lua"
fi
sed "s#/home/esh#$HOME#g" "$ROOT/payload/config/hypr/bindings.caelestia.lua" > "$STATE/bindings.caelestia.lua"
cp -a "$ROOT/payload/config/hypr/bindings.omarchy.lua" "$STATE/bindings.omarchy.lua"
cp -a "$STATE/bindings.caelestia.lua" "$HOME/.config/hypr/bindings.lua"

install_payload "$ROOT/hooks/theme-set.d/50-caelestia-scheme" "$HOME/.config/omarchy/hooks/theme-set.d/50-caelestia-scheme" 755

"$HOME/.config/omarchy/bridges/caelestia/omarchy-wallpaper-to-caelestia" || true
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null 2>&1 || true
fi
systemctl --user daemon-reload >/dev/null 2>&1 || true
if [[ -f $HOME/.config/systemd/user/caelestia-shell.service ]]; then
  "$HOME/.local/bin/caelestia-on" || true
fi
printf 'Installed the complete Caelestia integration.\n'
