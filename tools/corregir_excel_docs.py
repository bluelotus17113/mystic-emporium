#!/usr/bin/env python3
"""
Corrige la documentación de Catalogo_Maestro.xlsx con lo MEDIDO.
Idempotente: ejecutarlo dos veces deja el libro igual.

Afecta SOLO a: Guia_Estilo, README, Revision_Perspectiva, PixelArt_TODO.
"""

import argparse
import os
import shutil
import sys
from copy import copy

import openpyxl

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XLSX = os.path.join(REPO, "Catalogo_Maestro.xlsx")
BAK = os.path.join(REPO, "Catalogo_Maestro.xlsx.bak")

# ── Constantes leídas del código ──
# tools/normalizar_sprite.py
LUZ_CONTORNO = 60
MAX_COLORES = 21

# tools/sprite_check_items.py
CONTOUR_COLOR = "#21181b"
CONTOUR_MIN_PCT = 55.0

# ── Datos medidos (PASO 1) ──
# Contorno en items: #21181b al 100%
# Pitch 2 en items: 0/131
# Colores en items: 5 / 11 / 21 (min/mediana/max)
# Paleta items: 53 colores, todos en paleta_items.json

# ── Conteo de contenido real ──
CONTEO = {
    "items": 131,
    "recetas": 111,
    "investigaciones": 40,
    "pedidos": 84,
    "construibles": 222,
}


def corregir_guia_estilo(wb):
    """Reescribe filas específicas de Guia_Estilo, añade 2 filas nuevas."""
    ws = wb["Guia_Estilo"]
    cambios = []

    # ── Fila 10: Contorno ──
    old = ws.cell(10, 2).value
    nuevo_contorno = (
        "Contorno #21181b (negro cálido) medido sobre los 131 sprites de items: "
        "100% de los píxeles de borde son #21181b. "
        "Excepción: píxeles con luminancia ≥ 60 (LUZ_CONTORNO en "
        "tools/normalizar_sprite.py) — metal brillante, cristal, sigilos "
        "luminosos — no se unifican; su borde claro es intencionado."
    )
    if old != nuevo_contorno:
        ws.cell(10, 2).value = nuevo_contorno
        cambios.append("Contorno")

    # ── Fila 7: Pitch unificado ──
    old = ws.cell(7, 2).value
    nuevo_pitch = (
        "REGLA MUERTA (ago 2026). 0 de 131 items cumplen pitch 2. "
        "Los assets se dibujan a resolución nativa; las escenas Godot escalan "
        "×2 NEAREST donde conviene (personajes 64×64, tiles Minish 16×16). "
        "El pitch 2 no se aplica ni se exige."
    )
    if old != nuevo_pitch:
        ws.cell(7, 2).value = nuevo_pitch
        cambios.append("Pitch unificado")

    # ── Fila 11: Paleta arcana ──
    old = ws.cell(11, 2).value
    nuevo_paleta = (
        "El contrato vigente de items es art_reference/paleta_items.json "
        "(53 colores medidos sobre los 131 PNGs, contorno #21181b). "
        "Los 53 colores de los items están contenidos al 100% en esa paleta. "
        "Púrpuras (#3a2058/#6e3aa0/#9d6dff/#c89bff) como ACENTO temático "
        "para magia/gemas/UI: siguen apareciendo en ~15-20 sprites."
    )
    if old != nuevo_paleta:
        ws.cell(11, 2).value = nuevo_paleta
        cambios.append("Paleta arcana")

    # ── Fila 23: Referencia de ESTILO ──
    old = ws.cell(23, 2).value
    nuevo_ref = (
        "DOS VÍAS de generación, elegidas según el tipo de asset:\n"
        "  1. CÓDIGO Python (tools/items_endgame.py, cozy_all/*.py): "
        "formas geométricas repetibles — minerales, lingotes, frascos, "
        "gemas, monedas. 38 de los últimos 45 items de endgame.\n"
        "  2. PixelLab bitforge: detalle orgánico — armaduras, telas, "
        "runas, criaturas. 7 de los últimos 45. Usa recortes de "
        "art_reference/mockup_estilo.png como style_image.\n"
        "Ambas vías comparten la paleta_items.json y pasan por "
        "tools/normalizar_sprite.py al finalizar."
    )
    if old != nuevo_ref:
        ws.cell(23, 2).value = nuevo_ref
        cambios.append("Referencia de ESTILO")

    # ── Añadir fila: Número de colores (después de fila 26, como fila 27) ──
    # Verificar si ya existe
    ya_existe_colores = False
    for r in range(1, ws.max_row + 1):
        if ws.cell(r, 1).value == "Número de colores":
            ya_existe_colores = True
            break

    if not ya_existe_colores:
        ws.insert_rows(27)
        ws.cell(27, 1).value = "Número de colores"
        ws.cell(27, 2).value = (
            "Rango real medido: 5–21 colores por sprite (mín–máx, ignorando "
            "alpha 0 y contorno #21181b). Techo impuesto por "
            "tools/normalizar_sprite.py: MAX_COLORES = 21. Sprites que excedan "
            "21 colores son cuantizados a la paleta."
        )
        # Copiar formato de la fila 26
        for c in range(1, 3):
            src = ws.cell(26, c)
            dst = ws.cell(27, c)
            if src.font:
                dst.font = copy(src.font)
            if src.fill:
                dst.fill = copy(src.fill)
            if src.alignment:
                dst.alignment = copy(src.alignment)
        cambios.append("Número de colores (nueva)")

    # ── Añadir fila: Verificación (después de Número de colores) ──
    ya_existe_verif = False
    for r in range(1, ws.max_row + 1):
        if ws.cell(r, 1).value == "Verificación":
            ya_existe_verif = True
            break

    if not ya_existe_verif:
        # Encontrar la fila de "Número de colores" para insertar después
        insert_after = None
        for r in range(1, ws.max_row + 1):
            if ws.cell(r, 1).value == "Número de colores":
                insert_after = r
                break
        if insert_after is None:
            insert_after = 27
        ws.insert_rows(insert_after + 1)
        ws.cell(insert_after + 1, 1).value = "Verificación"
        ws.cell(insert_after + 1, 2).value = (
            "Todo sprite de item pasa por tools/normalizar_sprite.py "
            "(unifica contorno, cuantiza colores, recorta padding) y luego "
            "tools/sprite_check_items.py que exige ≥ 55% de píxeles de borde "
            "en #21181b (CONTOUR_MIN_PCT = 55.0). Por debajo de ese umbral "
            "el checker rechaza el sprite."
        )
        for c in range(1, 3):
            src = ws.cell(insert_after, c)
            dst = ws.cell(insert_after + 1, c)
            if src.font:
                dst.font = copy(src.font)
            if src.fill:
                dst.fill = copy(src.fill)
            if src.alignment:
                dst.alignment = copy(src.alignment)
        cambios.append("Verificación (nueva)")

    return cambios


