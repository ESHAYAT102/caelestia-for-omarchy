# Caelestia shell, on Omarchy 4

Run [Caelestia's](https://github.com/caelestia-dots/shell) shell as your desktop
without giving up anything Omarchy does for you.

Two Quickshell instances, layered. **Caelestia is what you see** — bar,
launcher, dashboard, OSD, lock screen. **Omarchy is what works** —
notifications, polkit, wallpaper, the menu, the clipboard, theming, and the
app-crash popup that hands a core dump to a coding agent.

```
   what you SEE ──▶  quickshell -n -p ~/.local/share/caelestia-shell/qs
                     bar · dashboard · launcher · OSD · lock
                              ▲ scheme.json (watched, live)
   what WORKS   ──▶  quickshell -n -p /usr/share/omarchy/shell
                     notifications · polkit · idle · background · menu ·
                     clipboard · theming · crash popup
```

Nothing under `/usr/share/omarchy` or `/usr/lib/omarchy` is touched. No Omarchy
package is replaced, removed or upgraded. Everything this installs lives in your
config tree, and `./uninstall.sh` takes it all back out.

Verified on **Omarchy 4.0.1** and **4.0.2**, Quickshell 0.3.1, Caelestia v2.4.0.

---

## Why it is built this way

The obvious approach — install `caelestia-shell` from the AUR — breaks Omarchy,
for a reason that is easy to miss:

> `caelestia-shell` depends on **`quickshell-git`**, which `provides` and
> `conflicts` `quickshell`. That is the package Omarchy's own shell depends on.
> Installing it removes your desktop.

So Caelestia is built from source into a **private prefix**
(`~/.local/share/caelestia-shell/`), against the stock `quickshell` package
Omarchy already ships. It cannot disturb Omarchy's, because it never installs
anything into `/usr`.

Running two shells then costs you four collisions, and resolving them is what
this repo actually is:

| Collision | Resolved by |
|---|---|
| Both draw a bar, both reserve screen edge | a **null bar** plugin for Omarchy |
| Both claim `org.freedesktop.Notifications` | a **guard** that watches the bus |
| Both want to own your colour scheme | a **one-directional theme bridge** |
| Both run an idle timer, and they fight | one lock script, and one careful number |

Each is explained below. If you only read one, read the notification race — it
is the one that fails silently.

---

## Requirements

- **Omarchy 4.x** (`pacman -Q omarchy`), on Arch
- ~10 minutes and about 2 GB of disk for the build
- These must **not** be installed: `quickshell-git`, `caelestia-cli`,
  `caelestia-shell`, `caelestia-shell-git`. The installer refuses to start if
  they are.

## Install

```bash
git clone https://github.com/EugeneTuaev/caelestia-shell-to-omarchy.git
cd caelestia-shell-to-omarchy
./install.sh --dry-run     # read what it will do first
./install.sh
```

| Flag | Does |
|---|---|
| `--dry-run` | print every action, change nothing |
| `--yes` | no prompts (still prints every diff) |
| `--ref <rev>` | build a different Caelestia revision |
| `--skip-build` | reuse an existing build prefix |

It installs the packages, builds M3Shapes and then Caelestia into the private
prefix at pinned revisions, drops in the bridges, the theme hook, two systemd
user units and the null bar, merges four keys into
`~/.config/omarchy/shell.json`, appends a marked block to your
`bindings.lua`, restarts Omarchy's shell, runs the theme bridge, and verifies
the result.

**Safe to run twice.** Every step checks whether it still has anything to do,
and nothing is overwritten without a `.bak.<epoch>` copy beside it.

Then, any time:

```bash
./healthcheck.sh     # 33 read-only checks; exits non-zero if anything is off
./uninstall.sh       # the way back (--purge also deletes the build)
```

### Keybinds

| Key | Does |
|---|---|
| `ALT + SPACE` | Caelestia launcher |
| `SUPER + D` | Dashboard |
| `SUPER + A` | Sidebar |
| `SUPER + U` | Utilities |
| `SUPER + CTRL + L` | Lock (Caelestia's) |

Omarchy keeps screenshots (`PRINT`), recording (`ALT + PRINT`), the colour
picker, its menu and all volume/brightness keys. The other 18 Caelestia global
shortcuts are registered but unbound — `hyprctl globalshortcuts` lists them.

The installer writes these between markers, so `./uninstall.sh` can excise them
without touching anything you added around them.

---

## How it works

### 1. The null bar — Omarchy's bar has no off switch

A bar in Omarchy 4 is **replaced, never disabled**. There is no
`bar.enabled: false`. So "off" has to be spelled as a bar that renders nothing:

```qml
Item {
    id: root
    readonly property int  barSize    : 0
    readonly property bool barHidden  : false
    readonly property string fontFamily: Style.font.family
}
```

That is the entire plugin. **It deliberately has no `PanelWindow`** — no panel
window means no Wayland layer surface, which means no exclusive zone, which
means Hyprland reserves nothing for Omarchy and Caelestia's bar gets the whole
screen edge. Your windows tile to the real edge instead of around a phantom
reserved strip.

The three properties are the only reason the file is not empty. Omarchy assigns
this object to `shell.bar`, and exactly three things are read off it anywhere in
Omarchy's shell — all three in the notification service:

```qml
// plugins/notifications/Service.qml:51
liveBarSize: shell.bar && !shell.bar.barHidden ? Math.max(0, shell.bar.barSize) : defaultBarSize
// plugins/notifications/Service.qml:1052
fontFamily: shell.bar ? shell.bar.fontFamily : ""
```

Leave `barSize`/`barHidden` undefined and `liveBarSize` computes
`Math.max(0, undefined)` → `NaN`, and your crash toast lands at an invalid
position. Leave `fontFamily` undefined and it loses its themed font. So they are
stated, not inherited.

> **If a future Omarchy reads a fourth property off `shell.bar`, the null bar
> needs it too.** That is the single most likely thing to break on an Omarchy
> update, and `healthcheck.sh` will not catch it — a missing property makes a
> widget misrender, it does not throw.

### 2. The notification race — the failure that looks like success

This is the one worth understanding.

Quickshell requests `org.freedesktop.Notifications` **without
`REPLACE_EXISTING`**, so whoever asks first keeps it. Caelestia's Quickshell
sits in the bus queue from the moment it starts. Then:

```
omarchy restart shell          ← routine; `omarchy update` does it every time
  → Omarchy releases the name
  → Caelestia is next in the queue and acquires it
  → the new omarchy-shell loses, and waits
```

**Nothing looks broken.** Toasts still appear, rendered by Caelestia, correctly
themed. But Omarchy's crash toast — *"Process crashed / Click to diagnose with
AI"* — carries an **empty** freedesktop actions array. Its click command rides
in a private `omarchy-exec-argv` hint that only Omarchy's shell knows how to
read. Under Caelestia the toast appears and the click does nothing, silently.

There is no configuration for this: Quickshell's `NotificationServer` has no
property to suppress registration, and Caelestia instantiates `Notifs`
unconditionally with no config key behind it. So it is solved by supervision.

`caelestia-notif-guard` watches **one D-Bus match rule** —
`NameOwnerChanged` on that name — and when it sees Caelestia holding it,
restarts Caelestia so Omarchy reclaims it. `caelestia-start` blocks until
Omarchy owns the name before launching, which is what stops the guard from
handing the bus straight back.

Event-driven, no polling, **0% CPU at idle**. `NameOwnerChanged` only fires when
ownership actually changes, so a state that stays broken produces no further
events and the guard cannot spin.

Cost: Caelestia restarts for about three seconds after every
`omarchy restart shell`. That is the price of keeping the crash popup working.

### 3. The theme bridge — one direction, on purpose

`omarchy theme set <name>` retints Caelestia in about a second. All 25 palette
colours, light and dark carried, across every Omarchy theme.

```
omarchy theme set  →  omarchy-hook theme-set  →  50-caelestia-scheme
                   →  omarchy-to-caelestia-scheme
                   →  ~/.local/state/caelestia/scheme.json   (Caelestia watches this)
```

The bridge reads the palette through `omarchy-theme-color --all` — Omarchy's own
resolver — so legacy `colorN` themes and missing `orange`/`brown` behave exactly
as they do everywhere else in Omarchy. The 16 ANSI slots are a byte-exact copy
of Omarchy's `alacritty.toml.tpl` mapping, so your terminal and your shell agree.

It writes a file and nothing else. It never talks to Caelestia, so it works the
same whether Caelestia is running or not, and a fresh start picks the file up on
its own.

Check it any time — this is the check that matters:

```bash
~/.config/omarchy/bridges/caelestia/omarchy-to-caelestia-scheme --check
# PASS  25/25 palette colours exact -> 74 tokens, mode=dark, flavour=osaka-jade
```

`--check` compares the tokens the bridge writes against the `M3Palette` block in
your **installed** `Colours.qml`. If a Caelestia update adds a Material role, it
fails loudly instead of leaving one widget silently untinted.

> **The bridge is one-directional by construction.** Toggling light/dark from
> inside Caelestia's own UI does nothing: `scheme.json` appears exactly once in
> Caelestia's source, in the read-side `FileView`. Every write path in Caelestia
> delegates to the `caelestia` CLI, which this setup deliberately does not
> install. Change themes through Omarchy.

### 4. Idle and lock — and the number that looks wrong

Both `SUPER + CTRL + L` and Caelestia's idle timer run the same script,
`caelestia-lock`, so a manual lock and a timed lock cannot drift apart. It
resets the keyboard layout first, kills Omarchy's screensaver, then locks —
falling back to `omarchy-system-lock` if Caelestia is not answering, because a
lock key that silently does nothing is worse than the wrong lock screen.

| | |
|---|---|
| Omarchy's screensaver | **5 min** (`idle.screensaver: 300`) |
| Caelestia's lock | **~10 min** (`timeouts[0].timeout: 310`) |
| Sleep / hibernate | never — no sleep verb in the timeout array |

**`310` is not a typo, and neither `300` nor `600` is more correct.**

Opening the screensaver window makes the compositor report activity ~575 ms
later, resetting every idle client. Both monitors are armed from the *same*
last-input moment, so that reset only extends a timer which has not fired yet:

```
C < 300    lock fires at C, before the screensaver
C == 300   both fire together → you get locked at 5 minutes, not 10
C > 300    lock fires at 300 + C
```

`310` lands at ~610 s with 9.4 s of margin against the reset. `301` would work
with only 425 ms of margin. `600` locks you at fifteen minutes. Measured end to
end: predicted 23:50:29.872, fired 23:50:29.985 — **113 ms** — with the
screensaver and the lock each firing exactly once.

> **If you change `idle.screensaver`, run this afterwards, every time:**
>
> ```bash
> omarchy-shell idle disable && omarchy-shell idle enable
> ```
>
> `shell.json` hot-reloads and `omarchy-shell idle status` reports the new
> number immediately, so it *looks* applied — but Omarchy's `IdleMonitor` does
> not re-register and stops firing entirely. The tell is `lastEventAt` standing
> still while `enabled` still says `true`. Caelestia's monitors re-arm correctly
> and need none of this.

---

## What this installs, and where

| Path | What it is |
|---|---|
| `~/.local/share/caelestia-shell/` | private build prefix — sources, QML modules, the `qs` config |
| `~/.config/caelestia/shell.json` | Caelestia's config: background and wallpaper off, session menu on, one idle timeout that locks |
| `~/.config/omarchy/plugins/thepiratefox.nullbar/` | the bar that draws nothing |
| `~/.config/omarchy/shell.json` | four keys merged: `bar.id`, `disabledPlugins`, `idle.screensaver`, `idle.lock` |
| `~/.config/omarchy/bridges/caelestia/caelestia-start` | the one place that knows how to launch Caelestia |
| `~/.config/omarchy/bridges/caelestia/caelestia-notif-guard` | keeps the notification bus on Omarchy |
| `~/.config/omarchy/bridges/caelestia/omarchy-to-caelestia-scheme` | the theme bridge |
| `~/.config/omarchy/bridges/caelestia/caelestia-lock` | the one lock path |
| `~/.config/omarchy/hooks/theme-set.d/50-caelestia-scheme` | fires the bridge on every theme switch |
| `~/.config/systemd/user/caelestia-{shell,notif-guard}.service` | autostart |
| `~/.config/hypr/bindings.lua` | five binds, between markers |

**14 packages added, zero removed, zero replaced, zero upgraded.** Build tooling
(`cmake ninja meson autoconf-archive`), libraries Caelestia's C++ plugin links
(`aubio libqalculate`), fonts, and two from the AUR (`libcava`, `ttf-rubik-vf`)
built with `makepkg` and installed with `pacman -U` — never through a helper, so
the package contents are listed before anything is installed and nothing runs as
root implicitly.

`libcava` is **not** `cava`: it is a library-only fork, and `cava` is not
installed, so there is no conflict. `qt6-m3shapes` is deliberately *not* taken
from the AUR — its package installs into `/usr/lib/qt6/qml`, so the same
upstream is built into the private prefix instead.

> **The plugin id is `thepiratefox.nullbar`** because Omarchy plugin ids are
> namespaced by author and this one is the original author's. It is just a
> string; nothing about it is personal to that machine.

---

## Resource cost, and what was done about it

Two shells cost more than one. Measured with PSS, not RSS:

| | |
|---|---|
| Omarchy's shell alone, before any of this | ~348 MB |
| Both shells, fresh boot (Omarchy 4.0.2) | **559 MB** (191 + 368) |
| Both shells, after opening every Caelestia panel once | ~744 MB |

Caelestia's panels load lazily, so the number climbs the first time you open
each one and then settles. If you need it lower, the single largest saving is
`"dashboard": { "enabled": false }` in `~/.config/caelestia/shell.json`, at the
cost of `SUPER + D`.

**A theme switch is expensive and does not come back.** On 4.0.2, one
`omarchy theme set` takes Omarchy's shell from 191 MB to 573 MB and holds it
there — retained image cache, not a leak, and not Caelestia's. `omarchy restart
shell` is the workaround if it bothers you.

Three things were done to keep the cost honest:

- **The guard is a single D-Bus match rule, not a poll loop.** Idle CPU 0%.
- **`omarchy.osd` is disabled.** Caelestia's OSD is state-driven — it fires on
  the PipeWire volume change itself, not on a keybind — so leaving both enabled
  makes two sliders appear on every volume keypress.
- **Caelestia is started by a systemd user unit, not by hand.** It spawns an
  `nmcli monitor` child that only gets reaped by the unit's cgroup; started
  outside the unit those accumulate. `healthcheck.sh` counts them, and more than
  one means something started Caelestia the wrong way.

Idle CPU sits at about **1.2%**, of which 0.9% is Caelestia's 1 Hz `SystemClock`
— which nothing in the shell actually displays. Fixing it means patching
upstream source and re-applying after every update, which is not worth it.

---

## Day-to-day

```bash
systemctl --user status  caelestia-shell.service caelestia-notif-guard.service
systemctl --user restart caelestia-shell.service     # reload Caelestia
systemctl --user stop    caelestia-shell.service     # stop it properly
journalctl --user -u caelestia-notif-guard.service   # see the guard's repairs

./healthcheck.sh
```

> **Do not `pkill` Caelestia.** The unit is `Restart=on-failure`, so it comes
> back in five seconds. Use `systemctl --user stop`.
>
> And beware `pkill -f 'caelestia-shell/qs'` — `pkill -f` matches your own
> shell's `/proc/*/cmdline`, so it kills the terminal you typed it in.

### Updating Omarchy

```bash
checkupdates | grep -E 'quickshell|qt6-'   # empty = no Caelestia rebuild needed
omarchy update                              # in a REAL terminal, see below
./healthcheck.sh
```

**Run `omarchy update` in a real terminal.** It has two prompts that need a tty
— a `gum confirm` and the sudo password — and `-y` only removes the first.
Started anywhere non-interactive it blocks at the first gate having done nothing
at all.

`omarchy update` restarts the shell, which is exactly the event the guard exists
for. No `omarchy-update*` script touches `shell.json`, `~/.config/omarchy/plugins/`
or `bindings.lua`.

What is most likely to break, in order:

1. **A `quickshell` or Qt upgrade.** Caelestia's compiled plugin is built
   against the versions installed at build time. `checkupdates` above is how you
   see it coming; the fix is a rebuild (below).
2. **`omarchy-theme-color`** is an internal (`omarchy:hidden=true`) script the
   bridge shells out to. If it is renamed or its `key<TAB>value` output changes,
   themes stop following. `--check` catches it.
3. **`default/themed/alacritty.toml.tpl`** defines the ANSI mapping the bridge
   copies. If Omarchy re-maps a slot, terminal and shell drift apart.
4. **A fourth `shell.bar` property**, as above.
5. **The bar lockout fallbacks** in `shell.qml` are what make an invalid
   `bar.id` safe rather than fatal. Worth re-testing after a shell update.
6. **A new Caelestia `M3Palette` role** — `--check` fails loudly.

All six were re-verified across 4.0.1 → 4.0.2 and all six held.

### Updating Caelestia

```bash
PREFIX="$HOME/.local/share/caelestia-shell"
cd "$PREFIX/src" && git pull
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QSCONFDIR="$PREFIX/qs" -DINSTALL_QMLDIR="$PREFIX/qml" \
  -DINSTALL_LIBDIR="$PREFIX/lib"
cmake --build build && cmake --install build
systemctl --user restart caelestia-shell.service
~/.config/omarchy/bridges/caelestia/omarchy-to-caelestia-scheme --check
```

The `--check` at the end is the point.

`install.sh` pins Caelestia to a known-good revision rather than tracking
`main`. `./install.sh --ref <rev>` builds a different one.

> **Never `pacman -S caelestia-shell-git`** — it pulls `quickshell-git`, which
> removes your desktop.
>
> **Never install `caelestia-cli`.** Its `apply_colours()` overwrites
> `~/.config/gtk-{3,4}.0/gtk.css`, dconf, qt5ct/qt6ct,
> `~/.config/hypr/scheme/current.lua`, btop, htop, fuzzel, chromium and more,
> blasts ANSI escapes into every `/dev/pts`, and runs `sudo -n papirus-folders`.
> All of that is Omarchy's territory. `healthcheck.sh` checks for the damage.

---

## What you give up

Real costs, not hypotheticals:

- **Omarchy's media/track OSD**, disabled so both don't fire at once.
- **Light/dark toggling from inside Caelestia's UI.** One-directional bridge —
  change themes through Omarchy.
- **~3 seconds of Caelestia restarting** after every `omarchy restart shell`.
  That is the guard reclaiming the notification bus.
- **The lock screen still needs Enter.** Auto-unlocking on a correct password
  means authenticating on every keystroke, and Caelestia's PAM config inherits
  Omarchy's `faillock deny = 10` — a password over ten characters would lock
  your account before the last character.
- **Low contrast on a few themes.** Some Omarchy themes have accent-on-panel
  pairs between 2.3:1 and 3.0:1. Those are the theme's own colours on the
  theme's own surfaces, and the bridge leaves them exact on purpose; the
  alternative is an accent that is no longer the theme's accent.
- **A layer surface cannot sit above one window and below another.** The chrome
  is above every window or below every window; there is no in-between for a
  scratchpad.

## If it goes wrong

A working Omarchy with no Caelestia beats a half-migrated system you cannot log
into. In order, cheapest first:

```bash
systemctl --user stop caelestia-shell.service   # Caelestia gone, Omarchy fine
./healthcheck.sh                                 # what specifically is wrong
./uninstall.sh --dry-run                         # then for real
omarchy snapshot restore                         # if you took one
```

An invalid `bar.id` is *safe*: Omarchy falls back to its own bar rather than
booting you into nothing. That fallback is what makes the null bar a reasonable
thing to do at all.

---

## Credits

- **[caelestia-dots/shell](https://github.com/caelestia-dots/shell)** — the
  shell itself. All the good-looking parts are theirs. None of its code is
  vendored here; `install.sh` builds it from upstream at a pinned revision.
- **[soramanew/m3shapes](https://github.com/soramanew/m3shapes)** — required by
  Caelestia's dashboard.
- **[basecamp/omarchy](https://github.com/basecamp/omarchy)** — everything
  underneath.

This repo is only the glue: the null bar, four bridge scripts, two units, a
theme hook, and the three scripts that put them in place, check them and take
them out again.
