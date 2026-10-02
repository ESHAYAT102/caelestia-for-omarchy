#!/usr/bin/env bash
#
# install.sh — Caelestia's shell, layered on top of Omarchy 4.
#
#   ./install.sh --dry-run     show every action, change nothing
#   ./install.sh               do it, prompting before each config overwrite
#   ./install.sh --yes         do it, no prompts (still shows every diff)
#   ./install.sh --ref <rev>   build a different Caelestia revision (default: pinned)
#   ./install.sh --skip-build  reuse an existing build prefix, install the rest
#
# Read README.md first — this script is the executable form of its "What this
# installs, and where" table, nothing more. `./uninstall.sh` is the inverse and
# `./healthcheck.sh` tells you whether the result is healthy.
#
# What you get: Caelestia is the bar, launcher, dashboard and OSD; Omarchy
# underneath keeps notifications, lock, polkit, wallpaper, the menu, the
# clipboard, theming and the app-crash popup. Two Quickshell processes, layered.
# Nothing under /usr/share/omarchy or /usr/lib/omarchy is touched, and no
# Omarchy package is replaced, removed or upgraded.
#
# Safe to run twice: every step checks whether it still has anything to do, and
# nothing is overwritten without a .bak.<epoch> copy beside it.
#
# NOT `set -e`: a cosmetic step that fails should say so and let the rest run.
# The exception is anything later steps depend on — the package install and the
# two builds — which call `die` instead, because enabling units against a
# half-built prefix produces a broken desktop rather than a partial one.

set -uo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- what this install owns --------------------------------------------------
# Same names and values as uninstall.sh. If a path changes, it changes in both.
readonly CAELESTIA_PREFIX="$HOME/.local/share/caelestia-shell"
readonly CAELESTIA_QSDIR="$CAELESTIA_PREFIX/qs"
readonly NULLBAR_ID="thepiratefox.nullbar"
readonly NULLBAR_DIR="$HOME/.config/omarchy/plugins/$NULLBAR_ID"
readonly BRIDGE_DIR="$HOME/.config/omarchy/bridges/caelestia"
readonly UNIT_DIR="$HOME/.config/systemd/user"
readonly UNITS=(caelestia-shell.service caelestia-notif-guard.service)
readonly THEME_HOOK="$HOME/.config/omarchy/hooks/theme-set.d/50-caelestia-scheme"
readonly CAELESTIA_CONFIG="$HOME/.config/caelestia"
readonly OMARCHY_SHELL_JSON="$HOME/.config/omarchy/shell.json"
readonly BINDINGS="$HOME/.config/hypr/bindings.lua"

# --- upstream, pinned to what this integration was actually verified against --
# state.md §1: Caelestia v2.4.0-8-gbe3d6522, M3Shapes 32ad9ce. Newer revisions
# very likely work; these are the ones the theme bridge's token map, the null
# bar's three properties and the notification race were all tested against.
readonly CAELESTIA_REPO="https://github.com/caelestia-dots/shell.git"
readonly CAELESTIA_CLI_REPO="https://github.com/caelestia-dots/cli.git"
readonly M3SHAPES_REPO="https://github.com/soramanew/m3shapes.git"
CAELESTIA_REF="be3d6522a5f070d8396338ec60e2958b81f07e45"
readonly M3SHAPES_REF="32ad9ce328bb77ed349b40a3be10ee9ea610b8ab"

# --- packages ----------------------------------------------------------------
# Build tooling plus the libraries Caelestia's C++ plugin links. `--needed`
# throughout, so anything Omarchy already ships is a no-op.
readonly PKGS_BUILD=(cmake ninja meson autoconf-archive)
readonly PKGS_LIB=(aubio libqalculate ttf-material-symbols-variable ttf-cascadia-code-nerd)
# Present on a stock Omarchy 4 box, listed so a leaner install still builds.
# qt6-shadertools is a hard requirement of both CMake projects.
readonly PKGS_ASSUMED=(qt6-shadertools qt6-imageformats ddcutil brightnessctl lm_sensors)
# Built with makepkg as an unprivileged user and installed with `pacman -U`,
# deliberately NOT through an AUR helper: the package contents get listed before
# anything is installed and no helper runs as root implicitly.
#   lib-cava provides the cava pkg-config module Caelestia requires. The newer
#   libcava package only provides libcava.pc, so it cannot satisfy this build.
readonly PKGS_AUR=(lib-cava ttf-rubik-vf)

