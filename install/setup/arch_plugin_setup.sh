#!/usr/bin/env zsh
set -eu
set -o pipefail

# =======================
# Desktop Environment Setup Script
# Hyprland components, cursors, hyprWorkspaceLayouts plugin, Hyprexpo, Zsh plugins
# =======================

installed_components=()
skipped_components=()
failed_components=()

log() { echo "$(date +'%Y-%m-%d %H:%M:%S') - $*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "❌ missing command: $1"; exit 1; }
}

# =======================
# Sanity checks
# =======================
if [ ! -f /etc/arch-release ]; then
  log "⚠️  This script is intended for Arch Linux. /etc/arch-release not found."
  log "    Continuing in 2s (Ctrl+C to abort)"; sleep 2
fi
need_cmd sudo
need_cmd bash

# Idempotent pacman install helper
install_pkgs() {
  local label="$1"; shift
  local -a pkgs=("$@")
  log "📦 Installing ${label}: ${pkgs[*]}"
  if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
    installed_components+=("${label}")
  else
    failed_components+=("${label}")
  fi
}

AUR_HELPER="${AUR_HELPER:-}"
AUR_HELPER_RESOLVED=0

ensure_aur_helper() {
  if [ -n "${AUR_HELPER:-}" ]; then
    if command -v "${AUR_HELPER}" >/dev/null 2>&1; then
      if [ "${AUR_HELPER_RESOLVED}" -eq 0 ]; then
        log "ℹ️ Using configured AUR helper: ${AUR_HELPER}"
      fi
      AUR_HELPER_RESOLVED=1
      return 0
    else
      log "⚠️ Specified AUR helper (${AUR_HELPER}) not found. Trying automatic detection."
    fi
  fi

  AUR_HELPER=""
  local -a helpers=()
  command -v yay >/dev/null 2>&1 && helpers+=("yay")
  command -v paru >/dev/null 2>&1 && helpers+=("paru")

  if [ ${#helpers[@]} -eq 0 ]; then
    return 1
  fi

  if [ ${#helpers[@]} -eq 1 ]; then
    AUR_HELPER="${helpers[1]}"
    AUR_HELPER_RESOLVED=1
    log "ℹ️ Using ${AUR_HELPER} as AUR helper."
    return 0
  fi

  if [ ! -t 0 ]; then
    AUR_HELPER="${helpers[1]}"
    AUR_HELPER_RESOLVED=1
    log "ℹ️ Multiple AUR helpers detected (${helpers[*]}). Non-interactive session: using ${AUR_HELPER}."
    return 0
  fi

  while true; do
    local input=""
    if ! read -r "?Select AUR helper (${helpers[*]}): " input; then
      log "❌ Input interrupted. No AUR helper selected."
      return 1
    fi
    for candidate in "${helpers[@]}"; do
      if [ "${input}" = "${candidate}" ]; then
        AUR_HELPER="${candidate}"
        AUR_HELPER_RESOLVED=1
        log "ℹ️ Using ${AUR_HELPER} as AUR helper."
        return 0
      fi
    done
    log "⚠️ Helper '${input}' not valid. Try again."
  done
}

install_aur_pkgs() {
  local label="$1"; shift
  local -a pkgs=("$@")

  if ! ensure_aur_helper; then
    log "⚠️ No AUR helper available to install ${label}."
    skipped_components+=("${label} (no AUR helper)")
    return 2
  fi

  log "📦 Installing ${label} via ${AUR_HELPER}: ${pkgs[*]}"
  if "${AUR_HELPER}" -S --needed --noconfirm "${pkgs[@]}"; then
    installed_components+=("${label} (${AUR_HELPER})")
    return 0
  else
    failed_components+=("${label} (${AUR_HELPER})")
    return 1
  fi
}

# =======================
# Zsh plugins (Powerlevel10k, autosuggestions, syntax-highlighting)
# =======================
install_zsh_plugin() {
  local plugin_name="$1"
  local plugin_url="$2"
  local plugin_dir="$3"

  if [ -d "$plugin_dir" ]; then
    log "✅ $plugin_name already installed."
    skipped_components+=("$plugin_name")
  else
    log "📥 Installing $plugin_name..."
    if git clone "$plugin_url" "$plugin_dir"; then
      installed_components+=("$plugin_name")
    else
      failed_components+=("$plugin_name")
    fi
  fi
}

# Powerlevel10k
install_zsh_plugin "Powerlevel10k" "https://github.com/romkatv/powerlevel10k.git" "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"

# zsh-autosuggestions
install_zsh_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

# zsh-syntax-highlighting
install_zsh_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

# =======================
# Alias (zsh)
# =======================
if [ -f "$HOME/.zshrc" ]; then
  if ! grep -q "^alias k='kubectl'" "$HOME/.zshrc"; then
    log "⚙️ Adding kubectl alias to ~/.zshrc..."
    echo "alias k='kubectl'" >> "$HOME/.zshrc"
  else
    log "✅ kubectl alias already present in ~/.zshrc."
    skipped_components+=("alias k (zsh)")
  fi
fi

# =======================
# Cursor theme (Hyprcursor + Bibata)
# =======================
install_pkgs "Hyprcursor" hyprcursor

# Install bibata-cursor-theme via AUR helper if available; fallback to pacman
if ensure_aur_helper; then
  install_aur_pkgs "bibata-cursor-theme" bibata-cursor-theme || log "⚠️ Installing bibata-cursor-theme via ${AUR_HELPER} failed."
else
  log "⚠️ No AUR helper; attempting bibata-cursor-theme via pacman (if available in repos)"
  if sudo pacman -S --needed --noconfirm bibata-cursor-theme; then
    installed_components+=("bibata-cursor-theme (pacman)")
  else
    skipped_components+=("bibata-cursor-theme (no AUR helper)")
    log "⚠️ Unable to install bibata-cursor-theme without an AUR helper. See doc/cursor.md"
  fi
fi

# Ensure icons directory and copy Bibata-Modern-Amber into local icons
log "🎨 Copying Bibata-Modern-Amber cursor theme into ~/.local/share/icons/ ..."
mkdir -p "$HOME/.local/share/icons/"
if [ -d "/usr/share/icons/Bibata-Modern-Amber" ]; then
  if cp -r "/usr/share/icons/Bibata-Modern-Amber" "$HOME/.local/share/icons/"; then
    installed_components+=("Bibata-Modern-Amber (copied to ~/.local/share/icons)")
  else
    failed_components+=("copy Bibata-Modern-Amber to ~/.local/share/icons")
  fi
else
  log "⚠️ /usr/share/icons/Bibata-Modern-Amber not found. Verify that the path exists."
  skipped_components+=("Bibata copy (source missing)")
fi

# =======================
# Hyprshell (AUR)
# =======================
if ! install_aur_pkgs "hyprshell" hyprshell; then
  :
fi

# =======================
# NetworkManager dmenu helper (AUR)
# =======================
if command -v networkmanager_dmenu >/dev/null 2>&1; then
  log "✅ networkmanager_dmenu already installed."
  skipped_components+=("networkmanager-dmenu-git")
else
  if ! install_aur_pkgs "networkmanager-dmenu-git" networkmanager-dmenu-git; then
    :
  fi
fi

# =======================
# Core applications (Thunar and wlogout)
# =======================
# Ensure Thunar file manager
if command -v thunar >/dev/null 2>&1; then
  log "✅ Thunar already installed."
  skipped_components+=("Thunar")
else
  install_pkgs "Thunar" thunar
fi

# Ensure wlogout
if command -v wlogout >/dev/null 2>&1; then
  log "✅ wlogout already installed."
  skipped_components+=("wlogout")
else
  log "📦 Installing wlogout via pacman..."
  if sudo pacman -S --needed --noconfirm wlogout; then
    installed_components+=("wlogout (pacman)")
  else
    log "ℹ️ wlogout installation via pacman failed or package missing. Trying AUR helper..."
    if ! install_aur_pkgs "wlogout" wlogout; then
      :
    fi
  fi
fi

# =======================
# Utilities (swaync and btop)
# =======================
# Ensure swaync
if command -v swaync >/dev/null 2>&1; then
  log "✅ swaync already installed."
  skipped_components+=("swaync")
else
  install_pkgs "swaync" swaync
fi

# Ensure btop
if command -v btop >/dev/null 2>&1; then
  log "✅ btop already installed."
  skipped_components+=("btop")
else
  install_pkgs "btop" btop
fi

# =======================
# Hyprland hyprWorkspaceLayouts plugin
# =======================
install_hypr_workspace_layouts_plugin() {
  if ! command -v hyprpm >/dev/null 2>&1; then
    log "❌ hyprpm not found. Make sure Hyprland is installed."
    failed_components+=("hyprWorkspaceLayouts plugin (hyprpm missing)")
    return 1
  fi

  if hyprpm list | grep -qi "hyprWorkspaceLayouts"; then
    log "✅ hyprWorkspaceLayouts plugin already installed/enabled."
    skipped_components+=("hyprWorkspaceLayouts plugin")
    return 0
  fi

  install_pkgs "hyprWorkspaceLayouts deps (meson cpio cmake)" meson cpio cmake

  log "↻ Running 'hyprpm update' before installing the plugin..."
  if ! hyprpm update; then
    log "⚠️ 'hyprpm update' failed. Will retry after adding the plugin repository."
  fi

  log "📦 Installing hyprWorkspaceLayouts plugin for Hyprland..."
  if ! hyprpm add https://github.com/zakk4223/hyprWorkspaceLayouts; then
    log "ℹ️ hyprWorkspaceLayouts repository might already be added, continuing..."
  fi

  if ! hyprpm update; then
    log "⚠️ Unable to update after adding the repository, continuing anyway..."
  fi

  if hyprpm enable hyprWorkspaceLayouts; then
    installed_components+=("hyprWorkspaceLayouts plugin")
    log "✅ hyprWorkspaceLayouts plugin installed and enabled."
  else
    failed_components+=("hyprWorkspaceLayouts plugin enable")
    log "❌ Error while enabling the hyprWorkspaceLayouts plugin."
  fi
}

# =======================
# Hyprland Hyprexpo plugin
# =======================
install_hyprexpo_plugin() {
  if ! command -v hyprpm >/dev/null 2>&1; then
    log "❌ hyprpm not found. Skipping hyprexpo."
    failed_components+=("hyprexpo plugin (hyprpm missing)")
    return 1
  fi

  # already present/enabled?
  if hyprpm list | grep -qiE "hyprexpo"; then
    log "✅ hyprexpo already present/enabled via hyprpm."
    skipped_components+=("hyprexpo plugin")
    return 0
  fi

  # frequent build dependencies
  install_pkgs "hyprexpo deps (meson cpio cmake ninja gcc pkgconf)" meson cpio cmake ninja gcc pkgconf

  # official plugin repository
  if ! hyprpm add https://github.com/hyprwm/hyprland-plugins; then
    log "ℹ️ hyprland-plugins repo might already be added, continuing..."
  fi

  # update and build
  if ! hyprpm update; then
    log "⚠️ hyprpm update failed. Attempting enable regardless."
  fi

  if hyprpm enable hyprexpo; then
    installed_components+=("hyprexpo plugin (hyprpm)")
    log "✅ hyprexpo enabled via hyprpm."
    hyprpm reload || true
    return 0
  fi

  log "ℹ️ hyprexpo not enabled via hyprpm (missing plugin or build failed). Trying AUR."

  # Fallback AUR
  if command -v yay >/dev/null 2>&1; then
    if yay -S --needed --noconfirm hyprland-plugin-hyprexpo; then
      installed_components+=("hyprexpo plugin (AUR)")
      log "✅ hyprexpo installed via AUR. Enable it with hyprpm or load it via hyprctl if needed."
      return 0
    else
      failed_components+=("hyprexpo plugin (AUR)")
      log "❌ AUR installation failed for hyprexpo."
      return 1
    fi
  else
    failed_components+=("hyprexpo plugin (no hyprpm enable, no yay)")
    log "⚠️ yay not available. Skipping AUR fallback for hyprexpo."
    return 1
  fi
}

# Install plugins
install_hypr_workspace_layouts_plugin
install_hyprexpo_plugin

# =======================
# Final summary
# =======================
printf "\n================== ✅ DESKTOP SETUP SUMMARY ✅ ==================\n"
echo "🟢 Installed components:"
for item in "${installed_components[@]:-}"; do echo "   - $item"; done
printf "\n🟡 Already present components:\n"
for item in "${skipped_components[@]:-}"; do echo "   - $item"; done
if [ ${#failed_components[@]:-0} -ne 0 ]; then
  printf "\n🔴 Failed components:\n"
  for item in "${failed_components[@]}"; do echo "   - $item"; done
else
  printf "\n✅ No failed components.\n"
fi
printf "===============================================================\n\n"

log "✅ Desktop environment setup completed."
