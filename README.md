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
   - Capa `WlrLayer.Overlay` anclada a la base central de la pantalla (`anchors.bottom: true`, `margins.bottom: 12`).
   - **Cinemática de Apertura**: Emerge verticalmente desde abajo hacia arriba con rebote elástico mediante `Easing.OutBack` (overshoot 1.35 en 260ms).
   - **Cinemática de Salto y Caída (*Jump & Dive*)**: Al cerrarse, ejecuta un salto previo de anticipación hacia arriba (16px en 75ms) seguido de una caída rápida acelerada (`Easing.InCubic` en 190ms).
   - **Triple Disparador de Cierre Reactivo**:
     - Selección de aplicación (`onLaunched` / Enter).
     - Tecla Escape (`Keys.onEscapePressed`).
     - Salida del cursor del área interactiva (`onExited` con debounce de 180ms tras registrar presencia previa).
   - **Desmapeo Total Diferido**: La visibilidad de la superficie Wayland (`surfaceActive`) se desacopla del estado lógico (`isOpen`), liberando el foco de teclado al instante y desmapeando la capa de Wayland solo tras concluir la animación de salida. Cero interferencia de ratón cuando está cerrado.

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
El arranque robusto se gestiona desde `~/.config/hypr/scripts/start_shell.sh`:
```ini
exec-once = ~/.config/hypr/scripts/start_shell.sh
exec-once = ~/.config/quickshell/cocoa/scripts/cocoa_daemon.sh
bind = SUPER, R, global, quickshell:launcher
```

---

## 4. Gestión de Fondo de Pantalla (Hyprpaper v0.8+)

- **Sintaxis de Bloque (Hyprlang)**: Hyprpaper v0.8+ descarta la sintaxis `wallpaper = MON, PATH` y exige bloques `wallpaper { monitor = ...; path = ... }`.
- **Script de Actualización**: `~/.config/quickshell/cocoa/scripts/set_wallpaper.sh <ruta>` genera la configuración en bloque, aplica el cambio en caliente vía `hyprctl hyprpaper wallpaper` y dispara `extract_colors.py` para la actualización dinámica de colores.
- **Desacoplamiento de Arranque**: `start_shell.sh` detecta dinámicamente si Hyprpaper o Quickshell están activos mediante comprobaciones exactas de proceso (`pgrep -x`), evitando falsos positivos con scripts concurrentes y eliminando dependencias de `graphical-session.target` inactivo en systemd.

---

## 5. Módulo OSD y HUD (`modules/osd/OsdWindow.qml`) [Retirado del Shell Activo]

- **Estado**: Desacoplado y retirado de `shell.qml` a petición de diseño. La retroalimentación gráfica de volumen y brillo ya no muestra la isla inferior, quedando reservada para una futura integración en la cápsula del panel superior.
- **Click-Through Total Histórico (`mask: Region {}`)**: Utilizaba una máscara de entrada vacía que delegaba el 100% de los eventos a las aplicaciones subyacentes.
- **Pruebas de Contrato**: Preservadas en `tests/test_osd_contract.py` para asegurar que el componente cumpla con las directrices de no interferencia si se reactiva en el futuro.

---

## 6. Sistema de Notificaciones PopUp (`modules/notifications/NotificationPopup.qml` & `services/NotificationService.qml`)

