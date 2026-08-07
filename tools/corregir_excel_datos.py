#!/usr/bin/env python3
"""
Corrige Catalogo_Maestro.xlsx — 4 arreglos sobre datos del juego.
Idempotente: ejecutarlo dos veces deja el libro igual.

Uso:
  python3 tools/corregir_excel_datos.py --seco    # Solo informe, no guarda
  python3 tools/corregir_excel_datos.py            # Aplica cambios
"""

import argparse
import os
import re
import shutil
import sys
from collections import Counter
from copy import copy

import openpyxl
from openpyxl.utils import get_column_letter
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XLSX = os.path.join(REPO, "Catalogo_Maestro.xlsx")
BAK = os.path.join(REPO, "Catalogo_Maestro.xlsx.bak")
ITEMS_PNG_DIR = os.path.join(REPO, "godot/art/sprites/items")
RECIPES_DIR = os.path.join(REPO, "godot/data/recipes")
BUILDABLES_DIR = os.path.join(REPO, "godot/data/buildables")
ORDERS_DIR = os.path.join(REPO, "godot/data/orders")
ITEMS_DATA_DIR = os.path.join(REPO, "godot/data/items")

CONTOUR_COLOR = (0x21, 0x18, 0x1B)  # #21181b

# ── helpers ────────────────────────────────────────────────────────────


def resolve_extresource(tres_path, ext_id):
    """Dado un .tres y un id de ext_resource, devuelve el id interno del
    recurso apuntado (leyendo la linea `id = &\"...\"` del fichero destino)."""
    with open(tres_path) as f:
        content = f.read()
    m = re.search(
        rf'\[ext_resource[^]]*id="{re.escape(ext_id)}"[^]]*path="([^"]+)"', content
    )
    if not m:
        return None
    res_path = m.group(1)
    if res_path.startswith("res://"):
        res_path = os.path.join(REPO, "godot", res_path[6:])
    if not os.path.exists(res_path):
        return None
    with open(res_path) as f2:
        c2 = f2.read()
    id_m = re.search(r'id = &"([^"]+)"', c2)
    return id_m.group(1) if id_m else None


def find_item_sources(item_id):
    """Busca item_id como SALIDA en recipes, buildables y orders.
    Devuelve lista de (tipo, fichero, id_receta/buildable/order)."""
    found = []

    # Recipes
    for fname in sorted(os.listdir(RECIPES_DIR)):
        if not fname.endswith(".tres"):
            continue
        path = os.path.join(RECIPES_DIR, fname)
        with open(path) as fh:
            content = fh.read()
        m = re.search(r'output_item\s*=\s*ExtResource\("([^"]+)"\)', content)
        if m:
            resolved = resolve_extresource(path, m.group(1))
            if resolved == item_id:
                rec_id = re.search(r'id = &"([^"]+)"', content)
                found.append(
                    ("recipe", fname, rec_id.group(1) if rec_id else "?")
                )

    # Buildables (algunos generadores producen items directamente)
    for fname in sorted(os.listdir(BUILDABLES_DIR)):
        if not fname.endswith(".tres"):
            continue
        path = os.path.join(BUILDABLES_DIR, fname)
        with open(path) as fh:
            content = fh.read()
        m = re.search(r'output_item\s*=\s*ExtResource\("([^"]+)"\)', content)
        if m:
            resolved = resolve_extresource(path, m.group(1))
            if resolved == item_id:
                bid = re.search(r'id = &"([^"]+)"', content)
                found.append(
                    ("buildable", fname, bid.group(1) if bid else "?")
                )

    # Orders
    for fname in sorted(os.listdir(ORDERS_DIR)):
        if not fname.endswith(".tres"):
            continue
        path = os.path.join(ORDERS_DIR, fname)
        with open(path) as fh:
            content = fh.read()
        m = re.search(r'requested_item\s*=\s*ExtResource\("([^"]+)"\)', content)
        if m:
            resolved = resolve_extresource(path, m.group(1))
            if resolved == item_id:
                oid = re.search(r'id = &"([^"]+)"', content)
                found.append(
                    ("order", fname, oid.group(1) if oid else "?")
                )

    return found


