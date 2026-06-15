#!/usr/bin/env bash
#MISE description="Validate custom/brew/*.Brewfile parses and references trusted taps"
#MISE sources=["custom/brew/**/*.Brewfile"]
#
# Requires `brew` on PATH.

set -euxo pipefail

# Stage the per-Brewfile tap list in a tempfile so the validator doesn't
# litter the repo root when run locally.
taps_file="$(mktemp -t holdfast-taps.XXXXXX.Brewfile)"
trap 'rm -f "$taps_file"' EXIT

echo "Validating Brewfiles in custom/brew/ directory..."
find "custom/brew" -iname '*\.Brewfile*' -print0 | while IFS= read -r -d '' brewfile; do
    echo "::group:: ===$(basename "$brewfile")==="
    if ! grep -E -e "^tap" "$brewfile" > "$taps_file"; then
        echo "# No taps" > "$taps_file"
    fi
    brew bundle --file="$taps_file"
    # Trust any third-party taps just installed.
    awk -F'"' '/^tap/ {print $2}' "$brewfile" | while read -r tap; do
        [[ -n "$tap" ]] && brew trust "$tap"
    done
    if brew bundle exec whoami --file="$brewfile" | grep -F -e "${USER}"; then
        echo "✓ $brewfile is valid"
    else
        echo "✗ $brewfile validation failed"
        exit 1
    fi
    echo "::endgroup::"
done