- **Diseño PopUp Flotante Opaco**: Superficie compacta y no intrusiva posicionada exactamente debajo de la barra central (`anchors.top: true`, `margins.top: Metrics.barHeight + 6`).
- **Superficie Sólida de Ventana Desplegable**: Fondo 100% opaco con el color idéntico de los paneles desplegables de Cocoa (`color: Colors.surface`, borde `border.color: Colors.surfaceRaised`, radio `radius: 12`), eliminando la transparencia translúcida anterior (0.50).
- **Degradado Horizontal Interno Dinámico**: Capa interna horizontal (`Gradient.Horizontal`) con disipación sutil hacia la derecha (`opacity: 0.35 -> 0.08 -> 0.0`) mapeada reactivamente al color de marca o agente (`NotificationService.gradientColor`).
- **Detección de Agentes IA y Glifos ASCII en Terminal**:
  - Clasificación de entornos de terminal y shells (`kitty`, `alacritty`, `foot`, `konsole`, `wezterm`, `gnome-terminal`, `xterm`, `bash`, `zsh`, `fish`, `terminal`).
  - Identificación determinista de agentes mediante análisis semántico en `NotificationService.classifyNotification` y `scripts/notification_classifier.py`:
    - **Antigravity / Gemini**: Glifo ASCII `▲` (`#8a63d2`) en tipografía monospaced.
    - **Claude**: Glifo ASCII `✻` (`#d97757`).
    - **ChatGPT / OpenAI**: Glifo ASCII `✳` (`#10a37f`).
    - **Aider**: Glifo ASCII `⯌` (`#3b82f6`).
    - **Cursor**: Glifo ASCII `❯_` (`#00b4d8`).
    - **Terminal genérica**: Glifo ASCII `>_` (`#22c55e`).
- **Reproducción en Spotify (Paleta Dinámica de 3 Colores y Formato Álbum - Artista)**:
  - **Formateo Estricto `{álbum} - {artista}`**: Al detectar notificaciones o eventos de reproducción de Spotify, se omite el prefijo de programa y timestamp, mostrando únicamente `{álbum} - {artista}` (e.g., `WEEDKILLER - Ashnikko`) con fallback a `{título} - {artista}`.
  - **Extracción Asíncrona de Carátula**: `scripts/album_palette_extractor.py` descarga y cuantiza la carátula activa (`mpris:artUrl`) mediante `PIL.Image.quantize(colors=3)` con K-Means/Median-Cut en subproceso asíncrono `Process` (cero bloqueo del hilo de renderizado QML).
  - **Caché en Disco de Paleta**: Almacena en `/tmp/cocoa_palette_cache/<md5>.json` los tres colores predominantes en formato hexadecimal para un tiempo de respuesta inferior a 1ms en pistas repetidas o cacheadas.
  - **Degradado Horizontal Tri-Color**: La tarjeta de notificación renderiza un degradado horizontal de 3 paradas basado en la paleta dinámica (`palette[0]` al 40%, `palette[1]` al 22%, `palette[2]` al 10%), disipándose suavemente sobre la superficie sólida `Colors.surface`.
- **Paleta de Marcas de Escritorio Estándar**:
  - Aplicaciones estándar conservan su icono gráfico de aplicación (`Icon.qml`, 16px) acompañado del degradado correspondiente:
    - Discord: `#5865f2`
    - Firefox: `#ff7139`
    - Telegram: `#24a1de`
    - Steam: `#2a475e`
    - Fallback: `#7f99cc` (`Colors.accent`)
- **Formato Estricto Determinista General**: Para aplicaciones estándar, muestra exclusivamente `{programa}:{mensaje} {hora}` con sanitización de marcado HTML, remoción de saltos de línea, elisión de longitud segura y tiempo local `HH:mm`.
- **Supresión y Descarte Reactivo**: Sincronizado reactivamente con el estado desacoplado del panel central (`NotificationService.centralPanelDetached`). Si el panel central se encuentra desacoplado (flyout de medios/telemetría abierto), cualquier notificación entrante se descarta instantáneamente; si ya estaba en pantalla, desaparece de inmediato.
- **Ciclo de Vida Eficiente**: La superficie de Wayland solo se mapea durante la presencia de notificaciones activas (`hasActiveNotification && !centralPanelDetached`), liberando recursos del compositor al finalizar el temporizador de auto-cierre (4s) o al hacer click sobre el popup.
- **Suite de Pruebas TDD**: Cobertura completa automatizada con `tests/test_album_palette_extractor.py`, `tests/test_spotify_notification_contract.py`, `tests/test_notification_classifier.py`, `tests/test_notification_formatter.py` y `tests/test_notification_contract.py`.

---

## 7. Lanzador Inferior y Cinemática (`modules/launcher/LauncherWindow.qml`)

