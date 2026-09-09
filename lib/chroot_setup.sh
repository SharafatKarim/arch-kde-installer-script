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
    echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}$*${RESET}"
    "$@"
}

run_eval() {
    echo -e "${CYAN}${BOLD}> RUNNING:${RESET} ${YELLOW}$*${RESET}"
    eval "$@"
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
run_eval "echo '${LOCALE}.UTF-8 UTF-8' >> /etc/locale.gen"
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
        run_cmd chown -R "${USERNAME}:${USERNAME}" "/home/$USERNAME" 2>/dev/null || true
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

# Bootloader Installation (GRUB)
msg_step "Installing GRUB Bootloader"
run_cmd grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot
run_cmd grub-mkconfig -o /boot/grub/grub.cfg

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

# Snapper, snap-pac, grub-btrfs Setup
if [ "$ENABLE_SNAPPER" = true ]; then
    msg_step "Configuring Snapper & GRUB Bootable Snapshots"
    run_cmd pacman -S --noconfirm --needed snapper snap-pac grub-btrfs

    # Unmount /.snapshots to avoid nested subvolume
    run_cmd umount /.snapshots || true
    run_cmd rm -rf /.snapshots

    # Create root snapper config
    run_cmd snapper -c root create-config /

    # Replace nested subvolume with Part 1 @snapshots subvolume
    run_cmd btrfs subvolume delete /.snapshots || true
    run_cmd mkdir -p /.snapshots
    run_cmd mount -a

    # Set secure permissions
    run_cmd chmod 750 /.snapshots
    run_cmd chown :wheel /.snapshots

    # Enable snapper timers
    run_cmd systemctl enable snapper-timeline.timer
    run_cmd systemctl enable snapper-cleanup.timer

    # Enable grub-btrfsd
    run_cmd systemctl enable grub-btrfsd.service

    # Regenerate GRUB configuration to include snapshot hooks
    run_cmd grub-mkconfig -o /boot/grub/grub.cfg
    msg_ok "Snapper & GRUB snapshot boot integration complete."
fi

# Performance & Memory Management (Swapfile & zram)
if [ "$SWAP_TYPE" = "btrfs" ] && [ -n "$SWAP_SIZE" ]; then
    msg_step "Configuring Btrfs Swapfile (${SWAP_SIZE}G)"
    if [ ! -f /swapfile ]; then
        run_cmd btrfs filesystem mkswapfile --size "${SWAP_SIZE}g" --uuid clear /swapfile
    fi
    run_cmd swapon /swapfile 2>/dev/null || true
    if ! grep -q "/swapfile" /etc/fstab; then
        run_eval "echo '/swapfile none swap defaults 0 0' >> /etc/fstab"
    fi
    msg_ok "Btrfs swapfile configured."
fi

if [ "$ENABLE_ZRAM" = true ]; then
    msg_step "Configuring zram-generator"
    run_cmd pacman -S --noconfirm --needed zram-generator
    if [ -f /root/installer/zram-generator.conf ]; then
        run_cmd cp /root/installer/zram-generator.conf /etc/systemd/zram-generator.conf
    elif [ -f /tmp/zram-generator.conf ]; then
        run_cmd cp /tmp/zram-generator.conf /etc/systemd/zram-generator.conf
    fi
    msg_ok "zram-generator configured."
fi

if [ "$ENABLE_TRIM" = true ]; then
    msg_step "Enabling Periodic SSD TRIM"
    run_cmd systemctl enable fstrim.timer
    msg_ok "fstrim.timer enabled."
fi

# Optional Bluetooth & Audio extras
if [ "$ENABLE_BLUETOOTH" = true ]; then
    msg_step "Installing & Enabling Bluetooth"
    run_cmd pacman -S --noconfirm --needed bluez bluez-utils bluedevil
    run_cmd systemctl enable bluetooth.service
fi

msg_ok "Chroot configuration completed successfully!"
