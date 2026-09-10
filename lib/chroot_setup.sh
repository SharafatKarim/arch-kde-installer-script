#!/usr/bin/env bash
# lib/chroot_setup.sh - Script executed inside arch-chroot /mnt

set -e

# Source variables passed via environment file
if [ -f /root/installer/installer_vars.sh ]; then
    source /root/installer/installer_vars.sh
elif [ -f /tmp/installer_vars.sh ]; then
    source /tmp/installer_vars.sh
fi

# Color definitions
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

msg_info() { echo -e "${CYAN}${BOLD}[*]${RESET} $1"; }
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
                rm -f /var/lib/pacman/db.lck 2>/dev/null || true
            fi
        fi

        echo ""
        msg_warn "Failure Options for: ${cmd[*]}"
        echo -e "  [${GREEN}r${RESET}] ${BOLD}Retry${RESET} command (Default)"
        echo -e "  [${CYAN}s${RESET}] Drop to interactive ${BOLD}Shell${RESET} (fix network/mirrors, then type 'exit' to return)"
        echo -e "  [${YELLOW}i${RESET}] ${BOLD}Ignore${RESET} / Skip this failure and continue"
        echo -e "  [${RED}q${RESET}] ${BOLD}Quit${RESET} and abort installer"

        local action=""
        echo -ne "${BOLD}Choice [${GREEN}r${RESET}/s/i/q]: ${RESET}"
        read -r action
        action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

        case "$action" in
            s|shell)
                msg_info "Opening interactive subshell. Type 'exit' when finished to resume installer."
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
                rm -f /var/lib/pacman/db.lck 2>/dev/null || true
            fi
        fi

        echo ""
        msg_warn "Failure Options for: ${cmd_str}"
        echo -e "  [${GREEN}r${RESET}] ${BOLD}Retry${RESET} command (Default)"
        echo -e "  [${CYAN}s${RESET}] Drop to interactive ${BOLD}Shell${RESET} (fix network/mirrors, then type 'exit' to return)"
        echo -e "  [${YELLOW}i${RESET}] ${BOLD}Ignore${RESET} / Skip this failure and continue"
        echo -e "  [${RED}q${RESET}] ${BOLD}Quit${RESET} and abort installer"

        local action=""
        echo -ne "${BOLD}Choice [${GREEN}r${RESET}/s/i/q]: ${RESET}"
        read -r action
        action=$(echo "$action" | tr '[:upper:]' '[:lower:]')

        case "$action" in
            s|shell)
                msg_info "Opening interactive subshell. Type 'exit' when finished to resume installer."
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

