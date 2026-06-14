###############################################################################
# Holdfast Containerfile
###############################################################################
# Multi-stage build following the Bluefin pattern: a `ctx` scratch stage that
# assembles local files (and optional OCI imports), then the final stage based
# on bluefin-dx that mounts ctx and runs every *.sh in /ctx/build.
# See: https://docs.projectbluefin.io/contributing/
###############################################################################

# Base image. Override at build time via --build-arg BASE_IMAGE=...
# Alternatives:
#   ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable  (NVIDIA open drivers)
#   ghcr.io/ublue-os/silverblue-main:latest         (plain GNOME, no DX tooling)
#   ghcr.io/ublue-os/base-main:latest               (no desktop)
#   quay.io/centos-bootc/centos-bootc:stream10      (CentOS-based)
ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:stable"

# Context stage: scratch image holding /build and /custom for the RUN below.
FROM scratch AS ctx

COPY build /build
COPY custom /custom
# OCI imports below are commented out because bluefin-dx:stable already provides them:
#   - projectbluefin/common: just files in /usr/share/ublue-os/just/, Brewfiles, dconf, branding
#   - ublue-os/brew: Homebrew binaries in /home/linuxbrew/.linuxbrew/
# Uncomment together with the matching block in build/10-build.sh if switching
# to a base that doesn't include them (e.g. silverblue-main, base-main).
# Renovate can update these :latest tags to SHA-256 digests for reproducibility.
# COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
# COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew

FROM ${BASE_IMAGE}

# Every *.sh at the top of /ctx/build runs in shell-glob (alphanumeric) order.
# Subdirectories (e.g. helpers/) are not invoked; they're for sourced libraries.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    bash -c 'for script in /ctx/build/*.sh; do echo "Running: ${script}" && bash "${script}"; done'

# Verify image is well-formed (selinux labels, mount points, kernel, etc.)
RUN bootc container lint
