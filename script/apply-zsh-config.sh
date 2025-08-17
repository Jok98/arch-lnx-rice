#!/usr/bin/env zsh
set -eu
set -o pipefail

# Cartella dello script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Sorgente (dotfiles zsh nel repository) e destinazione (HOME dell'utente)
SOURCE_DIR="$REPO_ROOT/zsh"
TARGET_DIR="$HOME"

# Controlli di base
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Errore: cartella sorgente non trovata: $SOURCE_DIR"
  exit 1
fi

# Copia includendo file nascosti e sovrascrivendo se già presenti
# L'uso di "." alla fine del percorso sorgente include TUTTI i file (anche dotfiles)
echo "-> Copio file zsh da: $SOURCE_DIR"
echo "-> A:  $TARGET_DIR (sovrascrivo se esistono)"
cp -af "$SOURCE_DIR"/. "$TARGET_DIR"/

echo "✓ Copia completata."
