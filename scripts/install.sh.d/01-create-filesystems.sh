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
        sudo mkfs.fat -F32 "$efi_partition" || quit_on_err 'Failed to format EFI partition'
    else
        sudo sfdisk "${OSI_DEVICE_PATH}" < "${osidir}/bits/mbr.sfdisk" || quit_on_err 'Failed to write MBR partition table'

        root_partition="${partition_path}1"
    fi
else
    if [[ $UEFI == true ]]; then
        root_partition="${OSI_DEVICE_PATH}"
    
        efi_partition="${OSI_DEVICE_EFI_PARTITION}"
        if [[ -z "$efi_partition" ]]; then
            quit_on_err 'No EFI partition found. Please create a fat32 partition with at least 100 MB of space and boot flag'
        fi
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

# Unmount and remount with subvolumes
sudo umount "$workdir"
sudo mount -o subvol=@,noatime,compress=zstd:1,discard=async "$root_device" "$workdir" || quit_on_err 'Failed to mount root subvolume'
sudo mkdir -p "$workdir/home"
sudo mount -o subvol=@home,noatime,compress=zstd:1,discard=async "$root_device" "$workdir/home" || quit_on_err 'Failed to mount home subvolume'

if [[ $UEFI == true ]]; then
    # Mount efi partition
    sudo mount --mkdir "$efi_partition" "$workdir/efi" || quit_on_err 'Failed to mount efi partition'
fi
