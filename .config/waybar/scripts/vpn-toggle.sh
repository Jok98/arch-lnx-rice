#!/usr/bin/env bash
set -uo pipefail

VPN_CONFIG="${HOME}/.openfortivpn/vpn_milano.conf"
VPN_MATCH="openfortivpn -c ${VPN_CONFIG}"
LOG_FILE="/tmp/openfortivpn-waybar.log"
LABEL="󰖂 VPN"
ACTION="${1:-status}"

if [[ ! -f "$VPN_CONFIG" ]]; then
  printf '{"text":"%s","tooltip":"Config VPN mancante","class":"disconnected"}\n' "$LABEL"
  exit 0
fi

is_connected() {
  pgrep -f "$VPN_MATCH" >/dev/null 2>&1
}

print_status() {
  if is_connected; then
    printf '{"text":"%s","tooltip":"VPN Milano connessa","class":"connected"}\n' "$LABEL"
  else
    printf '{"text":"%s","tooltip":"VPN Milano disconnessa","class":"disconnected"}\n' "$LABEL"
  fi
}

toggle_connection() {
  if is_connected; then
    sudo -n pkill -f "$VPN_MATCH" >/dev/null 2>&1 || true
  else
    sudo -n bash -c "nohup openfortivpn -c '$VPN_CONFIG' -v >>'$LOG_FILE' 2>&1 &" >/dev/null 2>&1 || true
  fi
}

case "$ACTION" in
  toggle)
    toggle_connection
    ;;
  status|*)
    print_status
    ;;
esac
