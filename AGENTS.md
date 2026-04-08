# Instructions for holdfast bootc Image

## CRITICAL: GitHub API Usage

**ALWAYS use GitHub API for external references.**

- When researching other repositories (for example: `projectbluefin/distroless`, `ublue-os/bluefin`)
- When checking `Containerfile`s, build scripts, or configuration files outside this repo
- Use the `github-mcp-server-get_file_contents` tool instead of `curl`/`wget`
- This provides consistent, authenticated access and better error handling

---

## CRITICAL: Pre-Commit Checklist

Execute before **every** commit:

1. **Conventional Commits** - All commits must follow required format
2. **Shellcheck** - Run `shellcheck *.sh` on modified shell files
3. **YAML validation** - Run `python3 -c "import yaml; yaml.safe_load(open('file.yml'))"` on modified YAML
4. **Justfile syntax** - Run `just --list`
5. **Atomic commits** - One logical change per commit; use `jj` (jujutsu), not `git`
6. **Remote safety** - Confirm with the user before pushing or making remote changes

Never commit files with syntax errors.

### Required Conventional Commit Format

```text
<type>[optional scope]: <description>
```

Valid types include: `feat`, `fix`, `docs`, `chore`, `build`, `ci`, `refactor`, `test`.

Breaking changes: add `!` in header or use `BREAKING CHANGE:` footer.

Reference: `.github/commit-convention.md`

---

## Repository Structure

```text
├── Containerfile                    # Main build definition (multi-stage with OCI imports)
├── Justfile                         # Local build automation (image name, build commands)
├── build/                           # Build-time scripts
│   ├── 10-build.sh                  # Main build script
│   ├── 20-*.sh.example              # Example third-party repo scripts
│   ├── 30-*.sh.example              # Example desktop replacement scripts
│   ├── copr-helpers.sh              # COPR helper functions
│   └── README.md                    # Build scripts docs
├── custom/                          # Runtime customizations (post-deploy/first boot)
│   ├── brew/
│   │   ├── default.Brewfile
│   │   ├── development.Brewfile
│   │   ├── fonts.Brewfile
│   │   └── README.md
│   ├── flatpaks/
│   │   ├── default.preinstall
│   │   └── README.md
│   └── ujust/
│       ├── custom-apps.just
│       ├── custom-system.just
│       └── README.md
├── iso/                             # Local testing only (no CI/CD)
│   ├── disk.toml
│   ├── iso.toml
│   └── rclone/
├── .github/
│   ├── workflows/
│   │   ├── build.yml
│   │   ├── clean.yml
│   │   ├── renovate.yml
│   │   ├── validate-*.yml
│   │   └── ...
│   ├── copilot-instructions.md
│   ├── SETUP_CHECKLIST.md
│   ├── commit-convention.md
│   └── renovate.json5
├── .pre-commit-config.yaml
└── .gitignore
```

---

## Core Principles

### Build-time vs Runtime

- **Build-time** (`build/`): baked into image; use `dnf5 install`; services/system configs/packages
- **Runtime** (`custom/`): user-installed after deployment; Brewfiles/Flatpaks/user commands

### Bluefin Convention Compliance

Always align with `@ublue-os/bluefin` patterns unless user explicitly approves deviation.

- Use `dnf5` only (never `dnf`, `yum`, `rpm-ostree`)
- Use `-y` for non-interactive operations
- COPR flow: enable → install → **disable**
- Prefer `copr_install_isolated` helper pattern
- Keep numbered scripts (`10-*`, `20-*`, `30-*`)

### Branch and Release Strategy

- `master` is production only; never push directly
- Release Please handles testing→master merges
- Conventional commits are required for commit and PR titles
- Merging to main/master triggers stable builds

### Validation Workflows

PR checks include:

- `validate-shellcheck.yml`
- `validate-brewfiles.yml`
- `validate-flatpaks.yml`
- `validate-justfiles.yml`
- `validate-renovate.yml`

Fix validation errors before merge.

---

## Multi-Stage Build Architecture

This repository follows the `@projectbluefin/distroless` pattern.

### Architecture Layers

1. **Context stage (`ctx`)** combines:
   - local build scripts (`/build`)
   - local custom files (`/custom`)
   - OCI resources in isolated directories (`/oci/*`)
2. **Final image stage** starts from the chosen base image and runs mounted scripts

### Common Base Image Options

- `ghcr.io/ublue-os/silverblue-main:42` (default Fedora-based)
- `quay.io/centos-bootc/centos-bootc:stream10` (CentOS-based)

Other common alternatives:

- `ghcr.io/ublue-os/bluefin:stable`
- `ghcr.io/ublue-os/bazzite:stable`
- `ghcr.io/ublue-os/aurora:stable`
- `quay.io/fedora/fedora-bootc:42`

