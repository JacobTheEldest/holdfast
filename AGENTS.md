# Instructions for holdfast bootc Image

## CRITICAL: GitHub API Usage

**ALWAYS use GitHub API for external references** (other repos, upstream Containerfiles, etc). Use `github-mcp-server-get_file_contents` instead of `curl`/`wget`.

---

## Pre-Commit Checklist

Execute before **every** commit:

1. **Conventional Commits** — format: `<type>[scope]: <description>` (see Commit Convention below)
2. **Pre-commit hooks** — `pre-commit run --all-files` (yaml/json/toml + Brewfile validation)
3. **Mise validators** — `mise run validate:justfiles` (the canonical validator; CI runs the same)
4. **Shellcheck** — `shellcheck build/*.sh` on modified shell files (also covered by `mise run validate:shell-scripts`)
5. **Just syntax** — `just check` (or `just fix` to auto-format; `just --list` only prints recipes)
6. **Atomic commits** — one logical change per commit; use `jj` (jujutsu), not `git`
7. **Remote safety** — confirm with user before pushing

Never commit files with syntax errors.

---

## Repository Structure

```text
├── Containerfile                    # Multi-stage build definition (source of truth for base image, OCI imports, script runner)
├── Justfile                         # Local build automation
├── .config/mise/                    # mise tasks (canonical local validators at .config/mise/tasks/validate/)
├── .pre-commit-config.yaml          # Pre-commit hooks (yaml/json/toml + Brewfile validation)
├── .github/
│   └── workflows/                   # CI: build.yml, clean.yml, clean-pr-images.yml, renovate.yml, validate.yml
├── build/                           # Build-time scripts (see build/README.md)
│   └── helpers/copr.sh              # Sourced library; do not edit
├── cosign.pub                       # Cosign public key for image signature verification
├── custom/                          # Runtime customizations (post-deploy/first boot)
│   ├── brew/*.Brewfile              # Homebrew packages (default, development, fonts)
│   ├── flatpaks/*.preinstall        # Flatpak apps (installed post-first-boot)
│   └── ujust/*.just                 # User convenience commands (concatenated to 60-custom.just)
├── iso/                             # Local VM testing only (no CI/CD)
│   ├── disk.toml                    # BIB config for qcow2/raw (VM geometry)
│   ├── iso.toml                     # BIB config for installer ISO (update bootc switch URL before use)
│   └── rclone/                      # rclone config bundled into ISO
├── artifacthub-repo.yml             # ArtifactHub metadata
├── CLAUDE.md                        # Claude-specific entry; @AGENTS.md
├── LICENSE                          # Apache-2.0
├── README.md                        # User-facing deploy/customize docs
└── AGENTS.md                        # This file
```

---

## Core Principles

### Build-time vs Runtime

- **Build-time** (`build/`): baked into image via `dnf5 install`; services, system configs, packages
- **Runtime** (`custom/`): user-installed after deployment; Brewfiles, Flatpaks, ujust commands

### Inherited from the Base Image (`bluefin-dx:stable`)