- **Ubicación Inferior Central**: Posicionado en la parte inferior de la pantalla (`anchors.bottom: true`), extendiéndose hacia arriba con dimensiones calculadas (`implicitWidth: 520`, `implicitHeight: 480`).
- **Cinemática de Apertura y Cierre ("Jump")**:
  - **Apertura**: Desplazamiento vertical fluido desde abajo hacia su posición de reposo con curva `Easing.OutBack` para dar un efecto de rebote elástico orgánico.
  - **Cierre**: Secuencia `SequentialAnimation` con salto anticipatorio (`y: 20 -> 4` en 90ms con `Easing.OutQuad`) seguido de un clavado hacia abajo (`y: 4 -> 520` en 210ms con `Easing.InBack`).
- **Ocultamiento y Liberación de Superficie**: Al pulsar `Esc`, seleccionar un ejecutable o retirar el puntero del ratón (`MouseArea.onExited` con debounce de 180ms), el lanzador inicia la animación de salida y conmuta `visible: surfaceActive = false`, desmapeando la superficie Wayland para garantizar que el ratón pueda interactuar sin interferencias en esa área.
- **Pruebas de Contrato**: Validación de comportamiento en `tests/test_launcher_contract.py`.

---

## 8. HUD Dinámico en Panel Superior e Iconografía Vectorial (`modules/bar/RightPanel.qml` & `components/Icon.qml`)

- **Integración de Brillo**: El panel superior incluye ahora el nivel de brillo actual en porcentaje monospaced y control interactivo mediante la rueda del ratón (`onWheel` vinculado a `BrightnessService.setBrightness`).
- **Transformación Dinámica a HUD (Modo Ligero)**:
  - **Disparador Reactivo**: Al modificar el volumen o el brillo (ya sea por atajos de teclado globales vía `wpctl`/`brightnessctl` o por interacción directa de scroll en la barra), `RightPanel` detecta las señales `volumeChangedExplicitly` o `brightnessChangedExplicitly`.
  - **Cross-Fade Fluido**: Las métricas habituales del panel derecho (batería, red, micrófono) reducen su opacidad a 0 mientras emerge una barra minimalista (`hudRow`) compuesta por:
    1. Icono del servicio activo (`audio-volume-high`, `audio-volume-muted`, o `display-brightness-symbolic`).
    2. Barra de nivel `Meter.qml` (ancho 90px, grosor 4px, color de acento).
    3. Texto con porcentaje exacto o indicador "MUTE".
  - **Auto-Retorno Eficiente y Zero-Overhead**: Al cesar el ajuste, un temporizador `hudTimer` de 1.8 segundos sin repetición restaura suavemente las métricas estándar sin ningún bucle continuo ni consumo residual de CPU/GPU.
  - **Interacción Continua en HUD**: El usuario puede seguir usando la rueda del ratón directamente sobre la barra HUD activa para continuar ajustando el nivel, reiniciando el temporizador de 1.8s.
- **Optimización de Latencia Cero y Fluidez Líquida**:
  - **Lectura Directa SysFS para Brillo**: `BrightnessService.qml` lee directamente `/sys/class/backlight/intel_backlight/actual_brightness` a nivel de memoria del kernel mediante `FileView` a intervalos de 100ms, descartando la ejecución repetitiva de subprocesos bash (`brightnessctl -m`).
  - **Actualización Optimista Inmediata**: Tanto `VolumeService.setVolume()` como `BrightnessService.setBrightness()` actualizan inmediatamente las variables de estado reactivas (`root.volume = pct; root.brightness = pct;`) y disparan sus señales de notificación en el mismo frame de renderizado, eliminando por completo cualquier retraso perceptivo al girar la rueda del ratón.
  - **Despacho Directo sin Sub-Shells**: Las órdenes hacia el hardware se despachan llamando directamente a los binarios ejecutables (`["brightnessctl", "s", ...]` y `["wpctl", "set-volume", ...]`), suprimiendo el overhead de parsing e inicialización de shells intermedias.
  - **Desacoplamiento de Telemetría en `cocoa_daemon.sh`**: El demonio ejecuta el sondeo de audio a alta velocidad (~80-100ms) mientras aísla las consultas costosas de red (`nmcli`) para que ocurran cada 3 segundos, garantizando una detección casi instantánea de pulsaciones de teclas multimedia de hardware.
  - **Cinemática de Medidor Ágil**: `Meter.qml` utiliza `Metrics.animFast` (110ms) en la interpolación de ancho, proporcionando una respuesta elástica inmediata al scroll sin el rezago elástico pesado previo.
  - **Arquitectura de Layout Limpia**: Reestructuración de `hudContainer` como contenedor desacoplado para eliminar advertencias de QtQuick Layouts y garantizar la captura completa de eventos táctiles y de rueda.
