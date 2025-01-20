#!/usr/bin/env bash

declare -r workdir='/mnt'
declare -r osidir='/etc/os-installer'
declare -r rootlabel='sunny_root'

# Function used to quit and notify user or error
quit_on_err () {
	if [[ -n $1 ]]; then
		printf "$1\n"
	fi

	# Ensure console prints error
	sleep 2

	exit 1
}

if [ $OSI_DEVICE_IS_PARTITION -eq 1]; then
    quit_on_err 'Installing to a partition currently not supported'
fi

# Write partition table to the disk
if efibootmgr &>/dev/null; then
    sudo sfdisk $OSI_DEVICE_PATH < "$osidir/bits/gpt.sfdisk" || quit_on_err 'Failed to write GPT partition table'
else
    sudo sfdisk $OSI_DEVICE_PATH < "$osidir/bits/mbr.sfdisk" || quit_on_err 'Failed to write MBR partition table'
fi

# NVMe drives follow a slightly different naming scheme to other block devices
# this will change `/dev/nvme0n1` to `/dev/nvme0n1p` for easier parsing later
if [[ $OSI_DEVICE_PATH == *"nvme"*"n"* ]]; then
	declare -r partition_path="${OSI_DEVICE_PATH}p"
else
	declare -r partition_path="${OSI_DEVICE_PATH}"
fi

# Create filesystems
if [[ $OSI_USE_ENCRYPTION -eq 1 ]]; then
	sudo mkfs.fat -F32 -n "sunny_esp" ${partition_path}1 || quit_on_err 'Failed to format EFI partition'
	echo $OSI_ENCRYPTION_PIN | sudo cryptsetup -q luksFormat ${partition_path}2 || quit_on_err 'Failed to format encrypted partition'
	echo $OSI_ENCRYPTION_PIN | sudo cryptsetup open ${partition_path}2 sunny_root || quit_on_err 'Failed to open encrypted partition'
	sudo mkfs.btrfs -f -L sunny_root /dev/mapper/sunny_root || quit_on_err 'Failed to format root filesystem'
	sudo mount -o noatime,compress=zstd:1,discard=async /dev/mapper/sunny_root "$workdir" || quit_on_err 'Failed to mount root filesystem'
	sudo mount --mkdir ${partition_path}1 "$workdir/boot" || quit_on_err 'Failed to mount boot partition'
else
	sudo mkfs.fat -F32 -n "sunny_esp" ${partition_path}1 || quit_on_err 'Failed to format EFI partition'
	sudo mkfs.btrfs -f -L sunny_root ${partition_path}2 || quit_on_err 'Failed to format root filesystem'
	sudo mount -o noatime,compress=zstd:1,discard=async ${partition_path}2 "$workdir" || quit_on_err 'Failed to mount root filesystem'
	sudo mount --mkdir ${partition_path}1 "$workdir/boot" || quit_on_err 'Failed to mount boot partition'
fi

# Install basic system packages
sudo pacstrap "$workdir" base base-devel linux linux-firmware mkinitcpio || quit_on_err 'Failed to do pacstrap'

# Copy pacman.conf
sudo cp -rv "/etc/pacman.conf" "$workdir/etc/pacman.conf.new" || quit_on_err 'Failed to write pacman.conf.new'
sudo mv "$workdir/etc/pacman.conf.new" "$workdir/etc/pacman.conf" || quit_on_err 'Failed to write new pacman.conf'

