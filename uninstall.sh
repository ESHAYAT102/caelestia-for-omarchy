#!/usr/bin/env bash
#
# uninstall.sh — remove the Caelestia-on-Omarchy layering.
#
#   ./uninstall.sh --dry-run   show every action, change nothing
#   ./uninstall.sh             do it, prompting before each change
#   ./uninstall.sh --yes       do it, no prompts
#   ./uninstall.sh --purge     also delete the build prefix, Caelestia's config
#                              and its state (asks first unless --yes)
#
# The inverse of install.sh, and it removes exactly what install.sh adds.
#
# By default it removes the *layering* and leaves Caelestia itself on disk, so
# reinstalling is `./install.sh --skip-build` and takes seconds. `--purge` is
# the one that actually deletes things.
#
# Deliberately NOT `set -e` — an uninstall that stops half way is worse than one
# that reports a failed step and keeps going. A half-removed layering is the
# state you cannot log in from.
#
# Where install.sh left a `.bak.<epoch>` copy it is reported, never auto-
# restored: by the time you uninstall, that backup is usually older than edits
# you have since made by hand, and silently reverting those is how an uninstall
# script eats someone's work.

set -uo pipefail

# Same session-env recovery as install.sh (ssh/TTY/pipe have no OMARCHY_PATH).
: "${OMARCHY_PATH:=/usr/share/omarchy}"
export OMARCHY_PATH

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- what this owns ----------------------------------------------------------
# Same names and values as install.sh. If a path changes, it changes in both.
readonly CAELESTIA_PREFIX="$HOME/.local/share/caelestia-shell"
readonly CAELESTIA_QSDIR="$CAELESTIA_PREFIX/qs"
readonly NULLBAR_ID="thepiratefox.nullbar"
readonly NULLBAR_DIR="$HOME/.config/omarchy/plugins/$NULLBAR_ID"
readonly BRIDGE_DIR="$HOME/.config/omarchy/bridges/caelestia"
readonly UNIT_DIR="$HOME/.config/systemd/user"
readonly UNITS=(caelestia-shell.service caelestia-confetti.service caelestia-notif-guard.service)
readonly THEME_HOOK="$HOME/.config/omarchy/hooks/theme-set.d/50-caelestia-scheme"
readonly CAELESTIA_CONFIG="$HOME/.config/caelestia"
readonly CAELESTIA_STATE="$HOME/.local/state/caelestia"
readonly OMARCHY_SHELL_JSON="$HOME/.config/omarchy/shell.json"
readonly BINDINGS="$HOME/.config/hypr/bindings.lua"
readonly MARK_BEGIN="-- >>> caelestia-on-omarchy >>>"
readonly MARK_END="-- <<< caelestia-on-omarchy <<<"

DRY=0; ASSUME_YES=0; PURGE=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --purge)      PURGE=1 ;;
    -h|--help)    sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

failures=0
say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
skip() { printf '   · %s\n' "$*"; }
did()  { printf '   \033[32m✓\033[0m %s\n' "$*"; }
err()  { printf '   \033[31m✗\033[0m %s\n' "$*"; failures=$((failures+1)); }
run()  { if ((DRY)); then printf '   [dry-run] %s\n' "$*"; else "$@"; fi; }
runq() { if ((DRY)); then printf '   [dry-run] %s\n' "$*"; else "$@" >/dev/null 2>&1; fi; }

confirm() { # confirm <prompt> — yes in --yes mode, always yes in --dry-run
  ((DRY || ASSUME_YES)) && return 0
  local reply; read -r -p "   $1? [y/N] " reply </dev/tty
  [[ $reply == [yY]* ]]
}

((DRY)) && say $'\033[33mDRY RUN — nothing will be changed.\033[0m'

# -----------------------------------------------------------------------------
# First, and it has to be first: the unit is Restart=on-failure, so killing the
# process while the unit is still enabled just brings it back in five seconds.
step "1. Remove custom UI, mode commands, and restore keybindings"
if [[ -x $ROOT/remove-customizations.sh ]]; then
  if ((DRY)); then
    printf '   [dry-run] %s/remove-customizations.sh\n' "$ROOT"
  else
    "$ROOT/remove-customizations.sh" || err "customization removal reported an error"
  fi
