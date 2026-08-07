#!/usr/bin/env python3
"""
Mide hechos reales sobre los PNG del juego para contrastar con la documentación.
No toca nada — solo imprime y guarda en /tmp/medida_contrato.txt.

Mide: contorno real, tamaños, colores por sprite, pitch 2, paleta de items.
"""

import json
import os
import sys
from collections import Counter, defaultdict
from statistics import median

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(REPO, "godot/art/sprites")
TILES_DIR = os.path.join(REPO, "godot/art/tiles")
PALETA_JSON = os.path.join(REPO, "art_reference/paleta_items.json")

OUTPUT = []


def p(*args, **kwargs):
    line = " ".join(str(a) for a in args)
    OUTPUT.append(line)
    print(line, **kwargs)


# ── helpers ────────────────────────────────────────────────────────────


def get_pngs_recursive(root):
    """Yield (rel_path, abs_path) for all .png files under root, excluding .import files."""
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root)
        for f in sorted(filenames):
            if f.endswith(".png") and not f.endswith(".png.import"):
                rel = os.path.join(rel_dir, f) if rel_dir != "." else f
                yield rel, os.path.join(dirpath, f)


def foldername(rel_root, rel_path):
    """Grupo del sprite: la carpeta inmediata bajo el root."""
    parts = rel_path.split(os.sep)
    if len(parts) == 1:
        return "(raíz)"
    return parts[0]


def contour_color_and_pct(img):
    """Devuelve (color_hex_mas_frecuente, porcentaje_de_borde) para los píxeles de borde."""
    w, h = img.size
    border_colors = Counter()
    px = img.load()
    total_border = 0

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # Verificar 4-conectividad: algún vecino con alpha 0
            is_border = False
            for nx, ny in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]:
                if 0 <= nx < w and 0 <= ny < h:
                    if px[nx, ny][3] == 0:
                        is_border = True
                        break
                else:
                    # Fuera del canvas = borde
                    is_border = True
                    break
            if is_border:
                border_colors[(r, g, b)] += 1
                total_border += 1

    if total_border == 0:
        return None, 0.0

    most_common, count = border_colors.most_common(1)[0]
    pct = 100.0 * count / total_border
    hex_color = "#{:02x}{:02x}{:02x}".format(*most_common)
    return hex_color, pct


def unique_colors_ignoring_alpha0(img):
    """Número de colores únicos ignorando píxeles con alpha=0."""
    colors = set()
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            colors.add((r, g, b))
    return len(colors)


def all_colors_ignoring_alpha0(img):
    """Set de todos los colores (r,g,b) ignorando alpha=0."""
    colors = set()
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            colors.add((r, g, b))
    return colors


def is_pitch2(img):
    """True si TODOS los píxeles están en bloques 2×2 idénticos (pitch 2)."""
    w, h = img.size
    if w % 2 != 0 or h % 2 != 0:
        return False
    px = img.load()
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            p00 = px[x, y]
            p10 = px[x + 1, y]
            p01 = px[x, y + 1]
            p11 = px[x + 1, y + 1]
            if p00 != p10 or p00 != p01 or p00 != p11:
                return False
    return True


# ── main ────────────────────────────────────────────────────────────────


