#!/usr/bin/env bash
# install.sh - Main interactive Arch Linux installer with Btrfs & Minimal KDE Plasma
# Based on guides:
#   - Part 1 (Minimal Install): https://sharafat.pages.dev/archlinux-install/
#   - Part 2 (Post-Install & KDE): https://sharafat.pages.dev/archlinux-post-install/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper modules
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/disk.sh"
source "${SCRIPT_DIR}/lib/bootstrap.sh"

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
    _             _       _     _                  
   / \   _ __ ___| |__   | |   (_)_ __  _   ___  __
  / _ \ | '__/ __| '_ \  | |   | | '_ \| | | \ \/ /
 / ___ \| | | (__| | | | | |___| | | | | |_| |>  < 
/_/   \_\_|  \___|_| |_| |_____|_|_| |_|\__,_/_/\_\
     Arch Linux + Btrfs + KDE Plasma Installer
BANNER
echo -e "${RESET}"

# Pre-flight Checks
msg_step "Pre-flight Environment Checks"

# 1. Root check
if [ "$EUID" -ne 0 ]; then
    msg_err "This installer must be run as root. Run with 'sudo ./install.sh'."
    exit 1
fi
msg_ok "Running with root privileges."

# 2. UEFI check
if [ ! -d "/sys/firmware/efi/efivars" ]; then
    msg_err "System is not booted in UEFI mode (/sys/firmware/efi/efivars not found)."
    msg_err "This installer requires UEFI boot mode."
    exit 1
fi
msg_ok "UEFI boot mode detected."

# 3. Network check
msg_info "Checking network connectivity..."
if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    msg_warn "No active internet connection detected. (Required for fresh install, optional for rescue chroot)"
else
    msg_ok "Internet connectivity verified."
    timedatectl set-ntp true 2>/dev/null || true
fi

# Operation Mode Selection
msg_step "Select Operation Mode"
echo "  1) Install fresh Arch Linux (Btrfs + Plasma / CLI)"
echo "  2) Mount existing installation & chroot (Rescue / Maintenance mode)"
prompt_input "Enter choice (1/2)" "1" OP_MODE

if [ "$OP_MODE" = "2" ]; then
    mount_existing_system
    exit 0
fi

# Fresh install requires active network
if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    msg_err "Active internet connection is required for installation."
    msg_info "For Wi-Fi, run: nmtui or iwctl"
    exit 1
fi

CACHE_FILE="${SCRIPT_DIR}/.installer_cache.env"
LOADED_FROM_CACHE=false

save_config() {
    {
        printf 'HOSTNAME=%q\n' "${HOSTNAME:-}"
        printf 'USERNAME=%q\n' "${USERNAME:-}"
        printf 'USER_PASSWORD=%q\n' "${USER_PASSWORD:-}"
        printf 'ROOT_PASSWORD=%q\n' "${ROOT_PASSWORD:-}"
        printf 'TIMEZONE=%q\n' "${TIMEZONE:-}"
        printf 'LOCALE=%q\n' "${LOCALE:-}"
        printf 'KEYMAP=%q\n' "${KEYMAP:-}"
        printf 'KERNEL=%q\n' "${KERNEL:-}"
        printf 'UCODE=%q\n' "${UCODE:-}"
        printf 'GPU_DRIVERS=%q\n' "${GPU_DRIVERS:-}"
        printf 'INSTALL_DESKTOP=%q\n' "${INSTALL_DESKTOP:-}"
        printf 'PLASMA_FLAVOR=%q\n' "${PLASMA_FLAVOR:-}"
        printf 'ENABLE_BLUETOOTH=%q\n' "${ENABLE_BLUETOOTH:-}"
        printf 'ENABLE_REFLECTOR=%q\n' "${ENABLE_REFLECTOR:-}"
        printf 'PACMAN_NOCONFIRM=%q\n' "${PACMAN_NOCONFIRM:-true}"
        printf 'AUTO_MODE=%q\n' "${AUTO_MODE:-}"
        printf 'DISK_MODE=%q\n' "${DISK_MODE:-}"
        printf 'TARGET_DISK=%q\n' "${TARGET_DISK:-}"
        printf 'EFI_PART=%q\n' "${EFI_PART:-}"
        printf 'ROOT_PART=%q\n' "${ROOT_PART:-}"
        printf 'FORMAT_EFI=%q\n' "${FORMAT_EFI:-}"
        printf 'KEEP_HOME=%q\n' "${KEEP_HOME:-}"
        printf 'INSTALL_STAGE=%q\n' "${INSTALL_STAGE:-CONFIGURED}"
    } > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"
}

if [ -f "$CACHE_FILE" ]; then
    msg_info "Found saved configuration from a previous run."
    prompt_yes_no "Do you want to RESUME using saved settings?" "Y" RESUME_CACHE
    if [ "$RESUME_CACHE" = true ]; then
        source "$CACHE_FILE"
        LOADED_FROM_CACHE=true
        msg_ok "Loaded configuration from cache."
    fi
fi

if [ "$LOADED_FROM_CACHE" != true ]; then
    # Interactive Configuration Questions
    msg_step "Interactive System Configuration"

    # 1. Hostname & User
    while true; do
        prompt_input "Enter Hostname" "archlinux" HOSTNAME
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
            break
        else
            msg_warn "Invalid hostname '$HOSTNAME'. Must start with an alphanumeric character and contain only letters, numbers, hyphens, or dots."
        fi
    done

    while true; do
        prompt_input "Enter Non-Root Username" "arch" USERNAME
        if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            break
        else
            msg_warn "Invalid username '$USERNAME'. Must start with a lowercase letter or underscore, and contain only lowercase letters, digits, underscores, or hyphens."
        fi
    done

    prompt_password "Enter password for '$USERNAME'" USER_PASSWORD
    prompt_password "Enter Root password" ROOT_PASSWORD

    # 2. Localization
    prompt_input "Enter Timezone (Region/City)" "Asia/Dhaka" TIMEZONE
    prompt_input "Enter System Locale" "en_US" LOCALE
    prompt_input "Enter Keyboard Layout" "us" KEYMAP

    # 3. Kernel Selection
    echo ""
    msg_info "Select Linux Kernel:"
    echo "  1) linux     (Standard upstream kernel) [Default]"
    echo "  2) linux-zen (Tuned for desktop responsiveness)"
    echo "  3) linux-lts (Long Term Support kernel)"
    prompt_input "Enter kernel choice (1/2/3)" "1" KERNEL_CHOICE

    case "$KERNEL_CHOICE" in
        2) KERNEL="linux-zen" ;;
        3) KERNEL="linux-lts" ;;
        *) KERNEL="linux" ;;
    esac
    msg_ok "Selected Kernel: $KERNEL"

    # 4. CPU Microcode Detection
    CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
    if [[ "$CPU_VENDOR" =~ AuthenticAMD ]]; then
        DEFAULT_UCODE="amd-ucode"
    elif [[ "$CPU_VENDOR" =~ GenuineIntel ]]; then
        DEFAULT_UCODE="intel-ucode"
    else
        DEFAULT_UCODE="none"
    fi
    prompt_input "CPU Microcode package (amd-ucode / intel-ucode / none)" "$DEFAULT_UCODE" UCODE

    # 5. Graphics / GPU Driver Selection
    echo ""
    local has_nvidia=false
    local has_amd=false
    local has_intel=false

    if command -v lspci &>/dev/null; then
        lspci | grep -Ei 'vga|3d|display' | grep -qi 'nvidia' && has_nvidia=true
        lspci | grep -Ei 'vga|3d|display' | grep -qi 'amd' && has_amd=true
        lspci | grep -Ei 'vga|3d|display' | grep -qi 'intel' && has_intel=true
    fi

    if [ "$has_nvidia" = true ] && [ "$has_intel" = true ]; then
        GPU_DETECTED="Intel + NVIDIA (Hybrid / Optimus)"
        GPU_PKG="mesa vulkan-intel intel-media-driver lib32-mesa lib32-vulkan-intel nvidia-open-dkms nvidia-utils nvidia-settings lib32-nvidia-utils"
    elif [ "$has_nvidia" = true ] && [ "$has_amd" = true ]; then
        GPU_DETECTED="AMD + NVIDIA (Hybrid / Optimus)"
        GPU_PKG="mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon nvidia-open-dkms nvidia-utils nvidia-settings lib32-nvidia-utils"
    elif [ "$has_nvidia" = true ]; then
        GPU_DETECTED="NVIDIA"
        GPU_PKG="nvidia-open-dkms nvidia-utils nvidia-settings lib32-nvidia-utils"
    elif [ "$has_amd" = true ]; then
        GPU_DETECTED="AMD (Radeon)"
        GPU_PKG="mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon"
    elif [ "$has_intel" = true ]; then
        GPU_DETECTED="Intel (HD/Iris/Arc)"
        GPU_PKG="mesa vulkan-intel intel-media-driver lib32-mesa lib32-vulkan-intel"
    else
        GPU_DETECTED="Generic / Mesa"
        GPU_PKG="mesa vulkan-intel vulkan-radeon lib32-mesa"
    fi

    msg_info "Detected GPU: ${CYAN}${GPU_DETECTED}${RESET}"
    echo "  1) Auto / Detected ($GPU_DETECTED -> $GPU_PKG)"
    echo "  2) Open-Source Mesa (Intel / AMD / Generic Mesa + Vulkan + 32-bit)"
    echo "  3) NVIDIA DKMS (Modern open-kernel drivers for Nvidia + 32-bit)"
    echo "  4) None (Skip GPU driver installation)"
    prompt_input "Select graphics driver option (1/2/3/4)" "1" GPU_CHOICE

    case "$GPU_CHOICE" in
        2) GPU_DRIVERS="mesa vulkan-intel vulkan-radeon intel-media-driver lib32-mesa lib32-vulkan-intel lib32-vulkan-radeon" ;;
        3) GPU_DRIVERS="nvidia-open-dkms nvidia-utils nvidia-settings lib32-nvidia-utils" ;;
        4) GPU_DRIVERS="" ;;
        *) GPU_DRIVERS="$GPU_PKG" ;;
    esac
    msg_ok "Graphics Drivers: ${GPU_DRIVERS:-None}"

    # 6. Desktop Environment & Apps
    echo ""
    msg_info "KDE Plasma Installation Option:"
    echo "  1) Minimal Plasma (plasma-desktop + PipeWire + essential apps) [Recommended]"
    echo "  2) Full Plasma Group (plasma meta-package / all defaults)"
    echo "  3) None / CLI Only"
    prompt_input "Enter desktop choice (1/2/3)" "1" DESKTOP_CHOICE

    case "$DESKTOP_CHOICE" in
        2)
            INSTALL_DESKTOP=true
            PLASMA_FLAVOR="full"
            ;;
        3)
            INSTALL_DESKTOP=false
            PLASMA_FLAVOR="none"
            ;;
        *)
            INSTALL_DESKTOP=true
            PLASMA_FLAVOR="minimal"
            ;;
    esac
    msg_ok "Desktop Selection: $PLASMA_FLAVOR (Install: $INSTALL_DESKTOP)"

    prompt_yes_no "Enable Bluetooth support (bluez & bluedevil)?" "Y" ENABLE_BLUETOOTH

    # 7. Mirror Ranking
    echo ""
    prompt_yes_no "Sort fastest HTTPS mirrors with Reflector before installing?" "Y" ENABLE_REFLECTOR

    # 8. Pacman Confirmation Mode
    echo ""
    prompt_yes_no "Automatically confirm pacman package installations (--noconfirm)? (No = Review pacman prompts)" "Y" PACMAN_NOCONFIRM

    # 9. Execution Mode (Auto / Step-by-step Confirmation)
    echo ""
    prompt_yes_no "You know what you are doing? (Yes: Auto-run all commands; No: Prompt before every command)" "Y" AUTO_MODE

    # Save answers to cache file
    save_config
