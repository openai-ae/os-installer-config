#!/usr/bin/env bash

if [[ $OSI_DESKTOP == gnome ]]; then
    # Update dconf
    sudo arch-chroot "$workdir" dconf update || quit_on_err 'Failed to update dconf'

    # Reinstall feather-branding (should fix logo in gdm)
    sudo arch-chroot "$workdir" pacman -S --noconfirm feather-branding || quit_on_err 'Failed to update feather-branding'
    sudo arch-chroot "$workdir" dconf update || quit_on_err 'Failed to update dconf'

    # Enable GDM
    sudo arch-chroot "$workdir" systemctl enable gdm || quit_on_err 'Failed to enable GDM'
elif [[ $OSI_DESKTOP == kde || $OSI_DESKTOP == hyprland ]]; then
    # Enable SDDM
    sudo arch-chroot "$workdir" systemctl enable sddm || quit_on_err 'Failed to enable SDDM'
fi
sudo arch-chroot "$workdir" systemctl enable NetworkManager || quit_on_err 'Failed to enable NetworkManager'
sudo arch-chroot "$workdir" systemctl enable switcheroo-control || quit_on_err 'Failed to enable switcheroo-control'
sudo arch-chroot "$workdir" systemctl enable bluetooth || quit_on_err 'Failed to enable bluetooth'
sudo arch-chroot "$workdir" systemctl enable systemd-timesyncd || quit_on_err 'Failed to enable systemd-timesyncd'
sudo arch-chroot "$workdir" systemctl enable systemd-oomd || quit_on_err 'Failed to enable systemd-oomd'
sudo arch-chroot "$workdir" systemctl enable cups || quit_on_err 'Failed to enable cups'
sudo arch-chroot "$workdir" systemctl enable apparmor || quit_on_err 'Failed to enable apparmor'
sudo arch-chroot "$workdir" systemctl enable fstrim.timer || quit_on_err 'Failed to enable fstrim.timer'
