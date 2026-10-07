## Auditoría de Cierre - 2026-09-27 12:18:08
Hito 5: Implementación del Sistema de Notificaciones PopUp y Supresión Dinámica.
- Arquitectura desacoplada: Quickshell.Services.Notifications NotificationServer integrado en services/NotificationService.qml con pragma Singleton.
- Sanitización determinista de texto en scripts/notification_sanitizer.py asegurando formato estricto '{programa}:{mensaje} {hora}', desinfección de etiquetas HTML y control de buffer.
- Superficie PopUp flotante en modules/notifications/NotificationPopup.qml con anclaje superior centrado ('margins.top: Metrics.barHeight + 6'), estilo translúcido 0.50 y desenfoque nativo Wayland en Hyprland vía layerrule blur/ignorealpha.
- Restricción estricta de iconos: únicamente iconos propios del programa emisor (16px), descartando fallbacks genéricos de ventana.
- Supresión reactiva: sincronización bidireccional con 'BarWindow.mediaMenuVisible' (panel central desacoplado) que descarta inmediatamente cualquier notificación entrante o activa.
- Suite TDD: 48 pruebas unitarias y de contrato automatizadas ejecutándose en menos de 20ms con 100% de éxito.
---
## Auditoría de Cierre - 2026-09-27 13:43:32
Hito 6: Rediseño del Lanzador de Aplicaciones Inferior y Retiro del OSD HUD.
- Rediseño de LauncherWindow.qml: migración de anclaje fullscreen a anclaje de base central ('anchors.bottom: true', 'margins.bottom: 12') con dimensiones implícitas acotadas (520x460) y extensión vertical ascendente ('transformOrigin: Item.Bottom').
- Cierre reactivo y liberación de espacio: cierre activable mediante selección, tecla Escape o salida del cursor del área interactiva ('onExited' con 180ms debounce tras presencia previa). Desmapeo total Wayland ('visible: isOpen') que garantiza 0% interferencia de puntero en aplicaciones subyacentes.
- Retiro de OsdWindow: desacoplado y retirado de shell.qml, eliminando la aparición de la isla flotante inferior en ajustes de volumen y brillo (reservada para futura integración en la cápsula superior).
- Cobertura TDD: 54 pruebas unitarias y de contrato automatizadas ejecutadas con 100% de éxito en 0.015s.
---
## Auditoría de Cierre - 2026-09-27 13:57:18
Hito 6 (Actualización Cinemática): Implementación de Animaciones Verticales con Jump & Dive en el Lanzador.
- Desacoplamiento de ciclo de vida Wayland: la propiedad 'surfaceActive' mantiene mapeada la ventana durante la animación de salida mientras 'isOpen = false' libera inmediatamente el foco de teclado.
- Cinemática de entrada: traslación vertical 'y' desde el margen inferior (520 -> 20) con rebote elástico Easing.OutBack (overshoot 1.35 en 260ms).
- Cinemática de salida Jump & Dive: SequentialAnimation con salto previo hacia arriba de 16px (20 -> 4 en 75ms) y caída acelerada hacia el fondo (4 -> 520 en 190ms con Easing.InCubic), tras lo cual se desmapea la capa Wayland.
- Suite de pruebas: 55 pruebas unitarias y de contrato pasando en 0.025s (100% OK).
---
## Auditoría de Cierre - 2026-09-27 14:17:30
Hito 7: HUD Superior Dinámico, Métrica de Brillo e Iconografía Vectorial Nativa.
- Integración de Brillo en Panel Superior: incorporada métrica porcentual de brillo ('BrightnessService.brightness') en formato monospaced con control interactivo mediante rueda del ratón ('onWheel').
- Transformación Dinámica a HUD (Modo Ligero): conmutación suave por opacidad ('Behavior on opacity') entre las métricas estándar ('contentRow') y la barra HUD ('hudRow'). Activación reactiva ante cambios de volumen ('volumeChangedExplicitly') o brillo ('brightnessChangedExplicitly').
- Auto-Reversión Eficiente (Zero Overhead): temporizador no recurrente ('hudTimer': 1.8s) que restaura automáticamente las métricas del panel al cesar el ajuste, con soporte de scroll interactivo continuo durante el tiempo activo.
- Resolución de Glifos Espurios de Ventana: diagnóstico empírico de la falta de tema de iconos heredado en compositores Wayland sin puente Qt/GTK. Añadidos vectores SVG nativos monocromáticos en 'components/Icon.qml' para 'network-wireless', 'network-wired' y 'network-offline', eliminando dependencias de temas externos y fallbacks incorrectos.
- Cobertura TDD: 58 pruebas unitarias y de contrato automatizadas ejecutadas con 100% de éxito en 0.034s.
---
## Auditoría de Cierre - 2026-09-27 14:24:45
Hito 7.1: Optimización de Latencia Cero, Actualizaciones Optimistas de UI y Corrección de Brillo.
- Causa Raíz de Latencia y Falla en Brillo: dependencia de subprocesos bash (`brightnessctl -m`) ejecutados con temporizador lento de 500ms y falta de actualización optimista en `setBrightness`/`setVolume`, lo que provocaba que llamadas consecutivas de scroll leyeran valores desactualizados. En volumen, `cocoa_daemon.sh` bloqueaba la telemetría de audio durante 200ms en cada ciclo ejecutando `nmcli`.
- Lectura Directa Kernel SysFS: `BrightnessService.qml` ahora lee `/sys/class/backlight/intel_backlight/actual_brightness` a través de `FileView` a 100ms (0ms forks, cero overhead de CPU).
- Actualizaciones Optimistas Inmediatas: `setBrightness(pct)` y `setVolume(pct)` actualizan inmediatamente sus estados locales (`root.brightness = pct`, `root.volume = pct`) y emiten sus señales en el fotograma exacto del evento de ratón.
- Despacho Directo sin Shells: eliminación de invocaciones intermedias a bash (`["brightnessctl", "s", ...]` y `["wpctl", "set-volume", ...]`).
- Desacoplamiento de Demonio: `cocoa_daemon.sh` ejecuta el sondeo de audio a alta velocidad (~80ms) y separa las consultas lentas de red para ejecutarse cada 3 segundos.
- Corrección de Layout y Cinemática: reestructuración de `hudContainer` eliminando advertencias de QtQuick Layouts (`Detected anchors on an item that is managed by a layout`) y aceleración de animación en `Meter.qml` a `Metrics.animFast` (110ms).
- Cobertura TDD: 60 pruebas unitarias y contractuales ejecutadas con 100% de éxito en 0.015s.
---
## Auditoría de Cierre - 2026-09-27 14:52:30
Hito 8: Pantalla de Bloqueo Minimalista en Hyprlock con Desenfoque Completo y Entrada Oculta.
- Integración Nivel Compositor: configuración de '~/.config/hypr/hyprlock.conf' delegando el bloqueo al estándar nativo de Hyprland con captura instantánea de framebuffer ('path = screenshot').
- Shaders de Desenfoque en GPU: 'blur_passes = 3' y 'blur_size = 8' para un desenfoque Gaussiano continuo acelerado por hardware sin impacto en CPU.
- Ocultamiento Total en Reposo: 'fade_on_empty = true' y 'fade_timeout = 1500' en 'input-field', mostrando exclusivamente la hora central (72pt, JetBrainsMono) y fecha localizada (18pt) hasta la primera pulsación de tecla.
- Cinemática de Aclarado al Desbloquear: 'animation = fadeOut, 1, 5, easeOut' que interpola la opacidad del desenfoque a 0 al autenticar con éxito mediante PAM, aclarando fluidamente la pantalla hacia la sesión de escritorio activa.
- Cobertura TDD: 4 pruebas contractuales en 'tests/test_hyprlock_contract.py'. Total acumulado del proyecto: 64 pruebas unitarias y contractuales ejecutadas con 100% de éxito en 0.019s.
---
## Auditoría de Cierre - 2026-09-27 14:57:15
Hito 9: Cinemática Lenta y Mini-Reproductor Exclusivo de Spotify en Hyprlock.
- Cinemática Cinemática Desacelerada: ajuste en '~/.config/hypr/hyprlock.conf' con curva 'bezier = cinematic, 0.22, 1, 0.36, 1', elevando la duración a 900ms ('fadeOut, 1, 9') y 800ms ('fadeIn, 1, 8') para una disipación majestuosa y pausada del desenfoque al desbloquear.
- Módulo Condicional de Spotify: implementación de 'scripts/hyprlock_spotify.py' con consulta exclusiva a 'org.mpris.MediaPlayer2.spotify' mediante playerctl.
- Filtrado Estricto de Reproducción: retorno de cadena vacía (widget 100% oculto) si Spotify no está en estado 'Playing' (descartando pausas, paradas y otros reproductores MPRIS como navegadores web o reproductores de video).
- Sanitización y Pango Markup: escape de entidades XML ('&', '<', '>'), truncamiento defensivo (32/24 chars con elipsis) e inyección del glifo de Spotify ('\uf1bc' -> ) con tipografía JetBrainsMono Nerd Font.
- Cobertura TDD: 5 pruebas unitarias en 'tests/test_hyprlock_spotify_sanitizer.py' y 5 pruebas contractuales en 'tests/test_hyprlock_contract.py'. Total acumulado del proyecto: 70 pruebas unitarias y contractuales ejecutadas con 100% de éxito en 0.030s.
---
## Auditoría de Cierre - 2026-09-27 15:12:00
Hito 10: Notificaciones Opacas, Degradado Sutil Dinámico y Glifos ASCII para Agentes de Terminal.
- Homogeneización de Superficie Opaca: sustitución del estilo translúcido al 50% por la superficie sólida e idéntica de las ventanas flyout de Cocoa ('color: Colors.surface' #0a0a0a y borde 'border.color: Colors.surfaceRaised'), garantizando un contraste óptimo y un diseño visual coherente.
- Degradado Horizontal Interno Dinámico: capa 'Rectangle' interna con disipación horizontal suave ('Gradient.Horizontal' con 'Qt.rgba' atenuado: 0.35 -> 0.08 -> 0.0) indexada reactivamente a 'NotificationService.gradientColor'.
- Detección de Terminales y Agentes IA con Glifos ASCII:
  - Clasificación determinista en 'NotificationService.classifyNotification' y 'scripts/notification_classifier.py' para emuladores y shells ('kitty', 'alacritty', 'foot', 'wezterm', etc.).
  - Mapeo semántico a glifos ASCII monospaced de alto contraste:
    - Antigravity / Gemini: '▲' (#8a63d2)
    - Claude: '✻' (#d97757)
    - ChatGPT / OpenAI: '✳' (#10a37f)
    - Aider: '⯌' (#3b82f6)
    - Cursor: '❯_' (#00b4d8)
    - Terminal genérica: '>_' (#22c55e)
  - Prevención defensiva de colisiones en nombres cortos mediante expresiones regulares con límites de palabra ('\bst\b' vs 'steam').
- Paleta para Aplicaciones Estándar: integración de colores de marca para aplicaciones desktop comunes (Spotify #1db954, Discord #5865f2, Firefox #ff7139, Telegram #24a1de, Steam #2a475e, Fallback #7f99cc).
- Cobertura TDD: 14 pruebas unitarias en 'tests/test_notification_classifier.py' y 13 pruebas de contrato en 'tests/test_notification_contract.py'. Total acumulado del proyecto: 87 pruebas unitarias y contractuales ejecutadas con 100% de éxito en 0.036s.
---
## Auditoría de Cierre - 2026-09-27 15:35:00
Hito 11: Paleta Dinámica de Álbum y Formateo Especial para Spotify en Notificaciones.
- Extracción Asíncrona de Carátulas: desarrollo de 'scripts/album_palette_extractor.py' utilizando 'PIL.Image.quantize(colors=3)' con K-Means/Median-Cut en subproceso asíncrono 'Process' y 'SplitParser', garantizando cero congelamiento del hilo UI de Quickshell.
- Persistencia en Caché de Disco: almacenamiento en '<ipc-dir>/cocoa_palette_cache/<md5>.json' (directorio IPC por usuario), reduciendo el tiempo de recuperación de paleta a < 1ms para pistas repetidas.
- Degradado Tri-Color en Tarjeta PopUp: extensión del gradiente horizontal en 'NotificationPopup.qml' para soportar 3 paradas de color dinámicas ('palette[0]' al 40%, 'palette[1]' al 22%, 'palette[2]' al 10%) disipadas suavemente sobre la superficie sólida 'Colors.surface'.
- Formato Estricto '{álbum} - {artista}': supresión de prefijo de aplicación y timestamp en eventos de Spotify, mostrando exclusivamente el nombre del álbum y el artista (con fallback defensivo a título/artista si el álbum no está declarado).
- Sincronización Reactiva con MPRIS: vinculación bidireccional entre 'NotificationService.qml' y 'MediaService.qml' ('onArtUrlChanged' y 'onRawAlbumChanged') para emitir el PopUp con la paleta y carátula del álbum en tiempo real al cambiar de pista en reproducción activa.
- Cobertura TDD: 4 pruebas unitarias en 'tests/test_album_palette_extractor.py' y 4 pruebas de contrato en 'tests/test_spotify_notification_contract.py'. Total acumulado del proyecto: 95 pruebas unitarias y contractuales ejecutadas con 100% de éxito en 0.174s.
---