# --- packages that must NOT be present ---------------------------------------
# README.md, "Updating Caelestia": quickshell-git provides+conflicts quickshell,
# which Omarchy depends on — installing it removes the desktop. caelestia-cli's
# apply_colours() overwrites gtk.css, dconf, qt6ct, hypr/scheme, btop, fuzzel and
# more, all of which are Omarchy's territory.
readonly PKGS_FORBIDDEN=(quickshell-git caelestia-cli caelestia-shell caelestia-shell-git)

DRY=0; ASSUME_YES=0; SKIP_BUILD=0
while (($#)); do
  case "$1" in
    --dry-run|-n) DRY=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --ref)        CAELESTIA_REF="${2:?--ref needs a revision}"; shift ;;
    -h|--help)    sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
readonly CAELESTIA_REF

# --- session environment -----------------------------------------------------
# The curl|sh entrypoint runs under `sh` without the interactive shell's
# environment: OMARCHY_PATH (exported from bashrc), WAYLAND_DISPLAY and
# HYPRLAND_INSTANCE_SIGNATURE are all missing over ssh, on a TTY or in a
# pipe. Recover usable defaults so omarchy-shell IPC, hyprctl and busctl
# work anywhere in the install.
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

failures=0
say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
skip() { printf '   · %s\n' "$*"; }
did()  { printf '   \033[32m✓\033[0m %s\n' "$*"; }
err()  { printf '   \033[31m✗\033[0m %s\n' "$*"; failures=$((failures+1)); }
die()  { printf '   \033[31m✗ FATAL\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if ((DRY)); then printf '   [dry-run] %s\n' "$*"; else "$@"; fi; }
# Quiet variant. A plain `run cmd >/dev/null` would swallow run's own [dry-run]
# line too, so a dry run would print a green tick for a command it never ran.
runq() { if ((DRY)); then printf '   [dry-run] %s\n' "$*"; else "$@" >/dev/null 2>&1; fi; }

confirm() { # confirm <prompt> — yes in --yes mode, always yes in --dry-run
  ((DRY || ASSUME_YES)) && return 0
  local reply; read -r -p "   $1? [y/N] " reply </dev/tty
  [[ $reply == [yY]* ]]
}

# Copy a payload file into place, backing up anything different that is already
# there. Never overwrites without a backup, never deletes.
install_file() { # install_file <src> <dst> [mode]
  local src="$1" dst="$2" mode="${3:-644}"
  [[ -e $src ]] || { err "payload missing: $src"; return 1; }
  if [[ -e $dst ]] && cmp -s "$src" "$dst"; then skip "already identical: $dst"; return 0; fi
  run mkdir -p "$(dirname "$dst")"
  if [[ -e $dst ]]; then
    confirm "overwrite $dst (a .bak copy is kept)" || { err "declined: $dst"; return 1; }
    run cp -a "$dst" "$dst.bak.$(date +%s)"
  fi
  run install -Dm"$mode" "$src" "$dst" && did "installed $dst"
}

((DRY)) && say $'\033[33mDRY RUN — nothing will be changed.\033[0m'
say "payload source: $ROOT"
say "caelestia ref:  $CAELESTIA_REF"

# -----------------------------------------------------------------------------
step "1. Preflight"
[[ $EUID -ne 0 ]] || die "do not run this as root — it installs into \$HOME and calls sudo itself"
command -v pacman  >/dev/null || die "not an Arch system"
command -v omarchy >/dev/null || die "Omarchy is not installed"

omarchy_ver="$(pacman -Q omarchy 2>/dev/null | awk '{print $2}')"
[[ -n $omarchy_ver ]] || die "omarchy is not a pacman package here — this expects a stock Omarchy 4 install"
case "$omarchy_ver" in
  4.*) did "omarchy $omarchy_ver" ;;
  *)   die "omarchy $omarchy_ver — this integration targets Omarchy 4.x only" ;;
