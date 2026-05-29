# Build Scripts

Scripts in this directory are executed during image build by the loop in [`Containerfile`](../Containerfile):

```bash
for script in /ctx/build/[0-9]*-*.sh; do bash "${script}"; done
```

Only files matching `[0-9]*-*.sh` at the top level run; subdirectories (e.g. [`helpers/`](helpers/)) are for sourced libraries.

## Layout

- **`10-build.sh`** — base system: package installs, services, dconf, ujust/Brewfile/Flatpak file staging
- **`30-cosmic-desktop.sh`** — additive COSMIC desktop install (alongside GNOME) and display manager switch
- **`helpers/copr.sh`** — `copr_install_isolated` for COPR packages without persisting the repo

## Conventions

- `dnf5 -y` only (no `dnf`, `yum`, `rpm-ostree`)
- Use [`copr_install_isolated`](helpers/copr.sh) for COPR packages
- For raw third-party repos: write the `.repo` file, install, then `rm` it before the script exits (bootc images don't refresh repos at runtime)
- Scripts run as root with `set -eoux pipefail`; build context is mounted at `/ctx`

## Disabling a script

Rename it to drop the `[0-9]*-*.sh` pattern (e.g. `30-cosmic-desktop.sh` → `_30-cosmic-desktop.sh`). `chmod -x` and `.disabled` suffixes don't work — the loop invokes `bash "${script}"` and matches by glob.
