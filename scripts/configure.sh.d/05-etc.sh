#!/usr/bin/env bash

# Set custom keymap, very hacky but it gets the job done
declare -r current_keymap=$(gsettings get org.gnome.desktop.input-sources sources)
sudo mkdir -p "$workdir/etc/dconf/db/local.d"
printf "[org/gnome/desktop/input-sources]\nsources = %s\n" "$current_keymap" |
    sudo tee "$workdir/etc/dconf/db/local.d/keymap" ||
    quit_on_err 'Failed to set dconf keymap'

# Attempt to set vconsole keymap
data=${current_keymap#*(}
data=${data%%)*}
data=${data#*,}
data=${data//\'}
data=${data%%+*}
sudo localectl set-keymap "$data"
localctl_exit_code=$?
[[ $localctl_exit_code -ne 0 ]] && printf 'Failed to detect keymap, vconsole will default to US international\n'

# Update mkinitcpio config
sudo arch-chroot "$workdir" mkinitcpio -P || quit_on_err 'Failed to execute mkinitcpio'

# Uncomment wheel in sudoers
sudo sed -i "s|# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|g" "$workdir/etc/sudoers"