def deduce_buildable_category(build_id, tres_content):
    """Deduce categoría para un buildable a partir del .tres o del prefijo."""
    # 1) decoration_category
    m = re.search(r'decoration_category\s*=\s*&"([^"]+)"', tres_content)
    if m:
        cat = m.group(1)
        # Mapear a nombres legibles
        MAP = {
            "nature": "Decoración Natural",
            "wall": "Decoración Pared",
            "table": "Decoración Mesa",
            "floor": "Decoración Suelo",
            "luz": "Decoración Luz",
        }
        return MAP.get(cat, f"Decoración {cat.title()}")

    # 2) Prefijo del id
    if build_id.startswith("build_generador_"):
        return "Generador"
    if build_id.startswith("build_siege_"):
        return "Asedio"
    if build_id.startswith("build_"):
        # build_caldero, build_biblioteca, etc. -> Estación
        # Chequeamos si tiene recipe o producción
        return "Estación"
    if build_id.startswith("deco_"):
        return "Decoración"

    return ""


def deduce_zone(build_id, tres_content):
    """Deduce la zona para un buildable."""
    if "generador_" in build_id:
        return "Patio Natural"
    # allowed_zone
    m = re.search(r'allowed_zone\s*=\s*(\d+)', tres_content)
    if m:
        zone = int(m.group(1))
        if zone == 1:
            return "Patio Natural"
        elif zone == 2:
            return "Taller"
    return ""


def get_icon_path_from_tres(tres_content):
    """Extrae la ruta del icono/sprite del bloque [ext_resource ... type="Texture2D" ...]."""
    # Buscar ext_resource de tipo Texture2D
    for m in re.finditer(
        r'\[ext_resource[^]]*type="Texture2D"[^]]*path="([^"]+)"[^]]*\]', tres_content
    ):
        path = m.group(1)
        if path.startswith("res://art/"):
            return path[len("res://art/"):]
    return ""


def get_top_colors(png_path, n=3):
    """Abre el PNG, descarta alpha=0 y el color de contorno, devuelve los
    N colores más frecuentes como lista de '#rrggbb'."""
    img = Image.open(png_path).convert("RGBA")
    pixels = img.getdata()
    color_counts = Counter()
    for r, g, b, a in pixels:
        if a == 0:
            continue
        if (r, g, b) == CONTOUR_COLOR:
            continue
        color_counts[(r, g, b)] += 1
    top = color_counts.most_common(n)
    return ["#{:02x}{:02x}{:02x}".format(*color) for color, _ in top]


# ── ARREGLOS ───────────────────────────────────────────────────────────


def arreglo_1_filenames(ws):
    """Corrige columna F (Filename sugerido) para que apunte a sprites/items/<ID>.png"""
    corregidas = 0
    sin_png = []
    for r in range(2, ws.max_row + 1):
        item_id = ws.cell(r, 1).value
        if not item_id:
            continue
        png_path = os.path.join(ITEMS_PNG_DIR, f"{item_id}.png")
        expected = f"sprites/items/{item_id}.png"
        if os.path.exists(png_path):
            current = ws.cell(r, 6).value
            if current != expected:
                ws.cell(r, 6).value = expected
                corregidas += 1
        else:
            sin_png.append(item_id)
    return corregidas, sin_png


def arreglo_2_colores(ws):
    """Rellena columna G (Color/Tema) con los 3 colores más frecuentes del PNG."""
    rellenadas = 0
    sin_png = []
    for r in range(2, ws.max_row + 1):
        item_id = ws.cell(r, 1).value
        if not item_id:
            continue
        png_path = os.path.join(ITEMS_PNG_DIR, f"{item_id}.png")
        if os.path.exists(png_path):
            colors = get_top_colors(png_path, 3)
            val = " + ".join(colors)
            current = ws.cell(r, 7).value
            if current != val:
                ws.cell(r, 7).value = val
                rellenadas += 1
        else:
            sin_png.append(item_id)
    return rellenadas, sin_png


def arreglo_3_sin_fuente(ws):
    """Revisa los 4 items 'Sin fuente' por si ya aparecen como salida."""
    sin_fuente_ids = ["arcane_coin", "cristal_reputacion", "token_evento", "vale_gremio"]
    cambiados = []
    for r in range(2, ws.max_row + 1):
        item_id = ws.cell(r, 1).value
        if item_id not in sin_fuente_ids:
            continue
        sources = find_item_sources(item_id)
        if sources:
            # Cambiar estado y limpiar nota
            ws.cell(r, 9).value = "✅ Obtainable"
            ws.cell(r, 10).value = None
            cambiados.append((item_id, sources))
    return cambiados


