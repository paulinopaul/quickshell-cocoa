# Cocoa Desktop Shell

Cocoa es un shell de escritorio modular, reactivo y de alta eficiencia energética para el compositor Wayland **Hyprland**, construido sobre **Quickshell (Qt6/QML)**.

Diseñado bajo el principio de responsabilidad única (SOLID), Cocoa elimina el sobrecoste de shells monolíticos pesados, estructurando la interfaz en tres islas superiores especializadas y un lanzador modal integrado. Con soporte de iconografía vectorial monocromática adaptable a cualquier paleta dinámica de fondo de pantalla.

---

## 1. Arquitectura del Sistema

```
                    +------------------------------------+
                    |        Wayland Compositor          |
                    |            (Hyprland)              |
                    +-----------------+------------------+
                                      |
                      zwlr_layer_shell_v1 / IPC Sockets
                                      v
+-------------------------------------------------------------------------+
|                              ZENITH CORE                                |
|                                                                         |
|  +-------------------------------------------------------------------+  |
|  |                  Capa de Servicios Reactivos                      |  |
|  |  [Hyprland]     [Media/MPRIS]     [Audio/Pipewire]    [System]    |  |
|  +--------+--------------+------------------+---------------+--------+  |
|           |              |                  |               |           |
|           v              v                  v               v           |
|  +-------------------------------------------------------------------+  |
|  |                 Capa de Presentación (Paneles)                    |  |
|  |  +------------------+ +-------------------+ +------------------+  |  |
|  |  |   Panel Izq.     | |  Dynamic Capsule  | |   Panel Der.     |  |  |
|  |  | (Workspaces/App) | | (Media/Telemetry) | | (BATT/MIC/VOL/PWR|  |  |
|  |  +------------------+ +-------------------+ +------------------+  |  |
|  |  ---------------------------------------------------------------  |  |
|  |  +-------------------------------------------------------------+  |  |
|  |  |             Lanzador Modal (Overlay / On Demand)            |  |  |
|  |  +-------------------------------------------------------------+  |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

### Componentes Principales

1. **Panel Izquierdo (`modules/bar/LeftPanel.qml`)**:
   - Workspaces dinámicos vinculados a `Quickshell.Hyprland`.
   - Identificador gráfico de la aplicación activa y título saneado.
2. **Dynamic Capsule Central (`modules/bar/CenterCapsule.qml`)**:
   - Píldora interactiva anclada a la parte superior.
   - Modos conmutables vía scroll de ratón (`WheelHandler`):
     - Modo A: Reproductor multimedia MPRIS (metadatos, arte, barra de posición).
     - Modo B: Telemetría de hardware (CPU, RAM, temperatura).
     - Modo C: Contexto de ventana activa en detalle.
3. **Panel Derecho (`modules/bar/RightPanel.qml`)**:
   - Indicador de batería con autodetección de portátiles (`isLaptopBattery`).
   - Estado y conmutación de micrófono (PipeWire).
   - Control de volumen de salida con scroll y click.
   - Menú de control de energía (Bloqueo, Suspensión, Apagado).
4. **Lanzador de Aplicaciones (`modules/launcher/LauncherWindow.qml`)**:
   - Capa `WlrLayer.Overlay` con `WlrKeyboardFocus.Exclusive`.
   - Búsqueda difusa y ejecución aislada mediante `Hyprland.dispatch("exec ...")`.

---

## 2. Dependencias del Sistema

- **Runtime Base**: `quickshell` (>= 0.3.1, con módulos `Quickshell.Hyprland`, `Quickshell.Services.Pipewire`, `Quickshell.Services.Mpris`, `Quickshell.Services.UPower`, `Quickshell.Wayland`).
- **Compositor**: `Hyprland` (>= 0.40.0).
- **Audio**: `pipewire`, `wireplumber`.
- **Hardware y Batería**: `upower`.
- **Python (Suite de Pruebas)**: `python` (>= 3.10) para pruebas unitarias de parseo y mocks de IPC.

---

## 3. Comandos de Despliegue y Pruebas

### Ejecución de Pruebas Automatizadas
```bash
# Ejecutar suite de pruebas unitarias TDD
python3 -m unittest discover -s ~/.config/quickshell/cocoa/tests -p "test_*.py" -v
```

### Despliegue Local / Prueba del Shell
```bash
# Lanzar Cocoa en modo foreground con logging detallado
quickshell -p ~/.config/quickshell/cocoa -v

# Lanzar en segundo plano (producción)
quickshell -d -p ~/.config/quickshell/cocoa
```

### Recarga e Integración con Hyprland
Agregar en `~/.config/hypr/hyprland.conf`:
```ini
exec-once = quickshell -p ~/.config/quickshell/cocoa
bind = SUPER, SPACE, global, quickshell:launcher
```
