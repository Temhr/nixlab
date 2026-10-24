#!/usr/bin/env bash
set -eu
norm(){ sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g'; }
for f in $(cd "$1/etc/systemd/system" && ls *.service *.timer 2>/dev/null); do
  diff -u <(norm < "$1/etc/systemd/system/$f") <(norm < "$2/etc/systemd/system/$f" 2>/dev/null) \
    | sed "1,2s#^#[$f] #" || true
done
nix store diff-closures "$1" "$2"
