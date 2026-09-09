# Arch Linux + Btrfs + Minimal KDE Plasma Installer

An automated, interactive installer script for Arch Linux based on the architecture detailed in the following guides:
- [Part 1: Arch Linux Minimal Install with Btrfs](https://sharafat.pages.dev/archlinux-install/)
- [Part 2: Arch Linux Post-Install with Minimal Plasma](https://sharafat.pages.dev/archlinux-post-install/)

## Quick Start (From Arch Live ISO)

1. Boot into the official Arch Linux live ISO (UEFI mode).
2. Connect to the internet (`nmtui` for Wi-Fi or plug in Ethernet).
3. Update the system packages, and `archlinux-keyring`:
   ```bash
   pacman -Sy archlinux-keyring --noconfirm
   ```
4. Install `git`:
   ```bash
   pacman -Sy git --noconfirm
   ```
5. Clone or download this repository:
   ```bash
   git clone https://github.com/SharafatKarim/arch-kde-installer-script.git
   cd arch-kde-installer-script
   ```
6. Run the installer:
   ```bash
   sudo ./install.sh
   ```

## Repository Structure

```
arch-kde-installer-script/
├── install.sh             # Main interactive orchestrator
├── lib/
│   ├── utils.sh           # Terminal styling, run_cmd logger, input helpers
│   ├── disk.sh            # Partition selector, subvolumes, mount operations
│   ├── bootstrap.sh       # Keyring, mirror optimization, pacstrap, fstab
│   └── chroot_setup.sh    # Configuration executed inside arch-chroot
├── configs/
│   └── zram-generator.conf# ZRAM RAM compression configuration
└── README.md
```
