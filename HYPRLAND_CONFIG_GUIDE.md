# Complete Hyprland Configuration Guide

This comprehensive guide covers all available configuration parameters in Hyprland. Based on the official Hyprland wiki and documentation.

## Table of Contents
1. [Variable Types](#variable-types)
2. [Monitor Configuration](#monitor-configuration)
3. [General Settings](#general-settings)
4. [Decoration](#decoration)
5. [Input](#input)
6. [Gestures](#gestures)
7. [Group](#group)
8. [Misc](#misc)
9. [Animations](#animations)
10. [Dwindle Layout](#dwindle-layout)
11. [Master Layout](#master-layout)
12. [Environment Variables](#environment-variables)
13. [Keybindings](#keybindings)
14. [Window Rules](#window-rules)
15. [Layer Rules](#layer-rules)

## Variable Types

Hyprland supports the following variable types:

- **int**: Integer values
- **bool**: Boolean values (true/false, yes/no, on/off, 0/1)
- **float**: Floating point numbers
- **color**: Color values (hex format: 0xRRGGBB or rgba format)
- **vec2**: Vector with 2 float values
- **MOD**: Modmask string (e.g., "SUPER", "SUPERSHIFT")
- **str**: String values
- **gradient**: Color gradient with optional angle
- **font_weight**: Integer between 100-1000 or preset values

## Monitor Configuration

```conf
# Basic monitor configuration
monitor = NAME, RESOLUTION, POSITION, SCALE

# Examples:
monitor = ,preferred,auto,auto                    # Auto-detect monitor
monitor = DP-1,1920x1080@60,0x0,1                # Specific monitor setup
monitor = eDP-1,2560x1440@165,1920x0,1.25        # High DPI monitor with scaling
monitor = HDMI-A-1,disable                       # Disable specific monitor
```

**Parameters:**
- **NAME**: Monitor name (use `hyprctl monitors` to list)
- **RESOLUTION**: Width x Height @ Refresh Rate
- **POSITION**: X offset x Y offset
- **SCALE**: Scaling factor

## General Settings

```conf
general {
    gaps_in = 5                    # Inner gaps between windows (int, default: 5)
    gaps_out = 20                  # Outer gaps between windows and screen edge (int, default: 20)
    border_size = 2                # Window border thickness in pixels (int, default: 2)
    
    # Border colors
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg    # Active window border (color/gradient)
    col.inactive_border = rgba(595959aa)                       # Inactive window border (color)
    col.nogroup_border = 0xffffaaff                           # Non-grouped window border (color)
    col.nogroup_border_active = 0xffff00ff                    # Active non-grouped window border (color)
    
    # Window behavior
    resize_on_border = false       # Enable window resizing by dragging borders (bool, default: false)
    extend_border_grab_area = 15   # Border grab area extension in pixels (int, default: 15)
    hover_icon_on_border = true    # Show resize cursor on borders (bool, default: true)
    
    # Layout settings
    layout = dwindle               # Window layout: dwindle, master (str, default: dwindle)
    
    # Tearing and performance
    allow_tearing = false          # Allow screen tearing for gaming (bool, default: false)
    no_border_on_floating = false  # Disable borders on floating windows (bool, default: false)
    no_focus_fallback = false      # Disable focus fallback (bool, default: false)
}
```

## Decoration

```conf
decoration {
    # Window rounding
    rounding = 10                  # Corner rounding radius in pixels (int, default: 10)
    
    # Opacity
    active_opacity = 1.0           # Opacity of active windows (float, 0.0-1.0, default: 1.0)
    inactive_opacity = 1.0         # Opacity of inactive windows (float, 0.0-1.0, default: 1.0)
    fullscreen_opacity = 1.0       # Opacity of fullscreen windows (float, 0.0-1.0, default: 1.0)
    
    # Shadows
    drop_shadow = true             # Enable drop shadows (bool, default: true)
    shadow_range = 4               # Shadow range in pixels (int, default: 4)
    shadow_render_power = 3        # Shadow render power (int, 1-4, default: 3)
    shadow_ignore_window = true    # Ignore window when rendering shadow (bool, default: true)
    shadow_offset = [0, 0]         # Shadow offset [x, y] (vec2, default: [0, 0])
    shadow_scale = 1.0            # Shadow scale (float, default: 1.0)
    col.shadow = rgba(1a1a1aee)   # Shadow color (color, default: rgba(1a1a1aee))
    col.shadow_inactive = rgba(1a1a1aee)  # Inactive shadow color (color)
    
    # Dimming
    dim_inactive = false           # Dim inactive windows (bool, default: false)
    dim_strength = 0.5            # Dimming strength (float, 0.0-1.0, default: 0.5)
    dim_special = 0.2             # Special workspace dimming (float, 0.0-1.0, default: 0.2)
    dim_around = 0.4              # Dimming around floating windows (float, 0.0-1.0, default: 0.4)
    
    # Screen shader
    screen_shader = ""            # Path to screen shader (str, default: "")
    
    # Blur settings
    blur {
        enabled = true            # Enable blur (bool, default: true)
        size = 8                  # Blur size/radius (int, default: 8)
        passes = 1                # Number of blur passes (int, default: 1)
        ignore_opacity = false    # Ignore window opacity for blur (bool, default: false)
        new_optimizations = true  # Enable new blur optimizations (bool, default: true)
        xray = false             # Enable X-ray mode (bool, default: false)
        noise = 0.0117           # Blur noise amount (float, default: 0.0117)
        contrast = 0.8916        # Blur contrast (float, default: 0.8916)
        brightness = 0.8172      # Blur brightness (float, default: 0.8172)
        vibrancy = 0.1696        # Blur vibrancy (float, default: 0.1696)
        vibrancy_darkness = 0.0  # Blur vibrancy darkness (float, default: 0.0)
        special = false          # Blur special workspaces (bool, default: false)
        popups = false           # Blur popups (bool, default: false)
        popups_ignorealpha = 0.2 # Alpha threshold for popup blur (float, default: 0.2)
    }
}
```

## Input

```conf
input {
    # Keyboard settings
    kb_model = ""                 # Keyboard model (str, default: "")
    kb_layout = us                # Keyboard layout (str, default: us)
    kb_variant = ""               # Keyboard variant (str, default: "")
    kb_options = ""               # Keyboard options (str, default: "")
    kb_rules = ""                 # Keyboard rules (str, default: "")
    kb_file = ""                  # Keyboard file path (str, default: "")
    
    numlock_by_default = false    # Enable numlock by default (bool, default: false)
    resolve_binds_by_sym = false  # Resolve keybinds by symbols (bool, default: false)
    repeat_rate = 25              # Key repeat rate (int, default: 25)
    repeat_delay = 600            # Key repeat delay in ms (int, default: 600)
    
    # Mouse settings
    sensitivity = 0.0             # Mouse sensitivity (-1.0 to 1.0, default: 0.0)
    accel_profile = ""            # Mouse acceleration profile (str, default: "")
    force_no_accel = false        # Force disable mouse acceleration (bool, default: false)
    left_handed = false           # Left-handed mouse mode (bool, default: false)
    scroll_method = ""            # Scroll method (str, default: "")
    scroll_button = 0             # Scroll button (int, default: 0)
    scroll_button_lock = false    # Lock scroll button (bool, default: false)
    scroll_points = ""            # Scroll points (str, default: "")
    natural_scroll = false        # Natural scrolling (bool, default: false)
    
    # Focus behavior
    follow_mouse = 1              # Mouse focus mode (int, 0-3, default: 1)
    mouse_refocus = true          # Refocus on mouse movement (bool, default: true)
    float_switch_override_focus = 1  # Override focus for floating windows (int, default: 1)
    special_fallthrough = false   # Special workspace fallthrough (bool, default: false)
    off_window_axis_events = 1    # Handle off-window axis events (int, default: 1)
    
    # Touchpad settings
    touchpad {
        disable_while_typing = true      # Disable touchpad while typing (bool, default: true)
        natural_scroll = false           # Natural scrolling (bool, default: false)
        scroll_factor = 1.0             # Scroll factor (float, default: 1.0)
        middle_button_emulation = false  # Middle button emulation (bool, default: false)
        tap_button_map = ""             # Tap button mapping (str, default: "")
        clickfinger_behavior = false    # Clickfinger behavior (bool, default: false)
        tap_to_click = true             # Tap to click (bool, default: true)
        drag_lock = false               # Drag lock (bool, default: false)
        tap_and_drag = false            # Tap and drag (bool, default: false)
    }
    
    # Tablet settings
    tablet {
        transform = 0               # Tablet transform (int, default: 0)
        output = ""                # Tablet output (str, default: "")
        region_position = [0, 0]   # Region position [x, y] (vec2, default: [0, 0])
        region_size = [0, 0]       # Region size [w, h] (vec2, default: [0, 0])
        relative_input = false     # Relative input mode (bool, default: false)
        left_handed = false        # Left-handed mode (bool, default: false)
        active_area_size = [0, 0]  # Active area size [w, h] (vec2, default: [0, 0])
        active_area_position = [0, 0]  # Active area position [x, y] (vec2, default: [0, 0])
    }
}
```

## Gestures

```conf
gestures {
    workspace_swipe = false           # Enable workspace swiping (bool, default: false)
    workspace_swipe_fingers = 3       # Fingers for workspace swipe (int, default: 3)
    workspace_swipe_distance = 300    # Swipe distance threshold (int, default: 300)
    workspace_swipe_invert = true     # Invert swipe direction (bool, default: true)
    workspace_swipe_min_speed_to_force = 30  # Minimum speed to force swipe (int, default: 30)
    workspace_swipe_cancel_ratio = 0.5        # Cancel ratio (float, default: 0.5)
    workspace_swipe_create_new = true         # Create new workspace on swipe (bool, default: true)
    workspace_swipe_direction_lock = true     # Lock swipe direction (bool, default: true)
    workspace_swipe_direction_lock_threshold = 10  # Direction lock threshold (int, default: 10)
    workspace_swipe_forever = false          # Enable infinite workspace swipe (bool, default: false)
    workspace_swipe_numbered = false         # Number workspace swipes (bool, default: false)
    workspace_swipe_use_r = false           # Use r for workspace swipe (bool, default: false)
}
```

## Group

```conf
group {
    insert_after_current = true      # Insert windows after current (bool, default: true)
    focus_removed_window = true      # Focus window when removed from group (bool, default: true)
    
    col.border_active = rgba(33ccffaa)     # Active group border color (color)
    col.border_inactive = rgba(595959aa)   # Inactive group border color (color)
    col.border_locked_active = rgba(33ccffaa)    # Locked active group border (color)
    col.border_locked_inactive = rgba(595959aa)  # Locked inactive group border (color)
    
    groupbar {
        enabled = true              # Enable group bar (bool, default: true)
        font_family = Sans          # Group bar font family (str, default: Sans)
        font_size = 8              # Group bar font size (int, default: 8)
        gradients = true           # Enable gradients in group bar (bool, default: true)
        height = 14               # Group bar height (int, default: 14)
        priority = 3              # Group bar priority (int, default: 3)
        render_titles = true      # Render titles in group bar (bool, default: true)
        scrolling = true          # Enable scrolling in group bar (bool, default: true)
        text_color = rgba(ffffffff)  # Group bar text color (color, default: rgba(ffffffff))
        
        col.active = rgba(33ccffaa)     # Active group bar color (color)
        col.inactive = rgba(595959aa)   # Inactive group bar color (color)
        col.locked_active = rgba(33ccffaa)    # Locked active group bar color (color)
        col.locked_inactive = rgba(595959aa)  # Locked inactive group bar color (color)
    }
}
```

## Misc

```conf
misc {
    disable_hyprland_logo = false       # Disable Hyprland logo (bool, default: false)
    disable_splash_rendering = false    # Disable splash screen (bool, default: false)
    col.splash = rgba(ffffffff)        # Splash screen color (color, default: rgba(ffffffff))
    splash_font_family = Sans          # Splash font family (str, default: Sans)
    
    force_default_wallpaper = -1       # Force default wallpaper (-1, 0, 1, 2, default: -1)
    vfr = true                         # Variable refresh rate (bool, default: true)
    vrr = 0                           # Variable refresh rate mode (int, 0-2, default: 0)
    
    mouse_move_enables_dpms = false    # Mouse movement enables DPMS (bool, default: false)
    key_press_enables_dpms = false     # Key press enables DPMS (bool, default: false)
    always_follow_on_dnd = true        # Always follow during drag and drop (bool, default: true)
    layers_hog_keyboard_focus = true   # Layers hog keyboard focus (bool, default: true)
    
    animate_manual_resizes = false     # Animate manual window resizes (bool, default: false)
    animate_mouse_windowdragging = false  # Animate mouse window dragging (bool, default: false)
    disable_autoreload = false         # Disable auto config reload (bool, default: false)
    
    enable_swallow = false             # Enable window swallowing (bool, default: false)
    swallow_regex = ""                # Swallow regex pattern (str, default: "")
    swallow_exception_regex = ""       # Swallow exception regex (str, default: "")
    
    focus_on_activate = false          # Focus window on activation (bool, default: false)
    no_direct_scanout = true          # Disable direct scanout (bool, default: true)
    hide_cursor_on_touch = true       # Hide cursor on touch (bool, default: true)
    mouse_move_focuses_monitor = true  # Mouse movement focuses monitor (bool, default: true)
    
    render_ahead_of_time = false      # Render ahead of time (bool, default: false)
    render_ahead_safezone = 1         # Render ahead safe zone (int, default: 1)
    
    cursor_zoom_factor = 1.0          # Cursor zoom factor (float, default: 1.0)
    cursor_zoom_rigid = false         # Rigid cursor zooming (bool, default: false)
    
    allow_session_lock_restore = false  # Allow session lock restore (bool, default: false)
    
    background_color = rgba(111111b4)   # Background color (color, default: rgba(111111b4))
    
    close_special_on_empty = true      # Close special workspace when empty (bool, default: true)
    new_window_takes_over_fullscreen = 0  # New window behavior in fullscreen (int, 0-2, default: 0)
    
    exit_window_retains_fullscreen = false  # Retain fullscreen on window exit (bool, default: false)
    initial_workspace_tracking = 1     # Initial workspace tracking (int, default: 1)
    middle_click_paste = true          # Middle click paste (bool, default: true)
}
```

## Animations

```conf
animations {
    enabled = true                # Enable animations (bool, default: true)
    first_launch_animation = true # First launch animation (bool, default: true)
    
    # Animation syntax: animation = NAME, ONOFF, SPEED, CURVE [,STYLE]
    
    # Available animation names:
    animation = global, 1, 10, default        # Global animation settings
    animation = windows, 1, 7, myBezier      # Window animations
    animation = windowsIn, 1, 7, myBezier    # Window fade in
    animation = windowsOut, 1, 7, myBezier   # Window fade out
    animation = windowsMove, 1, 7, myBezier  # Window movement
    animation = border, 1, 10, default       # Border animations
    animation = borderangle, 1, 8, default   # Border angle animations
    animation = fade, 1, 7, default          # Fade animations
    animation = fadeIn, 1, 7, default        # Fade in animations
    animation = fadeOut, 1, 7, default       # Fade out animations
    animation = fadeSwitch, 1, 7, default    # Fade switch animations
    animation = fadeShadow, 1, 7, default    # Shadow fade animations
    animation = fadeDim, 1, 7, default       # Dim fade animations
    animation = workspaces, 1, 6, default    # Workspace animations
    animation = specialWorkspace, 1, 6, default  # Special workspace animations
    
    # Bezier curves (custom curves)
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = linear, 0.0, 0.0, 1.0, 1.0
    bezier = easeInOutQuint, 0.83, 0, 0.17, 1
    bezier = easeOutExpo, 0.16, 1, 0.3, 1
    bezier = easeInExpo, 0.7, 0, 0.84, 0
    bezier = easeInOutCubic, 0.65, 0, 0.35, 1
    
    # Pre-defined curves:
    # default, linear, easeInQuint, easeInOutQuint, easeOutQuint
    # easeInQuart, easeInOutQuart, easeOutQuart
    # easeInCubic, easeInOutCubic, easeOutCubic
    # easeInSine, easeInOutSine, easeOutSine
    # easeInCirc, easeInOutCirc, easeOutCirc
    # easeInBack, easeInOutBack, easeOutBack
    # easeInElastic, easeInOutElastic, easeOutElastic
    # easeInBounce, easeInOutBounce, easeOutBounce
}
```

## Dwindle Layout

```conf
dwindle {
    pseudotile = false                # Enable pseudotiling (bool, default: false)
    force_split = 0                   # Force split direction (int, 0-2, default: 0)
    preserve_split = false            # Preserve split state (bool, default: false)
    smart_split = false               # Smart split based on cursor (bool, default: false)
    smart_resizing = true             # Smart resizing based on cursor (bool, default: true)
    permanent_direction_override = false  # Permanent direction override (bool, default: false)
    special_scale_factor = 1          # Special workspace scale (float, default: 1)
    split_width_multiplier = 1.0      # Split width multiplier (float, default: 1.0)
    use_active_for_splits = true      # Use active window for splits (bool, default: true)
    default_split_ratio = 1.0         # Default split ratio (float, default: 1.0)
    split_bias = 0                    # Split bias (int, default: 0)
    no_gaps_when_only = false         # No gaps with single window (bool, default: false)
}
```

## Master Layout

```conf
master {
    allow_small_split = false         # Allow small split style (bool, default: false)
    special_scale_factor = 1          # Special workspace scale (float, 0.0-1.0, default: 1)
    mfact = 0.55                     # Master window size ratio (float, 0.0-1.0, default: 0.55)
    new_status = slave               # New window placement (str: master/slave/inherit, default: slave)
    new_on_top = false               # New window on top of stack (bool, default: false)
    new_on_active = none             # New window relative to active (str: before/after/none, default: none)
    orientation = left               # Master area placement (str: left/right/top/bottom/center, default: left)
    inherit_fullscreen = true        # Inherit fullscreen status (bool, default: true)
    always_center_master = false     # Always center master window (bool, default: false)
    smart_resizing = true           # Smart resizing behavior (bool, default: true)
    drop_at_cursor = false          # Drop window at cursor (bool, default: false)
    no_gaps_when_only = false       # No gaps with single window (bool, default: false)
}
```

## Environment Variables

```conf
# Cursor settings
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

# Wayland specific
env = GDK_BACKEND,wayland,x11,*
env = QT_QPA_PLATFORM,wayland;xcb
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland

# XDG settings
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# Qt settings
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1

# Nvidia specific (if using Nvidia)
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
```

## Keybindings

```conf
# Modifier keys: SUPER, ALT, CTRL, SHIFT
$mainMod = SUPER

# Basic binds
bind = $mainMod, Q, exec, $terminal
bind = $mainMod, C, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, $menu
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
# ... (repeat for 3-9, 0)

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
# ... (repeat for 3-9, 0)

# Special workspace (scratchpad)
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Scroll through existing workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Additional useful binds
bind = $mainMod, F, fullscreen,
bind = $mainMod SHIFT, F, fullscreen, 1
bind = $mainMod, T, togglegroup,
bind = $mainMod, Tab, changegroupactive,

# Resize mode
bind = $mainMod, R, submap, resize
submap = resize
binde = , right, resizeactive, 10 0
binde = , left, resizeactive, -10 0
binde = , up, resizeactive, 0 -10
binde = , down, resizeactive, 0 10
bind = , escape, submap, reset
submap = reset
```

## Window Rules

```conf
# Window rule syntax: windowrule = RULE, WINDOW
# Window rule v2 syntax: windowrulev2 = RULE, WINDOW

# Basic window rules
windowrule = float, ^(kitty)$
windowrule = size 800 600, ^(kitty)$
windowrule = center, ^(kitty)$

# Window rules v2 (more advanced)
windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
windowrulev2 = size 800 600,class:^(kitty)$
windowrulev2 = opacity 0.8 0.8,class:^(Code)$
windowrulev2 = workspace 2,class:^(firefox)$
windowrulev2 = nomaximizerequest,class:.*

# Available rules:
# monitor, size, minsize, maxsize, position, move, workspace
# float, tile, fullscreen, maximize, pin, unset
# bordersize, rounding, opacity, opaque, forcergbx
# animation, animationstyle, shadowignore, focusonactivate
# windowdance, noborder, noblur, noshadow, nodim, noanim
# keepaspectratio, bordercolor, idleinhibit, dimaround
# xray, immediate, nearestneighbor, nomaxsize
```

## Layer Rules

```conf
# Layer rule syntax: layerrule = RULE, NAMESPACE

# Examples
layerrule = blur, rofi
layerrule = ignorezero, rofi
layerrule = dimaround, rofi

# Available rules:
# unset, top, bottom, overlay, background
# blur, ignorealpha, ignorezero, dimaround
# noanim, xray
```

## Program Variables

```conf
# Define commonly used programs
$terminal = kitty
$fileManager = dolphin
$menu = wofi --show drun
$browser = firefox
$editor = code
$launcher = rofi -show drun
```

## Workspace Rules

```conf
# Workspace rule syntax: workspace = WORKSPACE, RULES

# Examples
workspace = 1, monitor:DP-1, default:true
workspace = 2, monitor:HDMI-A-1
workspace = special:magic, on-created-empty:kitty
workspace = 10, persistent:true, gapsin:50, gapsout:100
```

## Plugin Configuration

```conf
# Plugin loading
plugin = /path/to/plugin.so

# Plugin-specific settings would go in their respective sections
# Example for hyprwinwrap plugin:
plugin {
    hyprwinwrap {
        # plugin-specific settings here
    }
}
```

## Debug Options

```conf
debug {
    overlay = false               # Enable debug overlay (bool, default: false)
    damage_blink = false         # Blink damaged areas (bool, default: false)
    disable_logs = false         # Disable logging (bool, default: false)
    disable_time = true          # Disable time in logs (bool, default: true)
    damage_tracking = 2          # Damage tracking mode (int, 0-2, default: 2)
    enable_stdout_logs = false   # Enable stdout logs (bool, default: false)
    manual_crash = 0            # Manual crash trigger (int, default: 0)
    suppress_errors = false      # Suppress error messages (bool, default: false)
    watchdog_timeout = 5        # Watchdog timeout in seconds (int, default: 5)
    disable_scale_checks = false # Disable scale checks (bool, default: false)
}
```

This guide covers all major configuration parameters available in Hyprland. For the most up-to-date information, always refer to the official Hyprland wiki at https://wiki.hypr.land/