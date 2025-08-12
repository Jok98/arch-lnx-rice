#!/bin/bash

# Percorso della cartella in cui si trova lo script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Percorso della cartella superiore
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Cartella di destinazione "config" allo stesso livello
TARGET_DIR="$PARENT_DIR/config"

# Cartella sorgente
SOURCE_DIR="$HOME/.config"

# Creo la cartella di destinazione se non esiste
mkdir -p "$TARGET_DIR"

# Copia mantenendo struttura, permessi e file nascosti
cp -a "$SOURCE_DIR"/. "$TARGET_DIR"

echo "Copia completata da $SOURCE_DIR a $TARGET_DIR"
