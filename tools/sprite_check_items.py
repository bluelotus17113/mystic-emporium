#!/usr/bin/env python3
"""Audita sprites de items contra el contrato medido de Mystic Emporium.

Uso:
    python3 sprite_check_items.py                    # audita todos
    python3 sprite_check_items.py id1 id2 id3        # audita solo esos ids
"""

import json
import os
import sys
import warnings
from collections import Counter
from pathlib import Path

warnings.filterwarnings("ignore", message=".*getdata.*")

from PIL import Image

# ── paths ────────────────────────────────────────────────────────────────
PROJECT = Path(__file__).resolve().parent.parent
ITEMS_DIR = PROJECT / "godot" / "art" / "sprites" / "items"
PALETTE_FILE = PROJECT / "art_reference" / "paleta_items.json"

# ── contrato medido ─────────────────────────────────────────────────────
EXPECTED_SIZE = (32, 32)
CONTOUR_COLOR = "#21181b"
# Medido: los sprites legítimos más flojos rondan el 58% (llevan canto de color
# donde el objeto brilla). Con el listón en 70 caían 7 buenos, y un checker que
# siempre se queja acaba ignorándose. lingote_plata sigue cayendo, y debe: usa
# #2b1b35 al 100%, del estilo de arte anterior.
CONTOUR_MIN_PCT = 55.0  # por debajo = fallo
COLOR_MIN = 6
COLOR_MAX = 21
BBOX_W_MIN = 10
BBOX_W_MAX = 31
BBOX_H_MIN = 16
BBOX_H_MAX = 32
MIN_OPAQUE = 40  # menos de esto = fallo duro
FULL_CANVAS_SIZE = 32  # bbox = 32×32 sin transparentes = fallo duro


def load_palette() -> set[str]:
    """Carga la paleta desde art_reference/paleta_items.json."""
    with open(PALETTE_FILE) as f:
        data = json.load(f)
    return set(data["colores"])


