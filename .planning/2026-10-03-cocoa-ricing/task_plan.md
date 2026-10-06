# Task Plan: Cocoa Ricing & Flyout Redesign

## Goal
Transform the Cocoa desktop shell with a dedicated coupled telemetry capsule (CPU, RAM, Intel & NVIDIA GPUs), a rounded detached overlay panel accessible via click or Super+P with scrollable sections (detailed telemetry + network speed + serial ports, media player, running agents info), and an interactive Wi-Fi network selection & password flyout in the right panel.

## Next Step
Work complete and verified. Deliver final completion report to parent agent.

## Current Phase
Complete

## Phases

### Phase 1: Requirements Analysis & Architectural Design
- [x] Analyze current implementation of CenterCapsule, CenterFlyout, RightPanel, SystemService, NetworkService.
- [x] Identify hardware characteristics (Alder Lake Intel GPU card1, NVIDIA RTX 3050 Mobile, WiFi interface wlo1).
- [x] Plan architecture for detached panel navigation (mouse wheel and trackpad swipe).
- [x] Plan Wi-Fi scan and connect flow with password input.
- **Status:** complete

### Phase 2: Backend Services & Telemetry Extension
- [x] Extend SystemService.qml and cocoa_daemon.sh to reliably measure Intel GPU RC6/frequency and NVIDIA utilization.
- [x] Measure real-time network download/upload speed (KB/s, MB/s) from /proc/net/dev.
- [x] Detect connected serial devices (/dev/serial/by-id or /dev/ttyUSB* /dev/ttyACM*).
- [x] Extend NetworkService.qml with scanning capabilities, Wi-Fi networks list, and connection execution script/command.
- **Status:** complete

### Phase 3: Central Panel (Coupled Format) Redesign
- [x] Restrict CenterCapsule.qml to render exclusively CPU, RAM, Intel GPU, and NVIDIA GPU in its coupled state.
- [x] Maintain sleek styling, trapezoidal base, and click trigger.
- **Status:** complete

### Phase 4: Detached Rounded Central Panel
- [x] Implement/overhaul CenterFlyout.qml as a rounded overlay superposed over the bar.
- [x] Implement smooth slidable section switching with mouse wheel and trackpad gestures.
- [x] Section 1: Detailed Telemetry (CPU %, RAM %, RAM used/total, Intel & NVIDIA GPU %, Network speed & SSID, Serial port name).
- [x] Section 2: Music Player (Album art, Track Title, Artist, Play/Pause, Prev, Next buttons, progress bar).
- [x] Section 3: Agent Activity Information (Antigravity and system agents, active tool/command, current status).
- **Status:** complete

### Phase 5: Right Panel Wi-Fi Dropdown
- [x] Add clickable trigger on the network metric in RightPanel.qml.
- [x] Implement NetworkFlyout.qml with list of available Wi-Fi networks (SSID, signal, security).
- [x] Include password input field and Connect button for secured networks.
- **Status:** complete

### Phase 6: Global Shortcut Integration (Super+P)
- [x] Expose GlobalShortcut for center panel toggle in Quickshell (`quickshell:center_panel`).
- [x] Update and verify ~/.config/hypr/hyprland.conf keybinding for Super+P.
- **Status:** complete

### Phase 7: Verification & Obsidian Documentation
- [x] Run all existing tests and add new contract/unit tests for telemetry, network scanner, and flyouts (114 passing tests).
- [x] Save Architecture Decision Record (ADR) and milestone in vault All_of_me using obsidian-context scripts.
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Coupled Center Capsule restricted to CPU, RAM, Intel GPU, NVIDIA GPU | User explicit requirement: reduce clutter on the bar and focus coupled view strictly on essential core metrics. |
| Rounded overlay for detached panel | Modern dynamic island / floating HUD visual aesthetic that gracefully pops out on click or Super+P. |
| nmcli backend for Wi-Fi management | Standard, reliable, non-root tool available across Linux systems that handles scanning and WPA/WPA2 authentication without extra daemons. |
| FileView & atomic JSON integration | Guarantees zero blocking of Quickshell's UI thread and smooth 60/144 FPS rendering. |

## Errors Encountered
| Error | Resolution |
|-------|------------|
| TypeScript `: void` return syntax in QML functions | Removed `: void` type annotations to conform with Qt6/QML ECMAScript syntax validated by `qmllint`. |
| Missing `Quickshell.Hyprland` import for `GlobalShortcut` | Added `import Quickshell.Hyprland` to `BarWindow.qml`. |
