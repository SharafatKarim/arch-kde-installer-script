#!/usr/bin/env bash
# post-install.sh - Interactive Arch Linux Post-Installation & Tuning Script
# Based on: https://sharafat.pages.dev/archlinux-post-install/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color definitions
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

msg_info() { echo -e "${BLUE}${BOLD}[*]${RESET} $1"; }
msg_ok()   { echo -e "${GREEN}${BOLD}[✓]${RESET} $1"; }
msg_warn() { echo -e "${YELLOW}${BOLD}[!]${RESET} $1"; }
msg_err()  { echo -e "${RED}${BOLD}[✗]${RESET} $1"; }
msg_step() { echo -e "\n${MAGENTA}${BOLD}=== $1 ===${RESET}"; }

run_cmd() {
    local cmd=("$@")
    while true; do
        echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}${cmd[*]}${RESET}"
        if [ "${AUTO_MODE}" = false ]; then
            local user_confirm=""
            echo -ne "${YELLOW}${BOLD}Execute this command? [${GREEN}Y${RESET}/n/q(uit)]: ${RESET}"
            read -r user_confirm
            user_confirm=$(echo "$user_confirm" | tr '[:upper:]' '[:lower:]')
            if [ "$user_confirm" = "q" ] || [ "$user_confirm" = "quit" ]; then
                msg_err "Aborted by user."
                exit 1
            elif [ "$user_confirm" = "n" ] || [ "$user_confirm" = "no" ]; then
                msg_warn "Skipped: ${cmd[*]}"
                return 0
            fi
        fi

        set +e
        "${cmd[@]}"
        local status=$?
        set -e
        if [ $status -eq 0 ]; then
            return 0
        fi

        msg_err "Command failed with exit code $status: ${cmd[*]}"

        # Smart diagnostics for package managers
        if [[ "${cmd[*]}" =~ pacman|yay ]]; then
            if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
                msg_warn "Network seems unreachable! Please check your internet connection."
            fi
            if [ -f /var/lib/pacman/db.lck ]; then
                msg_warn "Found stale pacman lock file: /var/lib/pacman/db.lck. Removing it..."
                sudo rm -f /var/lib/pacman/db.lck 2>/dev/null || true
            fi
        fi

        echo ""
        msg_warn "Failure Options for: ${cmd[*]}"
        echo -e "  [${GREEN}r${RESET}] ${BOLD}Retry${RESET} command (Default)"
        echo -e "  [${CYAN}s${RESET}] Drop to interactive ${BOLD}Shell${RESET} (fix network/mirrors, then type 'exit' to return)"
        echo -e "  [${YELLOW}i${RESET}] ${BOLD}Ignore${RESET} / Skip this failure and continue"
        echo -e "  [${RED}q${RESET}] ${BOLD}Quit${RESET} and abort script"

        local action=""
        echo -ne "${BOLD}Choice [${GREEN}r${RESET}/s/i/q]: ${RESET}"
        read -r action
        action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

        case "$action" in
            s|shell)
                msg_info "Opening interactive subshell. Type 'exit' when finished to resume script."
                bash --norc -i || bash -i
                ;;
            i|ignore|skip)
                msg_warn "Ignored error. Continuing..."
                return 0
                ;;
            q|quit|abort)
                msg_err "Aborted by user."
                exit $status
                ;;
            r|retry|*)
                msg_info "Retrying command..."
                ;;
        esac
    done
}

