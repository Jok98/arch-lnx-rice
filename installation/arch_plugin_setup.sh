#!/usr/bin/env zsh
set -eu
set -o pipefail

# =======================
# Desktop Environment Setup Script
# Hyprland components, cursors, nstack plugin, Zsh plugins
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
  log "⚠️  Questo script è pensato per Arch Linux. /etc/arch-release non trovato."
  log "    Continuo comunque tra 2s (Ctrl+C per abortire)"; sleep 2
fi
need_cmd sudo
need_cmd bash

# Helper pacman install idempotente
install_pkgs() {
  local label="$1"; shift
  local pkgs=("$@")
  log "📦 Installing ${label}: ${pkgs[*]}"
  if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
    installed_components+=("${label}")
  else
    failed_components+=("${label}")
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
    log "✅ $plugin_name già installato."
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
    log "⚙️ Aggiungo alias kubectl in ~/.zshrc..."
    echo "alias k='kubectl'" >> "$HOME/.zshrc"
  else
    log "✅ Alias kubectl già presente in ~/.zshrc."
    skipped_components+=("alias k (zsh)")
  fi
fi

# =======================
# Cursor theme (Hyprcursor + Bibata)
# =======================
install_pkgs "Hyprcursor" hyprcursor

# Install bibata-cursor-theme via yay if available; fallback to pacman if possible
if command -v yay >/dev/null 2>&1; then
  log "📦 Installing bibata-cursor-theme via yay..."
  if yay -S --needed --noconfirm bibata-cursor-theme; then
    installed_components+=("bibata-cursor-theme (yay)")
  else
    failed_components+=("bibata-cursor-theme (yay)")
  fi
else
  log "⚠️ yay non trovato; provo via pacman bibata-cursor-theme (se presente nei repo)"
  if sudo pacman -S --needed --noconfirm bibata-cursor-theme; then
    installed_components+=("bibata-cursor-theme (pacman)")
  else
    skipped_components+=("bibata-cursor-theme (no yay)")
    log "⚠️ Impossibile installare bibata-cursor-theme senza yay. Consulta doc/cursor.md"
  fi
fi

# Ensure icons directory and copy Bibata-Modern-Amber into local icons
log "🎨 Copio tema cursore Bibata-Modern-Amber in ~/.local/share/icons/ ..."
mkdir -p "$HOME/.local/share/icons/"
if [ -d "/usr/share/icons/Bibata-Modern-Amber" ]; then
  if cp -r "/usr/share/icons/Bibata-Modern-Amber" "$HOME/.local/share/icons/"; then
    installed_components+=("Bibata-Modern-Amber (copied to ~/.local/share/icons)")
  else
    failed_components+=("copy Bibata-Modern-Amber to ~/.local/share/icons")
  fi
else
  log "⚠️ /usr/share/icons/Bibata-Modern-Amber non trovato. Verificare che il path esista."
  skipped_components+=("Bibata copy (source missing)")
fi

# =======================
# Hyprland nstack plugin
# =======================
install_nstack_plugin() {
  # Check if hyprpm is available
  if ! command -v hyprpm >/dev/null 2>&1; then
    log "❌ hyprpm non trovato. Assicurati che Hyprland sia installato."
    failed_components+=("nstack plugin (hyprpm missing)")
    return 1
  fi

  # Check if nstack is already installed
  if hyprpm list | grep -q "hyprland-plugins"; then
    log "✅ Plugin nstack già installato."
    skipped_components+=("nstack plugin")
    return 0
  fi

  log "📦 Installing nstack plugin per Hyprland..."
  
  # Install build dependencies
  if ! install_pkgs "build dependencies for nstack" base-devel cmake meson ninja; then
    failed_components+=("nstack plugin dependencies")
    return 1
  fi

  # Clone and install hyprland-plugins repository
  local temp_dir=$(mktemp -d)
  cd "$temp_dir"
  
  if git clone https://github.com/hyprwm/hyprland-plugins.git; then
    cd hyprland-plugins
    
    # Add the plugin repository to hyprpm
    if hyprpm add .; then
      # Enable and install nstack
      if hyprpm enable hyprland-plugins && hyprpm update; then
        installed_components+=("nstack plugin")
        log "✅ Plugin nstack installato e abilitato."
      else
        failed_components+=("nstack plugin enable/update")
        log "❌ Errore durante l'abilitazione del plugin nstack."
      fi
    else
      failed_components+=("nstack plugin add")
      log "❌ Errore durante l'aggiunta del repository plugin."
    fi
  else
    failed_components+=("nstack plugin clone")
    log "❌ Errore durante il clone del repository hyprland-plugins."
  fi
  
  # Cleanup
  cd "$HOME"
  rm -rf "$temp_dir"
}

# Install nstack plugin
install_nstack_plugin

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

log "✅ Setup desktop environment completato."
log "ℹ️ Per caricare i plugin Zsh ora: source ~/.zshrc"
log "ℹ️ Riavvia Hyprland per attivare il plugin nstack."