esac
[[ $omarchy_ver == 4.0.2-1 ]] || skip "verified against 4.0.2-1; you are on $omarchy_ver — re-check README.md §17 if anything misbehaves"

command -v quickshell >/dev/null || die "quickshell missing — Omarchy's own shell needs it, something is wrong"
did "quickshell $(pacman -Q quickshell 2>/dev/null | awk '{print $2}') (Caelestia builds against this, no git version)"
for t in git jq; do command -v "$t" >/dev/null || die "missing required tool: $t"; done

for p in "${PKGS_FORBIDDEN[@]}"; do
  pacman -Qq "$p" >/dev/null 2>&1 && die "$p is installed. Remove it first — see README.md. quickshell-git in particular conflicts with the quickshell package Omarchy depends on."
done
did "none of the forbidden packages are installed"

for f in bridges/caelestia/caelestia-start bridges/caelestia/caelestia-lock \
         bridges/caelestia/caelestia-notif-guard bridges/caelestia/omarchy-to-caelestia-scheme \
         hooks/theme-set.d/50-caelestia-scheme systemd/user/caelestia-shell.service \
         systemd/user/caelestia-notif-guard.service thepiratefox.nullbar/manifest.json \
         thepiratefox.nullbar/Bar.qml config/caelestia/shell.json; do
  [[ -e $ROOT/$f ]] || die "payload file missing from the repo: $f"
done
did "payload complete"

# -----------------------------------------------------------------------------
step "2. Snapshot, so there is a way back"
# `omarchy snapshot create` prints "No Snapper configs found" without a tty —
# a false negative, it maps a failed `sudo snapper --csvout list-configs` to
# "unconfigured". Non-fatal either way: rollback.sh is the finer-grained undo.
if command -v snapper >/dev/null 2>&1; then
  if runq omarchy snapshot create; then
    did "snapper snapshot created"
  else
    err "could not create a snapshot automatically"
    say "     try by hand:  pkexec snapper -c root create -c number -d 'pre-caelestia $omarchy_ver'"
    say "     then pin it — every pacman -S rotates one out at NUMBER_LIMIT=5"
  fi
else
  skip "snapper absent — no system snapshot; rollback.sh is still your undo"
fi

