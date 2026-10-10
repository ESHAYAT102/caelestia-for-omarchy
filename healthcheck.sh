#!/usr/bin/env bash

set -uo pipefail

: "${OMARCHY_PATH:=/usr/share/omarchy}"
export OMARCHY_PATH
# Same session-env recovery as install.sh: hyprctl needs these, and they are
# missing over ssh or on a TTY.
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  _wl=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | head -n1)
  [[ -n ${_wl:-} ]] && export WAYLAND_DISPLAY=${_wl##*/}
fi
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  _hs=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}"/hypr/ 2>/dev/null | head -n1)
  [[ -n ${_hs:-} ]] && export HYPRLAND_INSTANCE_SIGNATURE=$_hs
fi
unset _wl _hs

pass=0
fail=0
ck() {
  local mark
  if [[ $3 == "$2"* ]]; then
    mark=$'\033[32m✓\033[0m'
    pass=$((pass + 1))
  else
    mark=$'\033[31m✗\033[0m'
    fail=$((fail + 1))
  fi
  printf '%s %-28s expect %-22s actual %s\n' "$mark" "$1" "$2" "${3:-<empty>}"
}

mode="omarchy"
pgrep -f "quickshell -n -p $HOME/.local/share/caelestia-shell/qs" >/dev/null && mode="caelestia"

echo "── mode ────────────────────────────────────────────────────────────────"
ck "mode command" "$mode" "$(caelestia-mode status 2>&1)"
ck "hypr config errors" "(none)" "$(hyprctl configerrors 2>/dev/null | head -1 | grep -q . && hyprctl configerrors | head -1 || echo '(none)')"
ck "omarchy shell IPC" "ok" "$(omarchy-shell shell ping 2>&1)"
ck "Confetti unit" "active" "$(systemctl --user is-active caelestia-confetti.service 2>&1)"
ck "Confetti enabled" "enabled" "$(systemctl --user is-enabled caelestia-confetti.service 2>&1)"
ck "Confetti layer" "1" "$(hyprctl layers 2>/dev/null | grep -c 'namespace: omarchy-confetti')"

if [[ $mode == caelestia ]]; then
  echo
  echo "── Caelestia mode ──────────────────────────────────────────────────────"
  ck "quickshell processes" "2" "$(pgrep -cx quickshell)"
  ck "Caelestia unit" "active" "$(systemctl --user is-active caelestia-shell.service 2>&1)"
  ck "Caelestia enabled" "enabled" "$(systemctl --user is-enabled caelestia-shell.service 2>&1)"
  ck "bar plugin" "thepiratefox.nullbar" "$(jq -r '.bar.id // ""' "$HOME/.config/omarchy/shell.json")"
  ck "bar-off toggle" "off" "$([[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo on || echo off)"
  ck "Omarchy OSD disabled" "yes" "$(jq -r 'if ((.disabledPlugins//[])|index("omarchy.osd")) then "yes" else "no" end' "$HOME/.config/omarchy/shell.json")"
  ck "Omarchy notifications disabled" "yes" "$(jq -r 'if ((.disabledPlugins//[])|index("omarchy.notifications")) then "yes" else "no" end' "$HOME/.config/omarchy/shell.json")"
  ck "notification bus owner" "$HOME/.local/share/caelestia-shell/qs" "$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/.*-p //p')"
  ck_at_least() { # ck_at_least <label> <min> <actual>
    local mark
    if [[ $3 -ge $2 ]]; then mark=$'\033[32m✓\033[0m'; pass=$((pass + 1));
    else mark=$'\033[31m✗\033[0m'; fail=$((fail + 1)); fi
    printf '%s %-28s expect at least %-14s actual %s\n' "$mark" "$1" "$2" "${3:-<empty>}"
  }
  ck_at_least "Caelestia drawer layer" "1" "$(hyprctl layers 2>/dev/null | grep -c 'namespace: caelestia-drawers')"
  # No background layer is correct when the user disabled Caelestia's background.
  if [[ $(jq -r '.background.enabled // false' "$HOME/.config/caelestia/shell.json" 2>/dev/null) == "true" ]]; then
    ck_at_least "Caelestia background" "1" "$(hyprctl layers 2>/dev/null | grep -c 'namespace: caelestia-background')"
  else
    ck "Caelestia background" "disabled" "disabled"
  fi
  ck "wallpaper scheme" "dynamic" "$(jq -r '.name // ""' "$HOME/.local/state/caelestia/scheme.json" 2>/dev/null)"
  ck "SUPER + SPACE" "Caelestia launcher" "$(omarchy menu keybindings --print | sed -n 's/^SUPER + SPACE *→ *//p')"
  ck "SUPER + ESCAPE" "Caelestia power menu" "$(omarchy menu keybindings --print | sed -n 's/^SUPER + ESCAPE *→ *//p')"
  ck "SUPER + V" "Caelestia clipboard" "$(omarchy menu keybindings --print | sed -n 's/^SUPER + V *→ *//p')"
  ck "SUPER + ALT + SPACE" "Confetti" "$(omarchy menu keybindings --print | sed -n 's/^SUPER ALT + SPACE *→ *//p')"
else
  echo
  echo "── Omarchy mode ────────────────────────────────────────────────────────"
  ck "quickshell processes" "1" "$(pgrep -cx quickshell)"
  ck "Caelestia unit" "inactive" "$(systemctl --user is-active caelestia-shell.service 2>&1)"
  ck "bar plugin" "omarchy.bar" "$(jq -r '.bar.id // "omarchy.bar"' "$HOME/.config/omarchy/shell.json")"
  ck "Omarchy bar layer" "1" "$(hyprctl layers 2>/dev/null | grep -c 'namespace: omarchy-bar')"
  ck "SUPER + SPACE" "Omarchy menu" "$(omarchy menu keybindings --print | sed -n 's/^SUPER + SPACE *→ *//p')"
  ck "SUPER + ESCAPE" "System menu" "$(omarchy menu keybindings --print | sed -n 's/^SUPER + ESCAPE *→ *//p')"
  ck "SUPER + V" "Clipboard manager" "$(omarchy menu keybindings --print | sed -n 's/^SUPER + V *→ *//p')"
fi

echo
if ((fail)); then
  printf '\033[31m%d of %d checks failed.\033[0m\n' "$fail" "$((pass + fail))"
  exit 1
fi
printf '\033[32mAll %d checks passed.\033[0m\n' "$pass"
