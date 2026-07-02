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
  cosmic-idle
  cosmic-randr
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

echo "::group:: Add COSMIC session registration for GDM"
# Without X-GDM-SessionRegisters=true, logind never marks the session active
# and cosmic-comp cannot acquire DRM master - causes immediate freeze on login
if [[ -f /usr/share/wayland-sessions/cosmic.desktop ]]; then
  # Check if keys already exist to avoid duplicates
  if ! grep -q 'X-GDM-SessionRegisters' /usr/share/wayland-sessions/cosmic.desktop; then
    echo "X-GDM-SessionRegisters=true" >> /usr/share/wayland-sessions/cosmic.desktop
    echo "X-GDM-CanRunHeadless=true" >> /usr/share/wayland-sessions/cosmic.desktop
    echo "Added GDM session registration keys to cosmic.desktop"
  fi
fi
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

  # Ensure the cosmic-greeter user is a member of the video and render groups.
  # The package's /usr/lib/sysusers.d/cosmic-greeter.conf declares
  #   m cosmic-greeter video
  # but the systemd-sysusers 'm' directive silently no-ops when the user
  # already exists with that UID (e.g. inherited from a prior deployment).
  # Result: cosmic-comp running as cosmic-greeter cannot open /dev/dri/card1,
  # exits with "Backend initialized without output", and the user sees a
  # blank screen.
  #
  # This follows the established Universal Blue pattern (see
  # /usr/bin/bluefin-dx-groups): first append the static group definitions
  # from /usr/lib/group into /etc/group, then add the user via usermod.
  cat > /usr/bin/holdfast-cosmic-greeter-groups <<'EOF'
#!/usr/bin/env bash
set -eoux pipefail

GROUP_SETUP_VER=1
GROUP_SETUP_VER_FILE="/etc/ublue/holdfast-cosmic-greeter-groups"
GROUP_SETUP_VER_RAN=$(cat "$GROUP_SETUP_VER_FILE" 2>/dev/null || true)

mkdir -p /etc/ublue

if [[ -f $GROUP_SETUP_VER_FILE && "$GROUP_SETUP_VER" = "$GROUP_SETUP_VER_RAN" ]]; then
  echo "cosmic-greeter group setup has already run. Exiting..."
  exit 0
fi

# Copy static group definitions from /usr/lib/group into /etc/group so
# usermod can add the user to them. /usr/lib/group is the systemd
# vendored system group database.
for grp in video render; do
  if ! grep -q "^${grp}:" /etc/group; then
    if grep -q "^${grp}:" /usr/lib/group; then
      echo "Appending $grp to /etc/group"
      grep "^${grp}:" /usr/lib/group | tee -a /etc/group >/dev/null
    else
      echo "WARNING: $grp not found in /usr/lib/group; skipping"
    fi
  fi
done

if id cosmic-greeter >/dev/null 2>&1; then
  usermod -aG video,render cosmic-greeter
  echo "Added cosmic-greeter to video and render groups"
else
  echo "WARNING: cosmic-greeter user not found; skipping usermod"
fi

echo "$GROUP_SETUP_VER" >"$GROUP_SETUP_VER_FILE"
EOF
  chmod +x /usr/bin/holdfast-cosmic-greeter-groups

  cat > /usr/lib/systemd/system/holdfast-cosmic-greeter-groups.service <<'EOF'
[Unit]
Description=Add cosmic-greeter to video and render groups
Documentation=https://github.com/pop-os/cosmic-greeter/issues/441
After=systemd-sysusers.service
Before=cosmic-greeter.service
ConditionPathExists=/var/lib/cosmic-greeter

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/holdfast-cosmic-greeter-groups

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable holdfast-cosmic-greeter-groups.service

  echo "::endgroup::"

  echo "::group:: Configure cosmic-greeter VT switch"
  # NOTE: vt = "next" forces a VT switch during login to give the DRM race
  # condition another chance to land correctly.
  # See: https://github.com/pop-os/cosmic-greeter/issues/441
  mkdir -p /etc/greetd/
  cat > /etc/greetd/cosmic-greeter.toml << 'EOF'
  [terminal]
  vt = "next"

  [general]
  service = "cosmic-greeter"

  [default_session]
  command = "cosmic-greeter-start"
  user = "cosmic-greeter"
EOF

  echo "::endgroup::"
fi

echo "COSMIC desktop installed. Select session at the login screen"