# -----------------------------------------------------------------------------
step "3. Packages"
pkgs=("${PKGS_BUILD[@]}" "${PKGS_LIB[@]}" "${PKGS_ASSUMED[@]}")
missing=()
for p in "${pkgs[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
if ((${#missing[@]})); then
  say "   to install: ${missing[*]}"
  run sudo pacman -S --needed --noconfirm "${missing[@]}" || die "package install failed"
  did "installed ${#missing[@]} package(s)"
else
  skip "all repo packages already present"
fi

for p in "${PKGS_AUR[@]}"; do
  if pacman -Qq "$p" >/dev/null 2>&1; then skip "AUR package already present: $p"; continue; fi
  if ((DRY)); then printf '   [dry-run] build %s from the AUR with makepkg, install with pacman -U\n' "$p"; continue; fi
  tmp="$(mktemp -d)"
  say "   building $p in $tmp"
  if ! git clone -q "https://aur.archlinux.org/$p.git" "$tmp/$p"; then
    err "could not clone AUR package $p"; continue
  fi
  # -s pulls makedepends (this is the only implicit sudo), -f rebuilds cleanly.
  if ! ( cd "$tmp/$p" && makepkg -sf --noconfirm >/dev/null ); then
    err "makepkg failed for $p — build log in $tmp/$p"; continue
  fi
  built="$(find "$tmp/$p" -maxdepth 1 -name "$p-[0-9]*.pkg.tar.*" ! -name '*.sig' ! -name '*-debug-*' | head -1)"
  [[ -n $built ]] || { err "no package produced for $p"; continue; }
  say "   $p contents:"
  bsdtar -tf "$built" 2>/dev/null | grep -v '^\.' | sed 's/^/     /' | head -20
  if confirm "install $(basename "$built")"; then
    sudo pacman -U --needed --noconfirm "$built" && did "installed $p" || err "pacman -U failed for $p"
  else
    err "declined: $p (Caelestia will not build without it)"
  fi
done

# -----------------------------------------------------------------------------
step "4. Build Caelestia into its own prefix"
# Built here, never into /usr, so it cannot disturb Omarchy's quickshell package.
# Absolute INSTALL_* values make every install(DESTINATION) absolute, which is
# what makes CMAKE_INSTALL_PREFIX=/ inert.
checkout() { # checkout <repo> <dir> <ref>
  local repo="$1" dir="$2" ref="$3"
  if [[ -d $dir/.git ]]; then
    runq git -C "$dir" fetch --all --tags || err "fetch failed: $dir"
  else
    run mkdir -p "$(dirname "$dir")"
    run git clone -q "$repo" "$dir" || { err "clone failed: $repo"; return 1; }
  fi
  runq git -C "$dir" checkout --detach "$ref" || { err "no such revision in $dir: $ref"; return 1; }
  did "$(basename "$dir") at ${ref:0:8}"
}

if ((SKIP_BUILD)); then
  skip "--skip-build: leaving $CAELESTIA_PREFIX as it is"
  [[ -d $CAELESTIA_PREFIX/qml/Caelestia ]] || die "--skip-build, but there is no build to reuse"
else
  # M3Shapes first: Caelestia's dashboard imports it and the shell refuses to
  # load without it (LOG.md §2.4, first-run failure).
  checkout "$M3SHAPES_REPO" "$CAELESTIA_PREFIX/m3shapes-src" "$M3SHAPES_REF" || die "M3Shapes checkout failed"
  run cmake -S "$CAELESTIA_PREFIX/m3shapes-src" -B "$CAELESTIA_PREFIX/m3shapes-src/build" \
        -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
        -DINSTALL_QMLDIR="$CAELESTIA_PREFIX/qml" || die "M3Shapes configure failed"
  run cmake --build "$CAELESTIA_PREFIX/m3shapes-src/build" || die "M3Shapes build failed"
  run cmake --install "$CAELESTIA_PREFIX/m3shapes-src/build" || die "M3Shapes install failed"
  did "M3Shapes installed into $CAELESTIA_PREFIX/qml"

  checkout "$CAELESTIA_REPO" "$CAELESTIA_PREFIX/src" "$CAELESTIA_REF" || die "Caelestia checkout failed"
  run cmake -S "$CAELESTIA_PREFIX/src" -B "$CAELESTIA_PREFIX/src/build" \
        -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
        -DINSTALL_QSCONFDIR="$CAELESTIA_QSDIR" \
        -DINSTALL_QMLDIR="$CAELESTIA_PREFIX/qml" \
        -DINSTALL_LIBDIR="$CAELESTIA_PREFIX/lib" \
        -DDISTRIBUTOR="local source build (caelestia-shell-to-omarchy)" || die "Caelestia configure failed"
  run cmake --build "$CAELESTIA_PREFIX/src/build" || die "Caelestia build failed"
  run cmake --install "$CAELESTIA_PREFIX/src/build" || die "Caelestia install failed"
  did "Caelestia installed into $CAELESTIA_PREFIX"
fi

# -----------------------------------------------------------------------------
step "5. Bridges, hook, units and the null bar"
install_file "$ROOT/bridges/caelestia/caelestia-start"             "$BRIDGE_DIR/caelestia-start"             755
install_file "$ROOT/bridges/caelestia/caelestia-notif-guard"       "$BRIDGE_DIR/caelestia-notif-guard"       755
install_file "$ROOT/bridges/caelestia/caelestia-lock"              "$BRIDGE_DIR/caelestia-lock"              755
install_file "$ROOT/bridges/caelestia/omarchy-to-caelestia-scheme" "$BRIDGE_DIR/omarchy-to-caelestia-scheme" 755
install_file "$ROOT/hooks/theme-set.d/50-caelestia-scheme"         "$THEME_HOOK"                             755
install_file "$ROOT/systemd/user/caelestia-shell.service"          "$UNIT_DIR/caelestia-shell.service"
install_file "$ROOT/systemd/user/caelestia-notif-guard.service"    "$UNIT_DIR/caelestia-notif-guard.service"
install_file "$ROOT/thepiratefox.nullbar/manifest.json"            "$NULLBAR_DIR/manifest.json"
install_file "$ROOT/thepiratefox.nullbar/Bar.qml"                  "$NULLBAR_DIR/Bar.qml"

# -----------------------------------------------------------------------------
step "6. Caelestia's own config"
# The idle action is an absolute path, so $HOME is substituted here rather than
# shipped. Battery follows the hardware: this was written on a desktop with the
# battery status icon off, which would hide it on a laptop.
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
  battery=true;  say "   battery detected — enabling the battery status icon"
else
  battery=false; say "   no battery — leaving the battery status icon off"
fi
tmpcfg="$(mktemp)"
sed "s#__HOME__#$HOME#g" "$ROOT/config/caelestia/shell.json" \
  | jq --argjson b "$battery" '(.bar.statusIcons[] | select(.id=="battery")).enabled = $b' > "$tmpcfg" \
  || die "could not render config/caelestia/shell.json"
# Compare as JSON, not as bytes. jq reformats, so a byte compare would rewrite
# a semantically identical file on every re-run and leave a .bak behind.
if [[ -e $CAELESTIA_CONFIG/shell.json ]] \
   && diff -q <(jq -S . "$tmpcfg" 2>/dev/null) <(jq -S . "$CAELESTIA_CONFIG/shell.json" 2>/dev/null) >/dev/null 2>&1; then
  skip "already equivalent: $CAELESTIA_CONFIG/shell.json"
else
  install_file "$tmpcfg" "$CAELESTIA_CONFIG/shell.json"
fi
rm -f "$tmpcfg"

# -----------------------------------------------------------------------------
step "7. Omarchy's shell.json — bar, plugins and idle, merged"
# Mirrors what caelestia-mode on writes, so setup.sh (step 12) does not undo
# this merge and the verify step agrees with it:
#   bar.id           omarchy.bar, hidden at runtime via the bar-off toggle
#                    (caelestia-mode on runs `omarchy-toggle bar-off on`)
#   bar.position     left, Caelestia's edge
#   disabledPlugins  omarchy.osd (or both OSDs fire), omarchy.notifications
#                    and esh.notification-center (Caelestia owns the bus)
#   idle.screensaver 300, and idle.lock parked at 24 h — Caelestia owns the
#                    timed lock now, at 310 s. Read README.md "Idle and lock"
#                    before changing either number; 310 is not a typo.
if [[ ! -e $OMARCHY_SHELL_JSON ]]; then
  run mkdir -p "$(dirname "$OMARCHY_SHELL_JSON")"
  run cp /usr/share/omarchy/config/omarchy/shell.json "$OMARCHY_SHELL_JSON" \
    && did "seeded shell.json from the Omarchy default"
fi
if ((DRY)); then
  printf '   [dry-run] jq-merge bar.id / disabledPlugins / idle into %s\n' "$OMARCHY_SHELL_JSON"
else
  merged="$(jq '
      .bar.id = "omarchy.bar"
    | .bar.position = "left"
    | .idle.screensaver = 300
    | .idle.lock = 86400
    | .disabledPlugins = (((.disabledPlugins // []) + ["omarchy.osd", "omarchy.notifications", "esh.notification-center"]) | unique)
  ' "$OMARCHY_SHELL_JSON")" || err "jq failed on $OMARCHY_SHELL_JSON"
  if [[ -n ${merged:-} ]]; then
    if [[ $merged == "$(cat "$OMARCHY_SHELL_JSON")" ]]; then
      skip "shell.json already carries the Caelestia keys"
    else
      diff -u --label current --label merged "$OMARCHY_SHELL_JSON" <(printf '%s\n' "$merged") | sed 's/^/   /' | head -40
      if confirm "apply this to shell.json (a .bak copy is kept)"; then
        cp -a "$OMARCHY_SHELL_JSON" "$OMARCHY_SHELL_JSON.bak.$(date +%s)"
        printf '%s\n' "$merged" > "$OMARCHY_SHELL_JSON" && did "merged into shell.json"
      else
        err "declined: shell.json unchanged — the bar will still be Omarchy's"
      fi
    fi
  fi
fi

# -----------------------------------------------------------------------------
step "8. Keybinds"
# Appended as a marked block so a re-run is a no-op rather than a duplicate.
# `o` and `hl` are globals Omarchy's Lua config loader injects; bindings.lua
# uses them the same way.
readonly MARK_BEGIN="-- >>> caelestia-on-omarchy >>>"
if true; then
  skip "complete keybinding profiles are installed by setup.sh"
elif [[ ! -e $BINDINGS ]]; then
  err "no $BINDINGS — Omarchy should ship one; skipping keybinds"
elif grep -qF -e "$MARK_BEGIN" "$BINDINGS"; then   # -e: the marker starts with --
  skip "keybind block already present in bindings.lua"
elif ((DRY)); then
  printf '   [dry-run] append the Caelestia keybind block to %s\n' "$BINDINGS"
else
  cp -a "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
  cat >>"$BINDINGS" <<'LUA'

-- >>> caelestia-on-omarchy >>>
-- Caelestia's panels. SUPER + D/A/U are Hyprland DBus global shortcuts (appid
-- "caelestia"); `hyprctl globalshortcuts` lists all 21, the rest stay unbound.
--
-- The launcher is the one exception: it goes through Caelestia's `drawers` IPC,
-- not the caelestia:launcher global shortcut. That one only toggles in its
-- onReleased handler -- upstream binds it to a bare modifier tap, where waiting
-- for the key to come up is the point. On a real chord like ALT + SPACE the
-- launcher cannot appear until both keys are lifted, and it misses whenever the
-- release is not delivered as the shortcut's own. The IPC call toggles on the
-- call itself, so it fires on key-down every time. Costs ~80 ms of `qs` startup
-- against a 500 ms open animation.
hl.unbind("ALT + SPACE")
o.bind("ALT + SPACE", "App launcher",
  "qs -p $HOME/.local/share/caelestia-shell/qs ipc call drawers toggle launcher")
o.bind("SUPER + D", "Dashboard", hl.dsp.global("caelestia:dashboard"))
o.bind("SUPER + A", "Sidebar", hl.dsp.global("caelestia:sidebar"))
o.bind("SUPER + U", "Utilities", hl.dsp.global("caelestia:utilities"))

-- Lock. Caelestia owns the lock screen now, on the key and on the idle timer
-- alike -- both run the same script, so they cannot drift apart. Omarchy's own
-- timed lock is parked at 24 h in ~/.config/omarchy/shell.json (its idle
-- service has no "disabled" value) and its screensaver still runs at 300 s.
-- omarchy-system-lock stays as caelestia-lock's fallback.
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Lock system",
  "$HOME/.config/omarchy/bridges/caelestia/caelestia-lock")
-- <<< caelestia-on-omarchy <<<
LUA
  did "appended the keybind block to bindings.lua"
fi

# -----------------------------------------------------------------------------
step "9. Restart Omarchy's shell so the merged shell.json takes effect"
# Before Caelestia starts. Caelestia is meant to own org.freedesktop.Notifications
# here (omarchy.notifications is disabled in step 7), and Quickshell grants the
# name without REPLACE_EXISTING to whoever asks first — so the shell must be
# back up before the unit starts below, and step 11 re-checks the owner.
run omarchy restart shell && did "omarchy restart shell"
if ((DRY)); then :; else
  for _ in {1..30}; do omarchy-shell shell ping >/dev/null 2>&1 && break; sleep 0.5; done
  omarchy-shell shell ping >/dev/null 2>&1 \
    && did "Omarchy's shell is answering IPC" \
    || err "Omarchy's shell did not come back — check: journalctl -t omarchy-shell -e"
fi

# -----------------------------------------------------------------------------
step "10. Wallpaper palette bridge"
if ((DRY)); then
  printf '   [dry-run] generate Caelestia palette from the active wallpaper\n'
else
  skip "installed by setup.sh after the private CLI is ready"
fi

# -----------------------------------------------------------------------------
step "11. Autostart"
run systemctl --user daemon-reload
for u in "${UNITS[@]}"; do
  if [[ $u == caelestia-notif-guard.service ]]; then
    skip "notification guard disabled; Caelestia owns notifications in this setup"
    continue
  fi
  runq systemctl --user enable --now "$u" && did "enabled and started $u" || err "could not start $u"
done
# Caelestia must own the notification bus (same guard as caelestia-mode on):
# if Omarchy claimed it first, restart the unit so Caelestia re-asks.
if ((DRY)); then :; else
  sleep 0.5
  if [[ $(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^CommandLine=//p') != *"$CAELESTIA_QSDIR"* ]]; then
    runq systemctl --user restart caelestia-shell.service \
      && did "restarted caelestia-shell.service so Caelestia owns notifications" \
      || err "could not restart caelestia-shell.service"
  else
    did "Caelestia owns notifications"
  fi
fi

# -----------------------------------------------------------------------------
step "12. Install custom shell UI and mode switching"
if ((DRY)); then
  printf '   [dry-run] %s/setup.sh\n' "$ROOT"
else
  "$ROOT/setup.sh" || die "customized integration setup failed"
  did "installed shell customizations and caelestia-on/off commands"
fi

# -----------------------------------------------------------------------------
step "13. Verify"
if ((DRY)); then
  skip "dry run — nothing to verify"
else
  # Poll rather than sleep a flat few seconds: Caelestia maps its layer surfaces
  # a moment after the unit reports active, and a fixed wait turns a slow boot
  # into a false failure.
  for _ in {1..30}; do
    hyprctl layers 2>/dev/null | grep -q 'namespace: caelestia-drawers' && break
    sleep 0.5
  done
  ck() { # ck <label> <expect> <actual>
    if [[ $3 == "$2" ]]; then did "$1: $3"; else err "$1: expected '$2', got '$3'"; fi
  }
  ck_at_least() { # ck_at_least <label> <min> <actual>
    if [[ $3 -ge $2 ]]; then did "$1: $3"; else err "$1: expected at least $2, got '$3'"; fi
  }
  # Same expressions driftcheck.sh uses, so the two agree on what "installed"
  # means. `pgrep -cx quickshell` and not -cf: -f would also match this script's
  # own command line.
  ck "quickshell processes" "2" "$(pgrep -cx quickshell)"
  ck "notification bus owner" "$CAELESTIA_QSDIR" \
     "$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/.*-p //p')"
  ck "omarchy-shell ping" "ok" "$(omarchy-shell shell ping 2>&1)"
  ck "bar.id" "omarchy.bar" "$(jq -r '.bar.id // ""' "$OMARCHY_SHELL_JSON" 2>/dev/null)"
  ck "bar-off toggle" "on" "$([[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo on || echo off)"
  ck_at_least "caelestia drawers" "1" "$(hyprctl layers 2>/dev/null | grep -c 'namespace: caelestia-drawers')"
  ck "caelestia-shell.service" "active" "$(systemctl --user is-active caelestia-shell.service 2>&1)"
fi

# -----------------------------------------------------------------------------
step "Result"
if ((failures)); then
  say $'\033[31m'"$failures step(s) did not complete."$'\033[0m'
  say "Read the ✗ lines above. ./uninstall.sh --dry-run shows what an undo would do."
  exit 1
fi
if ((DRY)); then
  say $'\033[33mDry run complete — nothing was changed.\033[0m'
else
  say $'\033[32mInstalled.\033[0m'
  say ""
  say "  ALT + SPACE          launcher        SUPER + D  dashboard"
  say "  SUPER + A  sidebar   SUPER + U  utilities"
  say "  SUPER + CTRL + L     lock (Caelestia's, via caelestia-lock)"
  say ""
  say "  $ROOT/healthcheck.sh        # is it actually healthy?"
  say "  $ROOT/uninstall.sh --dry-run # the way back"
  say ""
  say "Read README.md before changing the idle numbers — 310 is not a typo."
fi
