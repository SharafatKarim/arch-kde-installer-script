#!/usr/bin/env bash
# lib/disk.sh - Interactive partition selection, formatting, subvolumes, and mounting

setup_storage() {
    msg_step "Step 1: Disk & Partition Setup"

    echo -e "${CYAN}Available Block Devices and Partitions:${RESET}"
    lsblk -e 7,11 -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS

    echo ""
    msg_info "Choose how you want to configure your storage:"
    echo "  1) Select existing partitions (Preserves other partitions / Dual boot)"
    echo "  2) Auto-partition an entire drive (Wipes drive, creates 1GB EFI + Btrfs pool)"
    prompt_input "Enter choice (1/2)" "1" DISK_MODE

    if [ "$DISK_MODE" = "2" ]; then
        # Whole disk auto-partition mode
        while true; do
            prompt_input "Enter target disk to wipe and partition (e.g., /dev/sda, /dev/nvme0n1)" "" TARGET_DISK
            if [ -b "$TARGET_DISK" ]; then
                # Check if it's a whole disk rather than a partition
                local dev_type
                dev_type=$(lsblk -no TYPE "$TARGET_DISK" 2>/dev/null | head -n1)
                if [ "$dev_type" = "disk" ]; then
                    break
                else
                    msg_warn "'$TARGET_DISK' is a $dev_type, not a whole disk device. Please enter the main drive (e.g. /dev/sda or /dev/nvme0n1)."
                fi
            else
                msg_err "Device '$TARGET_DISK' not found. Please try again."
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

        # Determine partition naming convention (e.g., nvme0n1p1 vs sda1)
        if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
            EFI_PART="${TARGET_DISK}p1"
            ROOT_PART="${TARGET_DISK}p2"
        else
            EFI_PART="${TARGET_DISK}1"
            ROOT_PART="${TARGET_DISK}2"
        fi

        FORMAT_EFI=true

        msg_step "Partitioning $TARGET_DISK with GPT layout (1GiB EFI + Btrfs Root)"
        # Create GPT partition table with 1GiB EFI (type ef00) and remaining space for Linux root (type 8300)
        run_cmd sgdisk -Z "$TARGET_DISK"
        run_cmd sgdisk -n 1:0:+1024M -t 1:ef00 -c 1:"EFI System" "$TARGET_DISK"
        run_cmd sgdisk -n 2:0:0      -t 2:8300 -c 2:"Arch Linux Btrfs" "$TARGET_DISK"
        run_cmd partprobe "$TARGET_DISK"
        sleep 1
    else
        # Manual existing partitions mode
        msg_info "Please specify the existing partitions to use for the installation."
        msg_info "Example partition names: ${YELLOW}/dev/nvme0n1p1${RESET}, ${YELLOW}/dev/sda1${RESET}, etc."

        # 1. EFI / Boot partition
        while true; do
            prompt_input "Enter EFI / Boot partition path (e.g., /dev/sda1)" "" EFI_PART
            if [ -b "$EFI_PART" ]; then
                break
            else
                msg_err "Device '$EFI_PART' is not a valid block device. Please check lsblk and try again."
            fi
        done

        # 2. Format EFI partition question
        prompt_yes_no "Format ${EFI_PART} as FAT32? (Choose 'n' if dual-booting with Windows/existing EFI)" "Y" FORMAT_EFI

        # 3. Main Btrfs root partition
        while true; do
            prompt_input "Enter Root partition path for Btrfs pool (e.g., /dev/sda2)" "" ROOT_PART
            if [ -b "$ROOT_PART" ]; then
                if [ "$ROOT_PART" = "$EFI_PART" ]; then
                    msg_err "Root partition cannot be the same as EFI partition!"
                    continue
                fi
                break
            else
                msg_err "Device '$ROOT_PART' is not a valid block device. Please check lsblk and try again."
            fi
        done

        # Reinstall / Reset check: Check if @home already exists on this partition
        KEEP_HOME=false
        msg_info "Checking if ${ROOT_PART} contains an existing Btrfs pool..."
        if run_cmd mount "$ROOT_PART" /mnt 2>/dev/null; then
            if [ -d /mnt/@home ]; then
                msg_warn "Existing '@home' subvolume detected on ${ROOT_PART}."
                prompt_yes_no "Do you want to PRESERVE the existing '@home' subvolume (keep user data intact)?" "Y" KEEP_HOME
            fi
            run_cmd umount /mnt 2>/dev/null || true
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
        run_cmd mkfs.fat -F 32 "$EFI_PART"
        run_cmd fatlabel "$EFI_PART" EFI
    else
        msg_info "Skipping EFI format on ${EFI_PART} as requested."
    fi

    if [ "$KEEP_HOME" = true ]; then
        msg_step "Resetting Arch Installation (Preserving @home)"
        run_cmd mount "$ROOT_PART" /mnt

        # Delete system subvolumes (@, @pkg, @log, @snapshots) while leaving @home intact
        for subvol in @ @pkg @log @snapshots; do
            if [ -d "/mnt/$subvol" ]; then
                msg_info "Removing old subvolume: /mnt/$subvol"
                # Recursively delete any nested subvolumes or snapshots if present
                btrfs subvolume list -o /mnt/$subvol | awk '{print $9}' | sort -r | while read -r nested; do
                    btrfs subvolume delete "/mnt/$nested" 2>/dev/null || true
                done
                run_cmd btrfs subvolume delete "/mnt/$subvol"
            fi
        done

        # Recreate fresh system subvolumes
        msg_info "Creating fresh system subvolumes..."
        run_cmd btrfs subvolume create /mnt/@
        run_cmd btrfs subvolume create /mnt/@pkg
        run_cmd btrfs subvolume create /mnt/@log
        run_cmd btrfs subvolume create /mnt/@snapshots

        run_cmd umount /mnt
    else
        run_cmd mkfs.btrfs -f "$ROOT_PART"
        run_cmd btrfs filesystem label "$ROOT_PART" ARCH

        # Subvolumes
        msg_step "Creating Btrfs 5-Subvolume Layout (@, @home, @pkg, @log, @snapshots)"
        run_cmd mount "$ROOT_PART" /mnt

        run_cmd btrfs subvolume create /mnt/@
        run_cmd btrfs subvolume create /mnt/@home
        run_cmd btrfs subvolume create /mnt/@pkg
        run_cmd btrfs subvolume create /mnt/@log
        run_cmd btrfs subvolume create /mnt/@snapshots

        run_cmd umount /mnt
    fi

    # Mounting Subvolumes
    msg_step "Mounting Subvolumes with 'noatime,compress=zstd'"
    local btrfs_opts="noatime,compress=zstd"

    run_cmd mount -o "${btrfs_opts},subvol=@" "$ROOT_PART" /mnt

    run_cmd mkdir -p /mnt/{boot,home,.snapshots}
    run_cmd mkdir -p /mnt/var/log
    run_cmd mkdir -p /mnt/var/cache/pacman/pkg

    run_cmd mount -o "${btrfs_opts},subvol=@home" "$ROOT_PART" /mnt/home
    run_cmd mount -o "${btrfs_opts},subvol=@pkg" "$ROOT_PART" /mnt/var/cache/pacman/pkg
    run_cmd mount -o "${btrfs_opts},subvol=@log" "$ROOT_PART" /mnt/var/log
    run_cmd mount -o "${btrfs_opts},subvol=@snapshots" "$ROOT_PART" /mnt/.snapshots

    # Mount EFI partition
    run_cmd mount "$EFI_PART" /mnt/boot

    msg_ok "All partitions and subvolumes mounted successfully under /mnt."
}

