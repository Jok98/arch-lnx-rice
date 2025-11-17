#!/usr/bin/env bash
set -euo pipefail

# Simple rofi-based power menu replicating the old wlogout actions
entries=(
  "󰌾"
  "󰍃"
  "󰤄"
  "󰜉"
  "󰐥"
)

# Use index output so the command triggers even if markup/text changes
idx="$(printf '%s\n' "${entries[@]}" | rofi -dmenu -i -p "Power" -markup-rows \
  -format i \
  -me-accept-entry MousePrimary -me-select-entry MouseSecondary \
  -theme "${HOME}/.config/rofi/themes/powermenu.rasi")"

case "${idx}" in
  0) hyprlock ;;
  1) loginctl terminate-user "${USER}" ;;
  2) systemctl suspend ;;
  3) systemctl reboot ;;
  4) systemctl poweroff ;;
  *) exit 0 ;;
esac