def arreglo_4_buildables(ws):
    """Añade filas para los construibles que están en el juego pero no en la hoja."""
    # Leer IDs existentes en la hoja
    excel_ids = set()
    for r in range(2, ws.max_row + 1):
        vid = ws.cell(r, 1).value
        if vid:
            excel_ids.add(vid)

    # Leer todos los buildables del juego
    game_buildables = {}
    for fname in sorted(os.listdir(BUILDABLES_DIR)):
        if not fname.endswith(".tres"):
            continue
        path = os.path.join(BUILDABLES_DIR, fname)
        with open(path) as fh:
            content = fh.read()
        m = re.search(r'id = &"([^"]+)"', content)
        if not m:
            continue
        bid = m.group(1)
        game_buildables[bid] = content

    # Encontrar los que faltan
    missing_ids = sorted(set(game_buildables) - excel_ids)

    # Para copiar formato: usar la fila 2 como referencia
    ref_row = 2
    style_refs = {}
    for col in range(1, ws.max_column + 1):
        cell = ws.cell(ref_row, col)
        if cell.fill and cell.fill.fgColor and cell.fill.fgColor.rgb != "00000000":
            style_refs["fill"] = copy(cell.fill)
        if cell.font:
            style_refs["font"] = copy(cell.font)
        if cell.alignment:
            style_refs["alignment"] = copy(cell.alignment)
        if cell.border:
            style_refs["border"] = copy(cell.border)

    # Categorías deducidas para el informe
    deduced_categories = []
    zonas_vacias = 0
    start_row = ws.max_row + 1

    for bid in missing_ids:
        content = game_buildables[bid]
        r = ws.max_row + 1

        # ID
        ws.cell(r, 1).value = bid

        # Nombre
        dm = re.search(r'display_name\s*=\s*"([^"]*)"', content)
        ws.cell(r, 2).value = dm.group(1) if dm else bid

        # Categoría
        cat = deduce_buildable_category(bid, content)
        if cat and "deduc" in cat.lower():
            pass  # not applicable
        if cat and ("Generador" in cat or "Asedio" in cat):
            deduced_categories.append(f"{bid} -> {cat}")
        ws.cell(r, 3).value = cat

        # Zona
        zone = deduce_zone(bid, content)
        ws.cell(r, 4).value = zone
        if not zone:
            zonas_vacias += 1

        # Tier
        tm = re.search(r'tier\s*=\s*(\d+)', content)
        ws.cell(r, 5).value = int(tm.group(1)) if tm else None

        # Tamaño -> vacío
        ws.cell(r, 6).value = None

        # Filename sugerido -> del icono
        icon_path = get_icon_path_from_tres(content)
        ws.cell(r, 7).value = icon_path if icon_path else None

        # Color/Tema -> vacío
        ws.cell(r, 8).value = None

        # Función -> description
        descm = re.search(r'description\s*=\s*"([^"]*)"', content)
        ws.cell(r, 9).value = descm.group(1) if descm else None

        # Estado
        has_sprite = bool(icon_path)
        ws.cell(r, 10).value = "✅ Hecho" if has_sprite else "⏳ FALTA SPRITE"

        # Notas, Animación, Descripción Sprite -> vacías
        ws.cell(r, 11).value = None
        ws.cell(r, 12).value = None
        ws.cell(r, 13).value = None

        # Copiar estilo de la fila de referencia
        for col_idx in range(1, ws.max_column + 1):
            cell = ws.cell(r, col_idx)
            for attr in ("fill", "font", "alignment", "border"):
                if attr in style_refs:
                    setattr(cell, attr, copy(style_refs[attr]))

    return len(missing_ids), deduced_categories, zonas_vacias


