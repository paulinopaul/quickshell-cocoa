# Findings & Technical Discoveries: Cocoa Shell Ricing

## Hardware Environment
- **CPU & RAM**: Linux Alder Lake architecture. Standard `/proc/stat` and `/proc/meminfo`.
- **GPUs**:
  - **Integrated (Intel)**: Alder Lake-P GT2 [Iris Xe Graphics] on `/sys/class/drm/card1`. Act frequency at `gt_act_freq_mhz` (300MHz idle, up to 1300MHz max).
  - **Dedicated / Mobile (NVIDIA)**: GA107M [GeForce RTX 3050 Mobile]. Queryable via `nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits` (0-100%).
- **Network Interface**: `wlo1` (Wi-Fi) and `enp44s0` (Ethernet). Speed obtainable via deltas in `/proc/net/dev`.
- **Serial Ports**: Microcontrollers/TTYs located at `/dev/serial/by-id/*` or `/dev/ttyUSB*` / `/dev/ttyACM*`. When disconnected, report none.
- **Wi-Fi Management**: `nmcli -t -f in-use,ssid,bssid,signal,security dev wifi list` works smoothly and outputs active status, SSID, signal level, and security type.

## Cocoa Shell Architecture
- **Quickshell 0.3.1**: Layer shell with Qt6/QML.
- **Top Bar**: `BarWindow.qml` contains `LeftPanel`, `CenterCapsule`, and `RightPanel`.
- **Detached Panel (CenterFlyout)**: Currently instantiated inside `BarWindow.qml` anchored below `CenterCapsule`.
- **Shortcuts**: Hyprland uses `GlobalShortcut` integration via `quickshell:<name>`. In `LauncherWindow`, `GlobalShortcut { name: "launcher" }` connects to `SUPER + R` (or `SUPER + SPACE`).
  For `SUPER + P`, we will expose `GlobalShortcut { name: "center_panel" }` and bind `SUPER, P, global, quickshell:center_panel` in `hyprland.conf`.
- **Agent Tracking**: Real-time integration via `/tmp/agy_state.json` and `AntigravityService.qml`.