run_eval() {
    local cmd_str="$*"
    while true; do
        echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}${cmd_str}${RESET}"
        if [ "${AUTO_MODE}" = false ]; then
            local user_confirm=""
            echo -ne "${YELLOW}${BOLD}Execute this command? [${GREEN}Y${RESET}/n/q(uit)]: ${RESET}"
            read -r user_confirm
            user_confirm=$(echo "$user_confirm" | tr '[:upper:]' '[:lower:]')
            if [ "$user_confirm" = "q" ] || [ "$user_confirm" = "quit" ]; then
                msg_err "Aborted by user."
                exit 1
            elif [ "$user_confirm" = "n" ] || [ "$user_confirm" = "no" ]; then
                msg_warn "Skipped: ${cmd_str}"
                return 0
            fi
        fi

        set +e
        eval "${cmd_str}"
        local status=$?
        set -e
        if [ $status -eq 0 ]; then
            return 0
        fi

        msg_err "Command failed with exit code $status: ${cmd_str}"

        # Smart diagnostics for package managers
        if [[ "${cmd_str}" =~ pacman|yay ]]; then
            if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
                msg_warn "Network seems unreachable! Please check your internet connection."
            fi
            if [ -f /var/lib/pacman/db.lck ]; then
                msg_warn "Found stale pacman lock file: /var/lib/pacman/db.lck. Removing it..."
                sudo rm -f /var/lib/pacman/db.lck 2>/dev/null || true
            fi
        fi

        echo ""
        msg_warn "Failure Options for: ${cmd_str}"
        echo -e "  [${GREEN}r${RESET}] ${BOLD}Retry${RESET} command (Default)"
        echo -e "  [${CYAN}s${RESET}] Drop to interactive ${BOLD}Shell${RESET} (fix network/mirrors, then type 'exit' to return)"
        echo -e "  [${YELLOW}i${RESET}] ${BOLD}Ignore${RESET} / Skip this failure and continue"
        echo -e "  [${RED}q${RESET}] ${BOLD}Quit${RESET} and abort script"

        local action=""
        echo -ne "${BOLD}Choice [${GREEN}r${RESET}/s/i/q]: ${RESET}"
        read -r action
        action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

        case "$action" in
            s|shell)
                msg_info "Opening interactive subshell. Type 'exit' when finished to resume script."
                bash --norc -i || bash -i
                ;;
            i|ignore|skip)
                msg_warn "Ignored error. Continuing..."
                return 0
                ;;
            q|quit|abort)
                msg_err "Aborted by user."
                exit $status
                ;;
            r|retry|*)
                msg_info "Retrying command..."
                ;;
        esac
    done
}

prompt_input() {
    local prompt_text="$1"
    local default_val="$2"
    local var_name="$3"
    local user_val=""

    if [ -n "$default_val" ]; then
        echo -ne "${BOLD}${prompt_text} [${GREEN}${default_val}${RESET}${BOLD}]: ${RESET}"
    else
        echo -ne "${BOLD}${prompt_text}: ${RESET}"
    fi

    read -r user_val
    if [ -z "$user_val" ]; then
        printf -v "$var_name" '%s' "$default_val"
    else
        printf -v "$var_name" '%s' "$user_val"
    fi
}

prompt_yes_no() {
    local prompt_text="$1"
    local default_choice="$2" # "Y" or "N"
    local var_name="$3"
    local choice=""

    local options="[y/n]"
    [ "$default_choice" = "Y" ] && options="[${GREEN}Y${RESET}/n]"
    [ "$default_choice" = "N" ] && options="[y/${GREEN}N${RESET}]"

    while true; do
        echo -ne "${BOLD}${prompt_text} ${options}: ${RESET}"
        read -r choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        if [ -z "$choice" ]; then
            choice=$(echo "$default_choice" | tr '[:upper:]' '[:lower:]')
        fi

        if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
            printf -v "$var_name" '%s' "true"
            break
        elif [ "$choice" = "n" ] || [ "$choice" = "no" ]; then
            printf -v "$var_name" '%s' "false"
            break
        else
            msg_warn "Please enter 'y' for yes or 'n' for no."
        fi
    done
}

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
    _             _       _     _                  
   / \   _ __ ___| |__   | |   (_)_ __  _   ___  __
  / _ \ | '__/ __| '_ \  | |   | | '_ \| | | \ \/ /
 / ___ \| | | (__| | | | | |___| | | | | |_| |>  < 
/_/   \_\_|  \___|_| |_| |_____|_|_| |_|\__,_/_/\_\
           POST-INSTALLATION & TUNING SCRIPT
BANNER
echo -e "${RESET}"

msg_step "Pre-flight Environment Check"

# Privilege check
if [ "$EUID" -eq 0 ]; then
    msg_warn "Running post-install.sh directly as root is not recommended. It should be run as your regular user."
else
    msg_info "Validating sudo privileges..."
    if ! sudo -v; then
        msg_err "This script requires sudo privileges. Please run as a user in the wheel group."
        exit 1
    fi
    msg_ok "Sudo privileges verified."
fi

# Network test
msg_info "Checking internet connection..."
if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    msg_err "No active internet connection detected. Please connect to the internet first."
    exit 1
fi
msg_ok "Internet connectivity verified."

# Interactive Configuration
msg_step "Post-Installation Options"

prompt_yes_no "Configure Snapper & GRUB Bootable Snapshots (snapper, snap-pac, grub-btrfsd)?" "Y" SETUP_SNAPPER
# Detect total physical RAM in GiB for optimal swap sizing
TOTAL_RAM_GB=$(awk '/MemTotal/ {printf "%.0f\n", $2/(1024*1024)}' /proc/meminfo 2>/dev/null || echo "8")
[ -z "$TOTAL_RAM_GB" ] || [ "$TOTAL_RAM_GB" -le 0 ] && TOTAL_RAM_GB="8"

echo ""
msg_info "Memory & Swap Architecture (ArchWiki):"
echo "  1) Hybrid: ZRAM + Btrfs Swapfile [Default & Recommended]"
echo "     - ZRAM (${TOTAL_RAM_GB}G/2 in RAM with zstd, pri=100) absorbs all normal multitasking with 0 disk wear."
echo "     - Swapfile (${TOTAL_RAM_GB}G on @swap, pri=10) provides emergency overflow & hibernation support."
echo "  2) ZRAM Only (Compressed RAM swap; fastest, 0 disk wear, no hibernation)"
echo "  3) Btrfs Swapfile Only (Disk swapfile with kernel zswap caching)"
echo "  4) None (Skip swap configuration)"
prompt_input "Select swap strategy (1/2/3/4)" "1" SWAP_STRATEGY_CHOICE

SETUP_SWAP=false
SETUP_ZRAM=false
SWAP_SIZE="$TOTAL_RAM_GB"

case "$SWAP_STRATEGY_CHOICE" in
    1)
        SETUP_SWAP=true
        SETUP_ZRAM=true
        prompt_input "Enter Btrfs Swapfile size in GiB (equal to RAM for hibernation)" "$TOTAL_RAM_GB" SWAP_SIZE
        ;;
    2)
        SETUP_ZRAM=true
        ;;
    3)
        SETUP_SWAP=true
        prompt_input "Enter Btrfs Swapfile size in GiB" "$TOTAL_RAM_GB" SWAP_SIZE
        ;;
    *)
        SETUP_SWAP=false
        SETUP_ZRAM=false
        ;;
