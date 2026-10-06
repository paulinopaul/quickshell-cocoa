<div align="center">

# 🍫 Cocoa Desktop Shell

**A modular, reactive, and ultra-lightweight desktop shell for Hyprland built on Quickshell (Qt6/QML).**

[![Compositor: Hyprland](https://img.shields.io/badge/Compositor-Hyprland_%3E%3D_0.40.0-00ADD8?style=flat-square&logo=hyprland&logoColor=white)](https://hyprland.org)
[![Framework: Quickshell](https://img.shields.io/badge/Framework-Quickshell_%3E%3D_0.3.1-41CD52?style=flat-square&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me)
[![Wayland Layer: zwlr_layer_shell_v1](https://img.shields.io/badge/Wayland-Layer_Shell_v1-E95420?style=flat-square&logo=wayland&logoColor=white)](https://wayland.freedesktop.org)
[![Tests: 137 Passing](https://img.shields.io/badge/Tests-137_Passing-brightgreen?style=flat-square&logo=python&logoColor=white)](tests/)
[![Architecture: Clean & Modular](https://img.shields.io/badge/Architecture-SOLID_%2F_Reactive-blueviolet?style=flat-square)](#architecture)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)

<p align="center">
  <a href="#-showcase">Showcase</a> •
  <a href="#-key-features">Key Features</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-dependencies">Dependencies</a> •
  <a href="#-quick-start">Quick Start</a> •
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
  * Local filesystem caching (`/tmp/cocoa_palette_cache/<md5>.json`) delivers sub-millisecond lookups for repeated tracks.
* **Reactive Suppression**: Automatically suppresses and auto-dismisses popups when the center capsule flyout is detached.

### 4. Zero-Overhead Performance & Kernel Direct Reads
* **Direct SysFS Polling**: `BrightnessService.qml` reads kernel backlight directly from `/sys/class/backlight/*/actual_brightness` via `FileView` at 100ms intervals, eliminating recurring `brightnessctl` shell forks.
* **Direct Process Dispatch**: Binary calls (`wpctl`, `brightnessctl`) invoke executables directly without intermediate bash wrappers.
* **Embedded Vector Icons (`components/Icon.qml`)**: Self-contained SVG paths for network states (`network-wireless`, `network-wired`, `network-offline`), rendering reliably on bare Wayland without requiring external GTK/Qt icon bridges (`qt6ct`).

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
# Auto-start Cocoa Desktop Shell
exec-once = quickshell -d -p ~/.config/quickshell/cocoa

# Optional background daemon for fast polling and telemetry
exec-once = ~/.config/quickshell/cocoa/scripts/cocoa_daemon.sh

# Global shortcut to toggle the application launcher
bind = SUPER, R, global, quickshell:launcher
```

### 3. Running Manually

To run Cocoa in the foreground with verbose logging for development:

```bash
quickshell -p ~/.config/quickshell/cocoa -v
```

---

## 🧪 Test Suite

Cocoa features a comprehensive test suite covering contracts, classifiers, and data parsers:

```bash
# Run all unit and contract tests (137 tests)
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
├── tests/                   # TDD test suite (137 unit and contract tests)
├── theme/                   # Theme definitions and active wallpaper colors
└── shell.qml                # Quickshell entrypoint and window declaration
```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
