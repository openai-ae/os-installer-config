#!/usr/bin/env bash

# Generate the fstab file
sudo chmod 666 "$workdir/etc/fstab" || quit_on_err "Failed to change fstab permissions"
sudo genfstab -U "$workdir" > "$workdir/etc/fstab" || quit_on_err "Failed to generate fstab file"

# Install bootloader
if command -v efibootmgr &> /dev/null; then
    sudo arch-chroot "$workdir" pacman -S --noconfirm --needed efibootmgr os-prober || quit_on_err 'Failed to install efibootmgr and os-prober packages'
    sudo arch-chroot "$workdir" bootctl install || quit_on_err 'Failed to install Systemd-boot'
    sudo arch-chroot "$workdir" os-prober || quit_on_err 'Failed to execute os-prober'
    
    # Copy overlay-uefi
    for f in "${osidir}/overlay-uefi/"*; do
        sudo cp -rv "$f" "$workdir/" || quit_on_err 'Failed to copy uefi overlay'
    done
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
