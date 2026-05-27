#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# COSMIC Desktop (alongside GNOME)
###############################################################################
# Installs System76's COSMIC desktop from the ryanabx/cosmic-epoch COPR.
# GDM remains the display manager — users pick COSMIC from the session chooser.
# Based on: github.com/ericrocha97/bluefin
###############################################################################

# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

COSMIC_PACKAGES=(
    cosmic-session
    cosmic-greeter
    cosmic-comp
    cosmic-panel
    cosmic-launcher
    cosmic-applets
    cosmic-settings
    cosmic-files
    cosmic-edit
    cosmic-term
    cosmic-store
    cosmic-player
    cosmic-screenshot
    cosmic-bg
    cosmic-wallpapers
    cosmic-icon-theme
    cosmic-notifications
    cosmic-osd
    cosmic-app-library
    cosmic-workspaces
    xdg-desktop-portal-cosmic
)

echo "::group:: Install COSMIC Desktop"

copr_install_isolated "ryanabx/cosmic-epoch" "${COSMIC_PACKAGES[@]}"

echo "::endgroup::"

echo "::group:: Verify COSMIC Packages"

FAILED=0
for pkg in "${COSMIC_PACKAGES[@]}"; do
    if ! rpm -q "$pkg" > /dev/null 2>&1; then
        echo "ERROR: $pkg not installed"
        FAILED=1
    fi
done

if [[ "$FAILED" -eq 1 ]]; then
    echo "COSMIC package verification failed"
    exit 1
fi

echo "All COSMIC packages verified"
echo "::endgroup::"

echo "::group:: Verify COSMIC Session"

if [[ -f /usr/share/wayland-sessions/cosmic.desktop ]]; then
    echo "COSMIC session registered:"
    cat /usr/share/wayland-sessions/cosmic.desktop
else
    echo "WARNING: cosmic.desktop session file not found — users may need to select manually"
fi

echo "Available wayland sessions:"
ls -la /usr/share/wayland-sessions/ || true

echo "::endgroup::"

echo "COSMIC desktop installed — select 'COSMIC' at the GDM login screen"
