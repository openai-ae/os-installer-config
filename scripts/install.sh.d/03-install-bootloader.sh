#!/usr/bin/env bash

# find root_partition (need for correct UUID with LUKS)
if [[ "${OSI_DEVICE_IS_PARTITION}" -eq 0 ]]; then
    if [[ $UEFI == true ]]; then
        root_partition="${partition_path}2"
    else
        root_partition="${partition_path}1"
    fi
else
    root_partition="${OSI_DEVICE_PATH}"
fi

# Find UUID
declare -r UUID=$(sudo blkid -o value -s UUID $root_partition)

declare -r BASE_KERNEL_PARAM='lsm=landlock,lockdown,yama,integrity,apparmor,bpf quiet splash loglevel=3 systemd.show_status=auto rd.udev.log_level=3 rw'

if [[ $UEFI == true ]]; then
    # Add cmdline options
    if [[ $OSI_USE_ENCRYPTION == 1 ]]; then
	    echo "rd.luks.name=$UUID=$rootlabel root=/dev/mapper/$rootlabel rootfstype=btrfs rootflags=subvol=@ $BASE_KERNEL_PARAM" | sudo tee -a "$workdir/etc/kernel/cmdline" || quit_on_err 'Failed to configure cmdline'
    else
	    echo "root=\"UUID=$UUID\" rootfstype=btrfs rootflags=subvol=@ $BASE_KERNEL_PARAM" | sudo tee -a "$workdir/etc/kernel/cmdline" || quit_on_err 'Failed to configure cmdline'
    fi

    # Configure UKI
    # Comment default_image and uncomment #default_uki for build default UKI
    sudo sed -i "s|default_image|#default_image|" "$workdir/etc/mkinitcpio.d/linux.preset"
    sudo sed -i 's|#default_uki="/efi/EFI/Linux/arch-linux.efi"|default_uki="/efi/EFI/Linux/sunny-linux.efi"|' "$workdir/etc/mkinitcpio.d/linux.preset"

    # Remove fallback initramfs
    sudo sed -i "s|fallback_image|#fallback_image|" "$workdir/etc/mkinitcpio.d/linux.preset"
fi

# Change mkinitcpio hooks
if [[ $OSI_USE_ENCRYPTION == 1 ]]; then
	sudo sed -i '/^#/!s/HOOKS=(.*)/HOOKS=(systemd plymouth microcode autodetect keyboard keymap consolefont modconf sd-vconsole block sd-encrypt filesystems fsck)/g' "$workdir/etc/mkinitcpio.conf" || quit_on_err 'Failed to set hooks'
else
    sudo sed -i '/^#/!s/HOOKS=(.*)/HOOKS=(systemd plymouth microcode autodetect keyboard keymap consolefont modconf block filesystems fsck)/g' "$workdir/etc/mkinitcpio.conf" || quit_on_err 'Failed to set hooks'
fi

# Generate the fstab file
sudo chmod 666 "$workdir/etc/fstab" || quit_on_err "Failed to change fstab permissions"
sudo genfstab -U "$workdir" > "$workdir/etc/fstab" || quit_on_err "Failed to generate fstab file"

# Install bootloader
if [[ $UEFI == true ]]; then
    sudo arch-chroot "$workdir" pacman -S --noconfirm --needed efibootmgr os-prober || quit_on_err 'Failed to install efibootmgr and os-prober packages'
    sudo arch-chroot "$workdir" bootctl install || quit_on_err 'Failed to install Systemd-boot'
    sudo arch-chroot "$workdir" os-prober || quit_on_err 'Failed to execute os-prober'
    
    # Configure systemd-boot loader.conf
    echo -e "timeout 5\nconsole-mode max\neditor yes\nauto-entries yes\nauto-firmware yes" | sudo tee "$workdir/efi/loader/loader.conf" > /dev/null
else
    sudo arch-chroot "$workdir" pacman -S --noconfirm --needed grub grub-btrfs os-prober || quit_on_err

    # Change GRUB config settings
    sudo sed -i 's|"Arch"|"SunnyOS"|g' "$workdir/etc/default/grub"
    sudo sed -i "s|\"loglevel=3 quiet\"|\"$BASE_KERNEL_PARAM\"|g" "$workdir/etc/default/grub"

    sudo arch-chroot "$workdir" grub-install --target=i386-pc "${OSI_DEVICE_PATH}" || quit_on_err 'Failed to install GRUB for BIOS'
    sudo arch-chroot "$workdir" os-prober || quit_on_err 'Failed to execute os-prober'
    sudo arch-chroot "$workdir" grub-mkconfig -o /boot/grub/grub.cfg || quit_on_err 'Failed to generate GRUB configuration'
fi
