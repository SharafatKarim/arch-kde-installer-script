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
        eval "$var_name=\"$default_val\""
    else
        eval "$var_name=\"$user_val\""
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
            eval "$var_name=true"
            break
        elif [ "$choice" = "n" ] || [ "$choice" = "no" ]; then
            eval "$var_name=false"
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
prompt_yes_no "Configure Btrfs Swapfile on dedicated @swap subvolume (uses kernel zswap automatically)?" "Y" SETUP_SWAP
if [ "$SETUP_SWAP" = true ]; then
    prompt_input "Enter Swapfile size in GiB" "8" SWAP_SIZE
fi

prompt_yes_no "Configure zram-generator instead of zswap (standalone RAM swap)?" "N" SETUP_ZRAM
prompt_yes_no "Enable periodic SSD TRIM (fstrim.timer)?" "Y" SETUP_TRIM
prompt_yes_no "Enable Chaotic-AUR and install yay AUR helper?" "Y" SETUP_CHAOTIC_AUR
prompt_yes_no "Install extra utilities (fastfetch, libnotify, power-profiles-daemon)?" "Y" SETUP_EXTRAS

# Execution Mode
echo ""
prompt_yes_no "You know what you are doing? (Yes: Auto-run all commands; No: Prompt before every command)" "Y" AUTO_MODE

# 1. Chaotic-AUR & yay
if [ "$SETUP_CHAOTIC_AUR" = true ]; then
    msg_step "Setting up Chaotic-AUR & yay"
    run_cmd sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || true
    run_cmd sudo pacman-key --lsign-key 3056513887B78AEB || true
    run_cmd sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
    run_cmd sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true

    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        sudo bash -c "cat << 'EOF' >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF"
    fi

    run_cmd sudo pacman -Sy --noconfirm
    run_cmd sudo pacman -S --noconfirm --needed yay
    msg_ok "Chaotic-AUR and yay configured."
fi

# 2. Snapper & GRUB Snapshots
if [ "$SETUP_SNAPPER" = true ]; then
    msg_step "Configuring Snapper & GRUB Snapshot Integration"
    run_cmd sudo pacman -S --noconfirm --needed snapper snap-pac grub-btrfs inotify-tools

    # Unmount /.snapshots if mounted
    sudo umount /.snapshots 2>/dev/null || true
    sudo rm -rf /.snapshots

    # Create root snapper configuration
    run_cmd sudo snapper -c root create-config /

    # Delete default nested subvolume and mount our dedicated @snapshots subvolume
    sudo btrfs subvolume delete /.snapshots 2>/dev/null || true
    sudo mkdir -p /.snapshots
    run_cmd sudo mount -a

    # Set secure permissions
    run_cmd sudo chmod 750 /.snapshots
    run_cmd sudo chown :wheel /.snapshots 2>/dev/null || true

    # Add root to SNAPPER_CONFIGS in /etc/conf.d/snapper if file exists
    if [ -f /etc/conf.d/snapper ]; then
        sudo sed -i 's/^SNAPPER_CONFIGS="\(.*\)"/SNAPPER_CONFIGS="\1 root"/' /etc/conf.d/snapper
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
    msg_step "Configuring Btrfs Swapfile (${SWAP_SIZE}G)"
    sudo mkdir -p /swap
    # Ensure @swap is mounted
    if ! mountpoint -q /swap; then
        sudo mount -a 2>/dev/null || true
    fi

    if [ ! -f /swap/swapfile ]; then
        run_cmd sudo btrfs filesystem mkswapfile --size "${SWAP_SIZE}g" --uuid clear /swap/swapfile
    fi
    if ! swapon --show | grep -q "/swap/swapfile"; then
        run_cmd sudo swapon /swap/swapfile
    else
        msg_ok "Swapfile is already active."
    fi
    if ! grep -q "/swap/swapfile" /etc/fstab; then
        echo '/swap/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
    fi
    msg_ok "Swapfile active at /swap/swapfile."
fi

# 4. zram-generator
if [ "$SETUP_ZRAM" = true ]; then
    msg_step "Configuring zram-generator (Disabling zswap to prevent dual-compression conflict)"
    run_cmd sudo pacman -S --noconfirm --needed zram-generator
    if [ -f "${SCRIPT_DIR}/configs/zram-generator.conf" ]; then
        sudo cp "${SCRIPT_DIR}/configs/zram-generator.conf" /etc/systemd/zram-generator.conf
    else
        sudo bash -c "cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
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
    run_cmd sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || run_cmd sudo systemctl start /dev/zram0 2>/dev/null || true
    msg_ok "zram-generator configured and zswap disabled."
fi

# 5. SSD TRIM
if [ "$SETUP_TRIM" = true ]; then
    msg_step "Enabling SSD TRIM Timer"
    run_cmd sudo systemctl enable --now fstrim.timer
    msg_ok "fstrim.timer enabled."
fi

# 6. Extras & Utilities
if [ "$SETUP_EXTRAS" = true ]; then
    msg_step "Installing Extra Utilities"
    run_cmd sudo pacman -S --noconfirm --needed fastfetch libnotify power-profiles-daemon
    if sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null; then
        msg_ok "power-profiles-daemon service enabled."
    else
        msg_warn "power-profiles-daemon not supported or masked (common in VMs). Skipping service start."
    fi
    msg_ok "Extra utilities installed."
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
