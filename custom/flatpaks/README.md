# Flatpak Preinstall

`.preinstall` files in this directory are copied to `/etc/flatpak/preinstall.d/` at build time and read by Flatpak on first boot after the user finishes initial setup and the network comes up. Add new apps into the existing files or create new ones. They are **not** baked into the image, so the first login takes a few minutes while Flathub installs land. During subsequent boots, Flatpak will skip already-installed apps and only install new ones from the preinstall files.

> Each file has is commented to describe its purpose.

## File Format

INI with `[Flatpak Preinstall <app-id>]` sections; see the [Flatpak preinstall reference](https://docs.flatpak.org/en/latest/flatpak-command-reference.html#flatpak-preinstall) for the full key list.

**Useful keys:**

```INI
Install=true # (boolean) Whether to install (default: true)
Branch=stable # (string) Branch name (default: "master", commonly "stable")
CollectionID=org.flathub.Stable # (string) Collection ID of the remote, if any
```

Find IDs with `flatpak search <app-name>` or browse Flathub: <https://flathub.org/>.

> Bluefin itself ships `bazaar.preinstall` at `/usr/share/flatpak/preinstall.d/`, so there's no need to list Bazaar here.

## References

- [Flatpak Documentation](https://docs.flatpak.org/)
- [Flatpak Preinstall Reference](https://docs.flatpak.org/en/latest/flatpak-command-reference.html#flatpak-preinstall)
