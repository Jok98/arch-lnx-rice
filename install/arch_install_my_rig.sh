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

echo "[+] Starting system configuration in chroot..."
echo "[+] Configuring for user: $USERNAME"

# Basic system setup
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale setup
sed -i 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
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
echo "[+] Installing systemd-boot..."
bootctl install

# Swapfile setup on Btrfs
echo "[+] Creating swapfile..."
mkdir -p /swap
btrfs filesystem mkswapfile --size ${SWAP_SIZE} --uuid clear /swap/swapfile
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
if ! grep -q '^/bin/zsh$' /etc/shells 2>/dev/null; then
  echo /bin/zsh >> /etc/shells
fi
usermod -s /bin/zsh "${USERNAME}" || true
usermod -s /bin/zsh root || true

# Install Oh My Zsh for the user
echo "[+] Setting up Oh My Zsh for user ${USERNAME}..."
USER_HOME="/home/${USERNAME}"

# Create Oh My Zsh setup script
cat > /tmp/setup_zsh.sh << 'EOFZSHSCRIPT'
#!/bin/bash
set -euo pipefail

USER_HOME="$1"
USERNAME="$2"

echo "[+] Setting up zsh for user: $USERNAME"
echo "[+] Home directory: $USER_HOME"

# Clone Oh My Zsh if not present
if [ ! -d "${USER_HOME}/.oh-my-zsh" ]; then
  echo "[+] Cloning Oh My Zsh..."
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${USER_HOME}/.oh-my-zsh"
fi

# Create zshrc
cat >"${USER_HOME}/.zshrc" <<'EOT'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Zsh plugins from system packages
fpath+=(/usr/share/zsh/plugins/zsh-syntax-highlighting /usr/share/zsh/plugins/zsh-autosuggestions)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Note: Powerlevel10k can be installed manually after first boot
# Run: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
# Then change ZSH_THEME="powerlevel10k/powerlevel10k" and run: p10k configure
EOT

echo "[+] Zsh setup completed for $USERNAME"
EOFZSHSCRIPT

chmod +x /tmp/setup_zsh.sh
sudo -u "${USERNAME}" bash /tmp/setup_zsh.sh "${USER_HOME}" "${USERNAME}"
rm /tmp/setup_zsh.sh

# Fix ownership
chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}/.oh-my-zsh" "${USER_HOME}/.zshrc" || true

# Install yay AUR helper
echo "[+] Installing yay AUR helper..."
pacman --noconfirm --needed -S git base-devel go

# Create yay installation script with multiple sources
cat > /tmp/install_yay.sh << 'EOFYAYSCRIPT'
#!/bin/bash
set -euo pipefail

USERNAME="$1"
USER_HOME="/home/$1"

echo "[+] Installing AUR helper for user: $USERNAME"

install_yay() {
    local repo_url="$1"
    local name="$2"
    
    echo "[+] Trying to install yay from: $name"
    
    # Create temporary directory
    TMPDIR="$(mktemp -d)"
    cd "$TMPDIR"
    
    echo "[+] Cloning yay repository from $name..."
    if git clone --depth 1 "$repo_url" yay; then
        cd yay
        echo "[+] Building and installing yay..."
        if makepkg -si --noconfirm --needed; then
            # Cleanup
            cd /
            rm -rf "$TMPDIR"
            
            # Verify installation
            if command -v yay >/dev/null 2>&1; then
                echo "[+] yay installed successfully: $(yay --version | head -n1)"
                return 0
            fi
        fi
    fi
    
    # Cleanup on failure
    cd /
    rm -rf "$TMPDIR"
    return 1
}

install_paru() {
    echo "[+] Trying to install paru as alternative..."
    
    # Create temporary directory
    TMPDIR="$(mktemp -d)"
    cd "$TMPDIR"
    
    echo "[+] Cloning paru repository..."
    if git clone --depth 1 https://aur.archlinux.org/paru.git; then
        cd paru
        echo "[+] Building and installing paru..."
        if makepkg -si --noconfirm --needed; then
            # Cleanup
            cd /
            rm -rf "$TMPDIR"
            
            # Verify installation
            if command -v paru >/dev/null 2>&1; then
                echo "[+] paru installed successfully: $(paru --version | head -n1)"
                # Create yay alias for compatibility
                echo 'alias yay="paru"' >> "$USER_HOME/.bashrc"
                echo 'alias yay="paru"' >> "$USER_HOME/.zshrc"
                return 0
            fi
        fi
    fi
    
    # Cleanup on failure
    cd /
    rm -rf "$TMPDIR"
    return 1
}

