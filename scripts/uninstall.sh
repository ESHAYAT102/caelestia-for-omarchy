#!/usr/bin/env sh
set -eu

install_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/caelestia-for-omarchy"
purge=0

usage() {
  echo "usage: uninstall.sh [--purge]"
  echo
  echo "Removes the Caelestia integration and $install_dir."
  echo "Pass --purge to also delete the private Caelestia build and state."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --purge)
      purge=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ ! -x "$install_dir/uninstall.sh" ]; then
  echo "error: installation was not found at $install_dir" >&2
  exit 1
fi

if [ "$purge" -eq 1 ]; then
  "$install_dir/uninstall.sh" --yes --purge
else
  "$install_dir/uninstall.sh" --yes
fi

rm -rf "$install_dir"
echo "removed Caelestia for Omarchy and $install_dir"
