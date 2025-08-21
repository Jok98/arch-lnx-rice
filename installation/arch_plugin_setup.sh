#!/usr/bin/env zsh
set -eu
set -o pipefail

# =======================
# Desktop Environment Setup Script
# Hyprland components, cursors, hyprWorkspaceLayouts plugin, Zsh plugins
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
# Hyprland hyprWorkspaceLayouts plugin
# =======================
install_hypr_workspace_layouts_plugin() {
  # Check if hyprpm is available
  if ! command -v hyprpm >/dev/null 2>&1; then
    log "❌ hyprpm non trovato. Assicurati che Hyprland sia installato."
    failed_components+=("hyprWorkspaceLayouts plugin (hyprpm missing)")
    return 1
  fi

  # Check if hyprWorkspaceLayouts is already installed/enabled
  if hyprpm list | grep -qi "hyprWorkspaceLayouts"; then
    log "✅ Plugin hyprWorkspaceLayouts già installato/abilitato."
    skipped_components+=("hyprWorkspaceLayouts plugin")
    return 0
  fi

  # Install required build dependencies before installing the plugin
  install_pkgs "hyprWorkspaceLayouts deps (meson cpio cmake)" meson cpio cmake

  # Update hyprpm before attempting installation
  log "↻ Eseguo 'hyprpm update' prima dell'installazione del plugin..."
  if ! hyprpm update; then
    log "⚠️ 'hyprpm update' non è riuscito. Riproverò dopo aver aggiunto il repository del plugin."
  fi

  log "📦 Installing hyprWorkspaceLayouts plugin per Hyprland..."

  # Add the plugin repository (idempotente)
  if ! hyprpm add https://github.com/zakk4223/hyprWorkspaceLayouts; then
    log "ℹ️ Repository hyprWorkspaceLayouts forse già aggiunto, continuo..."
  fi

  # Update again to make sure new repo is fetched
  if ! hyprpm update; then
    log "⚠️ Impossibile aggiornare dopo l'aggiunta del repository, continuo comunque..."
  fi

  # Enable the plugin
  if hyprpm enable hyprWorkspaceLayouts; then
    installed_components+=("hyprWorkspaceLayouts plugin")
    log "✅ Plugin hyprWorkspaceLayouts installato e abilitato."
  else
    failed_components+=("hyprWorkspaceLayouts plugin enable")
    log "❌ Errore durante l'abilitazione del plugin hyprWorkspaceLayouts."
  fi
}

# Install hyprWorkspaceLayouts plugin
install_hypr_workspace_layouts_plugin

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
log "ℹ️ Riavvia Hyprland per attivare il plugin hyprWorkspaceLayouts."