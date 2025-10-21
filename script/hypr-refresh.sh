#!/bin/zsh
set -euo pipefail

# Wait parameters (seconds)
WAIT_STEPS="${WAIT_STEPS:-40}"
WAIT_DELAY="${WAIT_DELAY:-0.25}"
FALLBACK_WAIT_STEPS="${FALLBACK_WAIT_STEPS:-20}"
FALLBACK_WAIT_DELAY="${FALLBACK_WAIT_DELAY:-0.25}"
SHORT_DELAY="${SHORT_DELAY:-0.05}"

process_running() {
  local proc_name="$1"
  pgrep -x "$proc_name" >/dev/null 2>&1
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

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "ℹ️ 'hyprctl' is not in PATH. Hyprland refresh skipped."
  exit 0
fi

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  echo "ℹ️ HYPRLAND_INSTANCE_SIGNATURE is not set. Run this inside an active Hyprland session."
  exit 0
fi

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SIG="$HYPRLAND_INSTANCE_SIGNATURE"

echo "-> Reloading Hyprland configuration..."
hyprctl reload && echo "✓ Hyprland reloaded."

# hyprpaper -----------------------------------------------------------------
HYPRPAPER_CONFIG="$HOME/.config/hyprpaper/hyprpaper.conf"
typeset -a HYPRPAPER_SOCKETS=(
  "$RUNTIME_DIR/hypr/$SIG/.hyprpaper.sock"
  "$RUNTIME_DIR/hypr/$SIG/hyprpaper.sock"
  "$RUNTIME_DIR/hypr/.hyprpaper.sock"
  "$RUNTIME_DIR/hypr/hyprpaper.sock"
)

hyprpaper_ready_simple() {
  pgrep -x hyprpaper >/dev/null 2>&1
}

echo "-> Restarting hyprpaper..."
if ! command -v hyprpaper >/dev/null 2>&1; then
  echo "⚠️ 'hyprpaper' is not in PATH. Install it or add it to PATH and try again."
else
  pkill -x hyprpaper >/dev/null 2>&1 || true
  sleep "$SHORT_DELAY"
  for socket_path in "${HYPRPAPER_SOCKETS[@]}"; do
    [ -S "$socket_path" ] && rm -f -- "$socket_path" || true
  done
  hyprctl dispatch exec "hyprpaper -c $HYPRPAPER_CONFIG" >/dev/null 2>&1 || true
  if ! wait_for_ready hyprpaper_ready_simple 10 0.25; then
    echo "⚠️ hyprpaper did not confirm startup via hyprctl; trying direct launch."
    env HYPRLAND_INSTANCE_SIGNATURE="$SIG" XDG_RUNTIME_DIR="$RUNTIME_DIR" nohup hyprpaper -c "$HYPRPAPER_CONFIG" >/dev/null 2>&1 &
    wait_for_ready hyprpaper_ready_simple 20 0.25 || echo "⚠️ Unable to confirm hyprpaper startup."
  fi
  echo "✓ hyprpaper restart requested."
fi

# Waybar --------------------------------------------------------------------
start_waybar_primary() {
  hyprctl dispatch exec "waybar" >/dev/null 2>&1 || true
}

start_waybar_fallback() {
  nohup waybar >/dev/null 2>&1 &
}

echo "-> Restarting Waybar..."
if ! command -v waybar >/dev/null 2>&1; then
  echo "⚠️ 'waybar' is not in PATH. Install it or add it to PATH before starting it."
else
  waybar_ready() {
    process_running "waybar"
  }

  if restart_with_wait "waybar" start_waybar_primary start_waybar_fallback waybar_ready "✓ Waybar started." "✓ Waybar started (fallback)." ""; then
    true
  else
    echo "⚠️ Unable to confirm Waybar startup."
    echo "   Tip: run inside Hyprland -> waybar"
  fi

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications >/dev/null 2>&1 || true
  fi
fi

# swaync --------------------------------------------------------------------
echo "-> Restarting swaync..."
if ! command -v swaync >/dev/null 2>&1; then
  echo "⚠️ 'swaync' is not in PATH. Install it or add it to PATH before starting it."
else
  swaync_ready() {
    process_running "swaync"
  }

  start_swaync_primary() {
    hyprctl dispatch exec "swaync" >/dev/null 2>&1 || true
  }

  start_swaync_fallback() {
    nohup swaync >/dev/null 2>&1 &
  }

  if restart_with_wait "swaync" start_swaync_primary start_swaync_fallback swaync_ready "✓ swaync started." "✓ swaync started (fallback)." ""; then
    true
  else
    echo "⚠️ Unable to confirm swaync startup."
    echo "   Tip: run inside Hyprland -> swaync"
  fi
fi

# hyprshell -----------------------------------------------------------------
echo "-> Restarting hyprshell..."
if ! command -v hyprshell >/dev/null 2>&1; then
  echo "⚠️ 'hyprshell' is not in PATH. Install it or add it to PATH before starting it."
else
  hyprshell_ready() {
    process_running "hyprshell"
  }

  start_hyprshell_primary() {
    hyprctl dispatch exec "hyprshell run" >/dev/null 2>&1 || true
  }

  start_hyprshell_fallback() {
    nohup hyprshell run >/dev/null 2>&1 &
  }

  if restart_with_wait "hyprshell" start_hyprshell_primary start_hyprshell_fallback hyprshell_ready "✓ hyprshell started." "✓ hyprshell started (fallback)." ""; then
    true
  else
    echo "⚠️ Unable to confirm hyprshell startup."
    echo "   Tip: run inside Hyprland -> hyprshell run"
  fi
fi

# wl-paste watchers ---------------------------------------------------------
echo "-> Refreshing wl-paste watchers..."
if ! command -v wl-paste >/dev/null 2>&1 || ! command -v cliphist >/dev/null 2>&1; then
  echo "⚠️ 'wl-paste' or 'cliphist' not in PATH. Skipping wl-paste watchers."
else
  typeset -a WL_PASTE_WATCHERS=(
    "--type text --watch cliphist store"
    "--type image --watch cliphist store"
  )
  for watcher in "${WL_PASTE_WATCHERS[@]}"; do
    pkill -f "wl-paste ${watcher}" >/dev/null 2>&1 || true
    nohup wl-paste ${=watcher} >/dev/null 2>&1 &
  done
  echo "✓ wl-paste watchers restarted."
fi

# Update DBus environment ---------------------------------------------------
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  echo "-> Updating DBus activation environment..."
  dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP >/dev/null 2>&1 || true
fi

# Hyprland extras -----------------------------------------------------------
if command -v hyprpm >/dev/null 2>&1; then
  echo "-> Reloading hyprpm plugins..."
  hyprpm reload -n >/dev/null 2>&1 || true
fi

echo "-> Setting cursor theme..."
hyprctl setcursor Bibata-Modern-Amber 24 >/dev/null 2>&1 || true

echo "✓ Hyprland refresh completed."
