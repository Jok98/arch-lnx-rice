#!/bin/bash

# Function to convert modmask to readable format
get_modmask() {
    local mask=$1
    local mods=""
    
    if (( mask & 1 )); then mods+="SHIFT+"; fi
    if (( mask & 4 )); then mods+="CTRL+"; fi
    if (( mask & 8 )); then mods+="ALT+"; fi
    if (( mask & 64 )); then mods+="SUPER+"; fi
    
    echo "${mods%+}"  # Remove trailing +
}

# Create HTML output with dynamic content
create_shortcut_html() {
    local html_file="$HOME/.config/hypr/shortcuts.html"
    
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hyprland Shortcuts</title>
    <style>
        body {
            font-family: 'JetBrains Mono', 'Fira Code', monospace;
            background-color: #1e1e2e;
            color: #cdd6f4;
            margin: 0;
            padding: 20px;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            color: #f38ba8;
            margin-bottom: 30px;
        }
        .section {
            margin-bottom: 30px;
            background: #313244;
            padding: 20px;
            border-radius: 10px;
            border-left: 4px solid #89b4fa;
        }
        .section h2 {
            color: #89b4fa;
            margin-top: 0;
            border-bottom: 2px solid #45475a;
            padding-bottom: 10px;
        }
        .shortcut-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 0;
            border-bottom: 1px solid #45475a;
        }
        .shortcut-row:last-child {
            border-bottom: none;
        }
        .shortcut {
            font-weight: bold;
            color: #f9e2af;
            font-family: 'JetBrains Mono', monospace;
            min-width: 200px;
        }
        .description {
            color: #a6e3a1;
            flex: 1;
            margin-left: 20px;
        }
        .key {
            background: #45475a;
            padding: 3px 8px;
            border-radius: 4px;
            margin: 0 2px;
            font-size: 0.9em;
        }
        .refresh-note {
            text-align: center;
            color: #fab387;
            font-style: italic;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔧 Hyprland Shortcuts Reference</h1>
        <div class="refresh-note">Live data from hyprctl - Updated: $(date)</div>
        <div id="shortcuts-content">
EOF

    # Parse hyprctl binds output and group by category
    declare -A system_binds
    declare -A app_binds
    declare -A media_binds
    declare -A navigation_binds
    declare -A other_binds
    
    while IFS= read -r line; do
        if [[ $line =~ ^bind ]]; then
            # Read the complete bind block
            bind_type=$(echo "$line" | awk '{print $1}')
            modmask=""
            key=""
            dispatcher=""
            arg=""
            
            # Read the following lines for this bind
            while IFS= read -r subline && [[ -n "$subline" ]]; do
                if [[ $subline =~ ^[[:space:]]*modmask:[[:space:]]*([0-9]+) ]]; then
                    modmask="${BASH_REMATCH[1]}"
                elif [[ $subline =~ ^[[:space:]]*key:[[:space:]]*(.+) ]]; then
                    key="${BASH_REMATCH[1]}"
                elif [[ $subline =~ ^[[:space:]]*dispatcher:[[:space:]]*(.+) ]]; then
                    dispatcher="${BASH_REMATCH[1]}"
                elif [[ $subline =~ ^[[:space:]]*arg:[[:space:]]*(.+) ]]; then
                    arg="${BASH_REMATCH[1]}"
                fi
            done
            
            if [[ -n "$modmask" && -n "$key" && -n "$dispatcher" ]]; then
                mod_readable=$(get_modmask "$modmask")
                if [[ -n "$mod_readable" ]]; then
                    shortcut="$mod_readable+$key"
                else
                    shortcut="$key"
                fi
                
                # Categorize the shortcut
                case "$dispatcher" in
                    "killactive"|"exit"|"fullscreen"|"togglefloating")
                        system_binds["$shortcut"]="$dispatcher $arg"
                        ;;
                    "movefocus")
                        navigation_binds["$shortcut"]="Move focus $arg"
                        ;;
                    "exec")
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
            fi
        fi
    done < <(hyprctl binds)
    
    # Generate HTML sections
    generate_section() {
        local title="$1"
        local icon="$2"
        declare -n binds_ref=$3
        
        if [[ ${#binds_ref[@]} -gt 0 ]]; then
            echo "        <div class=\"section\">"
            echo "            <h2>$icon $title</h2>"
            
            for shortcut in "${!binds_ref[@]}"; do
                local description="${binds_ref[$shortcut]}"
                # Format the shortcut keys
                local formatted_shortcut=$(echo "$shortcut" | sed 's/+/<\/span> + <span class="key">/g')
                formatted_shortcut="<span class=\"key\">$formatted_shortcut</span>"
                
                echo "            <div class=\"shortcut-row\">"
                echo "                <span class=\"shortcut\">$formatted_shortcut</span>"
                echo "                <span class=\"description\">$description</span>"
                echo "            </div>"
            done
            
            echo "        </div>"
        fi
    }
    
    generate_section "System Controls" "🖥️" system_binds >> "$html_file"
    generate_section "Navigation" "🧭" navigation_binds >> "$html_file"
    generate_section "Applications" "🚀" app_binds >> "$html_file"
    generate_section "Media Controls" "🎵" media_binds >> "$html_file"
    generate_section "Other" "⚙️" other_binds >> "$html_file"
    
    cat >> "$html_file" << 'EOF'
        </div>
    </div>
</body>
</html>
EOF
}

# Main execution
if [[ "$1" == "--generate" ]]; then
    create_shortcut_html
    echo "Shortcuts HTML generated at $HOME/.config/hypr/shortcuts.html"
elif [[ "$1" == "--show" ]]; then
    create_shortcut_html
    xdg-open "$HOME/.config/hypr/shortcuts.html"
else
    echo "Usage: $0 [--generate|--show]"
    echo "  --generate  Generate HTML file only"
    echo "  --show      Generate and open HTML file"
fi