fi

# -----------------------------------------------------------------------------
step "2. Stop and remove the systemd user units"
for u in "${UNITS[@]}"; do
  if [[ -e $UNIT_DIR/$u ]]; then
    runq systemctl --user disable --now "$u" && did "disabled and stopped $u"
    run rm -f "$UNIT_DIR/$u" && did "removed $UNIT_DIR/$u"
  else
    skip "absent: $UNIT_DIR/$u"
  fi
done
runq systemctl --user daemon-reload && did "systemctl --user daemon-reload"

# -----------------------------------------------------------------------------
step "3. Stop Caelestia, if it is still running by hand"
if pgrep -f "quickshell -n -p $CAELESTIA_QSDIR" >/dev/null 2>&1; then
  run pkill -f "quickshell -n -p $CAELESTIA_QSDIR" && did "sent TERM to Caelestia"
  ((DRY)) || { sleep 1; pgrep -f "quickshell -n -p $CAELESTIA_QSDIR" >/dev/null 2>&1 \
      && { run pkill -9 -f "quickshell -n -p $CAELESTIA_QSDIR"; did "escalated to KILL"; }; }
else
  skip "not running"
fi

# -----------------------------------------------------------------------------
step "4. Remove the theme hook and the bridges"
if [[ -e $THEME_HOOK ]]; then
  run rm -f "$THEME_HOOK" && did "removed $THEME_HOOK"
else
  skip "absent: $THEME_HOOK"
fi
if [[ -d $BRIDGE_DIR ]]; then
  run rm -rf "$BRIDGE_DIR" && did "removed $BRIDGE_DIR"
else
  skip "absent: $BRIDGE_DIR"
fi

# -----------------------------------------------------------------------------
step "5. Remove the null bar and give Omarchy its own bar back"
# Order matters: unregister over IPC while the shell still knows the id, then
# delete the directory. Reversed, the shell holds a dangling enabled id.
if [[ -d $NULLBAR_DIR ]]; then
  if omarchy-shell shell ping >/dev/null 2>&1; then
    runq omarchy-shell shell setPluginEnabled "$NULLBAR_ID" false \
      && did "disabled $NULLBAR_ID over IPC"
  else
    skip "omarchy-shell not answering; the shell.json edit below covers it"
  fi
  run rm -rf "$NULLBAR_DIR" && did "removed $NULLBAR_DIR"
else
  skip "absent: $NULLBAR_DIR"
fi

# -----------------------------------------------------------------------------
step "6. Undo the shell.json keys"
# Omitting bar.id selects the built-in bar. idle goes back to Omarchy's shipped
# 150/300 rather than to whatever you had, because this script has no record of
# what you had — check the .bak files listed at the end if those numbers matter.
if [[ ! -e $OMARCHY_SHELL_JSON ]]; then
  skip "absent: $OMARCHY_SHELL_JSON"
elif ((DRY)); then
  printf '   [dry-run] jq: del bar.id, drop caelestia plugins, idle back to 150/300\n'
