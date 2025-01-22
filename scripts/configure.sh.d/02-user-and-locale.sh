#!/usr/bin/env bash

# Set chosen locale and en_US.UTF-8 for it is required by some programs
echo "$OSI_LOCALE UTF-8" | sudo tee -a $workdir/etc/locale.gen || quit_on_err 'Failed to configure locale.gen'

if [[ $OSI_LOCALE != 'en_US.UTF-8' ]]; then
	echo "en_US.UTF-8 UTF-8" | sudo tee -a $workdir/etc/locale.gen || quit_on_err 'Failed to configure locale.gen with en_US.UTF-8'
fi

echo "LANG=\"$OSI_LOCALE\"" | sudo tee $workdir/etc/locale.conf || quit_on_err 'Failed to set default locale'

# Generate locales
sudo arch-chroot $workdir locale-gen || quit_on_err 'Failed to locale-gen'

# Get first name
declare firstname=($OSI_USER_NAME)
firstname=${firstname[0]}

# Add user, setup groups and set password
sudo arch-chroot $workdir useradd -m  -c "$OSI_USER_NAME" "${firstname,,}" || quit_on_err 'Failed to add user'
echo "${firstname,,}:$OSI_USER_PASSWORD" | sudo arch-chroot $workdir chpasswd || quit_on_err 'Failed to set user password'
sudo arch-chroot $workdir usermod -a -G wheel "${firstname,,}" || quit_on_err 'Failed to make user sudoer'

# Set root password
echo "root:$OSI_USER_PASSWORD" | sudo arch-chroot $workdir chpasswd || quit_on_err 'Failed to set root password'

# Set timezome
sudo arch-chroot $workdir ln -sf /usr/share/zoneinfo/$OSI_TIMEZONE /etc/localtime || quit_on_err 'Failed to set timezone'

# Set auto login if requested
if [[ $OSI_USER_AUTOLOGIN -eq 1 ]]; then
	if [[ $OSI_DESKTOP == gnome ]]; then
		sudo mkdir -p $workdir/etc/gdm
		printf "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=${firstname,,}\n" | sudo tee $workdir/etc/gdm/custom.conf || quit_on_err 'Failed to setup automatic login for user'
	elif [[ $OSI_DESKTOP == kde ]]; then
		sudo mkdir -p $workdir/etc/sddm.conf.d
		printf "[Autologin]\nUser=${firstname,,}\nSession=plasma\n" | sudo tee $workdir/etc/sddm.conf.d/autologin.conf || quit_on_err 'Failed to setup automatic login for user'
	elif [[ $OSI_DESKTOP == hyprland ]]; then
		sudo mkdir -p $workdir/etc/sddm.conf.d
		printf "[Autologin]\nUser=${firstname,,}\nSession=hyprland\n" | sudo tee $workdir/etc/sddm.conf.d/autologin.conf || quit_on_err 'Failed to setup automatic login for user'
	fi
fi
