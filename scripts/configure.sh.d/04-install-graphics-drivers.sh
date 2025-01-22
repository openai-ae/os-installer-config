#!/usr/bin/env bash

# Detect GPU type and install appropriate drivers
gpu_type=$(lspci)
if grep -E "NVIDIA|GeForce" <<< "${gpu_type}"; then
    if ! sudo arch-chroot "$workdir" pacman -S --noconfirm --needed dkms nvidia-dkms nvidia-utils nvidia-settings cuda; then
        printf 'Failed to install NVIDIA drivers.\n'
        exit 1
    fi
elif grep -E "Radeon|AMD" <<< "${gpu_type}"; then
    if ! sudo arch-chroot "$workdir" pacman -S --noconfirm --needed mesa xf86-video-amdgpu; then
        printf 'Failed to install AMD GPU drivers.\n'
        exit 1
    fi
elif ls /sys/class/drm/card* | grep "Intel"; then
    if ! sudo arch-chroot "$workdir" pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa; then
        printf 'Failed to install Intel Graphics drivers.\n'
        exit 1
    fi
fi

# Detect the virtualization platform
VIRTUALIZATION="Unknown"
if [[ -n "$(lspci | grep -i vmware)" ]]; then
    VIRTUALIZATION="VMware"
elif [[ -n "$(lspci | grep -i virtualbox)" ]]; then
    VIRTUALIZATION="VirtualBox"
elif [[ -n "$(sudo dmesg | grep -i qemu)" || -n "$(grep -i qemu /proc/sysinfo)" ]]; then
    VIRTUALIZATION="QEMU"
fi

# Install packages based on the detected virtualization platform
case "$VIRTUALIZATION" in
    "VMware")
        sudo arch-chroot "$workdir" pacman -Syyu --noconfirm open-vm-tools xf86-input-vmmouse xf86-video-vmware xf86-video-qxl
        ;;
    "VirtualBox")
        sudo arch-chroot "$workdir" pacman -Syyu --noconfirm virtualbox-guest-utils
        ;;
    "QEMU")
        sudo arch-chroot "$workdir" pacman -Syyu --noconfirm qemu-guest-agent spice-vdagent
        ;;
    *)
        echo "Unknown virtualization platform or no virtualization detected."
        ;;
esac
