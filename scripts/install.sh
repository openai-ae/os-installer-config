#!/usr/bin/env bash
set -o pipefail

declare -r workdir='/mnt'
declare -r osidir='/etc/os-installer'
declare -r scriptsdir="$osidir/scripts/install.sh.d"
declare -r rootlabel='sunny_root'
declare -r bootlabel='sunny_esp'

# Determine partition naming for NVMe drives
if [[ "${OSI_DEVICE_PATH}" == *"nvme"*"n"* ]]; then
    partition_path="${OSI_DEVICE_PATH}p"
else
    partition_path="${OSI_DEVICE_PATH}"
fi

efibootmgr
efibootmgr_exit_code=$?
if [[ $efibootmgr_exit_code == 2 ]]; then
    UEFI="false"
else
    UEFI="true"
fi

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

exit 0
