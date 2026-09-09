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
if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
    msg_warn "No active internet connection detected. (Required for fresh install, optional for rescue chroot)"
else
    msg_ok "Internet connectivity verified."
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
if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
    msg_err "Active internet connection is required for installation."
    msg_info "For Wi-Fi, run: nmtui or iwctl"
    exit 1
fi

# Interactive Configuration Questions
msg_step "Interactive System Configuration"

# 1. Hostname & User
prompt_input "Enter Hostname" "archlinux" HOSTNAME
prompt_input "Enter Non-Root Username" "arch" USERNAME
prompt_password "Enter password for '$USERNAME'" USER_PASSWORD
prompt_password "Enter Root password" ROOT_PASSWORD

# 2. Localization
prompt_input "Enter Timezone (Region/City)" "Asia/Dhaka" TIMEZONE
prompt_input "Enter System Locale" "en_US" LOCALE
prompt_input "Enter Keyboard Layout" "us" KEYMAP

# 3. Kernel Selection
echo ""
msg_info "Select Linux Kernel:"
echo "  1) linux-zen (Recommended for desktop responsiveness)"
echo "  2) linux     (Standard upstream kernel)"
echo "  3) linux-lts (Long Term Support kernel)"
prompt_input "Enter kernel choice (1/2/3)" "1" KERNEL_CHOICE

case "$KERNEL_CHOICE" in
    2) KERNEL="linux" ;;
    3) KERNEL="linux-lts" ;;
    *) KERNEL="linux-zen" ;;
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
GPU_DETECTED="Generic / Mesa"
GPU_PKG="mesa"
if lspci | grep -Ei 'vga|3d|display' | grep -qi 'nvidia'; then
    GPU_DETECTED="NVIDIA"
    GPU_PKG="nvidia-dkms nvidia-utils"
elif lspci | grep -Ei 'vga|3d|display' | grep -qi 'amd'; then
    GPU_DETECTED="AMD"
    GPU_PKG="mesa vulkan-radeon xf86-video-amdgpu"
elif lspci | grep -Ei 'vga|3d|display' | grep -qi 'intel'; then
    GPU_DETECTED="Intel"
    GPU_PKG="mesa vulkan-intel"
fi

msg_info "Detected GPU: ${CYAN}${GPU_DETECTED}${RESET}"
echo "  1) Auto / Detected ($GPU_DETECTED -> $GPU_PKG)"
echo "  2) Open-Source Mesa (Intel / AMD / Generic Mesa + Vulkan)"
echo "  3) NVIDIA DKMS (Proprietary drivers for Nvidia cards)"
echo "  4) None (Skip GPU driver installation)"
prompt_input "Select graphics driver option (1/2/3/4)" "1" GPU_CHOICE

case "$GPU_CHOICE" in
    2) GPU_DRIVERS="mesa vulkan-intel vulkan-radeon" ;;
    3) GPU_DRIVERS="nvidia-dkms nvidia-utils" ;;
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

# 7. AUR & Third-Party Repositories
echo ""
prompt_yes_no "Enable Chaotic-AUR and pre-install yay (AUR Helper)?" "N" ENABLE_CHAOTIC_AUR

# 8. Snapshots & Performance
echo ""
prompt_yes_no "Enable Snapper automated snapshots + GRUB boot menu integration?" "Y" ENABLE_SNAPPER
prompt_yes_no "Enable zram compressed RAM swap (zram-generator)?" "Y" ENABLE_ZRAM

echo ""
prompt_input "Btrfs Swapfile size in GiB (e.g., 8, 4, or 0 for none)" "8" SWAP_SIZE_INPUT
if [ "$SWAP_SIZE_INPUT" -gt 0 ] 2>/dev/null; then
    SWAP_TYPE="btrfs"
    SWAP_SIZE="$SWAP_SIZE_INPUT"
else
    SWAP_TYPE="none"
    SWAP_SIZE="0"
