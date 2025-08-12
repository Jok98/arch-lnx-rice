#!/bin/bash
set -euo pipefail

# Cartella dello script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Sorgente e destinazione
SOURCE_DIR="$PARENT_DIR/config"
TARGET_DIR="$HOME/.config"

# Controlli di base
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Errore: sorgente non trovata: $SOURCE_DIR"
  exit 1
fi

# Copia (sovrascrive, mantiene permessi, include file nascosti)
echo "-> Copio da: $SOURCE_DIR"
echo "-> A:  $TARGET_DIR"
cp -af "$SOURCE_DIR"/. "$TARGET_DIR"

echo "✓ Copia completata."

# --- Ricarica Hyprland se in esecuzione ---
# Hyprland espone la variabile HYPRLAND_INSTANCE_SIGNATURE quando è attivo
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  echo "-> Ricarico la configurazione di Hyprland..."
  hyprctl reload && echo "✓ Hyprland ricaricato."
else
  echo "ℹ️ Hyprland non sembra attivo (o 'hyprctl' non è nel PATH)."
  echo "   Avvia Hyprland e, se serve, esegui manualmente: hyprctl reload"
fi
