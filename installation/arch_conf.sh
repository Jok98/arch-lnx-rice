#!/usr/bin/env zsh
set -eu
set -o pipefail

# =======================
# Config toggles
# =======================
: "${SKIP_UPGRADE:=0}"                 # 1 = salta full upgrade
: "${SDK_JAVA_ID:=21.0.8-zulu}"       # Java 21 (Zulu LTS). Cambia vendor/versione se preferisci.

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

# =======================
# Package db sync/upgrade
# =======================
if [ "${SKIP_UPGRADE}" = "1" ]; then
  log "🔄 Refresh pacman db (no full upgrade)..."
  if sudo pacman -Sy --noconfirm; then
    installed_components+=("pacman -Sy")
  else
    failed_components+=("pacman -Sy")
  fi
else
  log "🔄 Full system upgrade (pacman -Syu)..."
  if sudo pacman -Syu --noconfirm; then
    installed_components+=("pacman -Syu")
  else
    failed_components+=("pacman -Syu")
  fi
fi

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
# Base utilities
# =======================
install_pkgs "base utilities (curl zip unzip)" curl zip unzip

# =======================
# Git
# =======================
if ! command -v git >/dev/null 2>&1; then
  install_pkgs "Git" git
else
  log "✅ Git già installato."
  skipped_components+=("Git")
fi

# =======================
# SDKMAN wrappers (sicuri con set -u)
# =======================
sdkman_init_safe() {
  local init="$HOME/.sdkman/bin/sdkman-init.sh"
  if [[ -s "$init" ]]; then
    set +u
    # shellcheck source=/dev/null
    source "$init"
    local rc=$?
    set -u
    return $rc
  fi
  return 1
}

sdk_safe() {
  # Esegue `sdk ...` con -u disabilitato per evitare "unbound variable" interni
  set +u
  sdk "$@"
  local rc=$?
  set -u
  return $rc
}

# =======================
# Install / init SDKMAN
# =======================
if [ ! -d "$HOME/.sdkman" ]; then
  log "📥 Installing SDKMAN..."
  if curl -s "https://get.sdkman.io" | bash; then
    installed_components+=("SDKMAN")
    sdkman_init_safe || { log "⚠️ SDKMAN init fallita (continuo)"; skipped_components+=("SDKMAN init"); }
  else
    log "❌ SDKMAN installation failed."
    failed_components+=("SDKMAN")
  fi
else
  log "✅ SDKMAN già installato."
  skipped_components+=("SDKMAN")
  sdkman_init_safe || { log "⚠️ SDKMAN init fallita (continuo)"; skipped_components+=("SDKMAN init"); }
fi

# =======================
# Java 21 (via SDKMAN con fallback pacman)
# =======================
install_java21_with_sdkman() {
  # richiede che sdkman_init_safe sia già stato chiamato
  if ! sdk_safe current java 2>/dev/null | grep -qE 'Using.*\b21(\.|$)'; then
    log "☕ Installing Java (SDKMAN) ${SDK_JAVA_ID}..."
    if sdk_safe install java "${SDK_JAVA_ID}" && sdk_safe default java "${SDK_JAVA_ID}"; then
      installed_components+=("Java ${SDK_JAVA_ID}")
      return 0
    else
      log "⚠️ SDKMAN Java install failed."
      return 1
    fi
  else
    log "✅ Java 21 già attivo: $( (sdk_safe current java) || true )"
    skipped_components+=("Java 21")
    return 0
  fi
}

if command -v sdk >/dev/null 2>&1 && sdkman_init_safe; then
  if ! install_java21_with_sdkman; then
    log "➡️  Fallback: installo Java 21 via pacman (jdk21-openjdk)..."
    if sudo pacman -S --needed --noconfirm jdk21-openjdk; then
      installed_components+=("Java (jdk21-openjdk)")
    else
      failed_components+=("Java 21")
    fi
  fi
else
  log "⚠️ SDKMAN non inizializzato; installo Java 21 via pacman (jdk21-openjdk)..."
  if sudo pacman -S --needed --noconfirm jdk21-openjdk; then
    installed_components+=("Java (jdk21-openjdk)")
  else
    failed_components+=("Java 21")
  fi
fi

# =======================
# Maven (SDKMAN con fallback pacman)
# =======================
if ! command -v mvn >/dev/null 2>&1; then
  if command -v sdk >/dev/null 2>&1 && sdkman_init_safe; then
    log "📦 Installing Maven via SDKMAN..."
    if sdk_safe install maven; then
      installed_components+=("Maven (SDKMAN)")
    else
      log "⚠️ SDKMAN Maven failed; fallback pacman."
      install_pkgs "Maven" maven
    fi
  else
    log "⚠️ SDKMAN assente; installo Maven via pacman."
    install_pkgs "Maven" maven
  fi
