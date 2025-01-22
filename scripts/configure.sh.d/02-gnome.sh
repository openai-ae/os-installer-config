#!/usr/bin/env bash

# Update dconf
sudo arch-chroot "$workdir" dconf update || quit_on_err 'Failed to update dconf'

# Reinstall feather-branding (should fix logo in gdm)
sudo arch-chroot "$workdir" pacman -S --noconfirm feather-branding || quit_on_err 'Failed to update feather-branding'
sudo arch-chroot "$workdir" dconf update || quit_on_err 'Failed to update dconf'

# Enable services
sudo arch-chroot "$workdir" systemctl enable gdm || quit_on_err 'Failed to enable GDM'
sudo arch-chroot "$workdir" systemctl enable NetworkManager || quit_on_err 'Failed to enable NetworkManager'
sudo arch-chroot "$workdir" systemctl enable switcheroo-control || quit_on_err 'Failed to enable switcheroo-control'
sudo arch-chroot "$workdir" systemctl enable bluetooth || quit_on_err 'Failed to enable bluetooth'
