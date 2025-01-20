#!/usr/bin/env bash

declare -r workdir='/mnt'
declare -r osidir='/etc/os-installer'

quit_on_err () {
	if [[ -n $1 ]]; then
		printf "$1\n"
	fi

	# Ensure console prints error
	sleep 2

	exit 1
}

# Copy overlay to new root
# For some reason this script dislikes catchalls, thus we are using a loop instead
for f in $(ls $osidir/overlay); do
	sudo cp -rv $osidir/overlay/$f $workdir/ || quit_on_err 'Failed to copy overlay'
done

# Update dconf
sudo arch-chroot "$workdir" dconf update || quit_on_err 'Failed to update dconf'

# Reinstall feather-branding (should fix logo in gdm)
sudo arch-chroot "$workdir" pacman -S --noconfirm feather-branding || quit_on_err 'Failed to update feather-branding'
sudo arch-chroot "$workdir" dconf update || quit_on_err 'Failed to update dconf'

# Set custom keymap, very hacky but it gets the job done
declare -r current_keymap=$(gsettings get org.gnome.desktop.input-sources sources)
sudo mkdir -p $workdir/etc/dconf/db/local.d
printf "[org/gnome/desktop/input-sources]\nsources = $current_keymap\n" |
	sudo tee $workdir/etc/dconf/db/local.d/keymap ||
	quit_on_err 'Failed to set dconf keymap'

# Attempt to set vconsole keymap
data=${current_keymap#*(}
data=${data%%)*}
data=${data#*,}
data=${data//\'}
data=${data%%+*}

sudo localectl set-keymap $data
localctl_exit_code=$?
[[ $localctl_exit_code -ne 0 ]] && printf 'Failed to detect keymap, vconsole will default to US international'

sudo arch-chroot "$workdir" mkinitcpio -P || quit_on_err 'Failed to execute mkinitcpio'

sudo arch-chroot "$workdir" exit

exit 0
