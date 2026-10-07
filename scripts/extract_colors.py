#!/usr/bin/env python3
"""
extract_colors.py — Extractor de paleta de theming dinámico para Cocoa Shell.

Entrada:   ruta a imagen (JPG / PNG / cualquier formato Pillow)
Salida:    JSON con tokens de color para textos e iconos

Los colores de PANEL (surface, background) son fijos en #1a1a1a y NUNCA
son modificados por este script. Solo se generan tokens para:
  - text      → color principal de texto e iconos
  - textMuted → texto secundario / iconos en reposo
  - textDim   → texto deshabilitado / separadores
  - accent    → indicadores activos (workspace actual, focus)

Algoritmo:
  1. Escalar imagen a 120×120 para velocidad.
  2. Cuantizar a 12 colores dominantes (Pillow palette mode).
  3. Convertir a HSL.
  4. Filtrar colores "inútiles" (demasiado oscuros o desaturados).
  5. Seleccionar el color con mejor puntuación de "viveza" (sat × lum).
  6. Mapear al rango visual seguro para paneles oscuros:
       H → preservado del wallpaper
       S → clampado a [0.25, 0.55]  (elegante, sin neón)
       L → clampado a [0.65, 0.85]  (legible sobre #1a1a1a)
  7. Derivar textMuted y textDim reduciendo progresivamente S y L.
  8. Serializar a JSON.

Uso:
  python3 extract_colors.py <wallpaper_path> [output_json_path]

  Si output_json_path se omite, escribe en stdout.
"""

import sys
import json
import colorsys
from pathlib import Path
from typing import Optional


# ── Constantes de mapeo ───────────────────────────────────────────────────────

# Rango de Lightness aceptable del color extraído (antes de mapear)
_MIN_LIGHTNESS_RAW: float = 0.15   # Descarta negros
_MIN_SATURATION_RAW: float = 0.05  # Descarta grises neutros

# Target display range (para garantizar legibilidad sobre panel #1a1a1a)
_SAT_TARGET_MIN: float = 0.20
_SAT_TARGET_MAX: float = 0.55
_LUM_TARGET_MIN: float = 0.65
_LUM_TARGET_MAX: float = 0.85

# Número de colores en la paleta cuantizada
_PALETTE_COLORS: int = 12

# Tamaño de reescalado para velocidad
_SAMPLE_SIZE: tuple[int, int] = (120, 120)


# ── Utilidades de color ───────────────────────────────────────────────────────

def _rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def _clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def _map_to_display_safe(h: float, s: float, l: float) -> tuple[float, float, float]:
    """
    Preserva el Hue, pero fuerza S y L al rango seguro para texto
    sobre un fondo oscuro (#1a1a1a).
    """
    s_safe = _clamp(s, _SAT_TARGET_MIN, _SAT_TARGET_MAX)
    l_safe = _clamp(l, _LUM_TARGET_MIN, _LUM_TARGET_MAX)
    return (h, s_safe, l_safe)


def _hsl_to_hex(h: float, s: float, l: float) -> str:
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return _rgb_to_hex(int(r * 255), int(g * 255), int(b * 255))


def _derive_muted(h: float, s: float, l: float) -> tuple[float, float, float]:
    """textMuted: mismo Hue, menos saturación, menos brillo."""
    return (h, _clamp(s * 0.65, 0.10, 0.40), _clamp(l * 0.82, 0.45, 0.70))


def _derive_dim(h: float, s: float, l: float) -> tuple[float, float, float]:
    """textDim: muy desaturado, bastante oscuro — para separadores y deshabilitados."""
    return (h, _clamp(s * 0.25, 0.05, 0.20), _clamp(l * 0.55, 0.28, 0.48))


# ── Extracción principal ──────────────────────────────────────────────────────