fi

# Review Summary
msg_step "Installation Summary"
echo -e "  Hostname         : ${GREEN}${HOSTNAME}${RESET}"
echo -e "  Username         : ${GREEN}${USERNAME}${RESET}"
echo -e "  Timezone         : ${GREEN}${TIMEZONE}${RESET}"
echo -e "  Locale           : ${GREEN}${LOCALE}${RESET}"
echo -e "  Kernel           : ${GREEN}${KERNEL}${RESET}"
echo -e "  Microcode        : ${GREEN}${UCODE}${RESET}"
echo -e "  GPU Drivers      : ${GREEN}${GPU_DRIVERS:-None}${RESET}"
echo -e "  Desktop Package  : ${GREEN}${PLASMA_FLAVOR}${RESET}"
echo -e "  Reflector Rank   : ${GREEN}${ENABLE_REFLECTOR}${RESET}"
echo -e "  Pacman Auto-yes  : ${GREEN}${PACMAN_NOCONFIRM:-true}${RESET}"
echo -e "  Bluetooth        : ${GREEN}${ENABLE_BLUETOOTH}${RESET}"
echo ""

prompt_yes_no "Do you want to proceed to partition selection?" "Y" PROCEED_CONFIG
if [ "$PROCEED_CONFIG" != true ]; then
    msg_err "Installation aborted by user."
    exit 1
