#!/usr/bin/bash

###############################################################################
# Installs System76's COSMIC desktop
###############################################################################

set -eoux pipefail

REMOVE_GNOME=true
# false:
# - Keep GDM as the display manager
# - Gnome and Cosmic are both selectable from the login screen
# - Uses cosmic-greeter as the lockscreen for Cosmic DE
#
# true:
# - Build a Cosmic-only image
# - Remove Gnome and GDM
# - Use cosmic-greeter as the display manager and lockscreen

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

dnf5 install -y "${COSMIC_PACKAGES[@]}"

echo "::endgroup::"

echo "::group:: Verify COSMIC Packages"

FAILED=0
for pkg in "${COSMIC_PACKAGES[@]}"; do
  if ! rpm -q "${pkg}" > /dev/null 2>&1; then
    echo "ERROR: ${pkg} not installed"
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

if [[ "$REMOVE_GNOME" == "true" ]]; then
  echo "::group:: Remove GNOME Desktop (COSMIC-only image)"

  dnf5 remove -y \
    gnome-shell \
    'gnome-shell-extension*' \
    gnome-terminal \
    gnome-software \
    gnome-control-center \
    nautilus \
    gdm

  # Use cosmic-greeter as the replacement display manager.
  systemctl enable cosmic-greeter

  echo "::endgroup::"
fi

echo "COSMIC desktop installed — select session at the login screen"