# Try multiple sources for yay
echo "[+] Attempting to install AUR helper..."

# Source 1: GitHub (more reliable)
if install_yay "https://github.com/Jguer/yay.git" "GitHub"; then
    exit 0
fi

echo "[WARNING] GitHub source failed, trying AUR..."

# Source 2: Official AUR
if install_yay "https://aur.archlinux.org/yay.git" "AUR"; then
    exit 0
fi

echo "[WARNING] AUR source failed, trying GitLab mirror..."

# Source 3: GitLab mirror
if install_yay "https://gitlab.archlinux.org/archlinux/packaging/packages/yay.git" "GitLab"; then
    exit 0
fi

echo "[WARNING] All yay sources failed, trying paru as alternative..."

# Fallback: Install paru instead
if install_paru; then
    exit 0
fi

echo "[ERROR] Failed to install any AUR helper (yay/paru)"
echo "[INFO] You can install it manually after reboot with:"
echo "  git clone https://github.com/Jguer/yay.git"
echo "  cd yay && makepkg -si"
exit 1
EOFYAYSCRIPT

chmod +x /tmp/install_yay.sh
if sudo -u "${USERNAME}" bash /tmp/install_yay.sh "${USERNAME}"; then
    echo "[+] AUR helper installation completed successfully"
    
    # Install AUR packages only if AUR helper is available
    echo "[+] Installing AUR packages..."
    
    # Install JetBrains Toolbox
    echo "[+] Installing JetBrains Toolbox..."
    sudo -u "${USERNAME}" bash /tmp/install_aur.sh "${USERNAME}" "jetbrains-toolbox" || echo "[WARNING] JetBrains Toolbox installation failed, continuing..."
    
    # Install NetworkManager dmenu
    echo "[+] Installing NetworkManager dmenu..."
    sudo -u "${USERNAME}" bash /tmp/install_aur.sh "${USERNAME}" "networkmanager-dmenu-git" || echo "[WARNING] NetworkManager dmenu installation failed, continuing..."
else
    echo "[WARNING] AUR helper installation failed completely"
    echo "[INFO] Skipping all AUR packages"
    echo "[INFO] After reboot, you can manually install yay with:"
    echo "       git clone https://github.com/Jguer/yay.git && cd yay && makepkg -si"
    echo "       Then install: yay -S jetbrains-toolbox networkmanager-dmenu-git"
fi

# Cleanup AUR installation scripts
rm -f /tmp/install_yay.sh /tmp/install_aur.sh

# Create Pictures directory for screenshots
mkdir -p "/home/${USERNAME}/Pictures"
chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Pictures"

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
mkdir -p "/home/${USERNAME}/.config"/{hypr,waybar,rofi,hyprpaper}

# Hyprland configuration
cat >"/home/${USERNAME}/.config/hypr/hyprland.conf" <<'EOT'
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
cat >"/home/${USERNAME}/.config/waybar/config" <<'EOT'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock"],
  "modules-center": ["window"],
  "modules-right": ["network", "battery", "tray"]
}
EOT

# Hyprpaper configuration
cat >"/home/${USERNAME}/.config/hyprpaper/hyprpaper.conf" <<'EOT'
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png
EOT

# Setup JetBrains Toolbox autostart if installed
if command -v jetbrains-toolbox >/dev/null 2>&1; then
    echo "[+] Setting up JetBrains Toolbox autostart..."
    mkdir -p "/home/${USERNAME}/.config/autostart"
    cat >"/home/${USERNAME}/.config/autostart/jetbrains-toolbox.desktop" <<'EOT'
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
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config"

# Pacman configuration improvements
echo "[+] Configuring pacman..."
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = .*/ParallelDownloads = 10/' /etc/pacman.conf

echo "[+] System configuration completed successfully in chroot"
EOFCHROOTSCRIPT

# Make the script executable
chmod +x /mnt/chroot_setup.sh

# Execute the chroot script with parameters
arch-chroot /mnt /chroot_setup.sh "$HOSTNAME" "$USERNAME" "$USERPASS" "$LOCALE" "$TIMEZONE" "$SWAP_SIZE" "$KEYMAP"

# Remove the script
rm /mnt/chroot_setup.sh

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