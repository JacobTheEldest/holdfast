#!/usr/bin/bash

set -eoux pipefail

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

###############################################################################
# Base system build
###############################################################################
# Stages runtime customizations into the image and installs build-time packages:
#   - Copies custom Brewfiles to /usr/share/ublue-os/homebrew/
#   - Appends custom ujust recipes into /usr/share/ublue-os/just/60-custom.just
#   - Copies Flatpak preinstall files to /etc/flatpak/preinstall.d/
#   - dnf5 installs sshfs, ghostty (via COPR), sets ghostty as GNOME default terminal
#   - Enables podman.socket
#
# Follows the @ublue-os/bluefin pattern with `set -eoux pipefail` for strict
# error handling and debug output.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/helpers/copr.sh

# # Bluefin "common" already included in base image.
# # Uncomment these lines and the matching COPY --from line in Containerfile if using a non-Bluefin base
# echo "::group:: Copy Bluefin Config from Common"
# mkdir -p /usr/share/ublue-os/just/
# shopt -s nullglob
# cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
# shopt -u nullglob
# echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
mkdir -p /usr/share/ublue-os/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Install Packages"

# Install packages using dnf5
dnf5 install -y sshfs

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

# Ghostty terminal emulator
copr_install_isolated "scottames/ghostty" ghostty

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
# Example: systemctl mask unwanted-service

# Set ghostty as the default GNOME terminal
mkdir -p /etc/dconf/db/local.d/
cat > /etc/dconf/db/local.d/01-default-terminal << 'EOF'
[org/gnome/desktop/default-applications/terminal]
exec='ghostty'
exec-arg=''
EOF
dconf update

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
