# Holdfast

Holdfast is a personal Linux distribution based on [Universal Blue](https://universal-blue.org/) and [Bluefin](https://projectbluefin.io). It provides a stable, dependable foundation for development, experimentation, and daily use.

| Variant | Image |
| --- | --- |
| Base | `ghcr.io/jacobtheeldest/holdfast:stable` |
| NVIDIA (open drivers) | `ghcr.io/jacobtheeldest/holdfast-nvidia-open:stable` |

## About this repo

- **Base:** [Bluefin DX](https://projectbluefin.io) (GNOME + developer tooling)
- **Desktop sessions:** Select GNOME or [COSMIC](https://system76.com/cosmic) at the login screen
- **Build-time packages:** See [`build/`](build/) scripts
- **Runtime tools:** Homebrew packages ([`custom/brew/`](custom/brew/)), Flatpaks ([`custom/flatpaks/`](custom/flatpaks/)), ujust commands ([`custom/ujust/`](custom/ujust/))
- **CI/CD:** Automated builds, validation, image signing, SBOM generation, Renovate dependency updates

### Image Build Architecture

Follows the [Bluefin multi-stage build pattern](https://docs.projectbluefin.io/contributing/). See [`Containerfile`](Containerfile) for the full definition.

1. **Context stage (`ctx`)** — assembles local `build/` and `custom/` files with OCI resources from `@projectbluefin/common` and `@ublue-os/brew`
2. **Final stage** — starts from `bluefin-dx:stable`, mounts the context, and runs all numbered build scripts

### Image Signing

Images are signed with [cosign](https://github.com/sigstore/cosign) on every push to `master`, using the `SIGNING_SECRET` repository secret. The public key is committed at [`cosign.pub`](cosign.pub).

Verify a pulled image:

```bash
cosign verify --key cosign.pub ghcr.io/jacobtheeldest/holdfast:stable
```

SBOM attestation is part of CI [`build.yml`](.github/workflows/build.yml).

## Deploy

### Clean install

No prebuilt ISO is published from CI — pick one of the two paths below.

#### From any Fedora live environment (recommended)

`bootc install` writes the image directly to disk from a running Fedora-like system (Workstation Live, Silverblue installer, etc.). Faster than building an ISO and avoids the kickstart roundtrip.

1. Boot a Fedora live USB and open a terminal.

1. Install to a target disk (this **wipes** the disk):

    ```bash
    sudo podman run \
      --rm --privileged --pid=host \
      --security-opt label=type:unconfined_t \
      -v /dev:/dev -v /var/lib/containers:/var/lib/containers \
      ghcr.io/jacobtheeldest/holdfast:stable \
      bootc install to-disk --wipe /dev/nvme0n1
    ```

    > Substitute the correct target device. Use `bootc install to-filesystem` instead if installing into pre-existing partitions. See the [bootc install reference](https://bootc-dev.github.io/bootc/bootc-install.html) for encryption, kernel arg overrides, and `--source-imgref` for offline installs.

1. Reboot, remove the live USB.

#### From a locally built installer ISO

Use this when you want Anaconda's guided partitioning/network/user setup.

1. Update the `bootc switch` URL in [`iso/iso.toml`](iso/iso.toml) - the upstream template ships with a `ghcr.io/USERNAME/REPO:stable` placeholder that needs replacing with the actual image ref.

1. Build the installer ISO:

    ```bash
    just build-iso
    ```

    > Output lands at `output/bootiso/install.iso`. Configured by [`iso/iso.toml`](iso/iso.toml); the Anaconda modules enabled there control which install steps the user sees.

1. Write the ISO to a USB stick (e.g. `dd if=output/bootiso/install.iso of=/dev/sdX bs=4M status=progress`) and boot from it. Anaconda runs the install, then the kickstart `%post` does `bootc switch` to pull the runtime image on first boot.

### Rebase from another atomic OS image

```bash
sudo bootc switch ghcr.io/jacobtheeldest/holdfast:stable
sudo systemctl reboot
```

## Update

Automatic updates are handled by [uupd](https://github.com/ublue-os/uupd). It runs daily at 4 AM, stages image + Flatpak + Homebrew updates, and applies them on next reboot.

| Task | Command |
| --- | --- |
| Check for image update | `uupd update-check` |
| Update everything (image + flatpaks + brew) | `ujust update` |
| Update and reboot | `ujust update-and-reboot` |
| Toggle automatic updates | `ujust toggle-updates` |
| Check current image status | `sudo bootc status` |

## Customize this Image

| What | Where |
| --- | --- |
| Base image / OCI imports | [`Containerfile`](Containerfile) |
| Build | [`build/*.sh`](build/) scripts |
| System packages | [`build/10-build.sh`](build/10-build.sh) (Use the [helper function](`build/helpers/copr.sh`) for COPR packages) |
| Desktop sessions | [`build/30-cosmic-desktop.sh`](build/30-cosmic-desktop.sh) for the pattern |
| CLI tools (runtime) | [`custom/brew/*.Brewfile`](custom/brew/) |
| GUI apps (runtime) | [`custom/flatpaks/*.preinstall`](custom/flatpaks/) |
| User commands | [`custom/ujust/*.just`](custom/ujust/) |

### Development Workflow

1. Open a pull request. CI validates Brewfiles, Flatpaks, Justfiles, shell scripts, and builds a test image.

    ```bash
    gh pr create --base master [--head <branch>] --fill
    ```

1. Merge to `master`. Triggers a `:stable` image build and push to GHCR. `master` is protected and auto-merge is enabled, so PRs land as soon as checks pass. Renovate keeps base images, OCI imports, and Actions up to date automatically.

    ```bash
    gh pr merge --auto --merge
    ```

1. [Rebase](#rebase-from-another-atomic-os-image) or [update](#update) to the new image as needed.

### Local Testing

#### Test on your hardware

1. Build the image container image locally:

    ```bash
    just build
    ```

1. Pin the current known-good deployment **before** switching.

    > `bootc` only keeps only the booted deployment plus the most recent for rollback. Multiple tests would garbage-collect your known-good image.

    ```bash
    sudo ostree admin pin booted   # Pin the running deployment
    sudo ostree admin status       # Confirm "Pinned: yes" on the booted entry
    ```

1. Copy the locally built image into root storage:

    ```bash
    sudo podman image scp \
      $(id -un)@localhost::localhost/holdfast:testing \
      root@localhost::
    sudo podman images localhost/holdfast # Verify the image landed
    ```

1. Switch to the local image and boot into it:

    ```bash
    sudo bootc switch --transport containers-storage localhost/holdfast:testing
    sudo bootc status # Confirm it's staged and the pinned image is intact
    sudo systemctl reboot
    ```

1. Roll back if necessary by selecting the pinned known-good entry at the boot menu or staging it from a working system:

    ```bash
    sudo bootc switch --transport registry ghcr.io/jacobtheeldest/holdfast:testing
    sudo systemctl reboot
    ```

    > `bootc rollback` only toggles the booted/rollback pair

1. Unpin the old deployment when it is no longer needed:

    ```bash
    sudo ostree admin status                 # Find the pinned deployment's index
    sudo ostree admin pin --unpin <index>    # Allow it to be cleaned up
    ```

#### Test in a VM

> The browser VM uses virtio-gpu and won't reproduce hardware-specific GPU/seat behaviour (e.g. amdgpu VT-switch handling). Test display-manager or compositor changes on real hardware (above).

1. Build the container image and a qcow2 disk from it in one step:

    ```bash
    just rebuild-qcow2
    ```

    > `just build-qcow2` alone reuses whatever container image is already in storage; `rebuild-qcow2` rebuilds the container first so the qcow2 reflects the working tree. Disk geometry is defined in [`iso/disk.toml`](iso/disk.toml). The build runs `bootc-image-builder` under `sudo podman` and drops the artifact at `output/qcow2/disk.qcow2`.

1. Boot the VM in a browser:

    ```bash
    just run-vm-qcow2
    ```

    > The recipe picks the first free port starting at 8006, prints the URL, then auto-opens it via `xdg-open` after 30 seconds. The VM gets KVM, TPM, virtio-GPU, 4 cores, 8 GB RAM, and a 64 GB disk. First boot lands in `gnome-initial-setup` — create whatever user account you want for testing.

1. (Optional) Run with `systemd-vmspawn` for a native window instead of the browser:

    ```bash
    just spawn-vm                       # qcow2 by default, 6 GB RAM
    just spawn-vm rebuild=1 ram=8G      # rebuild first, more RAM
    ```

1. Clean up build artifacts when done:

    ```bash
    just clean
    ```

#### Other build targets

- `just build-raw` / `just run-vm-raw` — raw disk image (same `iso/disk.toml`)
- `just build-iso` / `just run-vm-iso` — installer ISO; configured by [`iso/iso.toml`](iso/iso.toml). Update the `bootc switch` URL there before use.

### Syncing Upstream Template

Holdfast tracks [`projectbluefin/finpilot`](https://github.com/projectbluefin/finpilot) as `upstream`. To pull in template changes:

```bash
jj git fetch --remote upstream                          # Fetch upstream commits
jj log -r 'master..main@upstream'                       # Review what's new
jj rebase -s 'fork_point(master, main@upstream)+' \
          -d main@upstream                              # Rebase local commits onto upstream tip
jj bookmark move master --to <tip-change-id>            # Advance master to the rebased tip
```

Resolve any conflicts with `jj resolve`, then validate locally (`shellcheck build/*.sh`, `just --list`, `just build`) before pushing.

First-time setup if `upstream` isn't configured:

```bash
jj git remote add upstream git@github.com:projectbluefin/finpilot.git
jj bookmark track main@upstream
```

### Contributing Upstream

To send a fix or improvement back to `projectbluefin/finpilot`:

```bash
jj git fetch --remote upstream                          # Ensure upstream is current
jj new main@upstream                                    # Start a topic branch off upstream
jj duplicate <change-id> --destination @                # Copy your commit onto it
jj bookmark create contrib/<short-name> -r <new-id>     # Name the branch
jj git push --remote origin --bookmark contrib/<short-name>

gh pr create --repo projectbluefin/finpilot \
  --base main --head jacobtheeldest:contrib/<short-name>
```

`duplicate` leaves the original commit in your master chain, so the fix stays in your image while the PR is in review.

## Guides

- [Build Scripts](build/README.md)
- [Homebrew/Brewfiles](custom/brew/-README.md)
- [Flatpak Preinstall](custom/flat-paks/README.md)
- [ujust Commands](custom/ujust/README.md)

---

*Forked from [projectbluefin/finpilot](https://github.com/projectbluefin/finpilot)*
