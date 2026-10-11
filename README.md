<p align="center">
  <img src="assets/aerinite-lockup.svg" alt="Aerinite" width="420">
</p>

A minimal [bootc](https://github.com/bootc-dev/bootc) desktop image: the [niri](https://github.com/YaLTeR/niri) scrollable-tiling compositor with [Noctalia](https://github.com/noctalia-dev/noctalia) as the shell, built on Universal Blue's [`base-main`](https://github.com/ublue-os/main) (Fedora Atomic with no desktop, plus ublue's codecs, kernel, udev rules and `ujust`).

![Aerinite: niri with the Noctalia bar, Alacritty running fastfetch, and Godot](assets/screenshot.png)

## Status

Aerinite is in alpha and is currently built for my personal use. It's what I run
day to day, so it's kept working, but there's no stability promise between builds.
Feel free to use it, fork it, or borrow from it.

## Philosophy

Aerinite is minimal: [niri](https://github.com/YaLTeR/niri) and [Noctalia](https://github.com/noctalia-dev/noctalia), and little else.

niri is a scrollable-tiling compositor. Windows sit in columns on an endless horizontal strip, so opening a new window never squeezes the ones you already have; you scroll to it instead. Noctalia is a complete desktop shell on top of it, covering the bar, notifications, launcher, lock screen, wallpaper and settings.

Aerinite aims to be unopinionated: it ships sensible defaults, everything can be overridden, and it avoids changes that break existing workflows wherever possible. The goal is a stable platform with minimal changes.

This isn't a new distro. It's just Fedora Atomic, where the whole system ships as
one read-only image. [Universal Blue](https://universal-blue.org) builds on that
image to add codecs and hardware support. Aerinite is a thin layer on top of
Universal Blue. Like other Universal Blue images, it stays out of your way:

- **Updates happen in the background.** New images are built automatically and downloaded quietly, then take effect on your next reboot. Each update is a complete, signed image applied in one step. If something goes wrong, the previous version is still in the boot menu.
- **Apps live in containers.** Desktop apps are Flatpaks from Flathub, and development tools run in Distrobox containers, so the base system stays small and untouched.

## What you get

- **Desktop**: niri + Noctalia (bar, notifications, launcher, lock screen, idle, wallpaper, polkit agent), Alacritty, Nautilus (also the file chooser for open/save dialogs), imv
- **Login**: [Noctalia Greeter](https://github.com/noctalia-dev/noctalia-greeter)
- **Shell**: zsh with autosuggestions and syntax highlighting
- **Containers & VMs**: podman (+ compose, machine, tui) and the virtualization group; distrobox comes with base-main
- **Flatpaks**: Firefox and the [Bazaar](https://github.com/kolunmi/bazaar) app store from Flathub, installed on first boot via `flatpak preinstall` (uninstalling one opts out). Like any preinstall list, this also removes apps that a previous OS preinstalled and Aerinite doesn't list; apps you installed yourself are left alone
- **Hardware**: fprintd with fingerprint auth for sudo and the lock screen, brightnessctl, playerctl, power-profiles-daemon
- **Fonts**: Cascadia, JetBrains Mono, Google Noto

Codecs come from base-main (negativo17 fedora-multimedia). The rpm Firefox and niri's recommended extras (waybar, swaylock, fuzzel) are not installed.

## Install

### From an existing Fedora Atomic or Universal Blue system

Any Fedora Atomic desktop or Universal Blue image works as a starting point. Your current system doesn't have Aerinite's signing key yet, so the first switch can't verify the image:

```bash
sudo bootc switch ghcr.io/tedohayer/aerinite:latest
sudo reboot
```

Aerinite includes its key. Once you've booted into it, switch again with verification on:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tedohayer/aerinite:latest
```

From then on, every update is checked against the key before it's installed. Your system will only accept images built and signed by Aerinite's own build pipeline, so a tampered or substituted image is refused.

### Installer ISO

The **Build disk images** workflow (Actions tab, run manually) builds an installer ISO and a qcow2 VM image from the latest published image and attaches them to the run. The ISO is made with image-builder's `bootc-generic-iso`: `installer/Containerfile` defines the Aerinite-branded Anaconda installer environment, and the Aerinite image is embedded in the ISO, so installs work offline. The installer creates your user, then points the system at `ghcr.io/tedohayer/aerinite:latest` with signature enforcement. `just build-iso` builds the same ISO locally (needs sudo).

## Updating

Updates are pulled from `ghcr.io/tedohayer/aerinite:latest` and checked against Aerinite's signing key. ublue's update service (`rpm-ostreed-automatic`) stages them automatically; to update by hand, run `rpm-ostree upgrade` (no sudo needed; `--preview` shows the package changes first) or `sudo bootc upgrade`, then reboot. CI rebuilds whenever `base-main` changes, every Sunday (to pick up niri, Noctalia and greeter updates), and on every push to `main`.

### Versions and tags

Versions follow Universal Blue's scheme. Each build gets:

| Tag | Example | Use |
|---|---|---|
| `latest` | | Newest build; what installs follow by default |
| Fedora major | `44` | Newest build on that Fedora release; pin to it to choose when to move to the next one |
| Build | `44-20261008`, `44-20261008.1` | One specific build: Fedora major, UTC date, and a counter for later builds that day. Never overwritten |
| `beta` | | Newest build from the `beta` branch |
| Beta build | `beta-45-20261010` | One specific beta build |

The image's `org.opencontainers.image.version` label holds the dotted form (`44.20261008.1`). Every build also gets a [GitHub release](https://github.com/tedohayer/aerinite/releases) with the commits since the previous build and the base image it was built on.

The Fedora release comes from `BASE_IMAGE` in the `Containerfile`; moving to the next one is a one-line change there.

The beta channel is for testing larger changes before they reach `latest`, like the move to a new version of Fedora, and may break. Beta builds are published as prereleases. To try it, and to go back:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tedohayer/aerinite:beta
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tedohayer/aerinite:latest
```

## Configuration

The image ships defaults; anything in your home directory overrides them.

| What | Image default | Your overrides |
|---|---|---|
| niri | `/etc/niri/config.kdl` (from `system_files/etc/niri/config.kdl`), used when you have no config of your own | `~/.config/niri/config.kdl` starting with `include "/etc/niri/config.kdl"`, followed by your changes |
| Noctalia | `/usr/share/aerinite/noctalia.toml` (from `system_files/usr/share/aerinite/noctalia.toml`), linked into `~/.config/noctalia/00-image.toml` at login | `~/.config/noctalia/config.toml`. Changes made in Noctalia's settings window are saved to `~/.local/state/noctalia/settings.toml` |
| Greeter | `/etc/noctalia-greeter/greeter.toml` | Edit that file |
| GTK | Close button only, dark style (`zz0-aerinite.gschema.override`) | `gsettings set ...` |

To change the image itself, edit `build_files/build.sh` (packages and setup commands) or the config files under `system_files/` (laid out at their installed paths), and push to `main`.

## Verifying images

Images are signed with [cosign](https://github.com/sigstore/cosign). The public key is `cosign.pub` in this repo and `/etc/pki/containers/aerinite.pub` in the image:

```bash
cosign verify --key cosign.pub ghcr.io/tedohayer/aerinite:latest
```

## Building locally

```bash
just build          # builds localhost/aerinite:latest
just build-qcow2    # VM image via bootc-image-builder
just build-iso      # installer ISO
```

`just --list` shows everything else.

## Credits

Based on [fedora-atomic-niri](https://github.com/rgerardi/fedora-atomic-niri) and [ublue-os/image-template](https://github.com/ublue-os/image-template).
