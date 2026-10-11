#!/bin/bash

set -ouex pipefail

### Install packages

# The base is Universal Blue's base-main: Fedora Atomic with no desktop, plus
# ublue's codecs (negativo17 fedora-multimedia), kernel, udev rules and ujust.

dnf5 -y group install virtualization --with-optional

# Desktop session essentials that base-main doesn't ship
dnf5 -y install \
		alacritty \
		bluez \
		gnome-keyring \
		gnome-keyring-pam \
		NetworkManager-wifi \
		pipewire \
		pipewire-pulseaudio \
		playerctl \
		power-profiles-daemon \
		upower \
		wireplumber \
		xdg-desktop-portal-gnome \
		xdg-desktop-portal-gtk \
		xdg-user-dirs

# nautilus is also the file chooser: xdg-desktop-portal-gnome, which niri's
# portal config uses for open/save dialogs, hands them to Nautilus.
dnf5 -y install \
		brightnessctl \
		cascadia-fonts-all \
		fastfetch \
		fprintd \
		fprintd-pam \
		google-noto-sans-fonts \
		google-noto-sans-mono-fonts \
		google-noto-serif-fonts \
		imv \
		jetbrains-mono-fonts-all \
		nautilus \
		noctalia \
		podman-compose \
		podman-machine \
		podman-tui \
		qt6ct \
		zsh \
		zsh-autosuggestions \
		zsh-syntax-highlighting

dnf5 -y copr enable yalter/niri
# Skip niri's recommends (waybar, swaylock, fuzzel...): Noctalia replaces them
# and the parts we need (alacritty, portals, keyring) are installed above.
dnf5 -y install --setopt=install_weak_deps=False niri xwayland-satellite
dnf5 -y copr disable yalter/niri

### Desktop: Noctalia shell + Noctalia greeter

# Noctalia provides the bar, notifications, launcher, lock screen, idle,
# wallpaper and polkit agent, so no separate tools for those are installed.

# Noctalia Greeter is only packaged in Terra; enable it just for this install.
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf5 -y install greetd greetd-selinux noctalia-greeter
sed -i "s/^enabled=1/enabled=0/" /etc/yum.repos.d/terra*.repo

### Branding

# Rebrand os-release (boot menu entries, installer, hostname) as aerinite.
# ID stays "fedora" so dnf, the bootloader tooling and anything checking for
# Fedora keep working; AERINITE_VERSION is passed in by CI.
VERSION="${AERINITE_VERSION:-local}"
sed -i \
    -e "s|^NAME=.*|NAME=\"Aerinite\"|" \
    -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Aerinite ${VERSION}\"|" \
    -e "s|^VERSION=.*|VERSION=\"${VERSION} (Fedora $(rpm -E %fedora) / Universal Blue base-main)\"|" \
    -e "s|^VARIANT_ID=.*|VARIANT_ID=aerinite|" \
    -e "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"aerinite\"|" \
    -e "s|^HOME_URL=.*|HOME_URL=\"https://github.com/tedohayer/aerinite\"|" \
    -e "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"https://github.com/tedohayer/aerinite#readme\"|" \
    -e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"https://github.com/tedohayer/aerinite/issues\"|" \
    -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"https://github.com/tedohayer/aerinite/issues\"|" \
    -e "/^REDHAT_/d" \
    /usr/lib/os-release
grep -q '^VARIANT_ID=' /usr/lib/os-release || echo 'VARIANT_ID=aerinite' >> /usr/lib/os-release
printf 'IMAGE_ID="aerinite"\nIMAGE_VERSION="%s"\n' "${VERSION}" >> /usr/lib/os-release
cat /usr/lib/os-release

### System files

# Config files live under system_files/ at their installed paths. Copied after
# all packages are installed so package defaults can't overwrite them.
cp -avf /ctx/system_files/. /

# Add the pam_systemd session line the greeter needs (upstream helper). It
# leaves a timestamped backup, which is junk in an image and changes the
# initramfs/unpackaged layer on every build, so remove it.
/usr/share/noctalia-greeter/setup_greetd_pam.sh
rm -f /etc/pam.d/greetd.bak.noctalia.*

# Log in with a password, not a fingerprint: the login password is what
# unlocks the keyring, and without it the keyring is stored unencrypted.
# password-auth is system-auth without pam_fprintd (what GDM uses), so
# fingerprint stays available for sudo and the lock screen.
sed -i 's/\bsystem-auth\b/password-auth/' /etc/pam.d/greetd
if grep -q -e system-auth -e pam_fprintd /etc/pam.d/greetd; then
	echo "greetd PAM still reaches pam_fprintd" >&2
	exit 1
fi

# Fingerprint auth for sudo and polkit prompts (login uses password-auth, above;
# the lock screen talks to fprintd itself). Installing fprintd-pam
# doesn't enable it; authselect has to add pam_fprintd to the PAM stacks.
authselect enable-feature with-fingerprint
grep -q pam_fprintd /etc/pam.d/system-auth

# Trust Aerinite's cosign key for ghcr.io/tedohayer/aerinite, so installs can
# use ostree-image-signed:docker:// and refuse unsigned or tampered images.
# (registries.d/aerinite.yaml in system_files fetches the signatures.)
install -Dm644 /ctx/cosign.pub /etc/pki/containers/aerinite.pub
python3 - <<'PY'
import json
p = "/etc/containers/policy.json"
policy = json.load(open(p))
policy["transports"].setdefault("docker", {})["ghcr.io/tedohayer/aerinite"] = [{
    "type": "sigstoreSigned",
    "keyPaths": ["/etc/pki/containers/aerinite.pub"],
    "signedIdentity": {"type": "matchRepository"},
}]
json.dump(policy, open(p, "w"), indent=4)
PY

glib-compile-schemas /usr/share/glib-2.0/schemas

# Boot splash: the Aerinite theme reuses the spinner theme's frames;
# --update=none keeps our watermark.png (from system_files) over Fedora's.
cp --update=none /usr/share/plymouth/themes/spinner/*.png /usr/share/plymouth/themes/aerinite/

systemctl enable aerinite-flatpak-preinstall.service
systemctl enable greetd.service
systemctl disable getty@tty1.service

# Rebuild the initramfs so the boot splash theme is in it (base-main's
# initramfs carries the default theme). Same invocation as Bluefin.
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | tail -1)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KVER}" --reproducible -v --add ostree \
    -f "/usr/lib/modules/${KVER}/initramfs.img"
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"
# (list to a file first: grep -q exiting early would SIGPIPE lsinitrd under pipefail)
lsinitrd "/usr/lib/modules/${KVER}/initramfs.img" > /tmp/initramfs-contents.txt
grep -q 'plymouth/themes/aerinite/watermark.png' /tmp/initramfs-contents.txt

dnf5 list --installed kernel
rpm -q waybar swaylock fuzzel || true

dnf5 clean all
