#!/usr/bin/env sh
set -eu

repo_url="https://github.com/ESHAYAT102/caelestia-for-omarchy.git"
install_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/caelestia-for-omarchy"

if [ "$(id -u)" -eq 0 ]; then
  echo "error: run this updater as your normal user, not root" >&2
  exit 1
fi

if [ -d "$install_dir/.git" ]; then
  echo "updating $install_dir"
  git -C "$install_dir" fetch origin main
  git -C "$install_dir" checkout main
  git -C "$install_dir" reset --hard origin/main
elif [ -e "$install_dir" ]; then
  echo "error: $install_dir exists but is not a Git checkout" >&2
  exit 1
else
  mkdir -p "$(dirname "$install_dir")"
  git clone --depth 1 "$repo_url" "$install_dir"
fi

exec "$install_dir/update.sh" "$@"
