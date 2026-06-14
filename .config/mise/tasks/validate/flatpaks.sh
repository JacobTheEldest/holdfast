#!/usr/bin/env bash
#MISE description="Validate custom/flatpaks/*.preinstall references via flathub"
#MISE sources=["custom/flatpaks/**/*.preinstall"]
#
# Requires `flatpak` on PATH with the flathub remote configured.

set -euxo pipefail

echo "Validating flatpak files in custom/flatpak/ directory..."
find "custom/flatpaks" -iname '*\.list*' -print0 | while IFS= read -r -d '' flatpaks_file; do
    echo "::group:: ===$(basename "$flatpaks_file")==="
    grep -v "#.*" "$flatpaks_file" | grep -v "^$" | while read -r flatpak; do
        flatpak remote-info --user flathub "$flatpak"
    done
    echo "::endgroup::"
done