fi

# Function to update checkpoint state
set_stage() {
    INSTALL_STAGE="$1"
    save_config
}

# Step 1: Disk & Partition Setup
if [ "${INSTALL_STAGE}" = "CONFIGURED" ] || [ -z "${INSTALL_STAGE}" ]; then
    setup_storage
    set_stage "STORAGE_PREPARED"
else
    msg_info "Storage already partitioned and prepared (Stage: ${INSTALL_STAGE})."
    mount_target_subvolumes "$ROOT_PART" "$EFI_PART"
fi

# Step 2: Pacstrap Base System
if [ "${INSTALL_STAGE}" = "STORAGE_PREPARED" ]; then
    bootstrap_system "$KERNEL" "$UCODE" "$ENABLE_REFLECTOR" "${PACMAN_NOCONFIRM:-true}"
    set_stage "PACSTRAP_DONE"
else
    msg_info "Base system already installed via pacstrap (Stage: ${INSTALL_STAGE})."
fi

# Step 3: Pass variables and configs into target system for chroot
if [ "${INSTALL_STAGE}" = "PACSTRAP_DONE" ]; then
    msg_step "Preparing Chroot Environment"

    mkdir -p /mnt/root/installer

    {
        printf 'HOSTNAME=%q\n' "${HOSTNAME}"
        printf 'USERNAME=%q\n' "${USERNAME}"
        printf 'USER_PASSWORD=%q\n' "${USER_PASSWORD}"
        printf 'ROOT_PASSWORD=%q\n' "${ROOT_PASSWORD}"
        printf 'TIMEZONE=%q\n' "${TIMEZONE}"
        printf 'LOCALE=%q\n' "${LOCALE}"
        printf 'KEYMAP=%q\n' "${KEYMAP}"
        printf 'KERNEL=%q\n' "${KERNEL}"
        printf 'GPU_DRIVERS=%q\n' "${GPU_DRIVERS}"
        printf 'INSTALL_DESKTOP=%q\n' "${INSTALL_DESKTOP}"
        printf 'PLASMA_FLAVOR=%q\n' "${PLASMA_FLAVOR}"
        printf 'ENABLE_BLUETOOTH=%q\n' "${ENABLE_BLUETOOTH}"
        printf 'PACMAN_NOCONFIRM=%q\n' "${PACMAN_NOCONFIRM:-true}"
        printf 'AUTO_MODE=%q\n' "${AUTO_MODE}"
    } > /mnt/root/installer/installer_vars.sh

    chmod 600 /mnt/root/installer/installer_vars.sh

    # Copy config templates and chroot script
    cp "${SCRIPT_DIR}/lib/chroot_setup.sh" /mnt/root/installer/chroot_setup.sh
    chmod +x /mnt/root/installer/chroot_setup.sh
    cp -r "${SCRIPT_DIR}/configs" /mnt/root/installer/

    # Place post-install.sh in newly created system
    if [ -n "$USERNAME" ]; then
        mkdir -p "/mnt/home/${USERNAME}"
        cp "${SCRIPT_DIR}/post-install.sh" "/mnt/home/${USERNAME}/post-install.sh"
        chmod +x "/mnt/home/${USERNAME}/post-install.sh"
        mkdir -p "/mnt/home/${USERNAME}/configs"
        cp -r "${SCRIPT_DIR}/configs/"* "/mnt/home/${USERNAME}/configs/" 2>/dev/null || true
    fi

    # Execute Chroot Setup
    msg_step "Entering Chroot & Executing System Setup"
    run_cmd arch-chroot /mnt /bin/bash /root/installer/chroot_setup.sh

    # Ensure proper user ownership on post-install script
    if [ -n "$USERNAME" ]; then
        arch-chroot /mnt chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}" 2>/dev/null || true
    fi

    # Clean up temporary installer files from target
    run_cmd rm -rf /mnt/root/installer

    set_stage "CHROOT_DONE"
