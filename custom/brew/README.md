# Brewfiles

Brewfile declarations staged into the image at `/usr/share/ublue-os/homebrew/` alongside the ones bluefin already ships.

| File | Purpose |
| --- | --- |
| [`default.Brewfile`](default.Brewfile) | always-installed CLI tools |
| [`development.Brewfile`](development.Brewfile) | editors, language runtimes, dev CLIs |
| [`fonts.Brewfile`](fonts.Brewfile) | Nerd Fonts |

Install on a deployed system via the `install-*` shortcuts in [`custom/ujust/custom-apps.just`](../ujust/custom-apps.just), or directly:

```bash
brew bundle --file /usr/share/ublue-os/homebrew/<file>.Brewfile
```

> Bundles run at first login (or whenever the user invokes `ujust`), not at build time.

> Homebrew lives in the user's writable storage, not the immutable image.

To add a new category, drop a `<name>.Brewfile` here and a matching `install-<name>` recipe in [`custom-apps.just`](../ujust/custom-apps.just).