def corregir_readme(wb):
    """Actualiza versión, lista de hojas, tamaños, y recuento."""
    ws = wb["README"]
    cambios = []

    # ── 1. Versión y fecha ──
    old_ver = ws.cell(2, 1).value
    nueva_ver = "Versión: 1.1 — Generado 2026-08-05"
    if old_ver != nueva_ver:
        ws.cell(2, 1).value = nueva_ver
        cambios.append("Versión → 1.1")

    # ── 2. Convenciones de tamaño (rows 5-11) ──
    nuevas_conv = [
        "  • Personajes (protagonista, ayudantes, NPCs): 32×48 a 256×384 px (abanico real medido, 203 PNGs)",
        "  • Tiles del escenario (suelos, paredes): 64×64 px base; tiles Minish 16×16",
        "  • Edificios construibles: 18×18 a 64×64 px (abanico real medido, 251 PNGs en sprites/environment/)",
        "  • Items (iconos de inventario, recetas, pedidos): 32×32 px (131/131)",
        "  • VFX puntuales y partículas: generadas en runtime, no requieren PNG",
        "  • UI icons (action bar, badges, glyphs): 24×24 a 48×48 px",
    ]
    filas_conv = [5, 6, 7, 8, 9, 10]
    for i, (row, nuevo) in enumerate(zip(filas_conv, nuevas_conv)):
        old = ws.cell(row, 1).value
        if old != nuevo:
            ws.cell(row, 1).value = nuevo
            cambios.append(f"Tamaño fila {row}")

    # ── 3. Lista de hojas: reemplazar 14 entradas por 19 ──
    # Filas actuales: 33-46 (14 entradas), row 47 vacía, row 48+ otras secciones
    # Necesito 19 entradas → insertar 5 filas
    hojas_nuevas = [
        "  1. PixelArt_TODO    — campaña de sprites pendientes (CERRADA ago 2026)",
        "  2. README           — este documento, convenciones y guía rápida",
        "  3. Revision_Perspectiva — auditoría de isométrico→frontal (CERRADA ago 2026)",
        "  4. Guia_Estilo      — reglas detalladas de pixel art, contorno, paleta",
        "  5. Items            — todos los items consumibles, productos, materiales (32×32)",
        "  6. Personajes       — protagonista, ayudantes, compañero",
        "  7. NPCs_Clientes    — todos los tipos de cliente posibles",
        "  8. Edificios        — generadores, estaciones, decorativos, asedio",
        "  9. Tiles_Suelo      — pisos, caminos, parcelas",
        " 10. Tiles_Pared      — paredes, esquinas, puertas, ventanas",
        " 11. UI_Icons         — iconos de interfaz y badges",
        " 12. VFX              — efectos visuales (procedural, no requieren art)",
        " 13. Recetas          — qué fabrica qué, ingredientes y estación",
        " 14. Investigaciones  — árbol tecnológico, desbloqueos",
        " 15. Pedidos_Tipos    — variedad de pedidos posibles",
        " 16. Progresion       — tier y orden recomendado de desbloqueo",
        " 17. Eventos          — eventos aleatorios y temáticos (post-lanzamiento)",
        " 18. ModoCompañero    — sprites y widgets del Desktop Companion",
        " 19. Pedidos_Datos    — datos crudos de pedidos (cliente, item, recompensa)",
    ]

    # Verificar cuántas entradas hay actualmente contando desde row 33
    current_count = 0
    for r in range(33, ws.max_row + 1):
        v = ws.cell(r, 1).value
        if v and ("—" in str(v) or "--" in str(v)):
            current_count += 1
        else:
            break

    needed_insert = len(hojas_nuevas) - current_count

    if needed_insert > 0:
        # Insertar filas después de la última entrada actual (row 33 + current_count - 1)
        insert_at = 33 + current_count  # después de la última entrada, antes de la fila vacía
        for _ in range(needed_insert):
            ws.insert_rows(insert_at)
        cambios.append(f"Lista hojas: {needed_insert} filas insertadas")

    # Escribir las 19 entradas (si no están ya correctas)
    for i, texto in enumerate(hojas_nuevas):
        row = 33 + i
        old = ws.cell(row, 1).value
        if old != texto:
            ws.cell(row, 1).value = texto
            if f"hoja {i+1}" not in str(cambios):
                pass  # ya contabilizado

    # ── 4. Recuento real al final ──
    # Buscar si ya existe línea de recuento
    last_data_row = ws.max_row
    recuento_texto = (
        f"📊 Contenido real (ago 2026): {CONTEO['items']} items, "
        f"{CONTEO['recetas']} recetas, {CONTEO['investigaciones']} investigaciones, "
        f"{CONTEO['pedidos']} pedidos, {CONTEO['construibles']} construibles."
    )

    # Ver si ya está en alguna fila
    ya_existe_recuento = False
    for r in range(1, ws.max_row + 1):
        v = ws.cell(r, 1).value
        if v and "Contenido real" in str(v):
            ya_existe_recuento = True
            if v != recuento_texto:
                ws.cell(r, 1).value = recuento_texto
                cambios.append("Recuento actualizado")
            break

    if not ya_existe_recuento:
        # Añadir al final
        new_row = ws.max_row + 1
        ws.cell(new_row, 1).value = recuento_texto
        cambios.append("Recuento añadido")

    return cambios


