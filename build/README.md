# Build Scripts

Scripts for building the Holdfast container image, referenced by the [`Containerfile`](../Containerfile) during `podman build`.

## Layout

- **[`./`](./)** - every `*.sh` at this level is executed during image build by the loop in [`Containerfile`](../Containerfile), in shell-glob (alphanumeric) order. Each script documents its own purpose in a header comment.
- **[`helpers/`](helpers/)** - sourced libraries (not executed directly).

## Conventions

- Scripts run as root with `set -eoux pipefail`; build context is mounted at `/ctx`
- `dnf5 -y` only (no `dnf`, `yum`, `rpm-ostree`)
- For third-party packages, use [`copr_install_isolated`](helpers/copr.sh). See the helper file for details.

## Disabling a script

Rename so it doesn't match the glob pattern from the [`Containerfile`](../Containerfile) loop. (e.g. `99-example.sh` to `99-example.sh.disabled`)
