#!/usr/bin/bash

# Stage custom/ files into the image
# Install additional packages and services

set -eoux pipefail
shopt -s nullglob   # so empty custom/ subdirs don't break the cp/find globs

# shellcheck source=build/helpers/copr.sh
source /ctx/build/helpers/copr.sh

# # Bluefin "common" already included in base image.
# # Uncomment these lines and the matching COPY --from line in Containerfile if using a non-Bluefin base
# echo "::group:: Copy Bluefin Config from Common"
# mkdir -p /usr/share/ublue-os/just/
# shopt -s nullglob
# cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
# shopt -u nullglob
# echo "::endgroup::"

echo "::group:: Stage custom/ files"

# Add custom Brewfiles alongside Bluefin's
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Concatenate ujust recipes into 60-custom.just to be imported by Bluefin's 00-entry.just
mkdir -p /usr/share/ublue-os/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Install packages"

dnf5 install -y sshfs
copr_install_isolated "scottames/ghostty" ghostty

echo "::endgroup::"

echo "::group:: System configuration"

systemctl enable podman.socket

# Set Ghostty as GNOME's default terminal for Ctrl+Alt+T and Files' "Open Terminal"
mkdir -p /etc/dconf/db/local.d/
cat > /etc/dconf/db/local.d/01-default-terminal << 'EOF'
[org/gnome/desktop/default-applications/terminal]
exec='ghostty'
exec-arg=''
EOF
dconf update

# Disable AMD Panel Self-Refresh to prevent a known DMCUB firmware hang
# that freezes the desktop on AMD Phoenix/RDNA 3 iGPUs (e.g. Framework 16
# 780M) when running COSMIC. Upstream cosmic-comp triggers the hang via
# unnecessary atomic_commit(ALLOW_MODESET) on udev events; this kernel
# parameter avoids the underlying firmware bug. Safe to apply on non-AMD
# hardware (it's a no-op). See:
#   https://github.com/pop-os/cosmic-comp/issues/2375
#   https://github.com/pop-os/cosmic-comp/pull/2382
mkdir -p /usr/lib/bootc/kargs.d
install -m 0644 /ctx/build/helpers/kargs.d/99-amdgpu-psr.conf /usr/lib/bootc/kargs.d/99-amdgpu-psr.conf

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Build complete!"
