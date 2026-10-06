#!/usr/bin/env bash
# set_wallpaper.sh — Establece el fondo de pantalla y actualiza el tema de Cocoa.
#
# Uso:
#   ~/.config/quickshell/cocoa/scripts/set_wallpaper.sh <ruta_imagen>
#
# Lo que hace:
#   1. Configura el wallpaper en hyprpaper para todos los monitores detectados.
#   2. Actualiza hyprpaper.conf para persistencia entre reinicios.
#   3. Extrae la paleta de colores con extract_colors.py (Pillow).
#   4. Escribe el tema en theme/current_theme.json.
#   5. Cocoa Shell detecta el cambio automáticamente (FileView watchChanges).
#
# Dependencias: hyprpaper corriendo, hyprctl, python3, Pillow

set -euo pipefail

COCOA_DIR="$HOME/.config/quickshell/cocoa"
SCRIPTS_DIR="$COCOA_DIR/scripts"
THEME_FILE="$COCOA_DIR/theme/current_theme.json"
HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"

WALL="${1:-}"

# ── Validación ────────────────────────────────────────────────────────────────
if [[ -z "$WALL" ]]; then
    echo "Uso: set_wallpaper.sh <ruta_al_wallpaper>" >&2
    exit 1
fi

if [[ ! -f "$WALL" ]]; then
    echo "ERROR: No se encuentra el archivo: $WALL" >&2
    exit 2
fi

# ── Obtener lista de monitores desde hyprctl ──────────────────────────────────
MONITORS=()
if command -v hyprctl &>/dev/null; then
    while IFS= read -r mon; do
        [[ -n "$mon" ]] && MONITORS+=("$mon")
    done < <(hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
mons = json.load(sys.stdin)
for m in mons:
    print(m.get('name',''))
" 2>/dev/null)
fi

# Fallback si no se detectaron monitores
if [[ ${#MONITORS[@]} -eq 0 ]]; then
    MONITORS=("eDP-1")
fi

# ── 1. Actualizar hyprpaper.conf para persistencia ───────────────────────────
{
    echo "preload = $WALL"
    echo ""
    for MON in "${MONITORS[@]}"; do
        echo "wallpaper {"
        echo "    monitor = $MON"
        echo "    path = $WALL"
        echo "}"
        echo ""
    done
    echo "splash = false"
    echo "ipc = on"
} > "$HYPRPAPER_CONF"
echo "→ hyprpaper.conf actualizado"

# ── 2. Aplicar wallpaper via IPC (si hyprpaper está corriendo) ───────────────
echo "→ Aplicando wallpaper via IPC..."
HYPRPAPER_OK=false

if pgrep -x hyprpaper &>/dev/null; then
    ALL_OK=true
    for MON in "${MONITORS[@]}"; do
        hyprctl hyprpaper wallpaper "$MON,$WALL,cover" 2>/dev/null || ALL_OK=false
    done
    $ALL_OK && HYPRPAPER_OK=true
fi

if ! $HYPRPAPER_OK; then
    echo "  → Reiniciando hyprpaper con nueva configuración..."
    killall hyprpaper 2>/dev/null || true
    sleep 0.3
    setsid -f hyprpaper -c "$HYPRPAPER_CONF" >/dev/null 2>&1 || { nohup hyprpaper -c "$HYPRPAPER_CONF" >/dev/null 2>&1 & disown || true; }
    sleep 1
    echo "  → hyprpaper relanzado, wallpaper cargará desde conf"
fi

# Guardar ruta del wallpaper actual para referencia
echo "$WALL" > "$COCOA_DIR/theme/current_wallpaper.txt"

# ── 3. Extraer colores y generar tema ────────────────────────────────────────
echo "→ Extrayendo paleta de colores..."
python3 "$SCRIPTS_DIR/extract_colors.py" "$WALL" "$THEME_FILE"

# ── 4. Sincronizar marco y colores con Hyprland ──────────────────────────────
if [[ -x "$HOME/.config/hypr/scripts/apply_wallpaper_theme.sh" ]]; then
    echo "→ Sincronizando marco de Hyprland con el wallpaper..."
    "$HOME/.config/hypr/scripts/apply_wallpaper_theme.sh" "$WALL" || true
fi

# ── 5. Cocoa detecta el cambio automáticamente ───────────────────────────────
echo "✓ Tema actualizado. Cocoa Shell y Hyprland aplicarán los colores automáticamente."
echo "  Wallpaper: $WALL"
echo "  Tema:      $THEME_FILE"
echo "  Monitores: ${MONITORS[*]}"


