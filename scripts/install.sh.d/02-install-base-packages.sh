#!/usr/bin/env bash

if [[ $OSI_DESKTOP == '' ]]; then
    quit_on_err "No one desktop environment choosed"
fi

# Install base
sudo pacstrap "$workdir" base linux linux-firmware dosfstools e2fsprogs btrfs-progs || quit_on_err 'Failed to install base packages'

# Copy pacman.conf
sudo cp -v "/etc/pacman.conf" "$workdir/etc/pacman.conf.new" || quit_on_err 'Failed to write pacman.conf.new'
sudo mv "$workdir/etc/pacman.conf.new" "$workdir/etc/pacman.conf" || quit_on_err 'Failed to write new pacman.conf'
