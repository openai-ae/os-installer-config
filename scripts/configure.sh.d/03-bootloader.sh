#!/usr/bin/env bash

# Set kernel parameters in Systemd-boot based on if disk encryption is used or not
#
# This is the base string shared by all configurations
declare -r KERNEL_PARAM='lsm=landlock,lockdown,yama,integrity,apparmor,bpf quiet splash loglevel=3 systemd.show_status=auto rd.udev.log_level=3 rw'

# The kernel parameters have to be configured differently based upon if the
# user opted for disk encryption or not
if [[ $OSI_USE_ENCRYPTION == 1 ]]; then
	declare -r LUKS_UUID=$(sudo blkid -o value -s UUID ${OSI_DEVICE_PATH}2)
	echo "options rd.luks.name=$LUKS_UUID=$rootlabel root=/dev/mapper/$rootlabel rootflags=\"subvol=@\" $KERNEL_PARAM" | sudo tee -a $workdir/boot/loader/entries/sunny.conf || quit_on_err 'Failed to configure bootloader config'
	echo "options rd.luks.name=$LUKS_UUID=$rootlabel root=/dev/mapper/$rootlabel rootflags=\"subvol=@\" $KERNEL_PARAM" | sudo tee -a $workdir/boot/loader/entries/sunny-fallback.conf || quit_on_err 'Failed to configure bootloader fallback config'

	sudo sed -i '/^#/!s/HOOKS=(.*)/HOOKS=(systemd plymouth autodetect keyboard keymap consolefont modconf block sd-encrypt filesystems fsck)/g' $workdir/etc/mkinitcpio.conf || quit_on_err 'Failed to set hooks'
else
	echo "options root=\"LABEL=$rootlabel\" rootflags=\"subvol=@\" $KERNEL_PARAM" | sudo tee -a $workdir/boot/loader/entries/sunny.conf
	echo "options root=\"LABEL=$rootlabel\" rootflags=\"subvol=@\" $KERNEL_PARAM" | sudo tee -a $workdir/boot/loader/entries/sunny-fallback.conf

	sudo sed -i '/^#/!s/HOOKS=(.*)/HOOKS=(systemd plymouth autodetect keyboard keymap consolefont modconf block filesystems fsck)/g' $workdir/etc/mkinitcpio.conf || quit_on_err 'Failed to set hooks'
fi

# Update mkinitcpio
sudo touch "$workdir/usr/share/pixmaps/archlinux-logo.png" # For plymouth
sudo arch-chroot $workdir mkinitcpio -P || quit_on_err 'Failed to generate initramfs'