def cerrar_hoja_si_completada(wb, sheet_name):
    """Inserta fila de cierre si todas las filas de datos están completadas."""
    ws = wb[sheet_name]
    not_done = []

    # Detectar si ya está cerrada
    primera_fila = ws.cell(1, 1).value
    if primera_fila and "CERRADA" in str(primera_fila):
        return True, []

    # Verificar merged cells antes de insertar
    if list(ws.merged_cells.ranges):
        return False, [("ERROR", f"merged cells detected: {list(ws.merged_cells.ranges)}")]

    # Encontrar dónde empiezan los datos (primera fila que NO es cabecera)
    if sheet_name == "Revision_Perspectiva":
        data_start = None
        for r in range(1, ws.max_row + 1):
            v = ws.cell(r, 1).value
            # La cabecera de datos real tiene "Archivo PNG" en col A
            if v and "Archivo PNG" in str(v):
                data_start = r + 1
                break
        if data_start is None:
            data_start = 4  # fallback
        for r in range(data_start, ws.max_row + 1):
            estado = ws.cell(r, 5).value
            archivo = ws.cell(r, 1).value
            if not estado or not archivo:
                continue
            if "✅" not in str(estado) and "⚪ N/A" not in str(estado):
                not_done.append((r, archivo, estado))
    elif sheet_name == "PixelArt_TODO":
        data_start = None
        for r in range(1, ws.max_row + 1):
            v = ws.cell(r, 1).value
            if v and str(v).strip() == "TIPO":
                data_start = r + 1
                break
        if data_start is None:
            data_start = 2
        for r in range(data_start, ws.max_row + 1):
            estado = ws.cell(r, 6).value
            tid = ws.cell(r, 2).value
            nombre = ws.cell(r, 1).value
            # Filas sin tipo/ID no son datos (separadores, notas)
            if not tid and not nombre:
                continue
            if nombre and "Resto del" in str(nombre):
                continue  # nota histórica, no es tarea pendiente
            if not estado:
                not_done.append((r, tid, "(vacío)"))
                continue
            if "✅" not in str(estado):
                not_done.append((r, tid, estado))

    if not_done:
        return False, not_done

    # Insertar fila al principio
    ws.insert_rows(1)
    ws.cell(1, 1).value = (
        f"CERRADA (2026-08-05) — todas las filas completadas, "
        f"se conserva como histórico."
    )
    # Copiar formato de lo que antes era la fila 1 (ahora fila 2)
    for c in range(1, ws.max_column + 1):
        src = ws.cell(2, c)
        dst = ws.cell(1, c)
        if src.font:
            dst.font = copy(src.font)
        if src.fill:
            dst.fill = copy(src.fill)
    return True, []


