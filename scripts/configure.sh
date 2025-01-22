#!/usr/bin/env bash
set -o pipefail

## Set common variables
#
# Commonly used variables
declare -r workdir='/mnt'
declare -r osidir='/etc/os-installer'
declare -r scriptsdir="$osidir/scripts/configure.sh.d"
declare -r rootlabel='sunny_root'

# Get target disk UUID
if [[ $OSI_DEVICE_IS_PARTITION -ne 0 ]]; then
    declare -r uuid=$(sudo blkid -o value -s UUID ${OSI_DEVICE_PATH})
elif [[ $OSI_DEVICE_PATH == *"nvme"*"n"* ]]; then
    declare -r uuid=$(sudo blkid -o value -s UUID ${OSI_DEVICE_PATH}p2)
else
    declare -r uuid=$(sudo blkid -o value -s UUID ${OSI_DEVICE_PATH}2)
fi

# User can provide full name as input, if they do only the first word will be used as username
# OSI_USER_NAME is still used in the account comments
declare firstname=($OSI_USER_NAME)
firstname=${firstname[0]}

# Quit script with error if called
quit_on_err () {
    if [[ -n $1 ]]; then
        printf "$1\n"
    fi
    # Ensure console prints error
    sleep 2
    exit 1
}

# Get list of all child scripts
declare -r scripts=($(ls $scriptsdir/*.sh | sort))
# Loop and run install scripts
for script in "${scripts[@]}"; do
    printf "Now running $script\n"
    source "$script"
done

# Ensure synced and umount
sync
sudo umount -R /mnt
exit 0
