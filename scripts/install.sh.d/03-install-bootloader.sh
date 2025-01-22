#!/usr/bin/env bash

declare -r KERNEL_PARAM='rootflags="subvol=@" lsm=landlock,lockdown,yama,integrity,apparmor,bpf quiet splash loglevel=3 systemd.show_status=auto rd.udev.log_level=3 rw'
declare -r UUID=$(sudo blkid -o value -s UUID $(findmnt -n -o SOURCE $workdir | cut -d'[' -f1))

if [[ $OSI_USE_ENCRYPTION == 1 ]]; then
    # Add cmdline options
	echo "rd.luks.name=$UUID=$rootlabel root=/dev/mapper/$rootlabel $KERNEL_PARAM" | sudo tee -a "$workdir/etc/kernel/cmdline" || quit_on_err 'Failed to configure cmdline'

    # Change mkinitcpio hooks
	sudo sed -i '/^#/!s/HOOKS=(.*)/HOOKS=(systemd plymouth autodetect keyboard keymap consolefont modconf block sd-encrypt filesystems fsck)/g' "$workdir/etc/mkinitcpio.conf" || quit_on_err 'Failed to set hooks'
else
    # Add cmdline options
	echo "root=\"UUID=$UUID\" $KERNEL_PARAM" | sudo tee -a "$workdir/etc/kernel/cmdline" || quit_on_err 'Failed to configure cmdline'

    # Change mkinitcpio hooks
	sudo sed -i '/^#/!s/HOOKS=(.*)/HOOKS=(systemd plymouth autodetect keyboard keymap consolefont modconf block filesystems fsck)/g' "$workdir/etc/mkinitcpio.conf" || quit_on_err 'Failed to set hooks'
fi

# Configure UKI
# Comment default_image and uncomment #default_uki for build default UKI
sudo sed -i "s|default_image|#default_image|" "$workdir/etc/mkinitcpio.d/linux.preset"
sudo sed -i 's|#default_uki="/efi/EFI/Linux/arch-linux.efi"|default_uki="/efi/EFI/Linux/sunny-linux.efi"|' "$workdir/etc/mkinitcpio.d/linux.preset"

# Remove fallback initramfs
sudo sed -i "s|fallback_image|#fallback_image|" "$workdir/etc/mkinitcpio.d/linux.preset"

# Touch archlinux-logo.png for fix plymouth error
sudo touch "$workdir/usr/share/pixmaps/archlinux-logo.png"

# Generate the fstab file
sudo chmod 666 "$workdir/etc/fstab" || quit_on_err "Failed to change fstab permissions"
sudo genfstab -U "$workdir" > "$workdir/etc/fstab" || quit_on_err "Failed to generate fstab file"

# Install bootloader
if command -v efibootmgr &> /dev/null; then
    sudo arch-chroot "$workdir" pacman -S --noconfirm --needed efibootmgr os-prober || quit_on_err 'Failed to install efibootmgr and os-prober packages'
    sudo arch-chroot "$workdir" bootctl install || quit_on_err 'Failed to install Systemd-boot'
    sudo arch-chroot "$workdir" os-prober || quit_on_err 'Failed to execute os-prober'
    
    # Configure systemd-boot loader.conf
    echo -e "timeout 5\nconsole-mode max\neditor yes\nauto-entries yes\nauto-firmware yes" | sudo tee "$workdir/efi/loader/loader.conf" > /dev/null
else
    sudo arch-chroot "$workdir" pacman -S --noconfirm --needed grub grub-btrfs os-prober || quit_on_err
    sudo arch-chroot "$workdir" grub-install --target=i386-pc "${OSI_DEVICE_PATH}" || quit_on_err 'Failed to install GRUB for BIOS'
    sudo arch-chroot "$workdir" os-prober || quit_on_err 'Failed to execute os-prober'
    
    # Change GRUB config settings
    sudo sed -i 's|"Arch"|"SunnyOS"|g' "$workdir/etc/default/grub"
    sudo sed -i 's|"loglevel=3 quiet"|"quiet loglevel=3 splash udev.log_level=3"|g' "$workdir/etc/default/grub"
    
    # Write GRUB config
    sudo arch-chroot "$workdir" grub-mkconfig -o /boot/grub/grub.cfg || quit_on_err 'Failed to generate GRUB configuration'
fi
