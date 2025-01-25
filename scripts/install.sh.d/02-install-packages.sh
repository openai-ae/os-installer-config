#!/usr/bin/env bash

if [[ $OSI_DESKTOP == '' ]]; then
    quit_on_err "No one desktop environment choosed"
fi

# Install basic system packages
sudo pacstrap "$workdir" base linux linux-firmware mkinitcpio || quit_on_err 'Failed to install base packages'

# Copy pacman.conf
sudo cp -rv "/etc/pacman.conf" "$workdir/etc/pacman.conf.new" || quit_on_err 'Failed to write pacman.conf.new'
sudo mv "$workdir/etc/pacman.conf.new" "$workdir/etc/pacman.conf" || quit_on_err 'Failed to write new pacman.conf'

# Install remaining packages
sudo arch-chroot "$workdir" pacman -S --noconfirm application-cleaner bluez bluez-plugins bluez-utils btrfs-progs noto-fonts-cjk \
    dosfstools e2fsprogs exfatprogs f2fs-tools feather-branding flatpak fuse fwupd git switcheroo-control xdg-desktop-portal-gtk \
    grml-zsh-config gst-plugin-pipewire gst-plugins-base gst-plugins-good glibc-locales amd-ucode intel-ucode power-profiles-daemon \
    sudo sunny-keyring ibus-typing-booster jfsutils lvm2 nano networkmanager networkmanager-openconnect networkmanager-openvpn noto-fonts \
    noto-fonts-emoji pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse icoutils plymouth podman \
    webp-pixbuf-loader wget wireplumber xdg-user-dirs-gtk xdg-utils yai zsh || quit_on_err "Failed to install system packages"

# Install DE packages
if [[ $OSI_DESKTOP == gnome ]]; then
    # GNOME itself
    sudo arch-chroot "$workdir" pacman -S --noconfirm gnome xorg-server firefox || quit_on_err "Failed to install GNOME packages"
    
    # Feather customizations
    sudo arch-chroot "$workdir" pacman -S --noconfirm adw-gtk-theme feather-gnome-config \
        gnome-shell-extension-advanced-tab-bar gnome-shell-extension-appindicator gnome-shell-extension-caffeine \
        gnome-shell-extension-dash-to-dock gnome-shell-extension-fly-pie gnome-shell-extension-just-perfection-desktop \
        gnome-shell-extension-rounded-corners gnome-shell-extension-rounded-window-corners gnome-shell-extension-tilingshell \
        gnome-shell-extension-wiggle || quit_on_err "Failed to install GNOME customizations packages"

    sudo arch-chroot "$workdir" pacman -Rs --noconfirm epiphany yelp gnome-user-docs
elif [[ $OSI_DESKTOP == kde ]]; then
    sudo arch-chroot "$workdir" pacman -S --noconfirm plasma kdeconnect ffmpegthumbs dolphin-plugins \
    plymouth-kcm konsole krecorder ark filelight kde-system-meta kdenetwork-filesharing \
    kamoso elisa okular kimageformats kwin-effect-rounded-corners feather-plasma-config firefox || quit_on_err "Failed to install KDE packages"

elif [[ $OSI_DESKTOP == hyprland ]]; then
    sudo arch-chroot "$workdir" pacman -S --noconfirm hyprland sddm firefox kitty || quit_on_err "Failed to install Hyprland packages"
fi