msg_step "Configuring System Localization & Clock"
# Timezone & Clock
if [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
    run_cmd ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
else
    run_cmd ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi
run_cmd hwclock --systohc

# Localization
if grep -q "^#*${LOCALE}\.UTF-8 UTF-8" /etc/locale.gen 2>/dev/null; then
    run_cmd sed -i "s/^#*${LOCALE}\.UTF-8 UTF-8/${LOCALE}.UTF-8 UTF-8/" /etc/locale.gen
else
    run_eval "echo '${LOCALE}.UTF-8 UTF-8' >> /etc/locale.gen"
fi
run_cmd locale-gen
run_eval "echo 'LANG=${LOCALE}.UTF-8' > /etc/locale.conf"
run_eval "echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf"

# Hostname & Hosts
msg_step "Configuring Hostname & Networking"
run_eval "echo '${HOSTNAME}' > /etc/hostname"
cat << HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# Enable NetworkManager
run_cmd systemctl enable NetworkManager.service

# Root & User Passwords
msg_step "Configuring User Accounts & Sudo"
echo "root:${ROOT_PASSWORD}" | chpasswd
msg_ok "Root password updated."

if [ -n "$USERNAME" ]; then
    if id "$USERNAME" &>/dev/null; then
        msg_info "User '$USERNAME' already exists. Updating groups and shell..."
        run_cmd usermod -aG wheel -s /bin/bash "$USERNAME"
    else
        # -m won't overwrite existing home directory if it already exists
        run_cmd useradd -m -G wheel -s /bin/bash "$USERNAME" || run_cmd useradd -M -G wheel -s /bin/bash "$USERNAME"
    fi
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
    # Ensure correct permissions on user home directory if preserving
    if [ -d "/home/$USERNAME" ]; then
        chown -R "${USERNAME}:${USERNAME}" "/home/$USERNAME" 2>/dev/null || true
    fi
    # Enable %wheel in sudoers
    run_eval "echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel"
    run_cmd chmod 0440 /etc/sudoers.d/10-wheel
    msg_ok "User '$USERNAME' configured with sudo privileges."
fi

# Pacman configuration enhancements
msg_step "Enhancing pacman.conf"
run_cmd sed -i 's/^#Color/Color/' /etc/pacman.conf
if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    run_cmd sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
fi
run_cmd sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
run_cmd sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf

# Sync package databases inside chroot
run_cmd pacman -Sy --noconfirm

# Optional GPU Driver Installation
if [ -n "$GPU_DRIVERS" ]; then
    msg_step "Installing GPU Drivers ($GPU_DRIVERS)"
    # shellcheck disable=SC2086
    run_cmd pacman -S --noconfirm --needed $GPU_DRIVERS
fi

# Optional Chaotic AUR & yay Setup
if [ "$ENABLE_CHAOTIC_AUR" = true ]; then
    msg_step "Configuring Chaotic-AUR & Installing yay"
    run_cmd pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || true
    run_cmd pacman-key --lsign-key 3056513887B78AEB || true
    run_cmd pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
    run_cmd pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true

    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        cat << 'EOF' >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    fi

    run_cmd pacman -Sy --noconfirm
    run_cmd pacman -S --noconfirm --needed yay || msg_warn "Could not pre-install yay from chaotic-aur. You can install it manually later."
fi

# Bootloader Installation (GRUB & Multi-Boot OS Prober)
msg_step "Installing GRUB Bootloader & Configuring Dual-Boot Support"
run_cmd pacman -S --noconfirm --needed grub efibootmgr os-prober ntfs-3g

# Enable os-prober in /etc/default/grub
if grep -q "GRUB_DISABLE_OS_PROBER" /etc/default/grub 2>/dev/null; then
    run_cmd sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
    run_eval "echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub"
fi

run_cmd grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot
run_cmd grub-mkconfig -o /boot/grub/grub.cfg

if [ -d /boot/EFI/Microsoft ] || os-prober 2>/dev/null | grep -qi "Windows"; then
    msg_ok "Windows Boot Manager detected and integrated into GRUB boot menu."
fi

# KDE Plasma & Desktop Stack
if [ "$INSTALL_DESKTOP" = true ]; then
    if [ "$PLASMA_FLAVOR" = "full" ]; then
        msg_step "Installing Full KDE Plasma Package Group & PipeWire"
        plasma_pkgs=(
            plasma
            plasma-login-manager
            pipewire
            pipewire-pulse
            wireplumber
            dolphin
            konsole
            spectacle
            ark
            noto-fonts
            noto-fonts-emoji
            noto-fonts-cjk
        )
    else
        msg_step "Installing Minimal KDE Plasma (plasma-desktop) & PipeWire Stack"
        plasma_pkgs=(
            plasma-desktop
            plasma-login-manager
            xdg-desktop-portal-kde
            polkit-kde-agent
            powerdevil
            pipewire
            pipewire-pulse
            wireplumber
            plasma-nm
            plasma-pa
            dolphin
            konsole
            kscreen
            plasma-browser-integration
            plasma-systemmonitor
            spectacle
            ark
            noto-fonts
            noto-fonts-emoji
            noto-fonts-cjk
        )
    fi

    run_cmd pacman -S --noconfirm --needed "${plasma_pkgs[@]}"

    # Enable plasma-login-manager
    run_cmd systemctl enable plasmalogin.service
    msg_ok "plasma-login-manager (plasmalogin.service) enabled."
fi

# Optional Bluetooth
if [ "$ENABLE_BLUETOOTH" = true ]; then
    msg_step "Installing & Enabling Bluetooth"
    run_cmd pacman -S --noconfirm --needed bluez bluez-utils bluedevil
    run_cmd systemctl enable bluetooth.service
fi

msg_ok "Chroot base installation completed successfully!"
