#!/bin/bash

# Percorso della cartella in cui si trova lo script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Percorso della cartella superiore
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Cartella sorgente "config" allo stesso livello
SOURCE_DIR="$PARENT_DIR/config"

# Cartella di destinazione
TARGET_DIR="$HOME/.config"

# Controllo se la cartella sorgente esiste
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Errore: la cartella sorgente $SOURCE_DIR non esiste."
    exit 1
fi

# Copia con sovrascrittura (-f) mantenendo permessi e struttura (-a)
cp -af "$SOURCE_DIR"/. "$TARGET_DIR"

echo "File copiati da $SOURCE_DIR a $TARGET_DIR con sovrascrittura."
