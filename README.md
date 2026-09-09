# Arch Linux + Btrfs + Minimal KDE Plasma Installer

An automated, interactive installer script for Arch Linux based on the architecture detailed in the following guides:
- [Part 1: Arch Linux Minimal Install with Btrfs](https://sharafat.pages.dev/archlinux-install/)
- [Part 2: Arch Linux Post-Install with Minimal Plasma](https://sharafat.pages.dev/archlinux-post-install/)

## Architecture: Two-Stage Workflow for Maximum Stability

1. **Stage 1 (`install.sh`)**: Executed from the Arch Live ISO.
   - Sets up Btrfs subvolumes (`@`, `@home`, `@pkg`, `@log`, `@snapshots`, `@swap`) and EFI boot partition.
   - Bootstraps base system packages (`base`, `linux`, `sudo`, `grub`, `efibootmgr`, `networkmanager`).
   - Configures users, passwords, locale, timezone, GPU drivers, and KDE Plasma (`plasma-desktop` or `plasma` group) with `plasma-login-manager`.
   - Copies `post-install.sh` and configurations directly into your user's home folder.
   - Installs GRUB and prepares the system for reboot.

2. **Stage 2 (`post-install.sh`)**: Executed from your new KDE Plasma desktop.
   - Sets up Snapper automated snapshotting with DBus active in the booted system.
   - Configures `snap-pac` (pre/post pacman snapshots) and `grub-btrfs` / `grub-btrfsd` (boot into snapshots directly from GRUB).
   - Configures Btrfs swapfile on `@swap` (`/swap/swapfile`) and ZRAM (`zram-generator`).
   - Enables SSD TRIM timer (`fstrim.timer`).
   - Optionally installs Chaotic-AUR repository, `yay` AUR helper, and utility packages.

---

## Quick Start

### Stage 1: Base System & Desktop Installation (From Live ISO)

1. Boot into the official Arch Linux live ISO (UEFI mode).
2. Connect to the internet (`nmtui` for Wi-Fi or plug in Ethernet).
3. Update `archlinux-keyring` & install `git`:
   ```bash
   pacman -Sy archlinux-keyring git --noconfirm
   ```
4. Clone this repository:
   ```bash
   git clone https://github.com/SharafatKarim/arch-kde-installer-script.git
   cd arch-kde-installer-script
   ```
5. Run the installer:
   ```bash
   sudo ./install.sh
   ```
6. When prompted, reboot into your new installation.

---

### Stage 2: Post-Installation & Tuning (From Installed System)

1. Log into your new KDE Plasma desktop.
2. Open Konsole / Terminal in your home directory.
3. Run the post-installer script:
   ```bash
   ./post-install.sh
   ```

---

## Snapshot Management & Rollback Guide

Once [post-install.sh](file:///home/sharafat/Desktop/lab/arch-kde-installer-script/post-install.sh) runs, your system automatically creates snapshots:
- **Timeline snapshots**: Taken hourly by `snapper-timeline.timer` and cleaned up by `snapper-cleanup.timer`.
- **Pacman snapshots**: Taken automatically before and after any `pacman` install/update/removal via `snap-pac`.
- **GRUB Boot Menu**: Snapshots are automatically detected and populated in your GRUB bootloader via `grub-btrfsd.service`.

### How to Roll Back a Snapshot

If a system update or configuration breaks your installation:

1. **Reboot your system** and select **"Arch Linux snapshots"** from the GRUB boot menu.
2. Select the snapshot you want to boot into (it boots into a read-only snapshot of that exact point in time).
3. Once booted into the desktop or terminal, restore the snapshot:
   - **GUI Method**: Launch `btrfs-assistant` and click **Restore** on your selected snapshot.
   - **CLI Method**: Run `sudo snapper-rollback <snapshot_id>` (or use `snapper` to replace the default subvolume), then reboot normally.

