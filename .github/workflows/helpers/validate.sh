#!/usr/bin/env bash
#
# Helper functions for validate workflow extracted here for parsing and portability.
#
# Each subcommand is the actual validation work for one workflow step.
#
# usage:
#   validate.sh <brewfiles|setup-flathub|flatpaks|justfiles
#               |setup-shellcheck|shell-scripts|renovate>
#
# Env vars consumed:
#   USER              — runner user (set automatically by GitHub Actions)
#   RENOVATE_VERSION  — pinned via `env:` in the renovate step

set -euxo pipefail

# --- Brewfiles ---------------------------------------------------------------

validate_brewfiles() {
    echo "Validating Brewfiles in custom/brew/ directory..."
    find "custom/brew" -iname '*\.Brewfile*' -print0 | while IFS= read -r -d '' brewfile; do
        echo "::group:: ===$(basename "$brewfile")==="
        if ! grep -E -e "^tap" "$brewfile" > taps.Brewfile; then
            echo "# No taps" > taps.Brewfile
        fi
        brew bundle --file=./taps.Brewfile
        # Trust any third-party taps just installed. Homebrew added an
        # untrusted-tap guardrail; without this, `brew bundle exec` below
        # refuses to load formulae from non-core taps.
        awk -F'"' '/^tap/ {print $2}' "$brewfile" | while read -r tap; do
            [[ -n "$tap" ]] && brew trust "$tap"
        done
        if brew bundle exec whoami --file="$brewfile" | grep -F -e "${USER}"; then
            echo "✓ $brewfile is valid"
        else
            echo "✗ $brewfile validation failed"
            return 1
        fi
        echo "::endgroup::"
    done
}

# --- Flatpaks ----------------------------------------------------------------

setup_flathub() {
    sudo apt-get install -y flatpak
    flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
}

validate_flatpaks() {
    echo "Validating flatpak files in custom/flatpak/ directory..."
    find "custom/flatpak" -iname '*\.list*' -print0 | while IFS= read -r -d '' flatpaks_file; do
        echo "::group:: ===$(basename "$flatpaks_file")==="
        grep -v "#.*" "$flatpaks_file" | grep -v "^$" | while read -r flatpak; do
            flatpak remote-info --user flathub "$flatpak"
        done
        echo "::endgroup::"
    done
}

# --- Justfiles ---------------------------------------------------------------

validate_justfiles() {
    echo "Validating justfiles in custom/ujust/ directory..."
    echo "::group:: Validating Justfile"
    just --unstable --fmt --check -f Justfile
    echo "::endgroup::"
    find "custom/ujust" -iname '*.just' -print0 | while IFS= read -r -d '' justfile; do
        echo "::group:: ===$(basename "$justfile")==="
        just --unstable --fmt --check -f "$justfile"
        echo "::endgroup::"
    done
    echo "All justfiles are valid"
}

# --- Shell scripts -----------------------------------------------------------

setup_shellcheck() {
    sudo apt-get update
    sudo apt-get install -y shellcheck
}

validate_shell_scripts() {
    echo "Running shellcheck on build/ and .github/workflows/helpers/ scripts..."
    find "build" ".github/workflows/helpers" -iname '*.sh' -print0 | while IFS= read -r -d '' script; do
        echo "::group:: ===$(basename "$script")==="
        shellcheck -x "$script"
        echo "✓ $script passed shellcheck"
        echo "::endgroup::"
    done
    echo "All shell scripts passed validation"
}

# --- Renovate ----------------------------------------------------------------

validate_renovate_config() {
    npm install -g "renovate@${RENOVATE_VERSION:-latest}"
    renovate-config-validator --strict
}

# --- Dispatch ----------------------------------------------------------------

case "${1:-}" in
    brewfiles)        validate_brewfiles ;;
    setup-flathub)    setup_flathub ;;
    flatpaks)         validate_flatpaks ;;
    justfiles)        validate_justfiles ;;
    setup-shellcheck) setup_shellcheck ;;
    shell-scripts)    validate_shell_scripts ;;
    renovate)         validate_renovate_config ;;
    *)
        echo "usage: $0 <brewfiles|setup-flathub|flatpaks|justfiles|setup-shellcheck|shell-scripts|renovate>" >&2
        exit 2
        ;;
esac
