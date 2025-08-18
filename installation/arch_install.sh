#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG (puoi cambiarli) ======
HOSTNAME="arch"
USERNAME="jok"
USERPASS="changeme"          # cambia dopo il primo boot
LOCALE="en_US.UTF-8"         # lingua sistema
KEYMAP="us"                  # layout tastiera console
TIMEZONE="Europe/Rome"
SWAP_SIZE="8G"
# =====================================

say() { echo -e "\n[+] $*"; }
die() { echo "ERR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
online() { ping -c1 -W2 bbs.archlinux.org >/dev/null 2>&1; }

need_cmd sgdisk; need_cmd mkfs.btrfs; need_cmd pacstrap; need_cmd lsblk; need_cmd blkid

# --- argomento obbligatorio: disco target ---
if [[ $# -lt 1 ]]; then
  die "Usage: $0 <disk>   e.g.  $0 nvme0n1   or   $0 /dev/nvme0n1"
fi
if [[ "$1" == /dev/* ]]; then DISK="$1"; else DISK="/dev/$1"; fi
[[ -b "$DISK" ]] || die "Block device not found: $DISK"

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

get_uuid()      { blkid -s UUID -o value "$1"; }

write_arch_entry() {
  local esp="$1" root_uuid="$2" ucode_line=""
  [ -f /mnt/boot/intel-ucode.img ] && ucode_line="initrd  /intel-ucode.img"
  [ -f /mnt/boot/amd-ucode.img ]   && ucode_line="initrd  /amd-ucode.img"
  cat >"$esp/loader/entries/arch.conf" <<EOT
title   Arch Linux
linux   /vmlinuz-linux
$ucode_line
initrd  /initramfs-linux.img
options root=UUID=${root_uuid} rw rootflags=subvol=@ nvidia_drm.modeset=1
EOT
}

final_uuid_fix() {
  local rootp="$1" rootuuid
  rootuuid=$(get_uuid "$rootp") || die "Cannot read UUID of $rootp"
  sed -i "s|root=UUID=[^ ]*|root=UUID=${rootuuid}|" /mnt/boot/loader/entries/arch.conf
  grep -q "root=UUID=${rootuuid}" /mnt/boot/loader/entries/arch.conf || die "UUID patch failed"
  say "Root UUID verified in arch.conf: ${rootuuid}"
}

# --- preflight ---
say "Checking network..."
online || die "No network. Connect first with 'iwctl' (station <iface> connect <SSID>)."

echo "****************************"
echo "  Arch install FULL DISK"
echo "  Disk target: $DISK"
echo "  FS: Btrfs (subvolumes)"
echo "  Bootloader: systemd-boot"
echo "  Desktop: Hyprland (Wayland) + Firefox"
echo "  GPU: NVIDIA (proprietary)"
echo "  Locale: $LOCALE | Keymap: $KEYMAP"
echo "****************************"
read -r -p "Type EXACTLY 'YES' to confirm FULL WIPE of $DISK: " CONF
[[ "$CONF" == "YES" ]] || die "Aborted."

# --- partizionamento ---
say "Partitioning $DISK (GPT: ESP 512M + ROOT Btrfs)..."
sgdisk -Z "$DISK"
sgdisk -g "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0      -t 2:8300 -c 2:"Linux Btrfs" "$DISK"
partprobe "$DISK"

# --- format ---
say "Formatting..."
mkfs.fat -F32 "$ESP"
mkfs.btrfs -f -L archroot "$ROOT"

# --- subvolumi ---
say "Creating Btrfs subvolumes..."
mount "$ROOT" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
umount /mnt

# --- mount ---
say "Mounting subvolumes..."
mount -o subvol=@,compress=zstd,noatime "$ROOT" /mnt
mkdir -p /mnt/{boot,home,var,log,pkg,.snapshots}
mount -o subvol=@home,compress=zstd,noatime      "$ROOT" /mnt/home
mount -o subvol=@var,compress=zstd,noatime       "$ROOT" /mnt/var
mount -o subvol=@log,compress=zstd,noatime       "$ROOT" /mnt/log
mount -o subvol=@pkg,compress=zstd,noatime       "$ROOT" /mnt/pkg
mount -o subvol=@snapshots,compress=zstd,noatime "$ROOT" /mnt/.snapshots
mount "$ESP" /mnt/boot

# --- pacstrap ---
say "Installing base system..."
pacstrap -K /mnt base linux linux-firmware btrfs-progs vim sudo \
  networkmanager iwd git base-devel

genfstab -U /mnt >> /mnt/etc/fstab

# --- chroot config ---
say "Configuring system in chroot..."
arch-chroot /mnt /bin/bash <<EOFCHROOT
# Remove strict error handling temporarily for variable assignments
set +u

# Re-define variables in chroot context
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME" 
USERPASS="$USERPASS"
LOCALE="$LOCALE"
TIMEZONE="$TIMEZONE"
SWAP_SIZE="$SWAP_SIZE"
KEYMAP="$KEYMAP"

# Re-enable strict error handling
set -euo pipefail

echo "[+] Starting system configuration in chroot..."

# Basic system setup
ln -sf /usr/share/zoneinfo/\${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale setup
sed -i 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=\${LOCALE}" > /etc/locale.conf
echo "KEYMAP=\${KEYMAP}" > /etc/vconsole.conf

# Hostname setup
echo "\${HOSTNAME}" > /etc/hostname
cat >> /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   \${HOSTNAME}.localdomain \${HOSTNAME}
EOT

# User setup
echo "root:\${USERPASS}" | chpasswd
useradd -m -G wheel,audio,video,storage -s /bin/bash "\${USERNAME}"
echo "\${USERNAME}:\${USERPASS}" | chpasswd
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
echo "[+] Installing systemd-boot..."
bootctl install

# Swapfile setup on Btrfs
echo "[+] Creating swapfile..."
mkdir -p /swap
btrfs filesystem mkswapfile --size \${SWAP_SIZE} --uuid clear /swap/swapfile
swapon /swap/swapfile
echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab

# Audio + Bluetooth
echo "[+] Installing audio and bluetooth..."
pacman --noconfirm -S pipewire pipewire-alsa pipewire-pulse wireplumber bluez bluez-utils
systemctl enable bluetooth

# NVIDIA drivers
echo "[+] Installing NVIDIA drivers..."
pacman --noconfirm -S nvidia nvidia-utils nvidia-settings
mkinitcpio -P

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
if ! grep -q '^/bin/zsh\$' /etc/shells 2>/dev/null; then
  echo /bin/zsh >> /etc/shells
fi
usermod -s /bin/zsh "\${USERNAME}" || true
usermod -s /bin/zsh root || true

# Install Oh My Zsh for the user
echo "[+] Setting up Oh My Zsh for user \${USERNAME}..."
sudo -u "\${USERNAME}" HOME="/home/\${USERNAME}" bash <<'EOFZSH'
set -euo pipefail

# Clone Oh My Zsh if not present
if [ ! -d "\${HOME}/.oh-my-zsh" ]; then
  echo "[+] Cloning Oh My Zsh..."
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "\${HOME}/.oh-my-zsh"
fi

# Create zshrc with proper escaping
cat >"\${HOME}/.zshrc" <<'EOT'
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source \$ZSH/oh-my-zsh.sh

# Zsh plugins from system packages
fpath+=(/usr/share/zsh/plugins/zsh-syntax-highlighting /usr/share/zsh/plugins/zsh-autosuggestions)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Note: Powerlevel10k can be installed manually after first boot
# Run: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
# Then change ZSH_THEME="powerlevel10k/powerlevel10k" and run: p10k configure
EOT
EOFZSH

# Fix ownership
chown -R "\${USERNAME}:\${USERNAME}" "/home/\${USERNAME}/.oh-my-zsh" "/home/\${USERNAME}/.zshrc" || true

# Install yay AUR helper
echo "[+] Installing yay AUR helper..."
pacman --noconfirm --needed -S git base-devel go

# Build yay as normal user with improved error handling
sudo -u "\${USERNAME}" bash <<'EOFYAY'
set -euo pipefail
export HOME="/home/\${USERNAME}"
export PATH="/usr/bin:/usr/local/bin:\${PATH}"

echo "[+] Building yay in temporary directory..."
TMPDIR="\$(mktemp -d)"
cd "\${TMPDIR}"

echo "[+] Cloning yay repository..."
git clone --depth 1 https://aur.archlinux.org/yay.git
cd yay

echo "[+] Building and installing yay..."
makepkg -si --noconfirm --needed

# Cleanup
cd /
rm -rf "\${TMPDIR}"

# Verify installation
if command -v yay >/dev/null 2>&1; then
    echo "[+] yay installed successfully: \$(yay --version | head -n1)"
else
    echo "[ERROR] yay installation failed"
    exit 1
fi
EOFYAY

echo "[+] yay installation completed"

# Wait a moment for yay to be fully available
sleep 3

# Install AUR packages with better error handling
echo "[+] Installing AUR packages..."

# Function to install AUR package with retry
install_aur_package() {
    local package="\$1"
    local max_attempts=3
    local attempt=1
    
    while [ \$attempt -le \$max_attempts ]; do
        echo "[+] Installing \${package} (attempt \${attempt}/\${max_attempts})..."
        if sudo -u "\${USERNAME}" bash -c "
            export HOME='/home/\${USERNAME}'
            export PATH='/usr/bin:/usr/local/bin:\${PATH}'
            yay -S --noconfirm --needed \${package}
        "; then
            echo "[+] \${package} installed successfully"
            return 0
        else
            echo "[WARNING] \${package} installation failed on attempt \${attempt}"
            ((attempt++))
            sleep 2
        fi
    done
    
    echo "[WARNING] Failed to install \${package} after \${max_attempts} attempts, continuing..."
    return 1
}

# Install JetBrains Toolbox
install_aur_package "jetbrains-toolbox"

# Install NetworkManager dmenu
install_aur_package "networkmanager-dmenu-git"

# Create Pictures directory for screenshots
mkdir -p "/home/\${USERNAME}/Pictures"
chown "\${USERNAME}:\${USERNAME}" "/home/\${USERNAME}/Pictures"

# Setup greetd
echo "[+] Setting up greetd display manager..."
pacman --noconfirm -S greetd
cat >/etc/greetd/config.toml <<'EOT'
[terminal]
vt = 1
[default_session]
command = "agreety --cmd Hyprland"
user = "greeter"
EOT
systemctl enable greetd

# Create user configuration directories
echo "[+] Setting up user configurations..."
mkdir -p "/home/\${USERNAME}/.config"/{hypr,waybar,rofi,hyprpaper}

# Hyprland configuration
cat >"/home/\${USERNAME}/.config/hypr/hyprland.conf" <<'EOT'
monitor=,preferred,auto,1
exec-once = waybar &
exec-once = hyprpaper &
exec-once = nm-applet --indicator &

input {
  kb_layout = us
}

# Key bindings
bind = SUPER, Return, exec, kitty
bind = SUPER, D, exec, rofi -show drun
bind = SUPER, Q, killactive
bind = SUPER, M, exit
bind = SUPER, V, togglefloating
bind = SUPER, F, fullscreen
EOT

# Waybar configuration
cat >"/home/\${USERNAME}/.config/waybar/config" <<'EOT'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock"],
  "modules-center": ["window"],
  "modules-right": ["network", "battery", "tray"]
}
EOT

# Hyprpaper configuration
cat >"/home/\${USERNAME}/.config/hyprpaper/hyprpaper.conf" <<'EOT'
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png
EOT

# Setup JetBrains Toolbox autostart if installed
if command -v jetbrains-toolbox >/dev/null 2>&1; then
    echo "[+] Setting up JetBrains Toolbox autostart..."
    mkdir -p "/home/\${USERNAME}/.config/autostart"
    cat >"/home/\${USERNAME}/.config/autostart/jetbrains-toolbox.desktop" <<'EOT'
[Desktop Entry]
Icon=/opt/jetbrains-toolbox/toolbox.svg
Exec=/opt/jetbrains-toolbox/jetbrains-toolbox --minimize
Version=1.0
Type=Application
Categories=Development
Name=JetBrains Toolbox
StartupWMClass=jetbrains-toolbox
Terminal=false
MimeType=x-scheme-handler/jetbrains;
X-GNOME-Autostart-enabled=true
StartupNotify=false
X-GNOME-Autostart-Delay=10
X-MATE-Autostart-Delay=10
X-KDE-autostart-after=panel
EOT
else
    echo "[WARNING] JetBrains Toolbox not found, skipping autostart configuration"
fi

# Fix ownership of all user config files
chown -R "\${USERNAME}:\${USERNAME}" "/home/\${USERNAME}/.config"

# Pacman configuration improvements
echo "[+] Configuring pacman..."
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = .*/ParallelDownloads = 10/' /etc/pacman.conf

echo "[+] System configuration completed successfully in chroot"
EOFCHROOT

# --- boot entry + fix UUID ---
say "Writing boot entry..."
ROOT_UUID=$(get_uuid "$ROOT") || die "Root UUID not found"
mkdir -p /mnt/boot/loader/entries
write_arch_entry "/mnt/boot" "$ROOT_UUID"
final_uuid_fix "$ROOT"
arch-chroot /mnt bootctl update || true
chmod 600 /mnt/boot/loader/random-seed 2>/dev/null || true

say "Installation completed successfully! Unmounting and rebooting..."
swapoff /mnt/swap/swapfile 2>/dev/null || true
umount -R /mnt || true
echo "System will reboot in 5 seconds..."
sleep 5
reboot