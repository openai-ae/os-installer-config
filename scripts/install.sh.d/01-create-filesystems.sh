#!/usr/bin/env bash

# Check if installing to a partition is supported
if [ "${OSI_DEVICE_IS_PARTITION}" -eq 1 ]; then
    quit_on_err 'Installing to a partition currently not supported'
fi

# Write partition table to the disk
if command -v efibootmgr &> /dev/null; then
    sudo sfdisk "${OSI_DEVICE_PATH}" < "${osidir}/bits/gpt.sfdisk" || quit_on_err 'Failed to write GPT partition table'
else
    sudo sfdisk "${OSI_DEVICE_PATH}" < "${osidir}/bits/mbr.sfdisk" || quit_on_err 'Failed to write MBR partition table'
fi

if [[ "$OSI_DEVICE_PATH" == *"nvme"*"n"* ]]; then
    partition_path="${OSI_DEVICE_PATH}p"
else
    partition_path="${OSI_DEVICE_PATH}"
fi

# Define root and EFI partitions
root_partition="${partition_path}2"
efi_partition="${partition_path}1"

# Format EFI partition
sudo mkfs.fat -F32 -n "$bootlabel" "$efi_partition" || quit_on_err 'Failed to format EFI partition'

# Handle encryption
if [[ "$OSI_USE_ENCRYPTION" -eq 1 ]]; then
    # Format encrypted root partition
    echo "$OSI_ENCRYPTION_PIN" | sudo cryptsetup -q luksFormat "$root_partition" || quit_on_err 'Failed to format encrypted partition'
    echo "$OSI_ENCRYPTION_PIN" | sudo cryptsetup open "$root_partition" $rootlabel || quit_on_err 'Failed to open encrypted partition'
    root_device="/dev/mapper/$rootlabel"
else
    root_device="$root_partition"
fi

# Create Btrfs subvolumes
sudo mkfs.btrfs -f -L $rootlabel "$root_device" || quit_on_err 'Failed to format root filesystem'
sudo mount "$root_device" "$workdir" || quit_on_err 'Failed to mount root filesystem'

# Create subvolumes
sudo btrfs subvolume create "$workdir/@"
sudo btrfs subvolume create "$workdir/@home"

# Unmount and remount with subvolumes
sudo umount "$workdir"
sudo mount -o subvol=@,noatime,compress=zstd:1,discard=async "$root_device" "$workdir" || quit_on_err 'Failed to mount root subvolume'
sudo mkdir -p "$workdir/home"
sudo mount -o subvol=@home,noatime,compress=zstd:1,discard=async "$root_device" "$workdir/home" || quit_on_err 'Failed to mount home subvolume'

# Mount boot partition
sudo mkdir -p "$workdir/boot"
sudo mount "$efi_partition" "$workdir/boot" || quit_on_err 'Failed to mount boot partition'
