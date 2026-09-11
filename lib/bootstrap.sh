#!/usr/bin/env bash
# lib/bootstrap.sh - Keyring update, mirrors, and base pacstrap

bootstrap_system() {
    local kernel="$1"
    local ucode="$2"
    local enable_reflector="$3"
    local pacman_noconfirm="${4:-true}"

    local noconfirm_flag=""
    [ "$pacman_noconfirm" = true ] && noconfirm_flag="--noconfirm"

    msg_step "Step 3: Bootstrapping Base System (pacstrap)"

    # Enable parallel downloads in live environment pacman.conf if not already enabled
    if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
        run_cmd sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    fi

    # Update keyring
    msg_info "Updating archlinux-keyring..."
    run_cmd pacman -Sy $noconfirm_flag archlinux-keyring

    # Reflector fast mirror ranking (if enabled by user)
    if [ "$enable_reflector" = true ]; then
        if command -v reflector &>/dev/null; then
            msg_info "Sorting fastest 10 HTTPS mirrors using reflector..."
            if reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null; then
                msg_ok "Mirrors sorted successfully."
            else
                msg_warn "Reflector ranking skipped or timed out. Keeping default mirrors."
            fi
        else
            msg_warn "reflector command not found in live environment. Keeping default mirrors."
        fi
    else
        msg_info "Skipping reflector mirror ranking as requested."
    fi

    # Base package selection
    local base_pkgs=(
        base
        base-devel
        "$kernel"
        "${kernel}-headers"
        linux-firmware
        btrfs-progs
        ntfs-3g
        nano
        networkmanager
        git
        sudo
        efibootmgr
        grub
        os-prober
    )

    # Microcode
    if [ "$ucode" != "none" ]; then
        base_pkgs+=("$ucode")
    fi

    msg_info "Installing base packages to /mnt:"
    echo -e "${CYAN}${base_pkgs[*]}${RESET}"

    local pacstrap_flags=("-K")
    [ "$pacman_noconfirm" = true ] && pacstrap_flags+=("-N")

    run_cmd pacstrap "${pacstrap_flags[@]}" /mnt "${base_pkgs[@]}"

    # Copy optimized mirrorlist to new system
    if [ -f /etc/pacman.d/mirrorlist ]; then
        run_cmd mkdir -p /mnt/etc/pacman.d
        run_cmd cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    fi

    # Generate fstab using UUIDs (overwrite cleanly with >)
    msg_step "Generating fstab (UUIDs)"
    run_eval "genfstab -U /mnt > /mnt/etc/fstab"

    msg_ok "Base system installed and fstab generated."
}
