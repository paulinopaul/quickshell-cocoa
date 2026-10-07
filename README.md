<div align="center">

# 🍫 Cocoa Desktop Shell

**A modular, reactive, and ultra-lightweight desktop shell for Hyprland built on Quickshell (Qt6/QML).**

[![Compositor: Hyprland](https://img.shields.io/badge/Compositor-Hyprland_%3E%3D_0.40.0-00ADD8?style=flat-square&logo=hyprland&logoColor=white)](https://hyprland.org)
[![Framework: Quickshell](https://img.shields.io/badge/Framework-Quickshell_%3E%3D_0.3.1-41CD52?style=flat-square&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me)
[![Wayland Layer: zwlr_layer_shell_v1](https://img.shields.io/badge/Wayland-Layer_Shell_v1-E95420?style=flat-square&logo=wayland&logoColor=white)](https://wayland.freedesktop.org)
[![Tests: 206 Passing](https://img.shields.io/badge/Tests-206_Passing-brightgreen?style=flat-square&logo=python&logoColor=white)](tests/)
[![Architecture: Clean & Modular](https://img.shields.io/badge/Architecture-SOLID_%2F_Reactive-blueviolet?style=flat-square)](#architecture)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)

<p align="center">
  <a href="#-showcase">Showcase</a> •
  <a href="#-key-features">Key Features</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-dependencies">Dependencies</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-updating-an-existing-install">Updating</a> •
  <a href="#-configuring-keybinds">Keybinds</a> •
  <a href="#-test-suite">Tests</a> •
  <a href="#-project-structure">Structure</a>
</p>

</div>

---

## 📸 Showcase

> [!TIP]
> **Place your screenshot files in [`assets/screenshots/`](assets/screenshots/):**
> Save your images as `overview.png`, `center_capsule.png`, `launcher.png`, and `notifications.png` to automatically display them below.

| Desktop Overview | Dynamic Center Capsule |
| :---: | :---: |
| ![Desktop Overview](assets/screenshots/overview.png)<br><sub>*Top bar with split islands and clean aesthetic*</sub> | ![Center Capsule](assets/screenshots/center_capsule.png)<br><sub>*Interactive scroll-switchable MPRIS & telemetry capsule*</sub> |
| **Application Launcher** | **Smart Notifications** |
| ![Application Launcher](assets/screenshots/launcher.png)<br><sub>*Bottom-docked launcher with Jump & Dive kinematics*</sub> | ![Smart Notifications](assets/screenshots/notifications.png)<br><sub>*Dynamic Spotify 3-color gradient & AI agent badges*</sub> |

---

## ✨ Key Features

### 1. Three-Island Modular Top Bar
* **Left Island (`modules/bar/LeftPanel.qml`)**: Dynamic Hyprland workspaces synced with compositor state and active window class title.
* **Dynamic Center Capsule (`modules/bar/CenterCapsule.qml`)**: Interactive pill widget supporting mouse-wheel scrolling (`WheelHandler`) to cycle between:
  * **Mode A (Media)**: MPRIS player controls, track metadata, album art, and progress bar.
  * **Mode B (Telemetry)**: Real-time hardware vitals (CPU load %, RAM usage, system temperature).
  * **Mode C (Window Details)**: Detailed active window class and sanitized process information.
* **Right Island & In-Bar HUD (`modules/bar/RightPanel.qml`)**:
  * **Dynamic HUD Mode**: Adjusting volume or screen brightness temporarily transforms the right panel via a liquid cross-fade into a minimal level indicator (`Meter.qml`), automatically reverting after 1.8 seconds with zero background polling overhead.
  * **System Monitors**: Real-time battery with laptop autodetection (`isLaptopBattery`), PipeWire microphone toggle, network status, and power session menu.

### 2. Application Launcher with Physics Kinematics (`modules/launcher/LauncherWindow.qml`)
* **Layer Shell Architecture**: `WlrLayer.Overlay` anchored at bottom-center.
* **"Jump & Dive" Physics**:
  * **Entrance**: Smooth vertical launch from bottom with elastic bounce (`Easing.OutBack`, overshoot 1.35 in 260ms).
  * **Anticipation & Exit**: Upward preparatory hop (+16px in 75ms) followed by an accelerated dive (`Easing.InCubic` in 190ms).
* **Deferred Wayland Unmapping**: Wayland surface active state (`surfaceActive`) decouples from animation state (`isOpen`), immediately releasing keyboard focus on exit and unmapping the Wayland surface only when the animation completes—ensuring zero mouse blocking when closed.

### 3. Intelligent Notification System (`modules/notifications/NotificationPopup.qml`)
* **Solid Non-Intrusive Floating Cards**: Opaque surface positioned below the top bar, eliminating intrusive translucent artifacts.
* **AI Agent & Terminal Glyph Classification**: Deterministic classification for AI coding agents and CLI utilities:
  * **Gemini / Antigravity**: Monospaced `▲` (`#8a63d2`)
  * **Claude**: `✻` (`#d97757`)
  * **ChatGPT / OpenAI**: `✳` (`#10a37f`)
  * **Cursor**: `❯_` (`#00b4d8`)
  * **Aider**: `⯌` (`#3b82f6`)
  * **Generic Terminal**: `>_` (`#22c55e`)
* **Spotify Dynamic 3-Color Palette Extraction**:
  * Asynchronously downloads and quantizes active album art (`mpris:artUrl`) via K-Means (`PIL.Image.quantize(colors=3)`), rendering a 3-stop dynamic horizontal gradient in zero render-thread blocking time.
  * Local filesystem caching (per-user IPC dir `<ipc-dir>/cocoa_palette_cache/<md5>.json`) delivers sub-millisecond lookups for repeated tracks.
* **Reactive Suppression**: Automatically suppresses and auto-dismisses popups when the center capsule flyout is detached.

### 4. Zero-Overhead Performance & Kernel Direct Reads
* **Direct SysFS Polling**: `BrightnessService.qml` reads kernel backlight directly from `/sys/class/backlight/*/actual_brightness` via `FileView` at 100ms intervals, eliminating recurring `brightnessctl` shell forks.
* **Direct Process Dispatch**: Binary calls (`wpctl`, `brightnessctl`) invoke executables directly without intermediate bash wrappers.
* **Embedded Vector Icons (`components/Icon.qml`)**: Self-contained SVG paths for network states (`network-wireless`, `network-wired`, `network-offline`), rendering reliably on bare Wayland without requiring external GTK/Qt icon bridges (`qt6ct`).

### 5. Standalone Settings Dialog (`modules/settings/SettingsWindow.qml`)
* **Elevated Overlay Architecture**: `WlrLayer.Overlay` centered without screen edge anchors, accessible via `Super + I` or the top bar gear icon.
* **Decoupled Kinetic Lifecycle**: Elastic entrance bounce (`Easing.OutBack`) and smooth exit fade (`Easing.InQuad`), freeing Wayland keyboard focus instantaneously on dismissal.
* **Wallpaper & Theme Engine (`ThemeSettingsView.qml`, `scripts/theme_manager.py`)**:
  * **9 Curated Global Palettes**: NeoNord (`#88c0d0`), Catppuccin Mocha (`#cba6f7`), Tokyo Night (`#7aa2f7`), Gruvbox Retro (`#d79921`), Rose Pine (`#eb6f92`), Cyberpunk Neon (`#00f0ff`), Emerald Forest (`#10b981`), Sunset Glow (`#f59e0b`), Cocoa Classic (`#e0a370`).
  * **Wallpaper-to-Theme Binding**: Directly link any named palette or custom color to the current wallpaper. Mappings are persisted in `theme/wallpaper_themes.json`.
  * **Contextual Automatic Switching**: When wallpapers change (`scripts/set_wallpaper.sh`), `theme_manager.py apply-for-wallpaper` detects assigned themes and applies them instantly, or automatically extracts vibrant colors via K-Means if unmapped.
  * **Live Hyprland Border Sync**: Automatically sets `general:col.active_border` via `hyprctl`.
* **Integrated Network Center (`NetworkSettingsView.qml`)**:
  * Real-time network telemetry (Wi-Fi SSID, Ethernet LAN, Disconnected).
  * Asynchronous Wi-Fi scanning with spinning activity indicators.
  * Expandable access point list with signal meters, lock glyphs, inline password field, and clean disconnection flow.
* **PipeWire Audio Control (`AudioSettingsView.qml`, `scripts/audio_manager.py`)**:
  * Real-time enumeration of audio output devices (Sinks) and input devices (Sources) via `wpctl status`.
  * One-click default device switching (`wpctl set-default <id>`).
  * Per-device volume level sliders and instant mute toggles.
* **Display & Monitor Configuration (`DisplaySettingsView.qml`, `scripts/display_manager.py`)**:
  * Real-time monitor telemetry from `hyprctl monitors -j`.
  * Resolution, refresh rate (Hz), and Wayland fractional scaling controls.
  * Immediate live application via `hyprctl keyword monitor` and persistent writing to `~/.config/hypr/hyprland.conf`.
* **Default Applications Center (`DefaultAppsView.qml`, `scripts/default_apps_manager.py`)**:
  * Configuration of default Terminal (`$terminal` in `hyprland.conf`), Web Browser, File Manager, and Code Editor via `xdg-mime default`.
  * Detection chips for installed common apps.
* **Keybindings Reference (`KeybindsView.qml`, `scripts/keybinds_manager.py`)**:
  * Active Hyprland bindings parsed live from `hyprctl binds -j`.
  * Bitwise modmask decoding (`SUPER`, `SHIFT`, `CTRL`, `ALT`) with categorized human-readable action summaries.
  * Real-time fuzzy search filter by key combination, category, or dispatcher.

---

## 🏗️ Architecture

```
                    +------------------------------------+
                    |        Wayland Compositor          |
                    |            (Hyprland)              |
                    +-----------------+------------------+
                                      |
                       zwlr_layer_shell_v1 / IPC Sockets
                                      v
+-------------------------------------------------------------------------+
|                               COCOA CORE                                |
|                                                                         |
|  +-------------------------------------------------------------------+  |
|  |                  Reactive Services Layer                          |  |
|  |  [Hyprland]     [Media/MPRIS]     [Audio/Pipewire]    [System]    |  |
|  +--------+--------------+------------------+---------------+--------+  |
|           |              |                  |               |           |
|           v              v                  v               v           |
|  +-------------------------------------------------------------------+  |
|  |                   Presentation Layer (Panels)                     |  |
|  |  +------------------+ +-------------------+ +------------------+  |  |
|  |  |   Left Island    | |  Dynamic Capsule  | |   Right Island   |  |  |
|  |  | (Workspaces/App) | | (Media/Telemetry) | | (HUD/Batt/Mic/Vol) |  |
|  |  +------------------+ +-------------------+ +------------------+  |  |
|  |  ---------------------------------------------------------------  |  |
|  |  +-------------------------------------------------------------+  |  |
|  |  |           Modal Launcher (Overlay / On Demand)              |  |  |
|  |  +-------------------------------------------------------------+  |  |
|  |  +-------------------------------------------------------------+  |  |
|  |  |           Smart Notification Card (Below Top Bar)           |  |  |
|  |  +-------------------------------------------------------------+  |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 📦 Dependencies

Ensure the following packages are installed on your system:

| Component | Required Package | Description |
| :--- | :--- | :--- |
| **Shell Engine** | `quickshell` (>= 0.3.1) | Wayland desktop shell library for Qt6/QML |
| **Compositor** | `hyprland` (>= 0.40.0) | Dynamic tiling Wayland compositor |
| **Audio** | `pipewire`, `wireplumber` | Audio server and session manager |
| **Hardware / Power** | `upower`, `brightnessctl` | Battery status & display backlight control |
| **Media Extraction** | `python` (>= 3.10), `python-pillow` | Asynchronous palette quantization for MPRIS covers |

### Installing runtime dependencies (Arch Linux)

Cocoa shells out to these tools at runtime. Install them in one go:

```bash
sudo pacman -S quickshell hyprland hyprpaper hyprlock ghostty grim slurp wl-clipboard flameshot brightnessctl wireplumber pipewire networkmanager upower python python-pillow xdg-utils jq playerctl papirus-icon-theme dolphin
```

| Tool | Arch package | Invoked by |
| :--- | :--- | :--- |
| `quickshell` | `quickshell` | The shell itself (`quickshell -p ~/.config/quickshell/cocoa`) |
| `hyprctl` | `hyprland` | Keybinds, display, and theme/border sync (`scripts/keybinds_manager.py`, `scripts/display_manager.py`, `scripts/theme_manager.py`) |
| `hyprpaper` | `hyprpaper` | Wallpaper backend (`scripts/set_wallpaper.sh`, `start_shell.sh`) |
| `hyprlock` | `hyprlock` | Lock screen (media-key binds, bar power menu) |
| `ghostty` | `ghostty` | Default `$terminal` (`hyprland.conf`, `scripts/ghostty_sync.py`) |
| `grim` + `slurp` piped to `wl-copy` | `grim`, `slurp`, `wl-clipboard` | Screenshot binds (`SUPER SHIFT + S`, `SUPER + F6`, `Print` via flameshot below) |
| `flameshot` | `flameshot` | `Print` key bind (`flameshot gui`) |
| `brightnessctl` | `brightnessctl` | Brightness keys (`services/BrightnessService.qml`) |
| `wpctl` | `wireplumber` (+ `pipewire`) | Volume/mute keys, audio settings (`services/VolumeService.qml`, `scripts/audio_manager.py`, `scripts/cocoa_daemon.sh`) |
| `nmcli` | `networkmanager` | Wi-Fi scan/connect and telemetry (`scripts/wifi_manager.py`, `scripts/cocoa_daemon.sh`) |
| `python3` + Pillow | `python`, `python-pillow` | Palette extraction and all `scripts/*.py` managers |
| `jq` | `jq` | JSON queries over `hyprctl -j` output in shell scripts |
| `playerctl` | `playerctl` | Media metadata fallback for the center capsule |
| Papirus icons | `papirus-icon-theme` | Terminal/app icon paths (`services/HyprlandService.qml`) |
| `dolphin` | `dolphin` | Default file manager (`SUPER + E` in `hyprland.conf`) |
| `xdg-mime` | `xdg-utils` | Default apps center (`scripts/default_apps_manager.py`) |

---

## 🚀 Quick Start

### 1. Installation

Clone this repository directly into your user configuration directory:

```bash
git clone https://github.com/paulinopaul/quickshell-cocoa.git ~/.config/quickshell/cocoa
```

### 2. Hyprland Integration

Add the following lines to your `~/.config/hypr/hyprland.conf`:

```ini
# Auto-start Cocoa Desktop Shell (via the Hyprland boot helper, which also
# ensures hyprpaper is running with a valid hyprpaper.conf)
exec-once = ~/.config/hypr/scripts/start_shell.sh
```

`start_shell.sh` launches the shell detached as
`setsid -f quickshell -p ~/.config/quickshell/cocoa` (plus `hyprpaper -c
~/.config/hypr/hyprpaper.conf`), and `hyprland.conf` also carries the fast
telemetry daemon:

```ini
# Optional background daemon for fast polling and telemetry
exec-once = ~/.config/quickshell/cocoa/scripts/cocoa_daemon.sh
```

### 2b. Global shortcuts

These four Cocoa shortcuts live in `hyprland.conf` (global dispatch):

| Shortcut | Action |
| :--- | :--- |
| `SUPER + R` | Application launcher (`quickshell:launcher`) |
| `SUPER + Space` | Wallpaper selector (`quickshell:wallpaper_selector`) |
| `SUPER + P` | Detachable center panel (`quickshell:center_panel`) |
| `SUPER + I` | Settings dialog (`quickshell:settings_dialog`) |

### 3. Running Manually

To run Cocoa in the foreground with verbose logging for development:

```bash
quickshell -p ~/.config/quickshell/cocoa -v
```

---

## 🔄 Updating an Existing Install

Already have Cocoa installed? Three steps:

```bash
cd ~/.config/quickshell/cocoa && git pull
quickshell kill
setsid -f quickshell -p ~/.config/quickshell/cocoa
```

(Alternatively, restart via `~/.config/hypr/scripts/start_shell.sh`, which also ensures `hyprpaper` is running.)

### What hot-reloads vs what needs a restart

| Change | Effect |
| :--- | :--- |
| Theme JSON (`theme/current_theme.json`, `theme/ui_config.json`, `theme/wallpaper_themes.json`) | Applies live — no restart needed |
| Any `.qml` file | Requires a shell restart (`quickshell kill` + relaunch) |

---

## ⌨️ Configuring Keybinds

### Quick path

1. Press `SUPER + I` to open Cocoa settings.
2. Go to the "Atajos de Teclado" tab — the live binding list is parsed from `hyprctl binds -j` and supports fuzzy search by key, category, or dispatcher.
3. Use the add/remove form to create (`mods + key + dispatcher + arg`) or delete a binding. Changes apply live via `hyprctl bind` / `hyprctl unbind` and persist to `hyprland.conf`.

### Details

| Topic | Behavior |
| :--- | :--- |
| Managed section | Cocoa writes only inside `# --- Keybindings gestionados por Cocoa ---` in `~/.config/hypr/hyprland.conf` (created after the last `bind` line if absent). |
| Your own binds | Anything outside the managed section is never touched — unmanaged binds are preserved. |
| File location | `~/.config/hypr/hyprland.conf`; backend is `scripts/keybinds_manager.py` (fail-soft: `hyprctl` errors surface as JSON, never crash the shell). |

---

## 🧪 Test Suite

Cocoa features a comprehensive test suite covering contracts, classifiers, and data parsers:

```bash
# Run all unit and contract tests (206 tests)
python3 -m unittest discover -s ~/.config/quickshell/cocoa/tests -p "test_*.py" -v
```

All tests execute in approximately ~100ms with zero GUI dependencies.

---

## 📂 Project Structure

```
~/.config/quickshell/cocoa/
├── assets/
│   └── screenshots/         # Showcase images for documentation
├── components/              # Atomic UI components (Icon, Meter, Button)
├── config/                  # Metrics and design tokens
├── modules/
│   ├── bar/                 # Top bar islands (LeftPanel, CenterCapsule, RightPanel)
│   ├── launcher/            # Bottom-docked application launcher
│   └── notifications/       # Smart notification popup
├── scripts/                 # Palette extraction, daemons, and helper utilities
├── services/                # Singletons (Audio, Brightness, Hyprland, Media, Network)
├── tests/                   # TDD test suite (206 unit and contract tests across 22 test files)
├── theme/                   # Theme definitions and active wallpaper colors
└── shell.qml                # Quickshell entrypoint and window declaration
```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
