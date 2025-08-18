# Theme install
```shell
yay -S bibata-cursor-theme
mkdir -p ~/.local/share/icons/
cp -r /usr/share/icons/Bibata-Modern-Amber ~/.local/share/icons/
hyprctl setcursor Bibata-Modern-Amber 24
```

# Why IntelliJ Overrides Cursor:
1. **Java AWT/Swing cursor handling** - Java apps manage their own cursors
2. **Wayland compatibility issues** - Java has historically poor Wayland support
3. **JetBrains runtime quirks** - IntelliJ uses its own JBR (JetBrains Runtime)
4. **X11 fallback behavior** - Many Java apps still run in XWayland mode

# Solutions (Step by Step)

## 1. Force IntelliJ to Use System Cursor
Add these JVM options to IntelliJ:

**Method A: Via `idea.vmoptions`**
```bash
# Edit your IntelliJ vmoptions file
# Location: ~/.config/JetBrains/IntelliJIdea{VERSION}/idea64.vmoptions

-Dawt.useSystemAAFontSettings=on
-Dsun.java2d.xrender=true
-Dsun.java2d.uiScale.enabled=false
-Dawt.toolkit.name=WLToolkit
```

**Method B: Environment Variables**
```bash
# In your shell profile or Hyprland config
export _JAVA_AWT_WM_NONREPARENTING=1
export JAVA_TOOL_OPTIONS="-Dawt.useSystemAAFontSettings=on -Dsun.java2d.xrender=true"
```
---
### 2. Hyprland-Specific Cursor Enforcement
```bash
# In hyprland.conf - force cursor for all windows
windowrulev2 = env HYPRCURSOR_THEME Bibata-Modern-Classic, class:^(jetbrains-.*)$
```

### 3. System-Wide Cursor Consistency
```bash
# Set cursor theme at multiple levels
export XCURSOR_THEME=your-theme-name
export XCURSOR_SIZE=24
env = HYPRCURSOR_THEME,your-theme-name
env = HYPRCURSOR_SIZE,24
```