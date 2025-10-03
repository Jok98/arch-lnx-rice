#!/bin/bash

set -o pipefail

get_modmask() {
    local mask=$1
    local mods=""

    (( mask & 1 )) && mods+="SHIFT+"
    (( mask & 4 )) && mods+="CTRL+"
    (( mask & 8 )) && mods+="ALT+"
    (( mask & 64 )) && mods+="SUPER+"

    echo "${mods%+}"
}

escape_markup() {
    local text=$1
    text=${text//&/&amp;}
    text=${text//</&lt;}
    text=${text//>/&gt;}
    text=${text//\'/&apos;}
    text=${text//\"/&quot;}
    echo "$text"
}

format_shortcut() {
    local shortcut=${1//+/' + '}
    echo "$shortcut"
}

collect_shortcuts() {
    declare -gA system_binds=()
    declare -gA app_binds=()
    declare -gA media_binds=()
    declare -gA navigation_binds=()
    declare -gA other_binds=()

    while IFS= read -r line; do
        [[ $line =~ ^bind ]] || continue

        local modmask="" key="" dispatcher="" arg=""

        while IFS= read -r subline && [[ -n $subline ]]; do
            if [[ $subline =~ ^[[:space:]]*modmask:[[:space:]]*([0-9]+) ]]; then
                modmask=${BASH_REMATCH[1]}
            elif [[ $subline =~ ^[[:space:]]*key:[[:space:]]*(.+) ]]; then
                key=${BASH_REMATCH[1]}
            elif [[ $subline =~ ^[[:space:]]*dispatcher:[[:space:]]*(.+) ]]; then
                dispatcher=${BASH_REMATCH[1]}
            elif [[ $subline =~ ^[[:space:]]*arg:[[:space:]]*(.+) ]]; then
                arg=${BASH_REMATCH[1]}
            fi
        done

        [[ -n $modmask && -n $key && -n $dispatcher ]] || continue

        local mod_readable shortcut
        mod_readable=$(get_modmask "$modmask")
        if [[ -n $mod_readable ]]; then
            shortcut="$mod_readable+$key"
        else
            shortcut="$key"
        fi

        case $dispatcher in
            killactive|exit|fullscreen|togglefloating)
                system_binds["$shortcut"]="$dispatcher $arg"
                ;;
            movefocus)
                navigation_binds["$shortcut"]="Move focus $arg"
                ;;
            exec)
                if [[ $arg =~ playerctl|wpctl|AudioPlay|AudioNext|AudioPrev|AudioMute|AudioRaise|AudioLower ]]; then
                    media_binds["$shortcut"]="$arg"
                elif [[ $arg =~ kitty|rofi|mousepad|spotify|hyprlock|grim ]]; then
                    app_binds["$shortcut"]="$arg"
                else
                    other_binds["$shortcut"]="$arg"
                fi
                ;;
            *)
                other_binds["$shortcut"]="$dispatcher $arg"
                ;;
        esac
    done < <(hyprctl binds)
}

show_shortcuts_rofi() {
    if ! command -v rofi >/dev/null 2>&1; then
        echo "rofi is not installed or not in PATH" >&2
        exit 1
    fi

    if ! command -v hyprctl >/dev/null 2>&1; then
        echo "hyprctl is not installed or not in PATH" >&2
        exit 1
    fi

    collect_shortcuts

    local -a entries=()

    add_section() {
        local title=$1
        declare -n binds_ref=$2
        local icon=$3

        if [[ ${#binds_ref[@]} -eq 0 ]]; then
            return
        fi

        entries+=("<span weight='bold' color='#9ece6a'>$icon $title</span>")

        local shortcut
        while IFS= read -r shortcut; do
            local description=${binds_ref[$shortcut]}
            local formatted_shortcut formatted_desc
            formatted_shortcut=$(escape_markup "$(format_shortcut "$shortcut")")
            formatted_desc=$(escape_markup "$description")
            entries+=("<span weight='bold'>$formatted_shortcut</span>  <span size='smaller'>$formatted_desc</span>")
        done < <(printf '%s\n' "${!binds_ref[@]}" | sort)

        entries+=(" ")
    }

    add_section "System Controls" system_binds "🖥️"
    add_section "Navigation" navigation_binds "🧭"
    add_section "Applications" app_binds "🚀"
    add_section "Media Controls" media_binds "🎵"
    add_section "Other" other_binds "⚙️"

    if [[ ${#entries[@]} -eq 0 ]]; then
        entries+=("No shortcuts found")
    fi

    printf '%s\n' "${entries[@]}" | rofi -dmenu -markup-rows -i -p "Hyprland Shortcuts" -width 80 >/dev/null
}

usage() {
    echo "Usage: $0 [--show]"
    echo "  --show  Display Hyprland shortcuts inside rofi"
}

case ${1:-} in
    --show|"")
        show_shortcuts_rofi
        ;;
    *)
        usage
        exit 1
        ;;
esac