# Mount an existing system installed with this script for chroot / rescue
mount_existing_system() {
    msg_step "Mount Existing Installation for Chroot"

    echo -e "${CYAN}Available Block Devices and Partitions:${RESET}"
    lsblk -e 7,11 -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS

    echo ""
    msg_info "Please specify the partitions of your existing installation."

    # 1. Root Btrfs partition
    while true; do
        prompt_input "Enter existing Btrfs Root partition path (e.g., /dev/sda2)" "" ROOT_PART
        if [ -b "$ROOT_PART" ]; then
            break
        else
            msg_err "Device '$ROOT_PART' is not a valid block device. Please check lsblk and try again."
        fi
    done

    # 2. EFI partition
    while true; do
        prompt_input "Enter existing EFI/Boot partition path (e.g., /dev/sda1)" "" EFI_PART
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
    run_cmd mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache/pacman/pkg}

    # Mount other subvolumes if they exist
    run_cmd mount -o "${btrfs_opts},subvol=@home" "$ROOT_PART" /mnt/home 2>/dev/null || true
    run_cmd mount -o "${btrfs_opts},subvol=@pkg" "$ROOT_PART" /mnt/var/cache/pacman/pkg 2>/dev/null || true
    run_cmd mount -o "${btrfs_opts},subvol=@log" "$ROOT_PART" /mnt/var/log 2>/dev/null || true
    run_cmd mount -o "${btrfs_opts},subvol=@snapshots" "$ROOT_PART" /mnt/.snapshots 2>/dev/null || true

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