esac
prompt_yes_no "Enable periodic SSD TRIM (fstrim.timer)?" "Y" SETUP_TRIM
prompt_yes_no "Enable Chaotic-AUR and install yay AUR helper?" "Y" SETUP_CHAOTIC_AUR
prompt_yes_no "Install extra utilities (fastfetch, libnotify, power-profiles-daemon, earlyoom)?" "Y" SETUP_EXTRAS
prompt_yes_no "Automatically confirm pacman package installations (--noconfirm)? (No = Review pacman prompts)" "Y" PACMAN_NOCONFIRM

# Execution Mode
echo ""
prompt_yes_no "You know what you are doing? (Yes: Auto-run all commands; No: Prompt before every command)" "Y" AUTO_MODE

NOCONFIRM_FLAG=""
if [ "${PACMAN_NOCONFIRM:-true}" = true ]; then
    NOCONFIRM_FLAG="--noconfirm"
fi

# 1. Chaotic-AUR & yay
if [ "$SETUP_CHAOTIC_AUR" = true ]; then
    msg_step "Setting up Chaotic-AUR & yay"
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || sudo pacman-key --recv-key 3056513887B78AEB 2>/dev/null || true
    sudo pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
    run_cmd sudo pacman -U $NOCONFIRM_FLAG 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    run_cmd sudo pacman -U $NOCONFIRM_FLAG 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        sudo bash -c "cat << 'EOF' >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF"
    fi

    run_cmd sudo pacman -Sy $NOCONFIRM_FLAG
    run_cmd sudo pacman -S $NOCONFIRM_FLAG --needed yay
    msg_ok "Chaotic-AUR and yay configured."
fi