# ── main ────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(description="Corrige Catalogo_Maestro.xlsx")
    parser.add_argument("--seco", action="store_true", help="Solo informe, no guarda")
    args = parser.parse_args()

    if not os.path.exists(XLSX):
        print(f"ERROR: no encuentro {XLSX}")
        sys.exit(1)

    print(f"Abriendo {XLSX} ...")
    wb = openpyxl.load_workbook(XLSX)

    # ── Arreglo 1 ──
    print("\n── ARREGLO 1: Filename sugerido ──")
    ws_items = wb["Items"]
    r1_corr, r1_sin = arreglo_1_filenames(ws_items)

    # ── Arreglo 2 ──
    print("── ARREGLO 2: Color/Tema ──")
    r2_rell, r2_sin = arreglo_2_colores(ws_items)

    # ── Arreglo 3 ──
    print("── ARREGLO 3: Sin fuente ──")
    r3_cambiados = arreglo_3_sin_fuente(ws_items)

    # ── Arreglo 4 ──
    print("── ARREGLO 4: Buildables ──")
    ws_edif = wb["Edificios"]
    # Verificar columnas
    if ws_edif.max_column < 13:
        print("  ERROR: la hoja Edificios tiene menos de 13 columnas")
        sys.exit(1)
    r4_n, r4_cats, r4_zonas_vacias = arreglo_4_buildables(ws_edif)

    # ── Informe ──
    print("\n" + "=" * 60)
    print("INFORME")
    print("=" * 60)

    print(f"\nARREGLO 1: {r1_corr} rutas corregidas, {len(r1_sin)} sin PNG"
          f" -> {r1_sin if r1_sin else '[]'}")

    print(f"ARREGLO 2: {r2_rell} celdas rellenadas, {len(r2_sin)} sin PNG")

    if r3_cambiados:
        lines = []
        for item_id, sources in r3_cambiados:
            src_str = ", ".join(f"{t}:{f}" for t, f, rid in sources)
            lines.append(f"{item_id} ({src_str})")
        print(f"ARREGLO 3: {lines}")
    else:
        print("ARREGLO 3: ninguno cambia")

    print(f"ARREGLO 4: {r4_n} filas añadidas.")
    if r4_cats:
        print(f"  Categorías deducidas por prefijo: {r4_cats}")
    else:
        print("  Categorías deducidas por prefijo: ninguna (todas por campo o decoración)")
    print(f"  Zonas dejadas vacías: {r4_zonas_vacias}")

    # ── Guardar ──
    if args.seco:
        print("\n⚠ MODO SECO: no se ha modificado el fichero.")
    else:
        # Backup
        print(f"\nCopiando backup a {BAK} ...")
        shutil.copy2(XLSX, BAK)
        print(f"Guardando {XLSX} ...")
        wb.save(XLSX)
        print("Hecho.")

    # ── Verificar idempotencia ──
    print("\n── Verificación de idempotencia ──")
    wb2 = openpyxl.load_workbook(XLSX)
    ws2 = wb2["Items"]
    r1b_corr, _ = arreglo_1_filenames(ws2)
    r2b_rell, _ = arreglo_2_colores(ws2)
    r3b = arreglo_3_sin_fuente(ws2)

    ws2e = wb2["Edificios"]
    excel_ids_2 = set()
    for r in range(2, ws2e.max_row + 1):
        vid = ws2e.cell(r, 1).value
        if vid:
            excel_ids_2.add(vid)
    game_ids = set()
    for fname in os.listdir(BUILDABLES_DIR):
        if not fname.endswith(".tres"):
            continue
        path = os.path.join(BUILDABLES_DIR, fname)
        with open(path) as fh:
            content = fh.read()
        m = re.search(r'id = &"([^"]+)"', content)
        if m:
            game_ids.add(m.group(1))
    r4_missing = game_ids - excel_ids_2

    idemp = r1b_corr == 0 and r2b_rell == 0 and len(r3b) == 0 and len(r4_missing) == 0
    print(f"  ARREGLO 1: {r1b_corr} cambios (0 = idempotente)")
    print(f"  ARREGLO 2: {r2b_rell} cambios (0 = idempotente)")
    print(f"  ARREGLO 3: {len(r3b)} cambios (0 = idempotente)")
    print(f"  ARREGLO 4: {len(r4_missing)} faltantes (0 = idempotente)")
    print(f"\nSCRIPT: tools/corregir_excel_datos.py, idempotente {'sí' if idemp else 'NO'}")


if __name__ == "__main__":
    main()
