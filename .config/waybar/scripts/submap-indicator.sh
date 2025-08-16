#!/bin/bash

# Funzione per ottenere lo stato corrente
get_submap_status() {
    if [ -f "/tmp/hypr-submap-state" ]; then
        submap=$(cat /tmp/hypr-submap-state)
        if [ "$submap" = "supermode" ]; then
            echo '{"text": "\uf2dd", "class": "supermode", "tooltip": "Supermode"}'
        else
            echo "{\"text\": \"●\", \"class\": \"active\", \"tooltip\": \"Submap: $submap\"}"
        fi
    else
        echo '{"text": "\uf2dd", "class": "inactive", "tooltip": "Normal mode"}'
    fi
}

# Output iniziale
get_submap_status

# Ascolta gli eventi di Hyprland
socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r event; do
    case "$event" in
        submap\>\>*)
            # Estrai il nome della submap
            submap_name="${event#submap>>}"

            if [ -n "$submap_name" ]; then
                echo "$submap_name" > /tmp/hypr-submap-state
            else
                rm -f /tmp/hypr-submap-state
            fi
            get_submap_status
            ;;
    esac
done