# 2. Snapper & GRUB Snapshots
if [ "$SETUP_SNAPPER" = true ]; then
    msg_step "Configuring Snapper & GRUB Snapshot Integration"
    run_cmd sudo pacman -S $NOCONFIRM_FLAG --needed snapper snap-pac grub-btrfs inotify-tools

    # Check if snapper config already exists
    if [ ! -f /etc/snapper/configs/root ]; then
        # Unmount /.snapshots if mounted
        sudo umount /.snapshots 2>/dev/null || true
        sudo rm -rf /.snapshots

        # Create root snapper configuration
        run_cmd sudo snapper -c root create-config /

        # Delete default nested subvolume created by snapper and mount our dedicated @snapshots subvolume
        sudo btrfs subvolume delete /.snapshots 2>/dev/null || true
        sudo mkdir -p /.snapshots
        run_cmd sudo mount -a
    else
        msg_info "Snapper root configuration already exists. Ensuring /.snapshots is mounted..."
        if ! mountpoint -q /.snapshots; then
            sudo mount /.snapshots 2>/dev/null || sudo mount -a 2>/dev/null || true
        fi
    fi

    # Set secure permissions
    run_cmd sudo chmod 750 /.snapshots
    run_cmd sudo chown :wheel /.snapshots 2>/dev/null || true

    # Add root to SNAPPER_CONFIGS in /etc/conf.d/snapper if file exists
    if [ -f /etc/conf.d/snapper ] && ! grep -q 'root' /etc/conf.d/snapper; then
        sudo sed -i 's/^SNAPPER_CONFIGS="\(.*\)"/SNAPPER_CONFIGS="\1 root"/' /etc/conf.d/snapper
        sudo sed -i 's/=" /="/' /etc/conf.d/snapper
        sudo sed -i 's/  */ /g' /etc/conf.d/snapper
    fi

    # Enable systemd timers and grub-btrfsd
    run_cmd sudo systemctl enable --now snapper-timeline.timer
    run_cmd sudo systemctl enable --now snapper-cleanup.timer
    run_cmd sudo systemctl enable --now grub-btrfsd.service

    # Ensure os-prober setting is enabled in GRUB config for multi-boot
    if grep -q "GRUB_DISABLE_OS_PROBER" /etc/default/grub 2>/dev/null; then
        sudo sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    else
        echo "GRUB_DISABLE_OS_PROBER=false" | sudo tee -a /etc/default/grub >/dev/null
    fi

    # Regenerate GRUB config
    run_cmd sudo grub-mkconfig -o /boot/grub/grub.cfg
    msg_ok "Snapper & GRUB snapshot integration complete."
fi

# 3. Swapfile Setup on @swap
if [ "$SETUP_SWAP" = true ] && [ -n "$SWAP_SIZE" ]; then
    SWAP_SIZE="${SWAP_SIZE%[gG]}"
    SWAP_SIZE="${SWAP_SIZE%[iI][bB]}"
    msg_step "Configuring Btrfs Swapfile (${SWAP_SIZE}G)"
    sudo mkdir -p /swap
    # Ensure @swap is mounted
    if ! mountpoint -q /swap; then
        sudo mount /swap 2>/dev/null || sudo mount -a 2>/dev/null || true
    fi

    if ! mountpoint -q /swap; then
        msg_warn "/swap is not mounted as a dedicated subvolume. Skipping swapfile creation to avoid snapshot conflicts on root."
    else
        if [ ! -f /swap/swapfile ]; then
            run_cmd sudo btrfs filesystem mkswapfile --size "${SWAP_SIZE}g" --uuid clear /swap/swapfile
        fi

        # Priority 10 for disk swap if ZRAM is also used (Scenario B: Hybrid)
        fstab_opts="defaults"
        swapon_opts=()
        if [ "$SETUP_ZRAM" = true ]; then
            fstab_opts="defaults,pri=10"
            swapon_opts=("-p" "10")
        fi

        if ! swapon --show | grep -q "/swap/swapfile"; then
            run_cmd sudo swapon "${swapon_opts[@]}" /swap/swapfile
        else
            msg_ok "Swapfile is already active."
        fi

        fstab_line="/swap/swapfile none swap ${fstab_opts} 0 0"
        if ! grep -q "/swap/swapfile" /etc/fstab; then
            echo "$fstab_line" | sudo tee -a /etc/fstab
        else
            sudo sed -i "s|^/swap/swapfile.*|${fstab_line}|" /etc/fstab
        fi

        # Query hibernation parameters from Btrfs swapfile (ArchWiki)
        root_uuid=""
        root_uuid=$(findmnt -no UUID -T /swap/swapfile 2>/dev/null || true)
        resume_offset=""
        resume_offset=$(sudo btrfs inspect-internal map-swapfile -r /swap/swapfile 2>/dev/null || true)
        if [ -n "$root_uuid" ] && [ -n "$resume_offset" ]; then
            msg_ok "Btrfs swapfile ready (Priority: ${fstab_opts})."
            msg_info "Hibernation Parameters (if you wish to enable suspend-to-disk in GRUB):"
            echo -e "  ${CYAN}${BOLD}resume=UUID=${root_uuid} resume_offset=${resume_offset}${RESET}"
        fi
    fi
fi

# 4. zram-generator
if [ "$SETUP_ZRAM" = true ]; then
    msg_step "Configuring zram-generator (Disabling zswap to prevent dual-compression conflict)"
    run_cmd sudo pacman -S $NOCONFIRM_FLAG --needed zram-generator
    if [ -f "${SCRIPT_DIR}/configs/zram-generator.conf" ]; then
        sudo cp "${SCRIPT_DIR}/configs/zram-generator.conf" /etc/systemd/zram-generator.conf
    else
        sudo bash -c "cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF"
    fi

    # Arch Wiki recommendation: Disable zswap when using zram to avoid double-compression overhead
    if [ -d /sys/module/zswap ]; then
        sudo bash -c "echo 0 > /sys/module/zswap/parameters/enabled" 2>/dev/null || true
        sudo bash -c "cat << 'EOF' > /etc/tmpfiles.d/disable-zswap.conf
