#!/bin/zsh
set -euo pipefail

# Cartella dello script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Sorgente e destinazione
SOURCE_DIR="$PARENT_DIR/.config"
TARGET_DIR="$HOME/.config"

# Controlli di base
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Errore: sorgente non trovata: $SOURCE_DIR"
  exit 1
fi

# Assicurati che la destinazione esista
mkdir -p "$TARGET_DIR"

# Rimuovi le cartelle di destinazione che verranno sostituite
# (solo le directory presenti in SOURCE_DIR, non l'intera ~/.config)
# In zsh, usiamo setopt invece di shopt
setopt dotglob nullglob
for entry in "$SOURCE_DIR"/*; do
  base_name="$(basename "$entry")"
  target_path="$TARGET_DIR/$base_name"
  if [ -d "$entry" ] && [ -e "$target_path" ]; then
    echo "-> Rimuovo cartella di destinazione: $target_path"
    rm -rf -- "$target_path"
  fi
done
unsetopt dotglob nullglob

# Copia (sovrascrive, mantiene permessi, include file nascosti)
echo "-> Copio da: $SOURCE_DIR"
echo "-> A:  $TARGET_DIR"
cp -af "$SOURCE_DIR"/. "$TARGET_DIR"

echo "✓ Copia completata."

# --- Normalizza percorsi nelle config (sostituisce ~/ con $HOME/) ---
HP_CONF="$TARGET_DIR/hyprpaper/hyprpaper.conf"
HL_CONF="$TARGET_DIR/hypr/hyprland.conf"
if [ -f "$HP_CONF" ]; then
  # Esempi trasformati:
  #   preload = ~/.config/wallpapers/img.jpg -> preload = /home/user/.config/wallpapers/img.jpg
  #   wallpaper = DP-6,~/.config/wallpapers/img.jpg -> wallpaper = DP-6,/home/user/.config/wallpapers/img.jpg
  sed -i -e "s#= ~/#= $HOME/#g" -e "s#,~/#,$HOME/#g" "$HP_CONF"
fi
if [ -f "$HL_CONF" ]; then
  # Corregge path in exec-once e altri campi che usano ~
  sed -i -e "s#~/.config/#$HOME/.config/#g" -e "s#= ~/#= $HOME/#g" "$HL_CONF"
fi

# --- Ricarica Hyprland e riavvia hyprpaper se in esecuzione ---
# Hyprland espone la variabile HYPRLAND_INSTANCE_SIGNATURE quando è attivo
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  echo "-> Ricarico la configurazione di Hyprland..."
  hyprctl reload && echo "✓ Hyprland ricaricato."

  # Prepara percorsi IPC per hyprpaper
  RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  SIG="$HYPRLAND_INSTANCE_SIGNATURE"
  HP_SOCKET1="$RUNTIME_DIR/hypr/$SIG/.hyprpaper.sock"   # vecchie versioni (scoped per instance)
  HP_SOCKET2="$RUNTIME_DIR/hypr/$SIG/hyprpaper.sock"    # nuove versioni (scoped per instance)
  HP_SOCKET3="$RUNTIME_DIR/hypr/.hyprpaper.sock"        # possibile path globale legacy (senza signature)
  HP_SOCKET4="$RUNTIME_DIR/hypr/hyprpaper.sock"         # possibile path globale nuovo (senza signature)

  echo "-> Riavvio hyprpaper..."
  # Termina eventuali istanze attive
  pkill -x hyprpaper >/dev/null 2>&1 || true

  # Se esistono socket orfani (nessun processo ma file presente), rimuovili
  if ! pgrep -x hyprpaper >/dev/null 2>&1; then
    [ -S "$HP_SOCKET1" ] && rm -f -- "$HP_SOCKET1" || true
    [ -S "$HP_SOCKET2" ] && rm -f -- "$HP_SOCKET2" || true
  fi

  # Verifica presenza binario hyprpaper
  if ! command -v hyprpaper >/dev/null 2>&1; then
    echo "⚠️ 'hyprpaper' non è nel PATH. Installa o aggiungi al PATH e riprova."
  else
    # Avvia hyprpaper dal contesto di Hyprland (ereditando la signature corretta)
    hyprctl dispatch exec "hyprpaper -c $HOME/.config/hyprpaper/hyprpaper.conf" >/dev/null 2>&1 || true
  fi

  # Attendi che hyprpaper parta (socket creato o processo presente)
  for i in {1..40}; do # ~10s (40 * 0.25s) - zsh range syntax
    if [ -S "$HP_SOCKET1" ] || [ -S "$HP_SOCKET2" ] || [ -S "$HP_SOCKET3" ] || [ -S "$HP_SOCKET4" ] || pgrep -x hyprpaper >/dev/null 2>&1; then
      echo "✓ hyprpaper avviato."
      break
    fi
    sleep 0.05
  done

  # Fallback: se non ancora confermato, prova ad avviare direttamente e attendi un altro po'
  if ! pgrep -x hyprpaper >/dev/null 2>&1 && [ ! -S "$HP_SOCKET1" ] && [ ! -S "$HP_SOCKET2" ] && [ ! -S "$HP_SOCKET3" ] && [ ! -S "$HP_SOCKET4" ]; then
    env HYPRLAND_INSTANCE_SIGNATURE="$SIG" XDG_RUNTIME_DIR="$RUNTIME_DIR" nohup hyprpaper -c "$HOME/.config/hyprpaper/hyprpaper.conf" >/dev/null 2>&1 &
    for i in {1..20}; do # ~5s - zsh range syntax
      if [ -S "$HP_SOCKET1" ] || [ -S "$HP_SOCKET2" ] || [ -S "$HP_SOCKET3" ] || [ -S "$HP_SOCKET4" ] || pgrep -x hyprpaper >/dev/null 2>&1; then
        echo "✓ hyprpaper avviato (fallback)."
        break
      fi
      sleep 0.05
    done
  fi

  if ! pgrep -x hyprpaper >/dev/null 2>&1 && [ ! -S "$HP_SOCKET1" ] && [ ! -S "$HP_SOCKET2" ] && [ ! -S "$HP_SOCKET3" ] && [ ! -S "$HP_SOCKET4" ]; then
    echo "⚠️ Impossibile confermare l'avvio di hyprpaper."
    echo "   Socket attesi: $HP_SOCKET1 oppure $HP_SOCKET2 oppure $HP_SOCKET3 oppure $HP_SOCKET4"
    echo "   Suggerimento: esegui dentro Hyprland -> hyprpaper -c $HOME/.config/hyprpaper/hyprpaper.conf"
    WP="$HOME/.config/wallpapers/1776186.jpg"; [ -f "$WP" ] || echo "   Nota: file wallpaper mancante: $WP"
  fi

  # --- Riavvio Waybar ---
  echo "-> Riavvio Waybar..."
  # Termina Waybar se in esecuzione
  pkill -x waybar >/dev/null 2>&1 || true
  sleep 0.05

  if ! command -v waybar >/dev/null 2>&1; then
    echo "⚠️ 'waybar' non è nel PATH. Installa o aggiungi al PATH per avviarlo."
  else
    # Avvia Waybar dal contesto di Hyprland
    hyprctl dispatch exec "waybar" >/dev/null 2>&1 || true

    # Attendi che Waybar parta
    for i in {1..40}; do # ~10s - zsh range syntax
      if pgrep -x waybar >/dev/null 2>&1; then
        echo "✓ Waybar avviato."
        break
      fi
      sleep 0.05
    done

    # Fallback: prova ad avviarlo direttamente se non è ancora partito
    if ! pgrep -x waybar >/dev/null 2>&1; then
      nohup waybar >/dev/null 2>&1 &
      for i in {1..20}; do # ~5s - zsh range syntax
        if pgrep -x waybar >/dev/null 2>&1; then
          echo "✓ Waybar avviato (fallback)."
          break
        fi
        sleep 0.05
      done
    fi

    update-desktop-database ~/.local/share/applications

    if ! pgrep -x waybar >/dev/null 2>&1; then
      echo "⚠️ Impossibile confermare l'avvio di Waybar."
      echo "   Suggerimento: esegui dentro Hyprland -> waybar"
    fi
  fi
else
  echo "ℹ️ Hyprland non sembra attivo (o 'hyprctl' non è nel PATH)."
  echo "   Avvia Hyprland e, se serve, esegui manualmente: hyprctl reload"
fi