def main():
    p("=" * 70)
    p("MEDICIÓN DEL CONTRATO DE ARTE —", os.path.basename(REPO))
    p("=" * 70)

    # Recolectar todos los PNGs
    all_pngs = {}
    for root, label in [(SPRITES_DIR, "sprites"), (TILES_DIR, "tiles")]:
        if not os.path.isdir(root):
            continue
        for rel, abspath in get_pngs_recursive(root):
            key = f"{label}/{rel}"
            all_pngs[key] = abspath

    p(f"\nTotal PNGs encontrados: {len(all_pngs)}")

    # Agrupar por carpeta
    by_folder = defaultdict(list)
    for key, abspath in all_pngs.items():
        folder = os.path.dirname(key)
        by_folder[folder].append((key, abspath))

    # ── (a) CONTORNO ──
    p("\n" + "─" * 40)
    p("(a) CONTORNO — color más frecuente de los píxeles de borde")
    p("─" * 40)
    contour_summary = {}
    for folder in sorted(by_folder):
        files = by_folder[folder]
        global_counter = Counter()
        for key, abspath in files:
            try:
                img = Image.open(abspath).convert("RGBA")
                hex_c, pct = contour_color_and_pct(img)
                if hex_c:
                    global_counter[hex_c] += 1
            except Exception as e:
                p(f"  ERROR {key}: {e}")
        if global_counter:
            top = global_counter.most_common(1)[0]
            total = sum(global_counter.values())
            p(f"  {folder}: {top[0]} en {top[1]}/{total} sprites ({100*top[1]/total:.1f}%)")
            contour_summary[folder] = (top[0], 100 * top[1] / total)
        else:
            p(f"  {folder}: sin píxeles de borde medibles")

    # ── (b) TAMAÑOS ──
    p("\n" + "─" * 40)
    p("(b) TAMAÑOS — 5 más comunes por carpeta")
    p("─" * 40)
    for folder in sorted(by_folder):
        size_counter = Counter()
        for key, abspath in by_folder[folder]:
            try:
                img = Image.open(abspath)
                size_counter[img.size] += 1
            except Exception:
                pass
        top5 = size_counter.most_common(5)
        parts = [f"{w}x{h} ({n})" for (w, h), n in top5]
        p(f"  {folder}: {', '.join(parts)}")

    # ── (c) COLORES POR SPRITE ──
    p("\n" + "─" * 40)
    p("(c) COLORES POR SPRITE — mínimo / mediana / máximo")
    p("─" * 40)
    for folder in sorted(by_folder):
        counts = []
        for key, abspath in by_folder[folder]:
            try:
                img = Image.open(abspath).convert("RGBA")
                counts.append(unique_colors_ignoring_alpha0(img))
            except Exception:
                pass
        if counts:
            p(f"  {folder}: {min(counts)} / {median(counts):.1f} / {max(counts)} "
              f"(n={len(counts)})")
        else:
            p(f"  {folder}: sin datos")

    # ── (d) PITCH 2 ──
    p("\n" + "─" * 40)
    p("(d) PITCH 2 — sprites con todos los píxeles en bloques 2×2 idénticos")
    p("─" * 40)
    pitch2_results = {}
    for folder in sorted(by_folder):
        total = 0
        pitch2 = 0
        skipped_odd = 0
        for key, abspath in by_folder[folder]:
            try:
                img = Image.open(abspath).convert("RGBA")
                w, h = img.size
                if w % 2 != 0 or h % 2 != 0:
                    skipped_odd += 1
                    continue
                total += 1
                if is_pitch2(img):
                    pitch2 += 1
            except Exception:
                pass
        p(f"  {folder}: {pitch2}/{total} pitch 2 ({skipped_odd} saltados por lado impar)")
        pitch2_results[folder] = (pitch2, total)

    total_p2 = sum(v[0] for v in pitch2_results.values())
    total_checked = sum(v[1] for v in pitch2_results.values())
    p(f"\n  TOTAL: {total_p2}/{total_checked} sprites son pitch 2")

    # ── (e) PALETA items ──
    p("\n" + "─" * 40)
    p("(e) PALETA — sprites/items/ vs paleta_items.json")
    p("─" * 40)

    all_item_colors = set()
    folder_key = "sprites/items"
    for key, abspath in by_folder.get(folder_key, []):
        try:
            img = Image.open(abspath).convert("RGBA")
            all_item_colors |= all_colors_ignoring_alpha0(img)
        except Exception:
            pass

    p(f"  Colores únicos totales en {folder_key}: {len(all_item_colors)}")

    # Cargar paleta de referencia
    if os.path.exists(PALETA_JSON):
        with open(PALETA_JSON) as f:
            paleta_data = json.load(f)
        paleta_colors = set()
        for hx in paleta_data.get("colores", []):
            hx = hx.lstrip("#")
            paleta_colors.add((int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16)))
        in_paleta = all_item_colors & paleta_colors
        outside = all_item_colors - paleta_colors
        p(f"  Colores en paleta_items.json: {len(paleta_colors)}")
        p(f"  Colores que ESTÁN en la paleta: {len(in_paleta)}")
        p(f"  Colores que se SALEN de la paleta: {len(outside)}")
        if outside:
            sample = sorted(outside)[:10]
            sample_hex = ["#{:02x}{:02x}{:02x}".format(*c) for c in sample]
            p(f"  Muestra de colores fuera: {sample_hex}")
    else:
        p(f"  ⚠ {PALETA_JSON} no encontrado")

    # ── Guardar ──
    out_path = "/tmp/medida_contrato.txt"
    with open(out_path, "w") as f:
        f.write("\n".join(OUTPUT))
    p(f"\nSalida guardada en {out_path}")


if __name__ == "__main__":
    main()
