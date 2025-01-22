#!/usr/bin/env bash

# Determine partition naming for NVMe drives
if [[ "${OSI_DEVICE_PATH}" == *"nvme"*"n"* ]]; then
    partition_path="${OSI_DEVICE_PATH}p"
else
    partition_path="${OSI_DEVICE_PATH}"
fi

# Handle disk partitioning
if [[ "${OSI_DEVICE_IS_PARTITION}" -eq 0 ]]; then
    if command -v efibootmgr &> /dev/null; then
        sudo sfdisk "${OSI_DEVICE_PATH}" < "${osidir}/bits/gpt.sfdisk" || quit_on_err 'Failed to write GPT partition table'
    else
        sudo sfdisk "${OSI_DEVICE_PATH}" < "${osidir}/bits/mbr.sfdisk" || quit_on_err 'Failed to write MBR partition table'
    fi
    root_partition="${partition_path}2"
    efi_partition="${partition_path}1"
    # Format EFI partition
    sudo mkfs.fat -F32 -n "$bootlabel" "$efi_partition" || quit_on_err 'Failed to format EFI partition'
else
    root_partition="${OSI_DEVICE_PATH}"
    
    # Search for an existing EFI partition with at least 150MB of free space
    efi_partition=$(lsblk -no NAME,FSTYPE,SIZE | awk '$2 == "vfat" && $3+0 >= 150 {print "/dev/"$1}' | sed 's/[^a-zA-Z0-9/_]//g' | head -n 1)
    if [[ -z "$efi_partition" ]]; then
        quit_on_err 'No suitable EFI partition found with at least 150MB of free space'
    fi
    # Set EFI partition label
    sudo fatlabel "$efi_partition" "$bootlabel" || quit_on_err 'Failed to set EFI partition label'
fi

# Handle encryption and formatting logic
if [[ "${OSI_USE_ENCRYPTION}" -eq 1 ]]; then
    echo "${OSI_ENCRYPTION_PIN}" | sudo cryptsetup -q luksFormat "$root_partition"
    echo "${OSI_ENCRYPTION_PIN}" | sudo cryptsetup open "$root_partition" "$rootlabel"
    root_device="/dev/mapper/$rootlabel"
else
    root_device="$root_partition"
fi

# Create Btrfs filesystem and subvolumes
sudo mkfs.btrfs -f -L "$rootlabel" "$root_device" || quit_on_err 'Failed to format root filesystem'
sudo mount "$root_device" "$workdir" || quit_on_err 'Failed to mount root filesystem'
sudo btrfs subvolume create "$workdir/@"
sudo btrfs subvolume create "$workdir/@home"

# Unmount and remount with subvolumes
sudo umount "$workdir"
sudo mount -o subvol=@,noatime,compress=zstd:1,discard=async "$root_device" "$workdir" || quit_on_err 'Failed to mount root subvolume'
sudo mkdir -p "$workdir/home"
sudo mount -o subvol=@home,noatime,compress=zstd:1,discard=async "$root_device" "$workdir/home" || quit_on_err 'Failed to mount home subvolume'

# Mount efi partition
sudo mount --mkdir "$efi_partition" "$workdir/efi" || quit_on_err 'Failed to mount efi partition'
