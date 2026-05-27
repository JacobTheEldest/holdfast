# Holdfast

Holdfast is a personal Linux distribution based on [Universal Blue](https://universal-blue.org/) and [Bluefin](https://projectbluefin.io). It provides a stable, dependable foundation for development, experimentation, and daily use.

**Image:** `ghcr.io/jacobtheeldest/holdfast:stable`

## What's Included

- **Base:** [Bluefin DX](https://projectbluefin.io) (GNOME + developer tooling)
- **Desktop sessions:** GNOME and [COSMIC](https://system76.com/cosmic) — choose at the GDM login screen
- **Build-time packages:** Ghostty terminal, sshfs, and anything in [`build/`](build/) scripts
- **Runtime tools:** Homebrew packages ([`custom/brew/`](custom/brew/)), Flatpaks ([`custom/flatpaks/`](custom/flatpaks/)), ujust commands ([`custom/ujust/`](custom/ujust/))
- **CI/CD:** Automated builds, validation, image signing, SBOM generation, Renovate dependency updates

## Deploy

```bash
sudo bootc switch ghcr.io/jacobtheeldest/holdfast:stable
sudo systemctl reboot
```

## Customize

| What | Where |
| --- | --- |
| System packages | [`build/10-build.sh`](build/10-build.sh) — `dnf5 install -y pkg` |
| COPR packages | [`build/copr-helpers.sh`](build/copr-helpers.sh) — `copr_install_isolated "owner/repo" pkg` |
| Desktop sessions | [`build/30-cosmic-desktop.sh`](build/30-cosmic-desktop.sh) for the pattern |
| CLI tools (runtime) | [`custom/brew/*.Brewfile`](custom/brew/) |
| GUI apps (runtime) | [`custom/flatpaks/*.preinstall`](custom/flatpaks/) |
| User commands | [`custom/ujust/*.just`](custom/ujust/) |
| Base image / OCI imports | [`Containerfile`](Containerfile) |

All `build/[0-9]*-*.sh` scripts run automatically in alphanumeric order. See [`build/README.md`](build/README.md) for details.

## Development Workflow

1. Open a pull request — CI validates Brewfiles, Flatpaks, Justfiles, shell scripts, and builds a test image
2. Merge to `master` — triggers a `:stable` image build and push to GHCR
3. Renovate keeps base images, OCI imports, and Actions up to date automatically

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

## Production Setup

Image signing and SBOM attestation are configured in [`.github/workflows/build.yml`](.github/workflows/build.yml). To enable signing:

1. Generate keys: `cosign generate-key-pair`
2. Add `cosign.key` contents as the `SIGNING_SECRET` GitHub repository secret
3. Commit `cosign.pub` to the repo
4. Uncomment the signing steps in `build.yml`

Verify: `cosign verify --key cosign.pub ghcr.io/jacobtheeldest/holdfast:stable`

For image rechunking (5-10x smaller updates), see the [bootc documentation](https://containers.github.io/bootc/) and [zirconium-dev/zirconium](https://github.com/zirconium-dev/zirconium) for a working example.

## Guides

- [Build Scripts](build/README.md)
- [Homebrew/Brewfiles](custom/brew/README.md)
- [Flatpak Preinstall](custom/flatpaks/README.md)
- [ujust Commands](custom/ujust/README.md)

---

*Forked from [projectbluefin/finpilot](https://github.com/projectbluefin/finpilot)*
