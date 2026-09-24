#!/usr/bin/env bash
# set_wallpaper.sh — Establece el fondo de pantalla y actualiza el tema de Cocoa.
#
# Uso:
#   ~/.config/quickshell/cocoa/scripts/set_wallpaper.sh <ruta_imagen>
#
# Lo que hace:
#   1. Configura el wallpaper en hyprpaper para el monitor actual.
#   2. Extrae la paleta de colores con extract_colors.py (Pillow).
#   3. Escribe el tema en theme/current_theme.json.
#   4. Cocoa Shell detecta el cambio automáticamente (FileView watchChanges).
#
# Dependencias: hyprpaper corriendo, python3, Pillow

set -euo pipefail

COCOA_DIR="$HOME/.config/quickshell/cocoa"
SCRIPTS_DIR="$COCOA_DIR/scripts"
THEME_FILE="$COCOA_DIR/theme/current_theme.json"

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

# ── Obtener monitor activo (hyprpaper requiere especificarlo o usar vacío) ────
# Con string vacío, hyprpaper aplica a todos los monitores
MONITOR=""

# ── 1. Establecer wallpaper en hyprpaper ─────────────────────────────────────
echo "→ Cargando wallpaper en hyprpaper..."
hyprctl hyprpaper preload "$WALL" 2>/dev/null && \
    hyprctl hyprpaper wallpaper "$MONITOR,$WALL" 2>/dev/null || \
    echo "  WARN: hyprpaper no respondió (puede no estar corriendo)" >&2

# Guardar ruta del wallpaper actual para referencia
echo "$WALL" > "$COCOA_DIR/theme/current_wallpaper.txt"

# ── 2. Extraer colores y generar tema ────────────────────────────────────────
echo "→ Extrayendo paleta de colores..."
python3 "$SCRIPTS_DIR/extract_colors.py" "$WALL" "$THEME_FILE"

# ── 3. Cocoa detecta el cambio automáticamente ───────────────────────────────
echo "✓ Tema actualizado. Cocoa Shell aplicará los colores automáticamente."
echo "  Wallpaper: $WALL"
echo "  Tema:      $THEME_FILE"
