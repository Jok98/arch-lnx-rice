#!/bin/zsh
set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source and destination
SOURCE_DIR="$PARENT_DIR/.config"
TARGET_DIR="$HOME/.config"

# Basic checks
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: source not found: $SOURCE_DIR"
  exit 1
fi

# Make sure the destination exists
mkdir -p "$TARGET_DIR"

# Remove target folders that will be replaced
# (only directories present in SOURCE_DIR, not the entire ~/.config)
# In zsh we use setopt instead of shopt
setopt dotglob nullglob
for entry in "$SOURCE_DIR"/*; do
  base_name="$(basename "$entry")"
  target_path="$TARGET_DIR/$base_name"
  if [ -d "$entry" ] && [ -e "$target_path" ]; then
    echo "-> Removing target directory: $target_path"
    rm -rf -- "$target_path"
  fi
done
unsetopt dotglob nullglob

# Copy (overwrite, keep permissions, include hidden files)
echo "-> Copying from: $SOURCE_DIR"
echo "-> To:           $TARGET_DIR"
cp -af "$SOURCE_DIR"/. "$TARGET_DIR"

echo "✓ Copy completed."

# --- Normalize paths in configs (replace ~/ with $HOME/) ---
HP_CONF="$TARGET_DIR/hyprpaper/hyprpaper.conf"
HL_CONF="$TARGET_DIR/hypr/hyprland.conf"
if [ -f "$HP_CONF" ]; then
  # Example transformations:
  #   preload = ~/.config/wallpapers/img.jpg -> preload = /home/user/.config/wallpapers/img.jpg
  #   wallpaper = DP-6,~/.config/wallpapers/img.jpg -> wallpaper = DP-6,/home/user/.config/wallpapers/img.jpg
  sed -i -e "s#= ~/#= $HOME/#g" -e "s#,~/#,$HOME/#g" "$HP_CONF"
fi
if [ -f "$HL_CONF" ]; then
  # Fix paths in exec-once and other fields that use ~
  sed -i -e "s#~/.config/#$HOME/.config/#g" -e "s#= ~/#= $HOME/#g" "$HL_CONF"
fi

REFRESH_SCRIPT="$SCRIPT_DIR/hypr-refresh.sh"
if [ -x "$REFRESH_SCRIPT" ]; then
  "$REFRESH_SCRIPT" || true
else
  echo "ℹ️ Hypr refresh script not found. Expected at: $REFRESH_SCRIPT"
fi