These come from upstream and are not managed by this repo. Renovate bumps the `FROM` line in [`Containerfile`](Containerfile), but the contents float with whatever bluefin-dx ships per release — watch [projectbluefin/bluefin](https://github.com/ublue-os/bluefin) releases for breaking changes.

- **GNOME desktop + dconf settings, branding, terminal config** — from bluefin
- **`/usr/share/ublue-os/just/`** — bluefin ujust recipes (`apps`, `changelog`, `default`, `shared`, `system`, `update`, plus `00-entry.just` which `import?`s `60-custom.just`)
- **`/usr/share/ublue-os/homebrew/`** — bluefin Brewfiles (`ai-tools`, `cli`, `cncf`, `default`, `development`, `fonts`, `full-desktop`, `ide`, etc.)
- **Homebrew itself** at `/home/linuxbrew/.linuxbrew/`
- **Developer tooling** (DX-specific): podman, devcontainers, container CLI, VS Code integration
- **`uupd`** for automated updates (timer fires daily at 04:00)

Because the base already ships the above, the `COPY --from=ghcr.io/projectbluefin/common` and `COPY --from=ghcr.io/ublue-os/brew` lines in [`Containerfile`](Containerfile) are commented out — uncomment if rebasing on `silverblue-main`, `base-main`, or `centos-bootc`.

For tighter change visibility, pin the `FROM` to a digest (`@sha256:…`) so Renovate's PR title shows the exact upstream delta.

### Added by Holdfast (this repo)

- **`build/10-build.sh`**: `sshfs`, Ghostty (COPR), set Ghostty as default GNOME terminal, enable `podman.socket`, stage `custom/` files
- **`build/30-cosmic-desktop.sh`**: Add COSMIC desktop session, optionally remove GNOME (set `REMOVE_GNOME=true` in script)
- **`custom/brew/*.Brewfile`** → dropped into `/usr/share/ublue-os/homebrew/` alongside bluefin's
- **`custom/flatpaks/*.preinstall`** → `/etc/flatpak/preinstall.d/`
- **`custom/ujust/*.just`** → appended to `/usr/share/ublue-os/just/60-custom.just`

### Bluefin Convention Compliance

Always align with `@ublue-os/bluefin` patterns unless user explicitly approves deviation.

- `dnf5` only (never `dnf`, `yum`, `rpm-ostree`); always with `-y`
- COPR: use `copr_install_isolated` from `build/helpers/copr.sh` (enables, disables, installs with `--enablerepo`)
- Never use `dnf5` in ujust files
- Validate Flatpak IDs on <https://flathub.org/>

### Branch and Release Strategy

- `master` is production; never push directly
- Conventional commits required for all commits and PR titles
- Merging to master triggers stable image builds

---

## Quick Reference

| Request | Location | Notes |
| --- | --- | --- |
| Add system package | `build/10-build.sh` | `dnf5 install -y pkg` |
| Add runtime CLI tool | `custom/brew/default.Brewfile` | `brew "pkg"` or `tap` + `brew` for third-party |
| Add GUI app | `custom/flatpaks/default.preinstall` | Validate ID on Flathub first |
| Add user command | `custom/ujust/*.just` | No `dnf5`; group with `[group('Category')]` |
| Add third-party repo | New `build/20-*.sh` | Write `.repo` file, install, then `rm` it before the script exits |
| Add desktop session | New `build/30-*.sh` | See `30-cosmic-desktop.sh` for additive pattern |
| Switch base image | `Containerfile` | Update `FROM` line; alternatives listed in comments |
| Add OCI resources | `Containerfile` ctx stage | Add `COPY --from` lines |
| Enable service | `build/10-build.sh` | `systemctl enable service.name` |
| Test locally | Terminal | `just build && just build-qcow2 && just run-vm-qcow2` |

---

## File Modification Priority

When implementing customizations, prefer this order:

1. `build/*.sh` — build-time packages/services/config
2. `custom/brew/` — runtime CLI/dev tools
3. `custom/ujust/` — user convenience commands
4. `custom/flatpaks/` — GUI apps
5. `Containerfile` — base image, OCI imports, build architecture
6. `Justfile` — local build automation
7. `iso/*.toml` — local image testing (**critical:** update `bootc switch` URL in `iso/iso.toml` before use)
8. `.github/workflows/` — only when needed

### Do Not Modify (unless required)

`.github/renovate.json5`, `.github/workflows/validate-*.yml`, `build/helpers/copr.sh`, `cosign.pub`

### Modify with Extreme Caution

`.github/workflows/build.yml`, `.github/workflows/clean.yml`, `Justfile`

---

## Troubleshooting

| Symptom | Cause | Solution |
| --- | --- | --- |
| Build fails: permission denied | Signing misconfigured | Verify `SIGNING_SECRET` or disable signing |
| Build fails: package not found | Typo or missing repo | Verify package name; add repo/COPR |
| Build fails: base image not found | Invalid `FROM` | Check `Containerfile` |
| Build fails: shellcheck error | Script syntax | `shellcheck build/*.sh` |
| PR validation fails | Invalid Brewfile/Flatpak/justfile | Run local validation; check file syntax |
| COPR package missing at runtime | COPR not isolated | Use `copr_install_isolated` pattern |
| Flatpaks absent on first boot | Expected | Installed post-first-boot with internet |
| Third-party repo issues | Repo file persisted | Remove repo file after install in same script |

---

## Rules

1. Use Conventional Commits for all commits
2. Use `dnf5 -y` only (never `dnf`/`yum`/`rpm-ostree`)
3. Always disable COPRs after use (`copr_install_isolated`)
4. Never use `dnf5` in ujust files
5. Never push directly to `master`; confirm with user before any push
6. Run validation before committing
7. Be surgical: smallest maintainable change set possible

### Edit Collaboration

When you see discrepancies between expected file content and actual content, **ask for clarification before making assumptions**. The user may have intentionally made changes that differ from your expectations. Verify intent before modifying or "fixing" content.

---

## Commit Convention

Format: `<type>[scope]: <description>` — lowercase type, optional scope in parens, imperative present tense.

| Type | Use for |
| --- | --- |
| `feat` | New user-visible feature (package, ujust command, desktop session) |
| `fix` | Bug fix |
| `chore` | Tooling, deps, non-functional changes |
| `docs` | Documentation only |
| `refactor` | Restructuring without behavior change |
| `ci` | Workflow / Renovate / signing changes |
| `build` | Containerfile, Justfile, build scripts |

Scope examples: `cosmic`, `brew`, `flatpaks`, `containerfile`, `ci`, `renovate`.

## Resources

- [Bluefin patterns](https://github.com/ublue-os/bluefin) | [Contributing guide](https://docs.projectbluefin.io/contributing/)
- [bootc](https://github.com/containers/bootc) | [Conventional Commits](https://www.conventionalcommits.org/)
- [Flathub](https://flathub.org/) | [Homebrew](https://brew.sh/) | [Just](https://just.systems/)
- [Universal Blue](https://universal-blue.org/) | [Renovate](https://docs.renovatebot.com/)
