# Holdfast

Holdfast is a personal Linux distribution based on [Universal Blue](https://universal-blue.org/) and [Bluefin](https://projectbluefin.io). It provides a stable, dependable foundation for development, experimentation, and daily use.

| Variant | Image |
| --- | --- |
| Base | `ghcr.io/jacobtheeldest/holdfast:stable` |
| NVIDIA (open drivers) | `ghcr.io/jacobtheeldest/holdfast-nvidia-open:stable` |

## What's Included

- **Base:** [Bluefin DX](https://projectbluefin.io) (GNOME + developer tooling)
- **Desktop sessions:** GNOME and [COSMIC](https://system76.com/cosmic) — choose at the login screen (cosmic-greeter)
- **Build-time packages:** Ghostty terminal, sshfs, and anything in [`build/`](build/) scripts
- **Runtime tools:** Homebrew packages ([`custom/brew/`](custom/brew/)), Flatpaks ([`custom/flatpaks/`](custom/flatpaks/)), ujust commands ([`custom/ujust/`](custom/ujust/))
- **CI/CD:** Automated builds, validation, image signing, SBOM generation, Renovate dependency updates

## Deploy

```bash
sudo bootc switch ghcr.io/jacobtheeldest/holdfast:stable
sudo systemctl reboot
```

## Updates

Automatic updates are handled by [uupd](https://github.com/ublue-os/uupd) (from the Bluefin base). It runs daily at 4 AM, stages image + Flatpak + Homebrew updates, and applies them on next reboot.

| Task | Command |
| --- | --- |
| Check for image update | `uupd update-check` |
| Update everything (image + flatpaks + brew) | `ujust update` |
| Update and reboot | `ujust update-and-reboot` |
| Toggle automatic updates | `ujust toggle-updates` |
| Check current image status | `sudo bootc status` |

## Customize

| What | Where |
| --- | --- |
| System packages | [`build/10-build.sh`](build/10-build.sh) — `dnf5 install -y pkg` |
| COPR packages | [`build/helpers/copr.sh`](build/helpers/copr.sh) — `copr_install_isolated "owner/repo" pkg` |
| Desktop sessions | [`build/30-cosmic-desktop.sh`](build/30-cosmic-desktop.sh) for the pattern |
| CLI tools (runtime) | [`custom/brew/*.Brewfile`](custom/brew/) |
| GUI apps (runtime) | [`custom/flatpaks/*.preinstall`](custom/flatpaks/) |
| User commands | [`custom/ujust/*.just`](custom/ujust/) |
| Base image / OCI imports | [`Containerfile`](Containerfile) |

All `build/[0-9]*-*.sh` scripts run automatically in alphanumeric order. See [`build/README.md`](build/README.md) for details.

## Development Workflow

1. Open a pull request: `gh pr create --base master --fill`. CI validates Brewfiles, Flatpaks, Justfiles, shell scripts, and builds a test image.
2. Merge to `master`: `gh pr merge --auto --merge`. Triggers a `:stable` image build and push to GHCR.

`master` is protected and auto-merge is enabled, so PRs land as soon as checks pass. Renovate keeps base images, OCI imports, and Actions up to date automatically.

## Syncing Upstream Template

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

## Contributing Upstream

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

## Local Testing

```bash
just build              # Build container image
just build-qcow2        # Build VM disk image
just run-vm-qcow2       # Test in browser-based VM
```

## Architecture

Follows the [Bluefin multi-stage build pattern](https://docs.projectbluefin.io/contributing/). See [`Containerfile`](Containerfile) for the full definition.

1. **Context stage (`ctx`)** — assembles local `build/` and `custom/` files with OCI resources from `@projectbluefin/common` and `@ublue-os/brew`
2. **Final stage** — starts from `bluefin-dx:stable`, mounts the context, and runs all numbered build scripts

## Image Signing

Images are signed with [cosign](https://github.com/sigstore/cosign) on every push to `master`, using the `SIGNING_SECRET` repository secret. The public key is committed at [`cosign.pub`](cosign.pub).

Verify a pulled image:

```bash
cosign verify --key cosign.pub ghcr.io/jacobtheeldest/holdfast:stable
```

SBOM attestation is scaffolded in [`build.yml`](.github/workflows/build.yml) but currently disabled.

## Guides

- [Build Scripts](build/README.md)
- [Homebrew/Brewfiles](custom/brew/README.md)
- [Flatpak Preinstall](custom/flatpaks/README.md)
- [ujust Commands](custom/ujust/README.md)

---

*Forked from [projectbluefin/finpilot](https://github.com/projectbluefin/finpilot)*