Tags: prefer `:stable` for reliability, `:latest` for bleeding edge; `-nvidia` variants may exist.

### OCI Container Resources

Primary OCI inputs used in `ctx` stage:

- `ghcr.io/ublue-os/base-main`
- `ghcr.io/projectbluefin/common`
- `ghcr.io/projectbluefin/branding`
- `ghcr.io/ublue-os/artwork`
- `ghcr.io/ublue-os/brew`

Why this matters:

- Avoids file conflicts via `/oci/*` subdirectories
- Supports modular shared components
- Renovate updates OCI tags/digests for reproducibility (every ~6 hours)

### Canonical Stage Pattern

```dockerfile
FROM scratch AS ctx

COPY build /build
COPY custom /custom
COPY --from=ghcr.io/ublue-os/base-main:latest /system_files /oci/base
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/projectbluefin/branding:latest /system_files /oci/branding
COPY --from=ghcr.io/ublue-os/artwork:latest /system_files /oci/artwork
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

```dockerfile
FROM ghcr.io/ublue-os/silverblue-main:latest

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build/10-build.sh
```

### Build Script Path Map

- Local scripts: `/ctx/build/`
- Local custom files: `/ctx/custom/`
- OCI base: `/ctx/oci/base/`
- OCI common: `/ctx/oci/common/`
- OCI branding: `/ctx/oci/branding/`
- OCI artwork: `/ctx/oci/artwork/`
- OCI brew: `/ctx/oci/brew/`

### Optional Additional OCI System Files

These are commonly left commented in template examples:

```dockerfile
COPY --from=ghcr.io/projectbluefin/common:latest /system_files/bluefin /files/bluefin
COPY --from=ghcr.io/projectbluefin/common:latest /system_files/shared /files/shared
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /files/brew
```

Use when you explicitly want additional Bluefin/shared files and copy from `/ctx/files/*` into system locations during build.

---

## Where to Add Packages and Customizations

### System Packages (Build-time)

Location: `build/10-build.sh`

Use for system utilities, services, and first-boot-required components.

```bash
dnf5 install -y vim git htop neovim tmux
```

### Homebrew Packages (Runtime)

Location: `custom/brew/*.Brewfile`

- `default.Brewfile` - general CLI tools
- `development.Brewfile` - development tools
- `fonts.Brewfile` - font packages

```ruby
brew "bat"
brew "eza"
brew "ripgrep"
brew "fd"
```

Users install via `ujust` shortcuts.

### Flatpak Applications (Runtime GUI)

Location: `custom/flatpaks/*.preinstall`

```ini
[Flatpak Preinstall org.mozilla.firefox]
Branch=stable

[Flatpak Preinstall com.visualstudio.code]
Branch=stable
```

Notes:

- Installed post-first-boot (not baked into container/ISO)
- Requires internet
- Validate IDs on <https://flathub.org/>

### ujust Commands

Location: `custom/ujust/*.just`

Rules:

- Never use `dnf5` in ujust commands
- Use these for Brewfile/Flatpak/system convenience flows
- Group commands with `[group('Category')]`

### Script Naming Convention

- `10-build.sh` (main first)
- `20-*.sh` (additional)
- `30-*.sh` (desktop swaps/advanced)
- `.example` suffix means template; rename to `.sh` to activate

---

## Quick Reference: Common User Requests

| Request | Action | Location |
| --- | --- | --- |
| Add package (build-time) | `dnf5 install -y pkg` | `build/10-build.sh` |
| Add package (runtime) | `brew "pkg"` | `custom/brew/default.Brewfile` |
| Add GUI app | `[Flatpak Preinstall org.app.id]` | `custom/flatpaks/default.preinstall` |
| Add user command | Create shortcut (no `dnf5`) | `custom/ujust/*.just` |
| Add third-party repo | Use example scripts | `build/20-*.sh.example` |
| Replace desktop | Use example script | `build/30-cosmic-desktop.sh.example` |
| Switch base image | Update `FROM` line | `Containerfile` |
| Add OCI containers | Uncomment/add `COPY --from` | `Containerfile` ctx stage |
| Enable service | `systemctl enable service.name` | `build/10-build.sh` |
| Test locally | `just build && just build-qcow2 && just run-vm-qcow2` | Terminal |
| Deploy production | `sudo bootc switch ghcr.io/user/repo:stable` | Terminal |
| Validate changes | Run local checks + PR workflows | `.github/workflows/validate-*.yml` |

---

## Detailed Workflow Patterns

### 1. Build Scripts (`build/`)

Pattern: numbered scripts run in order.

```bash
#!/usr/bin/env bash
set -euo pipefail

dnf5 install -y vim git htop neovim
systemctl enable podman.socket
```

### 2. Third-Party RPM Repositories

Typical flow:

1. Add GPG key/repo file
2. Install with `dnf5 install -y`
3. **Remove repo file** afterward

```bash
cat > /etc/yum.repos.d/google-chrome.repo << 'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

dnf5 install -y google-chrome-stable
rm -f /etc/yum.repos.d/google-chrome.repo
```

### 3. COPR Usage (Isolated)

Use helper functions and always disable COPRs after install.

```bash
source /ctx/build/copr-helpers.sh
copr_install_isolated "ublue-os/staging" package-name

copr_install_isolated "ryanabx/cosmic-epoch" \
  cosmic-session \
  cosmic-greeter \
  cosmic-comp
```

Note: Some historical examples refer to `copr-install-functions.sh`; current repo helper file is `build/copr-helpers.sh`.

### 4. Desktop Environment Replacement

See `build/30-cosmic-desktop.sh.example`.

Typical sequence:

1. Remove previous desktop components
2. Install new desktop (often via isolated COPR)
3. Configure DM/session
4. Set default target/session

### 5. ujust Command Pattern

```just
[group('Apps')]
install-default-apps:
    #!/usr/bin/env bash
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile
```

### 6. Local Testing Workflow

```bash
just build
just build-qcow2
just run-vm-qcow2
```

Alternative ISO flow:

```bash
just build
just build-iso
just run-vm-iso
```

### 7. Optional Pre-commit Hooks

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

---

## ISO and Disk Image Notes (`iso/`)

- Local testing only; no CI/CD deployment path
- `iso/disk.toml` for QCOW2/RAW VM images
- `iso/iso.toml` for installer ISO

**Critical:** update `bootc switch` URL in `iso/iso.toml` to the user’s actual repo/image.

```toml
[customizations.installer.kickstart]
contents = """
%post
bootc switch --mutate-in-place --transport registry ghcr.io/USERNAME/REPO:stable
%end
"""
```

Uploads can use `iso/rclone/` configs (Cloudflare R2, AWS S3, Backblaze B2, SCP, SFTP).

---

## Release Workflow and Tags

### Workflows

- `build.yml` builds stable images from `master`
- `renovate.yml` monitors and proposes dependency/base updates
- `clean.yml` removes old images
- `validate-*.yml` covers PR validation gates

### Tags

- `stable`
- `stable.YYYYMMDD`
- `YYYYMMDD`
- `vX.Y.Z` (Release Please)
- PR/testing: `pr-123`, `sha-abc123`

---

## Build Process and Contents

### Container Build Flow

1. Pull base image from `Containerfile`
2. Assemble `ctx` stage (`build/` + `custom/` + OCI resources)
3. Run build scripts in numeric order (`10`, then `20`, then `30`)
4. Lint final image (`bootc container lint`)
5. Push image to registry

### What Gets Included

Build-time:

- `dnf5` packages
- enabled systemd services
- copied custom files into system locations

Runtime:

- Homebrew package installs initiated by user
- Flatpak installs after first boot

Standard installed locations include:

- `/usr/share/ublue-os/homebrew/`
- `/usr/share/ublue-os/just/60-custom.just`
- `/etc/flatpak/preinstall.d/`

### Local vs CI

Local:

- Uses local podman
- Faster iteration
- Usually no signing

CI:

- GitHub runners
- Automated validation
- Optional signing
- Pushes to registry

### Layering Best Practices

- Group related `dnf5 install` commands
- Avoid install/remove churn in the same layer
- Clean up artifacts in same `RUN` where practical
- Use cache mounts for package manager workflows when applicable

---

## Advanced Topics

### `/opt` Immutability

If needed for workloads expecting immutable `/opt`, uncomment equivalent line in `Containerfile`:

```dockerfile
RUN rm /opt && mkdir /opt
```

### Multi-Architecture

- Local `just` supports host platform
- Many UBlue images support amd64/arm64
- Arm variant example suffix: `-arm64`
- Cross-arch builds require additional setup

### Custom Build Functions

Use helper patterns in repo helper scripts (for example `build/copr-helpers.sh`) and follow Bluefin conventions.

---

## File Modification Priority and Safety

When implementing user customizations, check in this order:

1. `build/10-build.sh` (build-time packages/services/config)
2. `custom/brew/` (runtime CLI/dev tools)
3. `custom/ujust/` (user convenience commands)
4. `custom/flatpaks/` (GUI apps)
5. `Containerfile` (base image/advanced)
6. `Justfile` (local build automation)
7. `iso/*.toml` (local image testing)
8. `.github/workflows/` (only when needed)

### Avoid Modifying Unless Required

- `.github/renovate.json5`
- `.github/workflows/validate-*.yml`
- `.gitignore`
- `build/copr-helpers.sh` (stable helper pattern)
- `LICENSE`
- `cosign.pub`

### Modify with Extreme Caution

- `.github/workflows/build.yml`
- `.github/workflows/clean.yml`
- `Justfile`

---

## Troubleshooting

| Symptom | Cause | Solution |
| --- | --- | --- |
| Build fails: permission denied | Signing misconfigured | Verify signing disabled or `SIGNING_SECRET` configured |
| Build fails: package not found | Typo/unavailable package | Verify package source/spelling; add proper repo/COPR |
| Build fails: base image not found | Invalid `FROM` | Check `Containerfile` base reference |
| Build fails: shellcheck error | Script syntax problem | Run `shellcheck build/*.sh` and fix |
| PR fails: Brewfile validation | Invalid brew syntax/package | Validate Brewfile and package names |
| PR fails: Flatpak validation | Invalid app ID | Confirm app ID on Flathub |
| PR fails: justfile validation | Invalid just syntax | Run `just --list` locally |
| Changes not in production | Wrong branch/workflow path | Merge via expected release flow |
| ISO missing customizations | Wrong bootc switch URL | Update `iso/iso.toml` bootc target |
| COPR package missing later | COPR persisted/disabled incorrectly | Use `copr_install_isolated` pattern |
| ujust command unavailable | Wrong install path | Ensure files are in `custom/ujust/` and copied to system path |
| Flatpaks absent initially | Expected behavior | Installed post-first-boot with internet |
| Local build fails | Environment mismatch | Use bootc-capable environment / podman |
| Renovate not opening PRs | Config issue | Validate `.github/renovate.json5` |
| Third-party repo issues | Repo file persisted | Remove repo file after install |

---

## Debugging Commands

### Local Build Debugging

```bash
podman build --log-level=debug .
shellcheck build/*.sh
podman run --rm -it ghcr.io/ublue-os/bluefin:stable bash
```

### Brewfile Debugging

```bash
brew bundle check --file custom/brew/default.Brewfile
brew bundle list --file custom/brew/default.Brewfile
```

### just Debugging

```bash
just --list
just --unstable --fmt --check -f custom/ujust/custom-apps.just
just --verbose install-default-apps
```

### CI Debugging

1. Open Actions tab
2. Open failed run
3. Expand failed step
4. Inspect logs

PR image testing:

```bash
podman pull ghcr.io/YOUR_USERNAME/YOUR_REPO:pr-123
podman run --rm -it ghcr.io/YOUR_USERNAME/YOUR_REPO:pr-123 bash
```

### Runtime Debugging

```bash
bootc status
systemctl list-units --failed
journalctl -b -p err
ujust --list
ls -la /usr/share/ublue-os/homebrew/
ls -la /etc/flatpak/preinstall.d/
```

Flatpak:

```bash
flatpak remotes
flatpak list
flatpak install -y flathub org.mozilla.firefox
```

Homebrew:

```bash
brew doctor
cat /usr/share/ublue-os/homebrew/default.Brewfile
brew install package-name
```

---

## Critical Rules (Enforced)

1. Always use Conventional Commits format
2. Never commit `cosign.key`
3. Always disable COPRs after use
4. Always use `dnf5` (never `dnf`/`yum`/`rpm-ostree`)
5. Always use `-y` for non-interactive install flows
6. Never use `dnf5` in `ujust` files
7. Always work on testing/non-production branch for development
8. Always rely on Release Please for testing→master promotion
9. Never push directly to `master`
10. Always confirm with user before deviating from Bluefin patterns
11. Always run shell/YAML/just validation before committing
12. Always follow numbered script conventions (`10-*`, `20-*`, `30-*`)
13. Always review `.example` scripts before creating new patterns
14. Always validate new Flatpak IDs on Flathub
15. Never change validation workflows without understanding PR impact
16. Be surgical: smallest maintainable change set possible

---

## Resources

- Bluefin patterns: <https://github.com/ublue-os/bluefin>
- Bluefin contributing guide: <https://docs.projectbluefin.io/contributing/>
- bootc docs: <https://github.com/containers/bootc>
- Conventional Commits: <https://www.conventionalcommits.org/>
- RPM Fusion: <https://mirrors.rpmfusion.org/>
- Flathub: <https://flathub.org/>
- Homebrew: <https://brew.sh/>
- Universal Blue: <https://universal-blue.org/>
- Renovate docs: <https://docs.renovatebot.com/>
- GitHub Actions docs: <https://docs.github.com/en/actions>
- Podman: <https://podman.io/>
- Just: <https://just.systems/>

---

**Last Updated**: 2025-11-14  
