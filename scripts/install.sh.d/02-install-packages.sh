#!/usr/bin/env bash

# Install basic system packages
sudo pacstrap "$workdir" base base-devel linux linux-firmware mkinitcpio || quit_on_err 'Failed to do pacstrap'

# Copy pacman.conf
sudo cp -rv "/etc/pacman.conf" "$workdir/etc/pacman.conf.new" || quit_on_err 'Failed to write pacman.conf.new'
sudo mv "$workdir/etc/pacman.conf.new" "$workdir/etc/pacman.conf" || quit_on_err 'Failed to write new pacman.conf'

# Install remaining packages
sudo arch-chroot "$workdir" pacman -S --noconfirm adw-gtk-theme application-cleaner bluez bluez-plugins bluez-utils btrfs-progs \
    dosfstools e2fsprogs exfatprogs f2fs-tools feather-branding feather-gnome-config flatpak fuse fwupd gdm git gnome \
    gnome-initial-setup gnome-shell-extension-advanced-tab-bar gnome-shell-extension-appindicator gnome-shell-extension-caffeine \
    gnome-shell-extension-dash-to-dock gnome-shell-extension-fly-pie gnome-shell-extension-just-perfection-desktop amd-ucode intel-ucode \
    gnome-shell-extension-rounded-corners gnome-shell-extension-rounded-window-corners gnome-shell-extension-tilingshell \
    gnome-shell-extension-wiggle grml-zsh-config gst-plugin-pipewire gst-plugins-base gst-plugins-good glibc-locales \
    ibus-typing-booster jfsutils lvm2 nano networkmanager networkmanager-openconnect networkmanager-openvpn noto-fonts noto-fonts-cjk \
    noto-fonts-emoji pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse plymouth podman power-profiles-daemon switcheroo-control \
    webp-pixbuf-loader wget wireplumber xdg-user-dirs-gtk xdg-utils xorg-server yai zsh || quit_on_err "Failed to install desktop environment packages"
