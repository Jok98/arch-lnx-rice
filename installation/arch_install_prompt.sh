#!/usr/bin/env bash
set -euo pipefail

# V 0.5

# ====== CONFIG (puoi cambiarli) ======
LOCALE="en_US.UTF-8"         # lingua sistema
KEYMAP="us"                  # layout tastiera console
TIMEZONE="Europe/Rome"
SWAP_SIZE="8G"
# =====================================

say() { echo -e "\n[+] $*"; }
die() { echo "ERR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
online() { ping -c1 -W2 bbs.archlinux.org >/dev/null 2>&1; }

ask_choice() {
  local prompt="$1"; shift
  local options=("$@")
  local values=()
  local labels=()
  local opt idx

  for opt in "${options[@]}"; do
    values+=("${opt%%::*}")
    labels+=("${opt##*::}")
  done

  local PS3="Seleziona un'opzione: "
  exec 3>&1
  echo >&2
  echo "$prompt" >&2
  
  select opt in "${labels[@]}"; do
    if [[ -n "$opt" ]]; then
      idx=$((REPLY-1))
      printf '%s\n' "${values[$idx]}" >&3
      exec 3>&-
      return 0
    fi
    echo "Scelta non valida, riprova." >&2
  done >&2
}

# Modificata per non accettare un default
ask_input_mandatory() {
  local prompt="$1" value
  while true; do
    echo >&2
    printf "%s: " "$prompt" >&2
    read -r value
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    else
      echo "Input non può essere vuoto." >&2
    fi
  done
}

# Modificata per non accettare un default
ask_secret_mandatory() {
  local prompt="$1" value
  while true; do
    echo >&2
    printf "%s: " "$prompt" >&2
    read -rs value
    echo >&2
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    else
      echo "La password non può essere vuota." >&2
    fi
  done
}

need_cmd pacstrap; need_cmd lsblk; need_cmd blkid; need_cmd mkfs.fat

# --- argomento obbligatorio: disco target ---
if [[ $# -lt 1 ]]; then
  die "Usage: $0 <disk>   e.g.  $0 nvme0n1   or   $0 /dev/nvme0n1"
fi
if [[ "$1" == /dev/* ]]; then DISK="$1"; else DISK="/dev/$1"; fi
[[ -b "$DISK" ]] || die "Block device not found: $DISK"

FILESYSTEM_CHOICE=$(ask_choice "Seleziona filesystem per la partizione root" \
  "btrfs::Btrfs (subvolumi)" \
  "ext4::Ext4 (classico)")
PARTITION_SCHEME=$(ask_choice "Schema di partizionamento" \
  "auto::Wipe automatico (riscrive l'intero disco)" \
  "manual::Manuale (usa partizioni esistenti)")
BOOTLOADER_CHOICE=$(ask_choice "Seleziona bootloader" \
  "systemd-boot::systemd-boot" \
  "grub::GRUB")
GPU_CHOICE=$(ask_choice "Driver GPU" \
  "nvidia::NVIDIA proprietari" \
  "amd::Driver AMD/Mesa" \
  "none::Solo driver open-source (nessun driver dedicato)")

# --- Richieste utente obbligatorie ---
HOSTNAME=$(ask_input_mandatory "Inserisci l'hostname del sistema")
USERNAME=$(ask_input_mandatory "Inserisci il nome utente amministratore")
USERPASS=$(ask_secret_mandatory "Inserisci la password per root e ${USERNAME}")

LOCALE_SELECTION=$(ask_choice "Seleziona locale di sistema" \
  "en_US.UTF-8::English (US)" \
  "it_IT.UTF-8::Italiano" \
  "de_DE.UTF-8::Deutsch" \
  "es_ES.UTF-8::Español" \
  "custom::Altro (inserisci manualmente)")
if [[ "$LOCALE_SELECTION" == "custom" ]]; then
  LOCALE=$(ask_input_mandatory "Locale completo (es. en_US.UTF-8)")
else
  LOCALE="$LOCALE_SELECTION"
fi

KEYMAP_SELECTION=$(ask_choice "Layout tastiera per la console" \
  "us::US" \
  "it::Italiano" \
  "de::Tedesco" \
  "fr::Francese" \
  "es::Spagnolo" \
  "custom::Altro (inserisci manualmente)")
if [[ "$KEYMAP_SELECTION" == "custom" ]]; then
  KEYMAP=$(ask_input_mandatory "Layout tastiera (es. us, it)")
else
  KEYMAP="$KEYMAP_SELECTION"
fi

TIMEZONE_SELECTION=$(ask_choice "Seleziona timezone" \
  "Europe/Rome::Europe/Rome" \
  "Europe/Berlin::Europe/Berlin" \
  "UTC::UTC" \
  "America/New_York::America/New_York" \
  "Asia/Tokyo::Asia/Tokyo" \
  "custom::Altro (inserisci manualmente)")
if [[ "$TIMEZONE_SELECTION" == "custom" ]]; then
  TIMEZONE=$(ask_input_mandatory "Timezone (es. Europe/Rome)")
else
  TIMEZONE="$TIMEZONE_SELECTION"
fi

SWAP_SIZE_SELECTION=$(ask_choice "Dimensione del file di swap" \
  "2G::2 GiB" \
  "4G::4 GiB" \
  "8G::8 GiB" \
  "16G::16 GiB" \
  "custom::Personalizzata")
if [[ "$SWAP_SIZE_SELECTION" == "custom" ]]; then
  SWAP_SIZE=$(ask_input_mandatory "Dimensione swap (es. 8G)")
else
  SWAP_SIZE="$SWAP_SIZE_SELECTION"
fi

# path partizioni (gestisce /dev/sda vs /dev/nvme0n1)
partpath() {
  local disk="$1" num="$2"
  if [[ "$disk" =~ (nvme|mmcblk|loop|nbd) ]]; then
    echo "${disk}p${num}"
  else
    echo "${disk}${num}"
  fi
}
ESP="$(partpath "$DISK" 1)"
ROOT="$(partpath "$DISK" 2)"

if [[ "$PARTITION_SCHEME" == "manual" ]]; then
  read -r -p "Partizione EFI da usare [$ESP]: " manual_esp
  ESP="${manual_esp:-$ESP}"
  read -r -p "Partizione root da usare [$ROOT]: " manual_root
  ROOT="${manual_root:-$ROOT}"
  [[ -b "$ESP" ]] || die "EFI partition not found: $ESP"
  [[ -b "$ROOT" ]] || die "Root partition not found: $ROOT"
fi

case "$FILESYSTEM_CHOICE" in
  btrfs) FS_LABEL="Btrfs (subvolumi)" ;;
  ext4)  FS_LABEL="Ext4" ;;
esac
case "$PARTITION_SCHEME" in
  auto)   PART_LABEL="Auto-wipe completo" ;;
  manual) PART_LABEL="Manuale (nessun wipe automatico)" ;;
esac
case "$BOOTLOADER_CHOICE" in
  systemd-boot) BOOT_LABEL="systemd-boot" ;;
  grub)         BOOT_LABEL="GRUB" ;;
esac
case "$GPU_CHOICE" in
  nvidia) GPU_LABEL="NVIDIA proprietari" ;;
  amd)    GPU_LABEL="AMD/Mesa" ;;
  none)   GPU_LABEL="Solo driver open-source" ;;
esac

if [[ "$PARTITION_SCHEME" == "auto" ]]; then
  need_cmd sgdisk
  need_cmd partprobe
fi
case "$FILESYSTEM_CHOICE" in
  btrfs)
    need_cmd mkfs.btrfs
    need_cmd btrfs
    ;;
  ext4)
    need_cmd mkfs.ext4
    ;;
esac

get_uuid()      { blkid -s UUID -o value "$1"; }

write_arch_entry() {
  local esp="$1" root_uuid="$2" fs_type="$3" gpu_choice="$4" ucode_line="" options
  options="options root=UUID=${root_uuid} rw"
  [ -f /mnt/boot/intel-ucode.img ] && ucode_line="initrd  /intel-ucode.img"
  [ -f /mnt/boot/amd-ucode.img ]   && ucode_line="initrd  /amd-ucode.img"
  if [[ "$fs_type" == "btrfs" ]]; then
    options+=" rootflags=subvol=@"
  fi
  if [[ "$gpu_choice" == "nvidia" ]]; then
    options+=" nvidia_drm.modeset=1"
  fi
  cat >"$esp/loader/entries/arch.conf" <<EOT
title   Arch Linux
linux   /vmlinuz-linux
$ucode_line
initrd  /initramfs-linux.img
$options
EOT
}

final_uuid_fix() {
  local rootp="$1" rootuuid
  [[ -f /mnt/boot/loader/entries/arch.conf ]] || return 0
  rootuuid=$(get_uuid "$rootp") || die "Cannot read UUID of $rootp"
  sed -i "s|root=UUID=[^ ]*|root=UUID=${rootuuid}|" /mnt/boot/loader/entries/arch.conf
  grep -q "root=UUID=${rootuuid}" /mnt/boot/loader/entries/arch.conf || die "UUID patch failed"
  say "Root UUID verified in arch.conf: ${rootuuid}"
}

# --- preflight ---
say "Checking network..."
online || die "No network. Connect first with 'iwctl' (station <iface> connect <SSID>)."

echo "****************************"
echo "  Arch install configurazione"
echo "  Disk target: $DISK"
echo "  Partizionamento: $PART_LABEL"
echo "  EFI partition: $ESP"
echo "  Root partition: $ROOT ($FS_LABEL)"
echo "  Bootloader: $BOOT_LABEL"
echo "  Desktop: Hyprland (Wayland) + Firefox"
echo "  GPU: $GPU_LABEL"
echo "  Hostname: $HOSTNAME | Utente: $USERNAME"
echo "  Locale: $LOCALE | Keymap: $KEYMAP"
echo "  Timezone: $TIMEZONE | Swap: $SWAP_SIZE"
echo "****************************"
if [[ "$PARTITION_SCHEME" == "auto" ]]; then
  read -r -p "Type EXACTLY 'YES' to confirm FULL WIPE of $DISK: " CONF
else
  read -r -p "Type EXACTLY 'YES' to continue con il partizionamento manuale (le partizioni selezionate verranno formattate): " CONF
fi
[[ "$CONF" == "YES" ]] || die "Aborted."

# --- partizionamento ---
case "$PARTITION_SCHEME" in
  auto)
    say "Partitioning $DISK (GPT: ESP 512M + ROOT ${FS_LABEL})..."
    sgdisk -Z "$DISK"
    sgdisk -g "$DISK"
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK"
    sgdisk -n 2:0:0      -t 2:8300 -c 2:"Linux ${FILESYSTEM_CHOICE^^}" "$DISK"
    partprobe "$DISK"
    ;;
  manual)
    say "Partitioning skipped: using existing layout"
    ;;
esac

# --- format & mount ---
say "Formatting EFI partition..."
mkfs.fat -F32 "$ESP"

case "$FILESYSTEM_CHOICE" in
  btrfs)
    say "Formatting root as Btrfs..."
    mkfs.btrfs -f -L archroot "$ROOT"
    say "Creating Btrfs subvolumes..."
    mount "$ROOT" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@pkg
    btrfs subvolume create /mnt/@snapshots
    umount /mnt

    say "Mounting Btrfs subvolumes..."
    mount -o subvol=@,compress=zstd,noatime "$ROOT" /mnt
    mkdir -p /mnt/{boot,home,var,log,pkg,.snapshots}
    mount -o subvol=@home,compress=zstd,noatime      "$ROOT" /mnt/home
    mount -o subvol=@var,compress=zstd,noatime       "$ROOT" /mnt/var
    mount -o subvol=@log,compress=zstd,noatime       "$ROOT" /mnt/log
    mount -o subvol=@pkg,compress=zstd,noatime       "$ROOT" /mnt/pkg
    mount -o subvol=@snapshots,compress=zstd,noatime "$ROOT" /mnt/.snapshots
    ;;
  ext4)
    say "Formatting root as ext4..."
    mkfs.ext4 -F "$ROOT"
    say "Mounting root filesystem..."
    mount "$ROOT" /mnt
    mkdir -p /mnt/{boot,home,var,log,pkg,.snapshots}
    ;;
esac

mount "$ESP" /mnt/boot

# --- pacstrap ---
say "Installing base system..."
BASE_PACKAGES=(base linux linux-firmware vim sudo networkmanager iwd git base-devel curl)
if [[ "$FILESYSTEM_CHOICE" == "btrfs" ]]; then
  BASE_PACKAGES+=(btrfs-progs)
fi
pacstrap -K /mnt "${BASE_PACKAGES[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# --- chroot config ---
say "Configuring system in chroot..."

# Create the chroot script as a file to avoid variable expansion issues
cat > /mnt/chroot_setup.sh << 'EOFCHROOTSCRIPT'
#!/bin/bash
set -euo pipefail

# These variables will be set by the parent script
HOSTNAME="$1"
USERNAME="$2"
USERPASS="$3"
LOCALE="$4"
TIMEZONE="$5"
SWAP_SIZE="$6"
KEYMAP="$7"
FILESYSTEM_TYPE="$8"
BOOTLOADER_CHOICE="$9"
GPU_CHOICE="${10}"

echo "[+] Starting system configuration in chroot..."
echo "[+] Configuring for user: $USERNAME"

# Basic system setup
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale setup
locale_pattern=$(printf '%s\n' "$LOCALE" | sed 's/[.[\*^$\\\/&]/\\&/g')
if grep -q "^#${locale_pattern}$" /etc/locale.gen; then
  sed -i "s/^#${locale_pattern}$/${LOCALE}/" /etc/locale.gen
elif ! grep -q "^${locale_pattern}$" /etc/locale.gen; then
  echo "${LOCALE}" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Hostname setup
echo "${HOSTNAME}" > /etc/hostname
cat >> /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOT

# User setup
echo "root:${USERPASS}" | chpasswd
useradd -m -G wheel,audio,video,storage -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USERPASS}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Network stack (iwd + NM)
mkdir -p /etc/NetworkManager/conf.d
cat >/etc/NetworkManager/conf.d/wifi_backend.conf <<EOT
[device]
wifi.backend=iwd
EOT

mkdir -p /var/lib/iwd
cat >/var/lib/iwd/main.conf <<'EOT'
[General]
EnableNetworkConfiguration=true
[Network]
NameResolvingService=systemd
EOT

systemctl enable NetworkManager iwd
systemctl enable fstrim.timer

# Microcode detection and installation
echo "[+] Detecting and installing microcode..."
if lscpu | grep -qi intel; then
    echo "[+] Intel CPU detected, installing intel-ucode..."
    pacman --noconfirm -S intel-ucode
fi
if lscpu | grep -qi amd; then
    echo "[+] AMD CPU detected, installing amd-ucode..."
    pacman --noconfirm -S amd-ucode
fi

# Bootloader
case "$BOOTLOADER_CHOICE" in
  systemd-boot)
    echo "[+] Installing systemd-boot..."
    bootctl install
    ;;
  grub)
    echo "[+] Installing GRUB..."
    pacman --noconfirm --needed -S grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    ;;
esac

# Swapfile setup
echo "[+] Creating swapfile..."
mkdir -p /swap
case "$FILESYSTEM_TYPE" in
  btrfs)
    btrfs filesystem mkswapfile --size "${SWAP_SIZE}" --uuid clear /swap/swapfile
    ;;
  *)
    fallocate -l "${SWAP_SIZE}" /swap/swapfile
    chmod 600 /swap/swapfile
    mkswap /swap/swapfile
    ;;
esac
chmod 600 /swap/swapfile
swapon /swap/swapfile
echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab

# Audio + Bluetooth
echo "[+] Installing audio and bluetooth..."
pacman --noconfirm -S pipewire pipewire-alsa pipewire-pulse wireplumber bluez bluez-utils
systemctl enable bluetooth

# GPU drivers
case "$GPU_CHOICE" in
  nvidia)
    echo "[+] Installing NVIDIA drivers..."
    pacman --noconfirm --needed -S nvidia nvidia-utils nvidia-settings
    mkinitcpio -P
    ;;
  amd)
    echo "[+] Installing AMD/Mesa stack..."
    pacman --noconfirm --needed -S mesa vulkan-radeon libva-mesa-driver mesa-vdpau xf86-video-amdgpu
    ;;
  none)
    echo "[+] Installing open-source Mesa drivers..."
    pacman --noconfirm --needed -S mesa vulkan-mesa-layers
    ;;
esac

# Hyprland and desktop environment
echo "[+] Installing Hyprland and desktop tools..."
pacman --noconfirm -S hyprland xdg-desktop-portal-hyprland xdg-desktop-portal \
  waybar hyprpaper rofi-wayland kitty alacritty firefox network-manager-applet \
  noto-fonts noto-fonts-cjk ttf-jetbrains-mono ttf-font-awesome \
  fastfetch pavucontrol blueman gsimplecal ttf-nerd-fonts-symbols-mono \
  grim slurp swappy wl-clipboard playerctl hyprlock pam mousepad wev

# Zsh and plugins
echo "[+] Installing zsh and plugins..."
pacman --noconfirm --needed -S zsh zsh-autosuggestions zsh-syntax-highlighting

# Ensure zsh is in /etc/shells and set as default shell
if ! grep -q '^/bin/zsh$' /etc/shells 2>/dev/null; then
  echo /bin/zsh >> /etc/shells
fi
usermod -s /bin/zsh "${USERNAME}" || true
usermod -s /bin/zsh root || true

# Install Oh My Zsh for the user
echo "[+] Setting up Oh My Zsh for user ${USERNAME}..."
USER_HOME="/home/${USERNAME}"
sudo -u "${USERNAME}" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
# Install Oh My Zsh for root
echo "[+] Setting up Oh My Zsh for root..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"

# Configure plugins for both user and root
echo "[+] Configuring Zsh plugins..."
sed -i 's/^plugins=(git)$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "${USER_HOME}/.zshrc"
sed -i 's/^plugins=(git)$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "/root/.zshrc"

# Fix ownership of all user files
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"

# Pacman configuration improvements
echo "[+] Configuring pacman..."
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = .*/ParallelDownloads = 10/' /etc/pacman.conf

echo "[+] System configuration completed successfully in chroot"
EOFCHROOTSCRIPT

# Make the script executable
chmod +x /mnt/chroot_setup.sh

# Execute the chroot script with parameters
arch-chroot /mnt /chroot_setup.sh "$HOSTNAME" "$USERNAME" "$USERPASS" "$LOCALE" "$TIMEZONE" "$SWAP_SIZE" "$KEYMAP" "$FILESYSTEM_CHOICE" "$BOOTLOADER_CHOICE" "$GPU_CHOICE"

# Remove the script
rm /mnt/chroot_setup.sh

# --- boot entry + fix UUID ---
if [[ "$BOOTLOADER_CHOICE" == "systemd-boot" ]]; then
  say "Writing boot entry..."
  ROOT_UUID=$(get_uuid "$ROOT") || die "Root UUID not found"
  mkdir -p /mnt/boot/loader/entries
  write_arch_entry "/mnt/boot" "$ROOT_UUID" "$FILESYSTEM_CHOICE" "$GPU_CHOICE"
  final_uuid_fix "$ROOT"
  arch-chroot /mnt bootctl update || true
  chmod 600 /mnt/boot/loader/random-seed 2>/dev/null || true
else
  say "GRUB configurato all'interno della chroot"
fi

say "Installation completed successfully! Unmounting and rebooting..."
swapoff /mnt/swap/swapfile 2>/dev/null || true
umount -R /mnt || true
echo "System will reboot in 5 seconds..."
sleep 5
reboot
