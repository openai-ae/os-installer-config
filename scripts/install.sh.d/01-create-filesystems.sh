#!/usr/bin/env bash

if [[ "${OSI_USE_ENCRYPTION}" -eq 1 ]]; then
    if [[ $UEFI == false ]]; then
        quit_on_err 'Encryption with BIOS not supported, please enable UEFI or disable encryption'
    fi
fi

# Handle disk partitioning
if [[ "${OSI_DEVICE_IS_PARTITION}" -eq 0 ]]; then
    if [[ $UEFI == true ]]; then
        sudo sfdisk "${OSI_DEVICE_PATH}" < "${osidir}/bits/gpt.sfdisk" || quit_on_err 'Failed to write GPT partition table'
        
        root_partition="${partition_path}2"
        efi_partition="${partition_path}1"

        # Format EFI partition
        sudo mkfs.fat -F32 -n "$bootlabel" "$efi_partition" || quit_on_err 'Failed to format EFI partition'
    else
        sudo sfdisk "${OSI_DEVICE_PATH}" < "${osidir}/bits/mbr.sfdisk" || quit_on_err 'Failed to write MBR partition table'

        root_partition="${partition_path}1"
    fi
else
    if [[ $UEFI == true ]]; then
        root_partition="${OSI_DEVICE_PATH}"
    
        # Search for an existing EFI partition with at least 150MB of free space
        efi_partition=$(lsblk -blno NAME,FSTYPE,SIZE | awk '$2 == "vfat" && $3 >= 157286400 {print "/dev/" $1}' | head -n 1)
        if [[ -z "$efi_partition" ]]; then
            quit_on_err 'No suitable EFI partition found with at least 150MB of free space'
        fi
        # Set EFI partition label
        sudo fatlabel "$efi_partition" "$bootlabel" || quit_on_err 'Failed to set EFI partition label'
    else
        root_partition="${OSI_DEVICE_PATH}"
    fi
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
sudo btrfs subvolume create "$workdir/@log"
sudo btrfs subvolume create "$workdir/@pkg"
sudo btrfs subvolume create "$workdir/@.snapshots"

# Unmount and remount with subvolumes
sudo umount "$workdir"
sudo mount -o noatime,compress=zstd:1,space_cache=v2,autodefrag,subvol=@ "$root_device" "$workdir" || quit_on_err 'Failed to mount /mnt'
sudo mount --mkdir -o noatime,compress=zstd:1,space_cache=v2,autodefrag,subvol=@home,nodev "$root_device" "$workdir/home" || quit_on_err 'Failed to mount /mnt/home'
sudo mount --mkdir -o noatime,compress=zstd:1,space_cache=v2,autodefrag,subvol=@log,nodev,nosuid,noexec "$root_device" "$workdir/var/log" || quit_on_err 'Failed to mount /mnt/var/log'
sudo mount --mkdir -o noatime,compress=zstd:1,space_cache=v2,autodefrag,subvol=@pkg,nodev,nosuid,noexec "$root_device" "$workdir/var/cache/pacman/pkg" || quit_on_err 'Failed to mount /mnt/var/cache/pacman/pkg'
sudo mount --mkdir -o noatime,compress=zstd:1,space_cache=v2,autodefrag,subvol=@.snapshots,nodev,nosuid,noexec "$root_device" "$workdir/.snapshots" || quit_on_err 'Failed to mount /mnt/.snapshots'

if [[ $UEFI == true ]]; then
    # Mount efi partition
    sudo mount --mkdir "$efi_partition" "$workdir/efi" || quit_on_err 'Failed to mount efi partition'
fi