w /sys/module/zswap/parameters/enabled - - - - 0
EOF"
    fi

    run_cmd sudo systemctl daemon-reload
    if ! sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null; then
        sudo systemctl start /dev/zram0 2>/dev/null || true
    fi
    msg_ok "zram-generator configured (Priority: 100) and zswap disabled."
fi

# Apply Unified VM Sysctl Performance Tuning (ArchWiki)
if [ "$SETUP_ZRAM" = true ]; then
    sudo rm -f /etc/sysctl.d/99-vm-swap-parameters.conf /etc/sysctl.d/99-vm-zram-parameters.conf 2>/dev/null || true
    sudo bash -c "cat << 'EOF' > /etc/sysctl.d/99-vm-parameters.conf
# ArchWiki ZRAM tuning: High swappiness prioritizes fast compressed RAM over dropping page cache
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF"
    sudo sysctl --system 2>/dev/null || true
    msg_ok "VM parameters tuned for ZRAM (swappiness=180, page-cluster=0)."
elif [ "$SETUP_SWAP" = true ]; then
    sudo rm -f /etc/sysctl.d/99-vm-swap-parameters.conf /etc/sysctl.d/99-vm-zram-parameters.conf 2>/dev/null || true
    sudo bash -c "cat << 'EOF' > /etc/sysctl.d/99-vm-parameters.conf
# ArchWiki Disk Swap tuning: Low swappiness prevents premature SSD writes
vm.swappiness = 10
EOF"
    sudo sysctl --system 2>/dev/null || true
    msg_ok "VM parameters tuned for Disk Swap (swappiness=10)."
fi

if [ "$SETUP_ZRAM" = true ] || [ "$SETUP_SWAP" = true ]; then
    echo ""
    msg_info "Active Swap Configuration Summary:"
    swapon --show || true
fi

# 5. SSD TRIM & Btrfs Maintenance
if [ "$SETUP_TRIM" = true ]; then
    msg_step "Enabling SSD TRIM & Btrfs Maintenance Timers"
    run_cmd sudo systemctl enable --now fstrim.timer
    run_cmd sudo systemctl enable --now btrfs-scrub@-.timer 2>/dev/null || true
    msg_ok "fstrim.timer and btrfs-scrub@-.timer enabled."
fi

# 6. Extras & Utilities
if [ "$SETUP_EXTRAS" = true ]; then
    msg_step "Installing Extra Utilities & Performance Tuning"
    run_cmd sudo pacman -S $NOCONFIRM_FLAG --needed fastfetch libnotify power-profiles-daemon earlyoom
    if sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null; then
        msg_ok "power-profiles-daemon service enabled."
    else
        msg_warn "power-profiles-daemon not supported or masked (common in VMs). Skipping service start."
    fi
    if sudo systemctl enable --now earlyoom.service 2>/dev/null; then
        msg_ok "earlyoom service enabled for proactive OOM freeze protection."
    fi

    # Deploy optimal I/O schedulers rule if present (ArchWiki: Improving performance)
    if [ -f "${SCRIPT_DIR}/configs/60-ioschedulers.rules" ]; then
        sudo cp "${SCRIPT_DIR}/configs/60-ioschedulers.rules" /etc/udev/rules.d/60-ioschedulers.rules
        sudo udevadm control --reload-rules && sudo udevadm trigger 2>/dev/null || true
        msg_ok "I/O schedulers configured (BFQ for SATA/HDD, none for NVMe)."
    fi
    msg_ok "Extra utilities installed and tuned."
fi

echo -e "\n${GREEN}${BOLD}"
cat << "CONGRATS"
  _  __                                _       _ 
 | |/ /___  _ __   __ _ _ __ __ _  ___| |  _  | |
 | ' // _ \| '_ \ / _` | '__/ _` |/ __| | (_) | |
 | . \ (_) | | | | (_| | | | (_| | (__|_|  _  |_|
 |_|\_\___/|_| |_|\__, |_|  \__,_|\___(_) (_) (_)
                  |___/                           
     Post-Installation & Tuning Complete!
CONGRATS
echo -e "${RESET}"

msg_ok "Kongrats! Your Arch Linux system is now fully tuned and snapshot-protected."