- **Iconografía Monocromática Nativa**:
  - **Diagnóstico de Glifos de Ventana**: En entornos Hyprland/Wayland puros sin puente de temas GTK (`qt6ct`/`qt5ct`), las consultas a iconos del tema retornaban falso para nombres como `network-wireless` y `network-wired`, provocando la caída al glifo por defecto de `Icon.qml` (una ventana de aplicación).
  - **Solución Vectorial Integrada**: Se incorporaron directamente en `components/Icon.qml` las rutas vectoriales SVG nativas para `network-wireless`, `network-wired` y `network-offline`. Esto garantiza un renderizado 100% independiente de temas externos, nítido a cualquier escala y teñido dinámicamente con los colores semánticos del sistema.
- **Suite de Pruebas TDD**: Validado al 100% con `tests/test_right_panel_hud_contract.py` (60 pruebas unitarias y contractuales en total).

---

## 9. Pantalla de Bloqueo Minimalista (`~/.config/hypr/hyprlock.conf`)

- **Integración de Sistema**: Disparada mediante `SUPER + F11`, `XF86Sleep` o el botón de apagado de Cocoa (`exec hyprlock || loginctl lock-session`).
- **Desenfoque en Tiempo Real por GPU**:
  - `path = screenshot`: Captura en vivo del framebuffer del escritorio en el fotograma exacto del bloqueo.
  - `blur_passes = 3` y `blur_size = 8`: Desenfoque Gaussiano multicapa acelerado por hardware sin carga de CPU.
- **Ocultamiento Total en Reposo (`fade_on_empty = true`)**:
  - En estado de reposo, el campo de contraseña es completamente invisible (`opacity: 0`).
  - Solo se muestran la hora central en gran formato (`$TIME`, JetBrainsMono, 72pt) y la fecha localizada (`date`, 18pt).
  - Al pulsar cualquier tecla, el campo de contraseña emerge suavemente para recibir la entrada del PIN o contraseña. Si se vacía, se desvanece tras 1.5s.
- **Cinemática Lenta y Aclarado Cinemático (`animations`)**:
  - Motor de cinemática con curva `bezier = cinematic, 0.22, 1, 0.36, 1`.
  - Transición desacelerada `animation = fadeOut, 1, 9, cinematic` (900ms) y `fadeIn, 1, 8, cinematic` (800ms) para un aclarado suave, profundo y majestuoso al desbloquear hacia el escritorio.
- **Mini-Reproductor Exclusivo de Spotify (`scripts/hyprlock_spotify.py`)**:
  - Módulo condicional de alta fidelidad que consulta única y exclusivamente el bus MPRIS de Spotify (`playerctl -p spotify`).
  - **Filtro Estricto de Reproducción**: Solo se renderiza si el estado es exactamente `Playing`. Si Spotify está cerrado, pausado o detenido, o si hay otro reproductor activo (Firefox, VLC), el widget retorna cadena vacía y se oculta al 100%.
  - **Formato y Sanitización**: Muestra el glifo de Spotify (``), título en negrita y artista en tonos Cocoa (`<span foreground="#1db954"></span> <b>Título</b> • Artista`), con sanitización XML contra inyecciones y truncamiento seguro a 32/24 caracteres.
- **Suite de Pruebas TDD**: Cobertura completa en `tests/test_hyprlock_spotify_sanitizer.py` y `tests/test_hyprlock_contract.py` (70 pruebas automatizadas en total).





