# Specifications: Extended Settings Dialog & Theming

## Requirements

### REQ-1: Wallpaper-Theme Binding
- The system MUST allow assigning a named preset (e.g. `NeoNord`) or custom palette to any wallpaper.
- When `set_wallpaper.sh` is invoked, the theme manager MUST inspect `theme/wallpaper_themes.json`. If a mapping exists for the wallpaper path or basename, it MUST apply that palette. If not, it MUST extract vibrant dominant colors from the image.
- Hyprland's `col.active_border` MUST sync to the applied primary accent.

### REQ-2: PipeWire Audio Control
- The UI MUST list available audio output devices (sinks) and input devices (sources).
- The user MUST be able to switch the default sink and source with immediate effect.
- The user MUST be able to adjust volume and toggle mute for individual devices.

### REQ-3: Display Monitor Configuration
- The UI MUST display connected monitors with current resolution, refresh rate, and scale factor.
- Applying a display configuration MUST execute `hyprctl keyword monitor` and update `~/.config/hypr/hyprland.conf`.

### REQ-4: Default Applications Configuration
- The UI MUST display and permit changing the default Terminal, Web Browser, File Manager, and Code Editor.
- Terminal changes MUST update `$terminal` in `hyprland.conf`.
- Other applications MUST update `xdg-mime` associations.

### REQ-5: Keybindings Viewer
- The UI MUST display active Hyprland keybindings grouped by category.
- A search input MUST filter shortcuts live by key combo, dispatcher, or description.
