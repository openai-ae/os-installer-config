#!/usr/bin/env bash

# Declare base packages
declare -a pkgs=(
    apparmor application-cleaner bluez bluez-cups bluez-plugins bluez-utils btrfs-progs cups noto-fonts-cjk
    exfatprogs f2fs-tools feather-branding flatpak fuse fwupd git switcheroo-control
    xdg-desktop-portal-gtk starship gst-plugin-pipewire gst-plugins-base gst-plugins-good
    glibc-locales amd-ucode intel-ucode power-profiles-daemon sudo sunny-keyring
    ibus-typing-booster jfsutils lvm2 nano networkmanager networkmanager-openconnect
    networkmanager-openvpn noto-fonts noto-fonts-emoji pipewire pipewire-alsa
    pipewire-audio pipewire-jack pipewire-pulse icoutils plymouth podman webp-pixbuf-loader
    wget wireplumber xdg-user-dirs-gtk xdg-utils yai ayhell zsh
)

# Declare packages for remove
declare -a remove_pkgs=()

case "$OSI_DESKTOP" in
    gnome)
        pkgs+=(
            gnome xorg-server firefox adw-gtk-theme feather-gnome-config
            gnome-shell-extension-advanced-tab-bar gnome-shell-extension-appindicator
            gnome-shell-extension-caffeine gnome-shell-extension-dash-to-dock
            gnome-shell-extension-fly-pie gnome-shell-extension-just-perfection-desktop
            gnome-shell-extension-rounded-corners gnome-shell-extension-rounded-window-corners
            gnome-shell-extension-tilingshell gnome-shell-extension-wiggle
        )
        remove_pkgs+=(epiphany yelp gnome-user-docs)
        ;;
    kde)
        pkgs+=(
            plasma kdeconnect ffmpegthumbs dolphin-plugins plymouth-kcm konsole
            krecorder ark filelight kde-system-meta kdenetwork-filesharing
            kate spectacle kamoso elisa okular kimageformats kwin-effect-rounded-corners
            feather-plasma-config firefox kaccounts-providers
        )
        ;;
    hyprland)
        pkgs+=(hyprland sddm firefox kitty)
        ;;
esac

if [[ ${#pkgs[@]} -gt 0 ]]; then
    sudo arch-chroot "$workdir" pacman -S --noconfirm "${pkgs[@]}" || quit_on_err "Failed to install packages"
fi

if [[ ${#remove_pkgs[@]} -gt 0 ]]; then
    sudo arch-chroot "$workdir" pacman -Rs --noconfirm "${remove_pkgs[@]}" || quit_on_err "Failed to remove packages"
fi