fi

# Post-Install Health Checkups
msg_step "Verifying Installation Health"

# 1. Kernel and Initramfs check
has_kernel=false
has_initramfs=false
for f in /mnt/boot/vmlinuz-*; do
    [ -f "$f" ] && has_kernel=true && break
done
for f in /mnt/boot/initramfs-*.img; do
    [ -f "$f" ] && has_initramfs=true && break
done

if [ "$has_kernel" = true ] && [ "$has_initramfs" = true ]; then
    msg_ok "Kernel and initramfs images present in /boot."
else
    msg_warn "Kernel/initramfs images not found in /boot."
fi

# 2. GRUB config check
if [ -f /mnt/boot/grub/grub.cfg ]; then
    msg_ok "GRUB configuration (/boot/grub/grub.cfg) verified."
else
    msg_warn "GRUB configuration (/boot/grub/grub.cfg) missing."
fi

# 3. fstab check
if [ -s /mnt/etc/fstab ]; then
    msg_ok "fstab (/etc/fstab) generated and non-empty."
else
    msg_warn "fstab (/etc/fstab) is missing or empty."
fi

# 4. User and Sudo check
if [ -n "$USERNAME" ] && grep -q "^${USERNAME}:" /mnt/etc/passwd 2>/dev/null; then
    msg_ok "User account '${USERNAME}' created."
fi

# Remove credentials cache file upon successful completion
rm -f "$CACHE_FILE" 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}"
cat << "CONGRATS"
  _  __                                _       _ 
 | |/ /___  _ __   __ _ _ __ __ _  ___| |  _  | |
 | ' // _ \| '_ \ / _` | '__/ _` |/ __| | (_) | |
 | . \ (_) | | | | (_| | | | (_| | (__|_|  _  |_|
 |_|\_\___/|_| |_|\__, |_|  \__,_|\___(_) (_) (_)
                  |___/                           
    Arch Linux + Btrfs + KDE Plasma is ready!
CONGRATS
echo -e "${RESET}"

msg_ok "Kongrats! Your new Arch Linux installation is complete and ready to boot."
echo ""
prompt_yes_no "Would you like to unmount all partitions and reboot now?" "Y" REBOOT_NOW

if [ "$REBOOT_NOW" = true ]; then
    msg_info "Unmounting /mnt and rebooting..."
    run_cmd umount -R /mnt
    run_cmd reboot
else
    msg_info "You can inspect your installation in /mnt or unmount manually when ready with:"
    echo -e "  ${YELLOW}umount -R /mnt${RESET}"
    echo -e "  ${YELLOW}reboot${RESET}"
fi