else
  reverted="$(jq '
      del(.bar.id)
    | .idle.screensaver = 150
    | .idle.lock = 300
    | .disabledPlugins = ((.disabledPlugins // []) - ["omarchy.osd", "omarchy.notifications", "esh.notification-center"])
    | if (.disabledPlugins | length) == 0 then del(.disabledPlugins) else . end
  ' "$OMARCHY_SHELL_JSON")" || err "jq failed on $OMARCHY_SHELL_JSON"
  if [[ -n ${reverted:-} ]]; then
    if [[ $reverted == "$(cat "$OMARCHY_SHELL_JSON")" ]]; then
      skip "shell.json already clean"
    else
      diff -u --label current --label reverted "$OMARCHY_SHELL_JSON" <(printf '%s\n' "$reverted") | sed 's/^/   /' | head -30
      if confirm "apply this to shell.json (a .bak copy is kept)"; then
        cp -a "$OMARCHY_SHELL_JSON" "$OMARCHY_SHELL_JSON.bak.$(date +%s)"
        printf '%s\n' "$reverted" > "$OMARCHY_SHELL_JSON" && did "reverted shell.json"
      else
        err "declined: shell.json left as-is — the bar will still be the null bar"
      fi
    fi
  fi
fi

# -----------------------------------------------------------------------------
step "7. Remove the keybind block from bindings.lua"
# Excised by marker, so anything you added around it survives untouched. This is
# why install.sh writes markers at all.
if [[ ! -e $BINDINGS ]]; then
  skip "absent: $BINDINGS"
elif ! grep -qF -e "$MARK_BEGIN" "$BINDINGS"; then
  skip "no marked block in bindings.lua (removed already, or added by hand)"
elif ((DRY)); then
  printf '   [dry-run] delete the marked block from %s\n' "$BINDINGS"
else
  cp -a "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
  if awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
        index($0, b) { skipping = 1 }
        !skipping    { print }
        index($0, e) { skipping = 0 }
      ' "$BINDINGS" > "$BINDINGS.tmp$$"; then
    mv "$BINDINGS.tmp$$" "$BINDINGS" && did "removed the marked block from bindings.lua"
  else
    rm -f "$BINDINGS.tmp$$"; err "could not rewrite bindings.lua"
  fi
fi

# -----------------------------------------------------------------------------
step "8. Restart Omarchy's shell"
# Caelestia mode hides Omarchy's bar via the bar-off toggle — clear it so the
# bar comes back with the shell.
if [[ -f $HOME/.local/state/omarchy/toggles/bar-off ]]; then
  run rm -f "$HOME/.local/state/omarchy/toggles/bar-off" && did "cleared the bar-off toggle"
fi
run omarchy restart shell && did "omarchy restart shell"
if ((DRY)); then :; else
  for _ in {1..30}; do omarchy-shell shell ping >/dev/null 2>&1 && break; sleep 0.5; done
  omarchy-shell shell ping >/dev/null 2>&1 \
    && did "Omarchy's shell is answering IPC" \
    || err "Omarchy's shell did not come back — check: journalctl -t omarchy-shell -e"
fi

# -----------------------------------------------------------------------------
step "9. Caelestia itself"
if ((PURGE)); then
  for p in "$CAELESTIA_PREFIX" "$CAELESTIA_CONFIG" "$CAELESTIA_STATE"; do
    if [[ -e $p ]]; then
      confirm "DELETE $p" && { run rm -rf "$p" && did "deleted $p"; } || skip "kept: $p"
    else
      skip "absent: $p"
    fi
  done
else
  say "   Left on disk. Re-installing is ./install.sh --skip-build (seconds, no rebuild)."
  for p in "$CAELESTIA_PREFIX" "$CAELESTIA_CONFIG" "$CAELESTIA_STATE"; do
    [[ -e $p ]] && say "   · $p"
  done
  say "   Pass --purge to delete them."
fi
say ""
say "   Packages installed for Caelestia are left alone — none replaced an"
say "   Omarchy package, so removing them is optional and never urgent."
say "   List them with: $ROOT/install.sh --help"

# -----------------------------------------------------------------------------
step "10. Backups install.sh and this script left behind"
found=0
for d in "$HOME/.config/omarchy" "$HOME/.config/hypr" "$HOME/.config/caelestia"; do
  [[ -d $d ]] || continue
  while IFS= read -r f; do say "   · $f"; found=1; done \
    < <(find "$d" -maxdepth 1 -name '*.bak.[0-9]*' 2>/dev/null | sort)
done
((found)) || skip "none found"
((found)) && say "   Not restored automatically — they are probably older than your own later edits."

# -----------------------------------------------------------------------------
step "Result"
if ((failures)); then
  say $'\033[31m'"$failures step(s) did not complete."$'\033[0m'" Re-run, or finish by hand."
  exit 1
fi
((DRY)) && say $'\033[33mDry run complete — nothing was changed.\033[0m' \
        || say $'\033[32mUninstalled. Omarchy is back to its own bar.\033[0m'
