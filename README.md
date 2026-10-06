# Caelestia for Omarchy

A complete Caelestia desktop-shell integration for Omarchy 4 without replacing Omarchy's stock `quickshell` package.

## Features

- Caelestia bar, launcher, dashboard, OSD, lock screen, notifications, wallpaper rendering, and dynamic wallpaper colors.
- Omarchy wallpaper, Plymouth unlock screens, package tools, screenshots, clipboard history, and system utilities.
- Native launcher clipboard history with `Delete` for one entry and `Shift+Delete` for all entries.
- Native launcher wallpaper and Omarchy unlock-screen pickers.
- Caelestia Wi-Fi, Bluetooth, Audio, Battery, Utilities, Sidebar, and power panels.
- `caelestia-on` and `caelestia-off` switch the shell, bar, OSD, idle behavior, services, and complete keybinding profile.
- Keeps all packaged Omarchy files under `/usr/share/omarchy` untouched.

## Install

Run the one-command installer:

```bash
curl -fsSL https://raw.githubusercontent.com/ESHAYAT102/caelestia-for-omarchy/main/scripts/install.sh | sh
```

It clones or updates the repository at:

```text
~/.config/caelestia-for-omarchy/
```

The installer builds Caelestia and M3Shapes into `~/.local/share/caelestia-shell`, installs required dependencies, syncs and installs every supported configuration from `ESHAYAT102/dotfiles`, copies the customized shell payload, installs user services, and enables Caelestia mode.

To reuse an existing private build:

```bash
curl -fsSL https://raw.githubusercontent.com/ESHAYAT102/caelestia-for-omarchy/main/scripts/install.sh | sh -s -- --skip-build
```

## Update configuration without rebuilding

```bash
curl -fsSL https://raw.githubusercontent.com/ESHAYAT102/caelestia-for-omarchy/main/scripts/update.sh | sh
```

This updates both repository checkouts, runs the dotfiles repository's `install.sh --all`, and reapplies all Caelestia QML, configuration, keybinding overlays, helpers, hooks, and service files without rebuilding Caelestia or M3Shapes.

## Mode switching

```bash
caelestia-on
caelestia-off
caelestia-mode status
```

`caelestia-off` restores the captured pre-install Omarchy keybindings, built-in bar, OSD, idle timings, and stops Caelestia. `caelestia-on` restores all Caelestia customizations.

## Important keybindings

| Key | Action |
|---|---|
| `SUPER + SPACE` | Caelestia launcher |
| `SUPER + CTRL + SPACE` | Wallpaper picker |
| `SUPER + V` / `SUPER + CTRL + V` | Native Caelestia clipboard history |
| `SUPER + D` | Dashboard |
| `SUPER + A` | Sidebar |
| `SUPER + U` | Utilities |
| `SUPER + ESCAPE` | Caelestia power menu |
| `SUPER + L` | Caelestia lock screen |
| `SUPER + CTRL + L` | Toggle workspace layout |
| `SUPER + CTRL + W/B/A` | Wi-Fi / Bluetooth / Audio panels |
| `SUPER + ALT + B` | Battery panel |

## Uninstall

Remove the integration while leaving the private build available for reuse:

```bash
curl -fsSL https://raw.githubusercontent.com/ESHAYAT102/caelestia-for-omarchy/main/scripts/uninstall.sh | sh
```

Also remove the private Caelestia build, config, and state:

```bash
curl -fsSL https://raw.githubusercontent.com/ESHAYAT102/caelestia-for-omarchy/main/scripts/uninstall.sh | sh -s -- --purge
```

## Repository layout

- `payload/qs/`: customized Caelestia QML files copied over the pinned upstream build.
- `payload/config/`: Caelestia configuration and the overlay applied to Hyprland bindings imported from the dotfiles repository.
- `payload/bin/`: `caelestia-on`, `caelestia-off`, mode switching, clipboard, and workspace-layout helpers.
- `bridges/`: wallpaper, theme, notification, launch, and lock integration.
- `systemd/user/`: Caelestia user services.
- `thepiratefox.nullbar/`: zero-size Omarchy bar, kept as an available spare. Caelestia mode currently keeps `omarchy.bar` and hides it at runtime via the `bar-off` toggle instead.

## Notes

The installer is designed for Omarchy 4.x and uses a pinned Caelestia revision. It does not install `quickshell-git`, `caelestia-shell`, or `caelestia-cli` system-wide, because those can conflict with Omarchy's shell package or overwrite Omarchy-managed configuration.
