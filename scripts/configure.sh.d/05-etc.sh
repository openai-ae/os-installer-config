#!/usr/bin/env bash

if [[ $OSI_DESKTOP == gnome ]]; then
    # Set custom keymap, very hacky but it gets the job done
    declare -r current_keymap=$(gsettings get org.gnome.desktop.input-sources sources)
    sudo mkdir -p "$workdir/etc/dconf/db/local.d"
    printf "[org/gnome/desktop/input-sources]\nsources = %s\n" "$current_keymap" |
        sudo tee "$workdir/etc/dconf/db/local.d/keymap" ||
        quit_on_err 'Failed to set dconf keymap'
fi

# Attempt to set vconsole keymap
data=${current_keymap#*(}
data=${data%%)*}
data=${data#*,}
data=${data//\'}
data=${data%%+*}
data=${data// /}
sudo localectl set-keymap "$data"
localctl_exit_code=$?
[[ $localctl_exit_code -ne 0 ]] && printf 'Failed to detect keymap, vconsole will default to US international\n' && sudo localectl set-keymap "us"

# Update mkinitcpio config
sudo arch-chroot "$workdir" mkinitcpio -P || quit_on_err 'Failed to execute mkinitcpio'

# Apply themes for KDE
if [[ $OSI_DESKTOP == kde ]]; then
    sudo mkdir -p "$workdir/etc/sddm.conf.d"
    printf "[Theme]\Current=breeze\n" | sudo tee "$workdir/etc/sddm.conf.d/theme.conf" || quit_on_err 'Failed to apply breeze SDDM theme'
    sudo mkdir -p "$workdir/etc/skel/.config"
    printf "[General]\nColorScheme=BreezeDark\n[KDE]\nLookAndFeelPackage=org.kde.breezedark.desktop" | sudo tee "$workdir/etc/skel/.config/kdeglobals" || quit_on_err 'Failed to apply Breeze Dark theme'
fi