def extract_theme(image_path: str) -> dict[str, str]:
    """
    Extrae la paleta de theming a partir de la imagen del wallpaper.

    Returns:
        dict con claves: text, textMuted, textDim, accent
    """
    try:
        from PIL import Image
    except ImportError as e:
        raise RuntimeError("Pillow no está instalado: pip install Pillow") from e

    img = Image.open(image_path).convert("RGB")
    img = img.resize(_SAMPLE_SIZE, Image.Resampling.LANCZOS)

    # Cuantizar → paleta de colores dominantes
    palette_img = img.quantize(colors=_PALETTE_COLORS, method=Image.Quantize.MEDIANCUT)
    palette = palette_img.getpalette()  # Lista plana [R,G,B, R,G,B, ...]
    if palette is None:
        raise ValueError("No se pudo extraer la paleta de la imagen.")

    # Contar píxeles por color de paleta (compatible Pillow ≥13 y ≥14)
    pixel_counts = [0] * _PALETTE_COLORS
    try:
        pixel_data = list(palette_img.get_flattened_data())
    except AttributeError:
        pixel_data = list(palette_img.getdata())
    for pixel_index in pixel_data:
        if pixel_index < _PALETTE_COLORS:
            pixel_counts[pixel_index] += 1

    # Construir candidatos (H, S, L, weight)
    candidates: list[tuple[float, float, float, float]] = []
    total_pixels: int = _SAMPLE_SIZE[0] * _SAMPLE_SIZE[1]

    for i in range(_PALETTE_COLORS):
        r = palette[i * 3]
        g = palette[i * 3 + 1]
        b = palette[i * 3 + 2]
        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
        weight = pixel_counts[i] / total_pixels if total_pixels > 0 else 0

        # Filtrar colores que no tienen suficiente información cromática
        if l < _MIN_LIGHTNESS_RAW or s < _MIN_SATURATION_RAW:
            continue

        candidates.append((h, s, l, weight))

    # Si no quedan candidatos, fallback a valores seguros
    if not candidates:
        return {
            "mode": "auto",
            "surface": "#161922",
            "surfaceDark": "#10121a",
            "surfaceRaised": "#1f2430",
            "surfaceBorder": "#323a4e",
            "surfaceHover": "#2a3142",
            "background": "#0e1017",
            "text": "#ffffff",
            "textMuted": "#909090",
            "textDim": "#484848",
            "accent": "#d8d8d8",
        }

    # Seleccionar el candidato con mejor puntuación de "viveza"
    # Score = saturación × √lightness × (1 + peso_visual)
    best = max(
        candidates,
        key=lambda c: c[1] * (c[2] ** 0.5) * (1.0 + c[3])
    )
    h_best, s_best, l_best, _ = best

    # Mapear al rango seguro para paneles oscuros
    h_a, s_a, l_a = _map_to_display_safe(h_best, s_best, l_best)
    h_m, s_m, l_m = _derive_muted(h_a, s_a, l_a)
    h_d, s_d, l_d = _derive_dim(h_a, s_a, l_a)

    # Derivar superficies dinámicas tintadas con el color del wallpaper
    s_surf = _clamp(s_best * 0.30, 0.10, 0.26)
    surf_hex = _hsl_to_hex(h_best, s_surf, 0.12)
    surf_dark_hex = _hsl_to_hex(h_best, s_surf, 0.08)
    surf_raised_hex = _hsl_to_hex(h_best, s_surf, 0.16)
    surf_hover_hex = _hsl_to_hex(h_best, s_surf, 0.20)
    surf_border_hex = _hsl_to_hex(h_best, _clamp(s_best * 0.35, 0.12, 0.32), 0.24)
    bg_hex = _hsl_to_hex(h_best, s_surf, 0.06)

    return {
        "mode": "auto",
        "surface": surf_hex,
        "surfaceDark": surf_dark_hex,
        "surfaceRaised": surf_raised_hex,
        "surfaceBorder": surf_border_hex,
        "surfaceHover": surf_hover_hex,
        "background": bg_hex,
        "text": "#ffffff",
        "textMuted": _hsl_to_hex(h_m, s_m, l_m),
        "textDim": _hsl_to_hex(h_d, s_d, l_d),
        "accent": _hsl_to_hex(h_a, s_a, l_a),
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    if len(sys.argv) < 2:
        print(f"Uso: {sys.argv[0]} <wallpaper_path> [output.json]", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    output_path: Optional[str] = sys.argv[2] if len(sys.argv) >= 3 else None

    if not Path(image_path).is_file():
        print(f"ERROR: No se encuentra el archivo: {image_path}", file=sys.stderr)
        sys.exit(2)

    try:
        theme = extract_theme(image_path)
    except Exception as e:
        print(f"ERROR al procesar imagen: {e}", file=sys.stderr)
        sys.exit(3)

    json_output = json.dumps(theme, indent=2)

    if output_path:
        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json_output, encoding="utf-8")
        print(f"Tema guardado en: {output_path}", file=sys.stderr)
    else:
        print(json_output)


if __name__ == "__main__":
    main()