def main():
    parser = argparse.ArgumentParser(description="Corrige documentación de Catalogo_Maestro.xlsx")
    parser.add_argument("--seco", action="store_true", help="Solo informe, no guarda")
    args = parser.parse_args()

    if not os.path.exists(XLSX):
        print(f"ERROR: no encuentro {XLSX}")
        sys.exit(1)

    print(f"Abriendo {XLSX} ...")
    wb = openpyxl.load_workbook(XLSX)

    # ── Guia_Estilo ──
    print("\n── Guia_Estilo ──")
    g_cambios = corregir_guia_estilo(wb)
    for c in g_cambios:
        print(f"  ✓ {c}")

    # ── README ──
    print("\n── README ──")
    r_cambios = corregir_readme(wb)
    for c in r_cambios:
        print(f"  ✓ {c}")

    # ── Cierre de hojas ──
    print("\n── CIERRES ──")
    for sname in ["Revision_Perspectiva", "PixelArt_TODO"]:
        was_already = bool(
            wb[sname].cell(1, 1).value
            and "CERRADA" in str(wb[sname].cell(1, 1).value)
        )
        cerrada, pendientes = cerrar_hoja_si_completada(wb, sname)
        if cerrada and not pendientes:
            if was_already:
                print(f"  ✓ {sname}: ya estaba cerrada")
            else:
                print(f"  ✓ {sname}: CERRADA (fila añadida)")
        else:
            print(f"  ✗ {sname}: NO cerrada — {len(pendientes)} filas pendientes")
            for r, rid, est in pendientes[:5]:
                print(f"      Row {r}: {rid} → {est}")

    # ── Guardar ──
    if args.seco:
        print("\n⚠ MODO SECO: no se ha modificado el fichero.")
    else:
        print(f"\nCopiando backup a {BAK} ...")
        shutil.copy2(XLSX, BAK)
        print(f"Guardando {XLSX} ...")
        wb.save(XLSX)
        print("Hecho.")

    # ── Informe final ──
    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)
    print(f"  Guia_Estilo: {len(g_cambios)} cambios")
    print(f"  README: {len(r_cambios)} cambios")
    print(f"  Contenido: {CONTEO['items']} items, {CONTEO['recetas']} recetas, "
          f"{CONTEO['investigaciones']} investigaciones, {CONTEO['pedidos']} pedidos, "
          f"{CONTEO['construibles']} construibles")


if __name__ == "__main__":
    main()