fi

prompt_yes_no "Enable periodic SSD TRIM (fstrim.timer)?" "Y" ENABLE_TRIM

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
echo -e "  Chaotic-AUR/yay  : ${GREEN}${ENABLE_CHAOTIC_AUR}${RESET}"
echo -e "  Snapper in GRUB  : ${GREEN}${ENABLE_SNAPPER}${RESET}"
echo -e "  zram Swap        : ${GREEN}${ENABLE_ZRAM}${RESET}"
echo -e "  Btrfs Swapfile   : ${GREEN}${SWAP_SIZE}G${RESET}"
echo -e "  SSD TRIM         : ${GREEN}${ENABLE_TRIM}${RESET}"
echo ""

prompt_yes_no "Do you want to proceed to partition selection?" "Y" PROCEED_CONFIG
if [ "$PROCEED_CONFIG" != true ]; then
    msg_err "Installation aborted by user."
    exit 1
fi

# Step 1: Disk & Partition Setup
setup_storage

# Step 2: Pacstrap Base System
bootstrap_system "$KERNEL" "$UCODE"

# Step 3: Pass variables and configs into target system for chroot
msg_step "Preparing Chroot Environment"

cat << VARS > /mnt/tmp/installer_vars.sh
HOSTNAME="${HOSTNAME}"
USERNAME="${USERNAME}"
USER_PASSWORD="${USER_PASSWORD}"
ROOT_PASSWORD="${ROOT_PASSWORD}"
TIMEZONE="${TIMEZONE}"
LOCALE="${LOCALE}"
KEYMAP="${KEYMAP}"
KERNEL="${KERNEL}"
GPU_DRIVERS="${GPU_DRIVERS}"
INSTALL_DESKTOP="${INSTALL_DESKTOP}"
PLASMA_FLAVOR="${PLASMA_FLAVOR}"
ENABLE_BLUETOOTH="${ENABLE_BLUETOOTH}"
ENABLE_CHAOTIC_AUR="${ENABLE_CHAOTIC_AUR}"
ENABLE_SNAPPER="${ENABLE_SNAPPER}"
ENABLE_ZRAM="${ENABLE_ZRAM}"
SWAP_TYPE="${SWAP_TYPE}"
SWAP_SIZE="${SWAP_SIZE}"
ENABLE_TRIM="${ENABLE_TRIM}"
VARS

chmod 600 /mnt/tmp/installer_vars.sh

# Copy config templates and chroot script
cp "${SCRIPT_DIR}/lib/chroot_setup.sh" /mnt/tmp/chroot_setup.sh
chmod +x /mnt/tmp/chroot_setup.sh

if [ -f "${SCRIPT_DIR}/configs/zram-generator.conf" ]; then
    cp "${SCRIPT_DIR}/configs/zram-generator.conf" /mnt/tmp/zram-generator.conf
fi

# Execute Chroot Setup
msg_step "Entering Chroot & Executing System Setup"
run_cmd arch-chroot /mnt /tmp/chroot_setup.sh

# Clean up temporary installer files from target
run_cmd rm -f /mnt/tmp/installer_vars.sh /mnt/tmp/chroot_setup.sh /mnt/tmp/zram-generator.conf

msg_step "Installation Complete!"
msg_ok "Arch Linux with Btrfs and Minimal KDE Plasma has been successfully installed."
echo ""
prompt_yes_no "Would you like to unmount all partitions and reboot now?" "N" REBOOT_NOW

if [ "$REBOOT_NOW" = true ]; then
    msg_info "Unmounting /mnt and rebooting..."
    run_cmd umount -R /mnt
    run_cmd reboot
else
    msg_info "You can now inspect your installation in /mnt or unmount manually with:"
    echo -e "  ${YELLOW}umount -R /mnt${RESET}"
    echo -e "  ${YELLOW}reboot${RESET}"
fi
