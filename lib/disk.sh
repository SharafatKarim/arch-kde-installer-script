#!/usr/bin/env bash
# lib/disk.sh - Interactive partition selection, formatting, subvolumes, and mounting

setup_storage() {
    msg_step "Step 1: Disk & Partition Setup"

    # Ensure /mnt is cleanly unmounted before beginning
    umount -R /mnt 2>/dev/null || true

    echo -e "${CYAN}Available Block Devices and Partitions:${RESET}"
    lsblk -e 7,11 -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS

    echo ""
    msg_info "Choose how you want to configure your storage:"
    echo "  1) Select existing partitions (Preserves other partitions / Dual boot)"
    echo "  2) Auto-partition an entire drive (Wipes drive, creates 1GB EFI + Btrfs pool)"
    prompt_input "Enter choice (1/2)" "1" DISK_MODE

    if [ "$DISK_MODE" = "2" ]; then
        # Whole disk auto-partition mode
        echo ""
        msg_info "Available Disks (Drives):"
        lsblk -d -e 7,11 -o PATH,SIZE,MODEL,TRAN,TYPE

        while true; do
            echo ""
            prompt_input "Enter target disk to wipe and partition (e.g., /dev/sda, /dev/vda, /dev/nvme0n1)" "" TARGET_DISK
            # Auto-prepend /dev/ if user enters only 'sda', 'vda', 'nvme0n1', etc.
            if [[ "$TARGET_DISK" != /* ]] && [ -b "/dev/$TARGET_DISK" ]; then
                TARGET_DISK="/dev/$TARGET_DISK"
            fi

            if [ -b "$TARGET_DISK" ]; then
                # Check if it's a whole disk rather than a partition
                local dev_type
                dev_type=$(lsblk -no TYPE "$TARGET_DISK" 2>/dev/null | head -n1)
                if [ "$dev_type" = "disk" ]; then
                    break
                else
                    msg_warn "'$TARGET_DISK' is a $dev_type, not a whole disk device. Please enter the main drive (e.g. /dev/sda, /dev/vda, or /dev/nvme0n1)."
                fi
            else
                msg_err "Device '$TARGET_DISK' not found."
                echo -e "${YELLOW}Please enter one of the full device paths shown above (e.g. /dev/vda or /dev/sda).${RESET}"
            fi
        done

        echo ""
        msg_warn "=== CRITICAL WARNING ==="
        msg_warn "The entire disk ${RED}${TARGET_DISK}${RESET}${YELLOW} will be WIPED and repartitioned!${RESET}"
        msg_warn "All data on this disk will be permanently destroyed."
        echo ""
        prompt_input "Type 'WIPE' to confirm full drive wipe" "" CONFIRM_WIPE
        if [ "$CONFIRM_WIPE" != "WIPE" ]; then
            msg_err "Installation cancelled by user."
            exit 1
        fi

        # Determine partition naming convention (e.g., nvme0n1p1, vda1, sda1)
        if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
            EFI_PART="${TARGET_DISK}p1"
            ROOT_PART="${TARGET_DISK}p2"
        else
            EFI_PART="${TARGET_DISK}1"
            ROOT_PART="${TARGET_DISK}2"
        fi

        FORMAT_EFI=true
        KEEP_HOME=false

        msg_step "Partitioning $TARGET_DISK with GPT layout (1GiB EFI + Btrfs Root)"
        # Create GPT partition table with 1GiB EFI (type ef00) and remaining space for Linux root (type 8300)
        run_cmd sgdisk -Z "$TARGET_DISK"
        run_cmd sgdisk -n 1:0:+1024M -t 1:ef00 -c 1:"EFI System" "$TARGET_DISK"
        run_cmd sgdisk -n 2:0:0      -t 2:8300 -c 2:"Arch Linux Btrfs" "$TARGET_DISK"
        run_cmd partprobe "$TARGET_DISK"
        udevadm settle 2>/dev/null || sleep 1
    else
        # Manual existing partitions mode
        echo ""
        msg_info "Available Partitions:"
        lsblk -e 7,11 -o PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS

        echo ""
        msg_info "Please specify the existing partitions to use for the installation."
        msg_info "Example partition names: ${YELLOW}/dev/nvme0n1p1${RESET}, ${YELLOW}/dev/vda1${RESET}, ${YELLOW}/dev/sda1${RESET}, etc."

        # 1. EFI / Boot partition
        while true; do
            prompt_input "Enter EFI / Boot partition path (e.g., /dev/sda1, /dev/vda1)" "" EFI_PART
            # Auto-prepend /dev/ if omitted
            if [[ "$EFI_PART" != /* ]] && [ -b "/dev/$EFI_PART" ]; then
                EFI_PART="/dev/$EFI_PART"
            fi

            if [ -b "$EFI_PART" ]; then
                break
            else
                msg_err "Device '$EFI_PART' is not a valid block device. Please check the list above and try again."
            fi
        done

        # Probe EFI partition for existing bootloaders (e.g. Windows)
        local default_format_efi="Y"
        local efi_temp="/tmp_probe_efi"
        mkdir -p "$efi_temp"
        if mount -o ro "$EFI_PART" "$efi_temp" 2>/dev/null; then
            if [ -d "${efi_temp}/EFI/Microsoft" ] || [ -f "${efi_temp}/EFI/Microsoft/Boot/bootmgfw.efi" ]; then
                echo ""
                msg_warn "=== Windows Boot Manager detected on ${EFI_PART}! ==="
                msg_warn "Formatting ${EFI_PART} will DESTROY the Windows bootloader and make Windows unbootable."
                msg_warn "Defaulting to KEEP / DO NOT FORMAT (${EFI_PART})."
                default_format_efi="N"
            elif [ -d "${efi_temp}/EFI" ]; then
                msg_info "Existing EFI boot directory detected on ${EFI_PART}."
            fi
            umount "$efi_temp" 2>/dev/null || true
        fi
        rmdir "$efi_temp" 2>/dev/null || true

        # 2. Format EFI partition question
        prompt_yes_no "Format ${EFI_PART} as FAT32? (Select 'N' to preserve Windows/existing bootloader)" "$default_format_efi" FORMAT_EFI

        # 3. Main Btrfs root partition
        while true; do
            prompt_input "Enter Root partition path for Btrfs pool (e.g., /dev/sda2, /dev/vda2)" "" ROOT_PART
            # Auto-prepend /dev/ if omitted
            if [[ "$ROOT_PART" != /* ]] && [ -b "/dev/$ROOT_PART" ]; then
                ROOT_PART="/dev/$ROOT_PART"
            fi

            if [ -b "$ROOT_PART" ]; then
                if [ "$ROOT_PART" = "$EFI_PART" ]; then
                    msg_err "Root partition cannot be the same as EFI partition!"
                    continue
                fi
                break
            else
                msg_err "Device '$ROOT_PART' is not a valid block device. Please check the list above and try again."
            fi
        done

        # Reinstall / Reset check: Check if @home already exists on this partition
        KEEP_HOME=false
        msg_info "Checking if ${ROOT_PART} contains an existing Btrfs pool..."
        local root_fstype=""
        root_fstype=$(blkid -s TYPE -o value "$ROOT_PART" 2>/dev/null || lsblk -no FSTYPE "$ROOT_PART" 2>/dev/null || true)
        if [ "$root_fstype" = "btrfs" ]; then
            local probe_mnt="/tmp_probe_root"
            mkdir -p "$probe_mnt"
            if mount -o ro "$ROOT_PART" "$probe_mnt" 2>/dev/null; then
                if [ -d "${probe_mnt}/@home" ]; then
                    echo ""
                    msg_warn "Existing '@home' subvolume detected on ${ROOT_PART}."
                    prompt_yes_no "Do you want to PRESERVE the existing '@home' subvolume (keep user data intact)?" "Y" KEEP_HOME
                fi
                umount "$probe_mnt" 2>/dev/null || true
            fi
            rmdir "$probe_mnt" 2>/dev/null || true
        fi

        # Confirmation
        echo ""
        msg_warn "=== PARTITION SUMMARY ==="
        echo -e "  EFI/Boot Partition : ${GREEN}${EFI_PART}${RESET} (Format as FAT32: ${YELLOW}${FORMAT_EFI}${RESET})"
        if [ "$KEEP_HOME" = true ]; then
            echo -e "  Btrfs Root Pool    : ${GREEN}${ROOT_PART}${RESET} (${CYAN}Reinstalling system, PRESERVING @home${RESET})"
        else
            echo -e "  Btrfs Root Pool    : ${GREEN}${ROOT_PART}${RESET} (${RED}WILL BE FORMATTED AS BTRFS${RESET})"
        fi
        echo ""
        
        prompt_input "Type 'YES' to confirm and write changes to disk" "" CONFIRM
        if [ "$CONFIRM" != "YES" ]; then
            msg_err "Installation cancelled by user."
            exit 1
        fi
    fi

    # Formatting / Preparing Partitions
    msg_step "Preparing Partitions & Subvolumes"

    if [ "$FORMAT_EFI" = true ]; then
        run_cmd mkfs.fat -F 32 -n EFI "$EFI_PART"
    else
        msg_info "Skipping EFI format on ${EFI_PART} as requested."
    fi

    local pool_mnt="/mnt_pool"
    mkdir -p "$pool_mnt"

    if [ "$KEEP_HOME" = true ]; then
        msg_step "Resetting Arch Installation (Preserving @home)"
        run_cmd mount "$ROOT_PART" "$pool_mnt"

        # Delete system subvolumes (@, @pkg, @log, @snapshots, @swap) while leaving @home intact
        for subvol in @ @pkg @log @snapshots @swap; do
            if [ -e "${pool_mnt}/$subvol" ]; then
                msg_info "Removing old subvolume: ${pool_mnt}/$subvol"
                # Recursively delete any nested subvolumes or snapshots if present
                btrfs subvolume list -o "${pool_mnt}/$subvol" 2>/dev/null | awk '{print $9}' | sort -r | while read -r nested; do
                    btrfs subvolume delete "${pool_mnt}/$nested" 2>/dev/null || true
                done
                run_cmd btrfs subvolume delete "${pool_mnt}/$subvol"
            fi
        done

        # Recreate fresh system subvolumes
        msg_info "Creating fresh system subvolumes..."
        run_cmd btrfs subvolume create "${pool_mnt}/@"
        run_cmd btrfs subvolume create "${pool_mnt}/@pkg"
        run_cmd btrfs subvolume create "${pool_mnt}/@log"
        run_cmd btrfs subvolume create "${pool_mnt}/@snapshots"
        run_cmd btrfs subvolume create "${pool_mnt}/@swap"

        run_cmd umount "$pool_mnt"
        rmdir "$pool_mnt" 2>/dev/null || true
    else
        run_cmd mkfs.btrfs -f "$ROOT_PART"
        run_cmd btrfs filesystem label "$ROOT_PART" ARCH

        # Subvolumes
        msg_step "Creating Btrfs 6-Subvolume Layout (@, @home, @pkg, @log, @snapshots, @swap)"
        run_cmd mount "$ROOT_PART" "$pool_mnt"

        run_cmd btrfs subvolume create "${pool_mnt}/@"
        run_cmd btrfs subvolume create "${pool_mnt}/@home"
        run_cmd btrfs subvolume create "${pool_mnt}/@pkg"
        run_cmd btrfs subvolume create "${pool_mnt}/@log"
        run_cmd btrfs subvolume create "${pool_mnt}/@snapshots"
        run_cmd btrfs subvolume create "${pool_mnt}/@swap"

        run_cmd umount "$pool_mnt"
        rmdir "$pool_mnt" 2>/dev/null || true
    fi

    # Mounting Subvolumes
    mount_target_subvolumes "$ROOT_PART" "$EFI_PART"

    # Save disk selection to persistent state if save_config is available
    if command -v save_config &>/dev/null; then
        save_config
    fi

    msg_ok "All partitions and subvolumes mounted successfully under /mnt."
}

# Mount target subvolumes and boot partition reliably under /mnt
mount_target_subvolumes() {
    local root_dev="$1"
    local efi_dev="$2"
    local btrfs_opts="noatime,compress=zstd"

    msg_step "Mounting Btrfs Subvolumes & EFI Partition"

    mkdir -p /mnt
    if ! mountpoint -q /mnt; then
        run_cmd mount -o "${btrfs_opts},subvol=@" "$root_dev" /mnt
    fi

    mkdir -p /mnt/{boot,home,.snapshots,swap,var/log,var/cache/pacman/pkg}

    mountpoint -q /mnt/home || run_cmd mount -o "${btrfs_opts},subvol=@home" "$root_dev" /mnt/home
    mountpoint -q /mnt/var/cache/pacman/pkg || run_cmd mount -o "${btrfs_opts},subvol=@pkg" "$root_dev" /mnt/var/cache/pacman/pkg
    mountpoint -q /mnt/var/log || run_cmd mount -o "${btrfs_opts},subvol=@log" "$root_dev" /mnt/var/log
    mountpoint -q /mnt/.snapshots || run_cmd mount -o "${btrfs_opts},subvol=@snapshots" "$root_dev" /mnt/.snapshots
    mountpoint -q /mnt/swap || run_cmd mount -o "noatime,nodatacow,subvol=@swap" "$root_dev" /mnt/swap
    mountpoint -q /mnt/boot || run_cmd mount "$efi_dev" /mnt/boot
}

# Mount an existing system installed with this script for chroot / rescue
mount_existing_system() {
    msg_step "Mount Existing Installation for Chroot"

    echo -e "${CYAN}Available Block Devices and Partitions:${RESET}"
    lsblk -e 7,11 -o PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS

    echo ""
    msg_info "Please specify the partitions of your existing installation."

    # 1. Root Btrfs partition
    while true; do
        prompt_input "Enter existing Btrfs Root partition path (e.g., /dev/sda2, /dev/vda2)" "" ROOT_PART
        if [[ "$ROOT_PART" != /* ]] && [ -b "/dev/$ROOT_PART" ]; then
            ROOT_PART="/dev/$ROOT_PART"
        fi

        if [ -b "$ROOT_PART" ]; then
            break
        else
            msg_err "Device '$ROOT_PART' is not a valid block device. Please check lsblk and try again."
        fi
    done

    # 2. EFI partition
    while true; do
        prompt_input "Enter existing EFI/Boot partition path (e.g., /dev/sda1, /dev/vda1)" "" EFI_PART
        if [[ "$EFI_PART" != /* ]] && [ -b "/dev/$EFI_PART" ]; then
            EFI_PART="/dev/$EFI_PART"
        fi

        if [ -b "$EFI_PART" ]; then
            if [ "$EFI_PART" = "$ROOT_PART" ]; then
                msg_err "EFI partition cannot be the same as Root partition!"
                continue
            fi
            break
        else
            msg_err "Device '$EFI_PART' is not a valid block device. Please check lsblk and try again."
        fi
    done

    msg_info "Mounting existing Btrfs subvolumes and EFI partition to /mnt..."
    local btrfs_opts="noatime,compress=zstd"

    run_cmd mount -o "${btrfs_opts},subvol=@" "$ROOT_PART" /mnt
    run_cmd mkdir -p /mnt/{boot,home,.snapshots,swap,var/log,var/cache/pacman/pkg}

    # Mount other subvolumes if they exist
    mount -o "${btrfs_opts},subvol=@home" "$ROOT_PART" /mnt/home 2>/dev/null || true
    mount -o "${btrfs_opts},subvol=@pkg" "$ROOT_PART" /mnt/var/cache/pacman/pkg 2>/dev/null || true
    mount -o "${btrfs_opts},subvol=@log" "$ROOT_PART" /mnt/var/log 2>/dev/null || true
    mount -o "${btrfs_opts},subvol=@snapshots" "$ROOT_PART" /mnt/.snapshots 2>/dev/null || true
    mount -o "noatime,nodatacow,subvol=@swap" "$ROOT_PART" /mnt/swap 2>/dev/null || true

    # Mount EFI
    run_cmd mount "$EFI_PART" /mnt/boot

    msg_ok "Existing system mounted under /mnt."
    msg_step "Entering arch-chroot (/mnt)"
    msg_info "Type 'exit' when you are done to return and unmount cleanly."
    run_cmd arch-chroot /mnt

    # After exit
    echo ""
    msg_info "Unmounting /mnt..."
    run_cmd umount -R /mnt
    msg_ok "Partitions unmounted cleanly."
}
