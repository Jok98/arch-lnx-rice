#!/bin/zsh
set -euo pipefail

# Wait parameters (seconds)
WAIT_STEPS=40
WAIT_DELAY=0.25
FALLBACK_WAIT_STEPS=20
FALLBACK_WAIT_DELAY=0.25
SHORT_DELAY=0.05

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

# Generic utilities ---------------------------------------------------------
process_running() {
  local proc_name="$1"
  pgrep -x "$proc_name" >/dev/null 2>&1
}

socket_exists() {
  local socket_path
  for socket_path in "$@"; do
    [ -S "$socket_path" ] && return 0
  done
  return 1
}

clean_orphan_sockets() {
  local socket_path
  for socket_path in "$@"; do
    [ -S "$socket_path" ] && rm -f -- "$socket_path" || true
  done
}

wait_for_ready() {
  local check_fn="$1"
  local steps="$2"
  local delay="$3"
  local i=0

  while (( i < steps )); do
    if "$check_fn"; then
      return 0
    fi
    sleep "$delay"
    ((i++))
  done
  return 1
}

restart_with_wait() {
  local proc_name="$1"
  local start_fn="$2"
  local fallback_fn="$3"
  local ready_fn="$4"
  local success_msg="$5"
  local fallback_success_msg="$6"
  local cleanup_fn="$7"

  pkill -x "$proc_name" >/dev/null 2>&1 || true
  sleep "$SHORT_DELAY"

  if [[ -n "$cleanup_fn" ]]; then
    "$cleanup_fn"
  fi

  if [[ -n "$start_fn" ]]; then
    "$start_fn"
  fi

  if wait_for_ready "$ready_fn" "$WAIT_STEPS" "$WAIT_DELAY"; then
    echo "$success_msg"
    return 0
  fi

  if [[ -n "$fallback_fn" ]]; then
    "$fallback_fn"
    if wait_for_ready "$ready_fn" "$FALLBACK_WAIT_STEPS" "$FALLBACK_WAIT_DELAY"; then
      echo "$fallback_success_msg"
      return 0
    fi
  fi

  return 1
}

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

# --- Reload Hyprland and restart hyprpaper if running ---
# Hyprland exposes HYPRLAND_INSTANCE_SIGNATURE when it is active
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  echo "-> Reloading Hyprland configuration..."
  hyprctl reload && echo "✓ Hyprland reloaded."

  # Prepare IPC paths for hyprpaper
  RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  SIG="$HYPRLAND_INSTANCE_SIGNATURE"
  typeset -a HYPRPAPER_SOCKETS=(
    "$RUNTIME_DIR/hypr/$SIG/.hyprpaper.sock"   # older versions (per-instance scope)
    "$RUNTIME_DIR/hypr/$SIG/hyprpaper.sock"    # newer versions (per-instance scope)
    "$RUNTIME_DIR/hypr/.hyprpaper.sock"        # possible global legacy path (no signature)
    "$RUNTIME_DIR/hypr/hyprpaper.sock"         # possible global path (no signature)
  )
  typeset -a HYPRPAPER_INSTANCE_SOCKETS=(
    "$RUNTIME_DIR/hypr/$SIG/.hyprpaper.sock"
    "$RUNTIME_DIR/hypr/$SIG/hyprpaper.sock"
  )

  hyprpaper_cleanup() {
    if ! process_running "hyprpaper"; then
      clean_orphan_sockets "${HYPRPAPER_INSTANCE_SOCKETS[@]}"
    fi
  }

  hyprpaper_ready() {
    process_running "hyprpaper" && return 0
    socket_exists "${HYPRPAPER_SOCKETS[@]}"
  }

  start_hyprpaper_primary() {
    hyprctl dispatch exec "hyprpaper -c $HOME/.config/hyprpaper/hyprpaper.conf" >/dev/null 2>&1 || true
  }

  start_hyprpaper_fallback() {
    env HYPRLAND_INSTANCE_SIGNATURE="$SIG" XDG_RUNTIME_DIR="$RUNTIME_DIR" nohup hyprpaper -c "$HOME/.config/hyprpaper/hyprpaper.conf" >/dev/null 2>&1 &
  }

  echo "-> Restarting hyprpaper..."
  if ! command -v hyprpaper >/dev/null 2>&1; then
    echo "⚠️ 'hyprpaper' is not in PATH. Install it or add it to PATH and try again."
  else
    if ! restart_with_wait "hyprpaper" start_hyprpaper_primary start_hyprpaper_fallback hyprpaper_ready "✓ hyprpaper started." "✓ hyprpaper started (fallback)." hyprpaper_cleanup; then
      echo "⚠️ Unable to confirm hyprpaper startup."
      echo "   Expected sockets: ${HYPRPAPER_SOCKETS[*]}"
      echo "   Tip: run inside Hyprland -> hyprpaper -c $HOME/.config/hyprpaper/hyprpaper.conf"
    fi
    WP="$HOME/.config/wallpapers/1776186.jpg"; [ -f "$WP" ] || echo "   Note: missing wallpaper file: $WP"
  fi

  # --- Restart Waybar ---
  echo "-> Restarting Waybar..."
  if ! command -v waybar >/dev/null 2>&1; then
    echo "⚠️ 'waybar' is not in PATH. Install it or add it to PATH before starting it."
  else
    waybar_ready() {
      process_running "waybar"
    }

    start_waybar_primary() {
      hyprctl dispatch exec "waybar" >/dev/null 2>&1 || true
    }

    start_waybar_fallback() {
      nohup waybar >/dev/null 2>&1 &
    }

    if restart_with_wait "waybar" start_waybar_primary start_waybar_fallback waybar_ready "✓ Waybar started." "✓ Waybar started (fallback)." ""; then
      true
    else
      echo "⚠️ Unable to confirm Waybar startup."
      echo "   Tip: run inside Hyprland -> waybar"
    fi

    update-desktop-database ~/.local/share/applications

  fi
else
  echo "ℹ️ Hyprland does not appear to be active (or 'hyprctl' is not in PATH)."
  echo "   Start Hyprland and run manually if needed: hyprctl reload"
fi
