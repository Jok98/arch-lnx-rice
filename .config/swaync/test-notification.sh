#!/bin/bash

# Test notification script
echo "Sending test notification..."

# Use gdbus to send notification directly
gdbus call --session \
    --dest=org.freedesktop.Notifications \
    --object-path=/org/freedesktop/Notifications \
    --method=org.freedesktop.Notifications.Notify \
    "Test App" 0 "" "Test Notification" "This is a test notification to verify swaync is working properly." "[]" "{}" 5000

echo "Test notification sent!"
echo "Press SUPER+N to toggle notification center"