# ujust Commands

`ujust` is built on top of [just](https://github.com/casey/just), a command runner similar to `make` but designed for commands rather than builds. This directory contains Just recipe files that will be installed into your custom image and made available to end users via the `ujust` command.

`.just` files in this directory are concatenated and appended to `/usr/share/ublue-os/just/60-custom.just` at build time (see [`build/10-build.sh`](../../build/10-build.sh)). Bluefin's `00-entry.just` does `import? "60-custom.just"`, so these recipes show up under `ujust` alongside the bluefin ones. Add custom commands by editing the existing files or created new ones.

> Each file is commented to describe its purpose.

## Conventions

- Verb-prefix names (`install-`, `configure-`, `setup-`, `toggle-`, `fix-`) keep `ujust --list` discoverable.

## Testing

Build and switch to the local image (see [Local Testing](../../README.md#local-testing)), then `ujust <recipe>`. To dry-run a `.just` file without building:

```bash
just --justfile custom/ujust/custom-apps.just --list
just --justfile custom/ujust/custom-apps.just install-something
```

## Best Practices

> Commands run with user privileges by default. Use `sudo` or `pkexec` when root access needed.

### Naming Conventions

- Use lowercase with hyphens: `install-something`
- Use verb prefixes for clarity:
  - `install-` - Install something
  - `configure-` - Configure something pre-installed
  - `setup-` - Install + configure
  - `toggle-` - Enable/disable a feature
  - `fix-` - Apply a fix or workaround

### Command Structure

Group recipes with `[group('Category')]` so they cluster in `ujust --list`.

> Consider providing both install and uninstall options for reversible actions.

```just
# Brief description of what the command does
[group('Category')]
command-name:
    #!/usr/bin/bash
    # Use bash shebang for multi-line scripts
    # Commands go here
```

### Error Handling

```just
install-something:
    #!/usr/bin/bash
    set -euo pipefail  # Exit on error, undefined vars, pipe failures
    # Your commands
```

### User Prompts

Use `gum` for interactive prompts. Source `/usr/lib/ujust/ujust.sh` to get:

- `Choose()` - Present multiple choice menu
- `Confirm()` - Yes/no prompt
- Color variables: `${bold}`, `${normal}`, etc.

```just
interactive-command:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh  # Provides Choose() and other helpers
    OPTION=$(Choose "Option 1" "Option 2" "Cancel")
    echo "You chose: $OPTION"
```

## Resources

- [Just Manual](https://just.systems/man/en/)
- [Universal Blue Just Documentation](https://universal-blue.org/guide/just/)
- [Bluefin ujust Commands](https://docs.projectbluefin.io/administration)
- [gum Documentation](https://github.com/charmbracelet/gum)