# Install remaining packages
sudo arch-chroot "$workdir" pacman -S --noconfirm adw-gtk-theme application-cleaner bluez bluez-cups bluez-plugins bluez-utils btrfs-progs \
    cups cups-pdf dosfstools e2fsprogs exfatprogs f2fs-tools feather-branding feather-gnome-config flatpak fuse fwupd gdm git gnome \
    gnome-initial-setup gnome-shell-extension-advanced-tab-bar gnome-shell-extension-appindicator gnome-shell-extension-caffeine \
    gnome-shell-extension-dash-to-dock gnome-shell-extension-fly-pie gnome-shell-extension-just-perfection-desktop amd-ucode intel-ucode \
    gnome-shell-extension-rounded-corners gnome-shell-extension-rounded-window-corners gnome-shell-extension-tilingshell \
    gnome-shell-extension-useless-gaps gnome-shell-extension-wiggle grml-zsh-config gst-plugin-pipewire gst-plugins-base gst-plugins-good \
    ibus-typing-booster jfsutils lvm2 nano networkmanager networkmanager-openconnect networkmanager-openvpn noto-fonts noto-fonts-cjk \
    noto-fonts-emoji pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse plymouth podman power-profiles-daemon switcheroo-control \
    webp-pixbuf-loader wget wireplumber xdg-user-dirs-gtk xdg-utils xorg-server yai zsh || quit_on_err "Failed to install desktop environment packages"

# Graphics Drivers find and install
gpu_type=$(lspci)

if grep -E "NVIDIA|GeForce" <<< ${gpu_type}; then
    # Install NVIDIA drivers
    if ! sudo arch-chroot "$workdir" pacman -S --noconfirm --needed dkms nvidia-dkms nvidia-utils nvidia-settings cuda; then
        printf 'Failed to install NVIDIA drivers.\n'
        exit 1
    fi
elif grep -E "Radeon|AMD" <<< ${gpu_type}; then
    # Install AMD GPU drivers
    if ! sudo arch-chroot "$workdir" pacman -S mesa xf86-video-amdgpu --noconfirm; then
        printf 'Failed to install AMD GPU drivers.\n'
        exit 1
    fi
elif ls /sys/class/drm/card* | grep "Intel"; then
    # Install Intel GPU drivers
    if ! sudo arch-chroot "$workdir" pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa; then
        printf 'Failed to install Intel Graphics drivers.\n'
        exit 1
    fi
fi

# Fix fstab permissions
sudo chmod 777 "$workdir/etc/fstab"

# Generate the fstab file
sudo genfstab -U "$workdir" >> "$workdir/etc/fstab" || quit_on_err "Failed to generate fstab file"  

# Install bootloader
if efibootmgr &>/dev/null; then
    sudo cp -rvf "$osidir/bits/fstab" "$workdir/etc/fstab" || quit_on_err 'Failed to copy fstab'
    sudo arch-chroot "$workdir" pacman -S --noconfirm --needed efibootmgr os-prober || quit_on_err 'Failed to install efibootmgr and os-prober packages'
    sudo arch-chroot "$workdir" bootctl install || quit_on_err 'Failed to install Systemd-boot'
    sudo arch-chroot "$workdir" os-prober || quit_on_err 'Failed to execute os-prober'
    
    # Copy overlay-uefi
    for f in $(ls $osidir/overlay-uefi); do
	    sudo cp -rv $osidir/overlay-uefi/$f $workdir/ || quit_on_err 'Failed to copy uefi overlay'
    done
else
    sudo arch-chroot "$workdir" pacman -S --noconfirm --needed grub grub-btrfs os-prober || quit_on_err
    sudo arch-chroot "$workdir" grub-install --target=i386-pc $OSI_DEVICE_PATH || quit_on_err 'Failed to install GRUB for BIOS'
    sudo arch-chroot "$workdir" os-prober || quit_on_err 'Failed to execute os-prober'
    
    # Change a grub config settings
    sudo sed -i 's|"Arch"|"SunnyOS"|g' "$workdir/etc/default/grub"
    sudo sed -i 's|"loglevel=3 quiet"|"quiet loglevel=3 splash udev.log_level=3"|g'

    # Write grub config
    sudo arch-chroot "$workdir" grub-mkconfig -o /boot/grub/grub.cfg || quit_on_err 'Failed to generate GRUB configuration'
fi

exit 0
