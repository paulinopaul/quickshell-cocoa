# Technical Design: Comprehensive Settings Expansion & Dynamic Wallpaper Binding

## Architecture Overview

```
                      +---------------------------------------+
                      |       SettingsWindow.qml (Overlay)   |
                      +---------------------------------------+
                        |         |          |          |
      +-----------------+         |          |          +-----------------+
      v                           v          v                            v
[ThemeSettingsView]     [AudioSettings]  [DisplaySettings]        [DefaultAppsView]
      |                           |          |                            |
      v                           v          v                            v
theme_manager.py          audio_manager.py  display_manager.py    default_apps_manager.py
      |                           |          |                            |
      +-> wallpaper_themes.json   +-> wpctl  +-> hyprctl monitor          +-> xdg-mime
      +-> active_palette.json                 +-> hyprland.conf           +-> hyprland.conf
      +-> hyprctl col.active_border
```

## Subsystem Details

### 1. Dynamic Wallpaper-Theme Binding
- **Storage**: `theme/wallpaper_themes.json` mapping wallpaper filenames (or paths) to named theme IDs or custom hex palettes.
- **Palette Registry**:
  - `NeoNord`: `#88c0d0` (Nord Frost)
  - `Catppuccin Mocha`: `#cba6f7` (Pastel Mauve)
  - `Tokyo Night`: `#7aa2f7` (Neon Blue)
  - `Gruvbox Retro`: `#d79921` (Warm Gold)
  - `Rose Pine`: `#eb6f92` (Pine Rose)
  - `Cyberpunk Neon`: `#00f0ff` (Electric Cyan)
  - `Emerald Forest`: `#10b981` (Vibrant Green)
  - `Sunset Glow`: `#f59e0b` (Twilight Orange)
  - `Cocoa Classic`: `#e0a370` (Warm Amber)
- **Lifecycle**:
  - Setting a wallpaper triggers `scripts/set_wallpaper.sh`.
  - The script calls `theme_manager.py apply-for-wallpaper "$WALL"`.
  - If a binding exists in `wallpaper_themes.json`, that palette is applied immediately.
  - If no binding exists, `theme_manager.py` falls back to color extraction from the image.
  - System borders in Hyprland are refreshed live via `hyprctl keyword general:col.active_border`.

### 2. Audio Engine (`audio_manager.py`)
- Executes `wpctl status` to parse active Sinks and Sources.
- Parses lines under `Audio -> Sinks` and `Audio -> Sources`.
- Default device detected via `*` prefix.
- Changes defaults using `wpctl set-default <ID>`.
- Controls volume via `wpctl set-volume <ID> <VAL>%` and mute toggles via `wpctl set-mute <ID> toggle`.

### 3. Display Engine (`display_manager.py`)
- Executes `hyprctl monitors -j` for accurate monitor identifiers, available modes, active refresh rates, and scales.
- Applies changes immediately via `hyprctl keyword monitor "<NAME>,<RES>@<HZ>,auto,<SCALE>"`.
- Persists monitor lines into `~/.config/hypr/hyprland.conf`.

### 4. Default Applications Engine (`default_apps_manager.py`)
- Terminal: reads and mutates `$terminal = <cmd>` in `~/.config/hypr/hyprland.conf`.
- Browser: reads and sets `xdg-mime default <desktop> x-scheme-handler/http x-scheme-handler/https`.
- File Manager: reads and sets `xdg-mime default <desktop> inode/directory`.
- Editor: reads and sets `xdg-mime default <desktop> text/plain`.

### 5. Keybindings Engine (`keybinds_manager.py`)
- Queries `hyprctl binds -j`.
- Decodes bitwise modmasks: 1=SHIFT, 4=CTRL, 8=ALT, 64=SUPER.
- Annotates binds with user-friendly descriptions and categories (Window Management, Workspaces, Launchers, Audio/Media, Navigation).
