#!/usr/bin/env bash

if pacman -Q gnome-shell &>/dev/null; then # if GNOME iso used
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
    data=${data// /}

    sudo localectl set-keymap $data
    localctl_exit_code=$?

    [[ $localctl_exit_code -ne 0 ]] && printf 'Failed to detect keymap, vconsole will default to US international'
    [[ $localctl_exit_code -eq 0 ]] && sudo cp /etc/vconsole.conf "$workdir/etc/vconsole.conf" || quit_on_err 'Failed to setup vconsole keymap'
else
    printf "KEYMAP=us\n" | sudo tee "$workdir/etc/vconsole.conf" || quit_on_err 'Failed to setup vconsole keymap' # Set us keymap (somehow it's not set by default)
fi
# Update mkinitcpio config
sudo arch-chroot "$workdir" mkinitcpio -P || quit_on_err 'Failed to execute mkinitcpio'