else
  log "✅ Maven già installato."
  skipped_components+=("Maven")
fi

# =======================
# Helm (pacman first, then binary fallback)
# =======================
install_helm_binary() {
  if command -v helm >/dev/null 2>&1; then
    log "✅ Helm già installato: $(helm version --short 2>/dev/null || echo '?')"
    skipped_components+=("Helm")
    return
  fi
  log "📥 Installing Helm (binary fallback)..."
  local HELM_VERSION
  HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4)
  if [ -z "${HELM_VERSION:-}" ]; then
    log "❌ Impossibile recuperare l'ultima versione Helm."
    failed_components+=("Helm")
    return
  fi
  log "ℹ️ Latest Helm version is ${HELM_VERSION}"
  curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
  curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum"
  if ! sha256sum -c "helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" --quiet; then
    log "❌ Verifica checksum Helm fallita."
    failed_components+=("Helm")
    rm -f "helm-${HELM_VERSION}-linux-amd64.tar.gz"*
    return
  fi
  tar -zxf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
  sudo mv linux-amd64/helm /usr/local/bin/helm
  sudo chmod +x /usr/local/bin/helm
  if command -v helm >/dev/null 2>&1; then
    installed_components+=("Helm ${HELM_VERSION}")
  else
    failed_components+=("Helm")
  fi
  rm -rf "helm-${HELM_VERSION}-linux-amd64.tar.gz"* linux-amd64
}

if ! command -v helm >/dev/null 2>&1; then
  if sudo pacman -S --needed --noconfirm helm; then
    installed_components+=("Helm (pacman)")
  else
    log "⚠️ pacman Helm fallito; uso binary fallback."
    install_helm_binary
  fi
else
  log "✅ Helm già installato."
  skipped_components+=("Helm")
fi

# =======================
# Docker (service + group)
# =======================
if ! command -v docker >/dev/null 2>&1; then
  install_pkgs "Docker" docker
  log "⚙️ Abilito e avvio servizio Docker..."
  if sudo systemctl enable --now docker; then
    installed_components+=("Docker service enabled")
  else
    failed_components+=("Docker service enable")
  fi
else
  log "✅ Docker già installato."
  skipped_components+=("Docker")
  sudo systemctl enable --now docker || true
fi

# docker group membership (idempotente)
if groups "$USER" | grep -qw docker; then
  log "✅ Utente '$USER' già nel gruppo 'docker'."
  skipped_components+=("docker group membership")
else
  log "👤 Aggiungo '$USER' al gruppo 'docker'..."
  if sudo usermod -aG docker "$USER"; then
    installed_components+=("docker group membership")
  else
    failed_components+=("docker group membership")
  fi
fi

# =======================
# kubectl
# =======================
if ! command -v kubectl >/dev/null 2>&1; then
  install_pkgs "kubectl" kubectl
else
  log "✅ kubectl già installato."
  skipped_components+=("kubectl")
fi

# =======================
# k3d (pacman first, fallback upstream)
# =======================
install_k3d_fallback() {
  log "📥 Installing k3d (upstream script)..."
  if curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; then
    installed_components+=("k3d (upstream)")
  else
    failed_components+=("k3d")
  fi
}

if ! command -v k3d >/dev/null 2>&1; then
  if sudo pacman -S --needed --noconfirm k3d; then
    installed_components+=("k3d (pacman)")
  else
    log "⚠️ pacman k3d fallito; uso upstream installer."
    install_k3d_fallback
  fi
else
  log "✅ k3d già installato."
  skipped_components+=("k3d")
fi

# =======================
# Node.js + npm
# =======================
if ! command -v npm >/dev/null 2>&1; then
  install_pkgs "Node.js and npm" nodejs npm
else
  log "✅ Node.js e npm già installati."
  skipped_components+=("Node.js and npm")
fi

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
# Final summary
# =======================
printf "\n================== ✅ INSTALLATION SUMMARY ✅ ==================\n"
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

log "✅ Tutti i componenti specificati sono installati/configurati."
log "ℹ️ Se sei stato aggiunto al gruppo 'docker', riapri la sessione o esegui: newgrp docker"
log "ℹ️ Per caricare l'alias ora: source ~/.zshrc"
