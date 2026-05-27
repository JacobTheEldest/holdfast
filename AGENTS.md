# Instructions for holdfast bootc Image

## CRITICAL: GitHub API Usage

**ALWAYS use GitHub API for external references** (other repos, upstream Containerfiles, etc). Use `github-mcp-server-get_file_contents` instead of `curl`/`wget`.

---

## Pre-Commit Checklist

Execute before **every** commit:

1. **Conventional Commits** — format: `<type>[scope]: <description>`. See `.github/commit-convention.md`
2. **Shellcheck** — `shellcheck build/*.sh` on modified shell files
3. **YAML validation** — validate modified YAML files
4. **Justfile syntax** — `just --list`
5. **Atomic commits** — one logical change per commit; use `jj` (jujutsu), not `git`
6. **Remote safety** — confirm with user before pushing

Never commit files with syntax errors.

---

## Repository Structure

```text
├── Containerfile                    # Multi-stage build definition (source of truth for base image, OCI imports, script runner)
├── Justfile                         # Local build automation
├── build/                           # Build-time scripts (all [0-9]*-*.sh run in alphanumeric order)
│   ├── 10-build.sh                  # Main: packages, services, config
│   ├── 30-cosmic-desktop.sh         # COSMIC desktop (additive, alongside GNOME)
│   ├── *.sh.example                 # Templates — rename to .sh to activate
│   └── copr-helpers.sh              # COPR helper functions (sourced, not run directly)
├── custom/                          # Runtime customizations (post-deploy/first boot)
│   ├── brew/*.Brewfile              # Homebrew packages (default, development, fonts)
│   ├── flatpaks/*.preinstall        # Flatpak apps (installed post-first-boot)
│   └── ujust/*.just                 # User convenience commands
├── iso/                             # Local VM testing only (no CI/CD)
└── .github/workflows/               # CI: build.yml, clean.yml, renovate.yml, validate-*.yml
```

---

## Core Principles

### Build-time vs Runtime

- **Build-time** (`build/`): baked into image via `dnf5 install`; services, system configs, packages
- **Runtime** (`custom/`): user-installed after deployment; Brewfiles, Flatpaks, ujust commands

### Bluefin Convention Compliance

Always align with `@ublue-os/bluefin` patterns unless user explicitly approves deviation.

- `dnf5` only (never `dnf`, `yum`, `rpm-ostree`); always with `-y`
- COPR: use `copr_install_isolated` from `build/copr-helpers.sh` (enables, disables, installs with `--enablerepo`)
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
| Add third-party repo | New `build/20-*.sh` | See `.example` files for patterns |
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

`.github/renovate.json5`, `.github/workflows/validate-*.yml`, `build/copr-helpers.sh`, `cosign.pub`

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
7. Review `.example` scripts before creating new patterns
8. Be surgical: smallest maintainable change set possible

---

## Resources

- [Bluefin patterns](https://github.com/ublue-os/bluefin) | [Contributing guide](https://docs.projectbluefin.io/contributing/)
- [bootc](https://github.com/containers/bootc) | [Conventional Commits](https://www.conventionalcommits.org/)
- [Flathub](https://flathub.org/) | [Homebrew](https://brew.sh/) | [Just](https://just.systems/)
- [Universal Blue](https://universal-blue.org/) | [Renovate](https://docs.renovatebot.com/)