def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def analyze_sprite(path: Path, palette: set[str]) -> dict:
    """Analiza un sprite y devuelve dict con todos los hallazgos."""
    name = path.name
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    pixels = list(img.getdata())

    result = {"name": name, "w": w, "h": h, "failures": [], "warnings": []}

    # ── 1. TAMAÑO ───────────────────────────────────────────────────
    if (w, h) != EXPECTED_SIZE:
        result["failures"].append(
            f"TAMAÑO: {w}×{h} (esperado {EXPECTED_SIZE[0]}×{EXPECTED_SIZE[1]})"
        )
        # Si no es 32×32, el resto de métricas no son comparables
        result["size_mismatch"] = True
        return result

    result["size_mismatch"] = False

    # ── índices de píxeles ──────────────────────────────────────────
    opaque_indices = [i for i, p in enumerate(pixels) if p[3] == 255]
    opaque_set = set(opaque_indices)
    transparent_indices = [i for i, p in enumerate(pixels) if p[3] == 0]
    semi_indices = [i for i, p in enumerate(pixels) if 0 < p[3] < 255]

    n_opaque = len(opaque_indices)

    # ── 2. ALPHA ────────────────────────────────────────────────────
    if semi_indices:
        result["failures"].append(
            f"ALPHA: {len(semi_indices)} píxeles con alpha parcial (0 < a < 255)"
        )
    result["alpha_partial_count"] = len(semi_indices)

    # ── 7. LIENZO VACÍO ─────────────────────────────────────────────
    if n_opaque < MIN_OPAQUE:
        result["failures"].append(
            f"VACÍO: solo {n_opaque} píxeles opacos (mínimo {MIN_OPAQUE})"
        )
        result["opaque_count"] = n_opaque
        # Si está vacío, el resto no importa mucho pero seguimos
    result["opaque_count"] = n_opaque

    # ── 3. CONTORNO ─────────────────────────────────────────────────
    # Píxel opaco que toca un transparente (4-vecindad) o el borde del lienzo
    contour_hexes = []
    for idx in opaque_indices:
        x, y = idx % w, idx // w
        is_contour = False
        if x == 0 or x == w - 1 or y == 0 or y == h - 1:
            is_contour = True
        else:
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                ni = (y + dy) * w + (x + dx)
                if ni not in opaque_set:
                    is_contour = True
                    break
        if is_contour:
            r, g, b, _ = pixels[idx]
            contour_hexes.append(rgb_to_hex(r, g, b))

    total_contour = len(contour_hexes)
    result["contour_total"] = total_contour
    if total_contour > 0:
        correct = sum(1 for hx in contour_hexes if hx == CONTOUR_COLOR)
        pct = correct / total_contour * 100
        result["contour_pct"] = round(pct, 1)
        result["contour_correct"] = correct

        if pct < CONTOUR_MIN_PCT:
            # Colores que ocupan el lugar del contorno correcto
            alt_counter = Counter(
                hx for hx in contour_hexes if hx != CONTOUR_COLOR
            )
            alt_summary = [(c, n) for c, n in alt_counter.most_common(5)]
            result["failures"].append(
                f"CONTORNO: {pct:.1f}% #{CONTOUR_COLOR[1:]} "
                f"(mínimo {CONTOUR_MIN_PCT:.0f}%). "
                f"Colores alternativos: {alt_summary}"
            )
        result["contour_alternatives"] = [
            (c, n) for c, n in alt_counter.most_common(5)
        ] if total_contour > 0 and pct < CONTOUR_MIN_PCT else []
    else:
        result["contour_pct"] = 0.0
        result["contour_alternatives"] = []
        result["failures"].append("CONTORNO: sin píxeles de contorno (sprite vacío?)")

    # ── 4. PALETA ───────────────────────────────────────────────────
    intruders = Counter()
    for idx in opaque_indices:
        r, g, b, _ = pixels[idx]
        hx = rgb_to_hex(r, g, b)
        if hx not in palette:
            intruders[hx] += 1

    result["palette_intruders"] = dict(intruders.most_common())
    if intruders:
        intruder_list = [
            f"{c} ({n}px)" for c, n in intruders.most_common()
        ]
        result["failures"].append(
            f"PALETA: {len(intruders)} colores fuera de paleta → {intruder_list}"
        )

    # ── 5. NÚMERO DE COLORES ────────────────────────────────────────
    unique_opaque = len(
        set(rgb_to_hex(p[0], p[1], p[2]) for p in pixels if p[3] == 255)
    )
    result["unique_colors"] = unique_opaque
    if unique_opaque < COLOR_MIN or unique_opaque > COLOR_MAX:
        result["warnings"].append(
            f"COLORES: {unique_opaque} (rango esperado {COLOR_MIN}-{COLOR_MAX})"
        )

    # ── 6. BBOX ─────────────────────────────────────────────────────
    xs = [i % w for i in opaque_indices]
    ys = [i // w for i in opaque_indices]
    bbox_x, bbox_y = min(xs), min(ys)
    bbox_w = max(xs) - bbox_x + 1
    bbox_h = max(ys) - bbox_y + 1
    result["bbox"] = (bbox_x, bbox_y, bbox_w, bbox_h)

    if bbox_w == FULL_CANVAS_SIZE and bbox_h == FULL_CANVAS_SIZE:
        result["failures"].append(
            f"BBOX: ocupa el lienzo entero {bbox_w}×{bbox_h} sin píxeles transparentes "
            f"— probable sprite fallido (cuadrado sólido)"
        )
    else:
        bbox_issues = []
        if bbox_w < BBOX_W_MIN or bbox_w > BBOX_W_MAX:
            bbox_issues.append(f"ancho={bbox_w} (rango {BBOX_W_MIN}-{BBOX_W_MAX})")
        if bbox_h < BBOX_H_MIN or bbox_h > BBOX_H_MAX:
            bbox_issues.append(f"alto={bbox_h} (rango {BBOX_H_MIN}-{BBOX_H_MAX})")
        if bbox_issues:
            result["warnings"].append(f"BBOX: {', '.join(bbox_issues)}")

    return result


def print_report(results: list[dict]) -> tuple[int, int]:
    """Imprime el informe y devuelve (passed, failed)."""
    failures = [r for r in results if r["failures"]]
    warnings_only = [
        r for r in results if not r["failures"] and r.get("warnings", [])
    ]
    clean = [
        r for r in results if not r["failures"] and not r.get("warnings", [])
    ]

    print(f"\n{'='*60}")
    print(f"AUDITORÍA DE SPRITES DE ITEMS — {len(results)} sprites")
    print(f"{'='*60}")

    # ── RESUMEN ──
    print(f"\n  ✅ Limpios:           {len(clean)}")
    print(f"  ⚠️  Solo avisos:       {len(warnings_only)}")
    print(f"  ❌ Con fallos:         {len(failures)}")

    # ── MÉTRICAS AGREGADAS ──
    sizes_ok = sum(1 for r in results if not r.get("size_mismatch", False))
    alpha_ok = sum(1 for r in results if r.get("alpha_partial_count", 0) == 0)
    contour_ok = sum(
        1 for r in results
        if r.get("contour_pct", 100) >= CONTOUR_MIN_PCT
    )
    palette_ok = sum(
        1 for r in results if not r.get("palette_intruders", {})
    )
    colors_ok = sum(
        1 for r in results
        if COLOR_MIN <= r.get("unique_colors", 0) <= COLOR_MAX
    )
    bbox_ok = sum(
        1 for r in results
        if "bbox" in r and not (
            r["bbox"][2] == FULL_CANVAS_SIZE and r["bbox"][3] == FULL_CANVAS_SIZE
        )
    )
    empty_ok = sum(
        1 for r in results if r.get("opaque_count", 0) >= MIN_OPAQUE
    )

    print(f"\n  ── Desglose por comprobación ──")
    print(f"  Tamaño 32×32:        {sizes_ok}/{len(results)}")
    print(f"  Alpha binario:       {alpha_ok}/{len(results)}")
    print(f"  Contorno #21181b:    {contour_ok}/{len(results)} (≥{CONTOUR_MIN_PCT:.0f}%)")
    print(f"  Paleta correcta:     {palette_ok}/{len(results)}")
    print(f"  Colores {COLOR_MIN}-{COLOR_MAX}:    {colors_ok}/{len(results)}")
    print(f"  BBox correcto:       {bbox_ok}/{len(results)}")
    print(f"  No vacío (≥{MIN_OPAQUE}px): {empty_ok}/{len(results)}")

    # ── DETALLE DE FALLOS ──
    if failures:
        print(f"\n  {'─'*50}")
        print(f"  ❌ FALLOS ({len(failures)} sprites)")
        print(f"  {'─'*50}")
        for r in failures:
            print(f"\n  ▸ {r['name']}")
            for f in r["failures"]:
                print(f"      {f}")

    # ── DETALLE DE AVISOS ──
    if warnings_only:
        print(f"\n  {'─'*50}")
        print(f"  ⚠️  AVISOS ({len(warnings_only)} sprites)")
        print(f"  {'─'*50}")
        for r in warnings_only:
            print(f"\n  ▸ {r['name']}")
            for w in r["warnings"]:
                print(f"      {w}")

    # ── ESTADÍSTICAS DE DISTRIBUCIÓN ──
    all_colors = [r.get("unique_colors", 0) for r in results if r.get("unique_colors")]
    all_bbox_w = [r["bbox"][2] for r in results if "bbox" in r]
    all_bbox_h = [r["bbox"][3] for r in results if "bbox" in r]
    all_opaque = [r.get("opaque_count", 0) for r in results]

    print(f"\n  {'─'*50}")
    print(f"  DISTRIBUCIONES")
    print(f"  {'─'*50}")
    if all_colors:
        sorted_colors = sorted(all_colors)
        print(f"  Colores/sprite:  mediana={sorted_colors[len(sorted_colors)//2]}, "
              f"min={min(all_colors)}, max={max(all_colors)}")
    if all_bbox_w:
        print(f"  BBox ancho:      min={min(all_bbox_w)}, max={max(all_bbox_w)}")
    if all_bbox_h:
        print(f"  BBox alto:       min={min(all_bbox_h)}, max={max(all_bbox_h)}")
    if all_opaque:
        print(f"  Píxeles opacos:  min={min(all_opaque)}, max={max(all_opaque)}")

    print()
    return len(clean) + len(warnings_only), len(failures)


def main():
    palette = load_palette()
    print(f"Paleta cargada: {len(palette)} colores desde {PALETTE_FILE}")

    # Determinar qué sprites auditar
    if len(sys.argv) > 1:
        ids = sys.argv[1:]
        paths = []
        for sid in ids:
            # Acepta con o sin .png
            if sid.endswith(".png"):
                p = ITEMS_DIR / sid
            else:
                p = ITEMS_DIR / f"{sid}.png"
            if not p.exists():
                print(f"⚠️  No existe: {p}")
                continue
            paths.append(p)
    else:
        paths = sorted(ITEMS_DIR.glob("*.png"))

    if not paths:
        print("No hay sprites que auditar.")
        return

    print(f"Auditando {len(paths)} sprite(s)...")

    results = []
    for p in paths:
        r = analyze_sprite(p, palette)
        results.append(r)

    passed, failed = print_report(results)

    # Código de salida
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
