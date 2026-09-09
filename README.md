# Arch Linux + Btrfs + Minimal KDE Plasma Installer

An automated, interactive installer script for Arch Linux based on the architecture detailed in the following guides:
- [Part 1: Arch Linux Minimal Install with Btrfs](https://sharafat.pages.dev/archlinux-install/)
- [Part 2: Arch Linux Post-Install with Minimal Plasma](https://sharafat.pages.dev/archlinux-post-install/)

## Features

- **Interactive Prompts:** Configures hostname, users, passwords (masked), timezone, locale, keyboard layout, microcode, kernel selection, and swap/zram.
- **Flexible Storage Configuration:**
  - **Auto-Partition Whole Drive:** Automatically creates GPT partition table with a 1 GiB FAT32 EFI partition and remaining space for the Btrfs pool on a brand new/wiped drive.
  - **Existing Partition Selection:** Preserves existing partitions (ideal for dual-booting with Windows or keeping existing data drives) by simply mapping existing EFI and Root partitions.
- **Command Transparency:** Prints every command in real-time (`> RUNNING: ...`) before execution so you can follow every step.
- **Btrfs 5-Subvolume Pool:** Automatically creates and mounts `@`, `@home`, `@pkg`, `@log`, and `@snapshots` with `noatime,compress=zstd`.
- **KDE Plasma Flavor Selection:** Choose between **Minimal Plasma** (`plasma-desktop` + essential utilities) and **Full Plasma** (the entire `plasma` package group), both bundled with `plasma-login-manager` (`plasmalogin.service`), PipeWire audio, and Noto fonts.
- **Automated Snapper & GRUB Bootable Snapshots:** Hooks Snapper to `@snapshots` and enables `snap-pac` + `grub-btrfsd` so system updates automatically generate bootable snapshot entries in the GRUB menu.
- **Reinstall & Reset Support (Preserve `@home`):** When installing to an existing Btrfs pool, the script detects the `@home` subvolume and gives you the option to completely reinstall/reset the root OS while preserving all user personal files, configurations, and data in `@home`.
- **GPU Driver Detection:** Detects NVIDIA, AMD, or Intel graphics and installs appropriate drivers (`nvidia-dkms`, `vulkan-radeon`, `vulkan-intel`, `mesa`).
- **Chaotic-AUR & `yay` Integration (Optional):** Pre-configures the Chaotic-AUR binary repository and installs the `yay` AUR helper.
- **Rescue / Chroot Mode:** Built-in option to quickly detect, mount, and `arch-chroot` into an existing system installed with this layout for easy maintenance and recovery.
- **Performance Optimizations:** Btrfs swapfile support, RAM compression (`zram-generator`), pacman candy & parallel downloads, Reflector mirror optimization, and SSD TRIM timer (`fstrim.timer`).

---

## Quick Start (From Arch Live ISO)

1. Boot into the official Arch Linux live ISO (UEFI mode).
2. Connect to the internet (`nmtui` for Wi-Fi or plug in Ethernet).
3. Clone or download this repository:
   ```bash
   git clone https://github.com/SharafatKarim/arch-kde-installer-script.git
   cd arch-kde-installer-script
   ```
4. Run the installer:
   ```bash
   sudo ./install.sh
   ```

---

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
