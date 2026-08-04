#!/usr/bin/env python3
"""Vuelca a Catalogo_Maestro.xlsx lo que falte de godot/data/.

Lee los `.tres`, que es lo que carga el juego de verdad, y no los CSV intermedios
del generador: si algo se quedó por el camino, se nota aquí.

Solo AÑADE filas que no estén ya (por ID). Nunca reescribe ni reordena las que hay,
porque las columnas de arte están rellenadas a mano.

Los items nuevos entran marcados `⏳ FALTA SPRITE`: el arte se dibuja después.

    python3 tools/sync_excel.py [--seco]
"""
import pathlib
import re
import shutil
import sys

import openpyxl

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DATOS = RAIZ / "godot/data"
LIBRO = RAIZ / "Catalogo_Maestro.xlsx"

CATEGORIA = {0: "Primario", 1: "Procesado", 2: "Final", 3: "Moneda"}
ESTACION = {
    0: "—", 1: "Caldero", 2: "Forja Mística", 3: "Mesa Encantamiento",
    4: "Escritorio Escriba", 5: "Círculo Invocación", 6: "Biblioteca Arcana",
    7: "Observatorio Astral", 8: "Almacén", 9: "Mostrador",
}
FALTA = "⏳ FALTA SPRITE"


def campos(ruta: pathlib.Path) -> dict:
    """Los pares `clave = valor` de un .tres, más las rutas de sus ext_resource."""
    t = ruta.read_text(encoding="utf-8")
    d = {k: v.strip() for k, v in re.findall(r"^(\w+) = (.+)$", t, re.M)}
    d["_ext"] = dict(re.findall(r'\[ext_resource[^\]]*path="res://([^"]+)"[^\]]*id="([^"]+)"', t))
    d["_ext"] = {v: k for k, v in d["_ext"].items()}  # id -> path
    d["_texto"] = t
    return d


def cadena(v: str) -> str:
    v = (v or "").strip()
    if v.startswith('&"') or v.startswith('"'):
        return v.strip('&"')
    return v


def entero(v: str, por_defecto: int = 0) -> int:
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return por_defecto


def ref(d: dict, clave: str) -> str:
    """El id del recurso al que apunta `clave = ExtResource("x")`."""
    m = re.match(r'ExtResource\("([^"]+)"\)', d.get(clave, "") or "")
    if not m:
        return ""
    return pathlib.Path(d["_ext"].get(m.group(1), "")).stem


def ids_de(carpeta: str) -> dict:
    """id declarado -> campos, para toda una carpeta."""
    out = {}
    for f in sorted((DATOS / carpeta).glob("*.tres")):
        d = campos(f)
        sid = cadena(d.get("id", "")) or f.stem
        d["_fichero"] = f.stem
        out[sid] = d
    return out


def ingredientes(d: dict) -> str:
    ids = re.findall(r'ExtResource\("([^"]+)"\)', d.get("ingredients", ""))
    qty = [int(x) for x in re.findall(r"\d+", d.get("ingredient_quantities", ""))]
    partes = []
    for i, e in enumerate(ids):
        nombre = pathlib.Path(d["_ext"].get(e, "")).stem
        partes.append(f"{qty[i] if i < len(qty) else 1}× {nombre}")
    return " + ".join(partes)


def main() -> None:
    seco = "--seco" in sys.argv
    if not seco:
        copia = LIBRO.with_suffix(".xlsx.bak")
        shutil.copy2(LIBRO, copia)
        print(f"copia de seguridad -> {copia.name}")

    wb = openpyxl.load_workbook(LIBRO)
    total = 0

    def existentes(hoja):
        return {str(c[0].value).strip() for c in hoja.iter_rows(min_row=2, max_col=1) if c[0].value}

    # --- Items -------------------------------------------------------------
    hoja = wb["Items"]
    ya = existentes(hoja)
    nuevos = 0
    for sid, d in ids_de("items").items():
        if sid in ya:
            continue
        tiene_icono = "icon = ExtResource" in d["_texto"]
        hoja.append([
            sid, cadena(d.get("display_name", "")),
            CATEGORIA.get(entero(d.get("category", "0")), f"?{d.get('category')}"),
            entero(d.get("tier", "1")), "32×32 / 40×40", f"items/{sid}.png", "",
            cadena(d.get("description", "")),
            "✅ Obtainable" if tiene_icono else FALTA,
            "" if tiene_icono else "generado sin sprite",
            "static" if tiene_icono else "—", "—", "",
        ])
        nuevos += 1
    print(f"  Items            +{nuevos}")
    total += nuevos

    # --- Recetas -----------------------------------------------------------
    hoja = wb["Recetas"]
    ya = existentes(hoja)
    nuevos = 0
    for sid, d in ids_de("recipes").items():
        if sid in ya:
            continue
        hoja.append([
            sid, cadena(d.get("display_name", "")),
            ESTACION.get(entero(d.get("required_station_type", "0")), "?"),
            entero(d.get("tier", "1")), ingredientes(d),
            f"{entero(d.get('output_quantity', '1'), 1)}× {ref(d, 'output_item')}",
            entero(d.get("crafting_time", "0")), "—", "✅ Implementado", "",
        ])
        nuevos += 1
    print(f"  Recetas          +{nuevos}")
    total += nuevos

    # --- Investigaciones ---------------------------------------------------
    hoja = wb["Investigaciones"]
    ya = existentes(hoja)
    nuevos = 0
    for sid, d in ids_de("research").items():
        if sid in ya:
            continue
        prereq = [pathlib.Path(d["_ext"].get(e, "")).stem
                  for e in re.findall(r'ExtResource\("([^"]+)"\)', d.get("prerequisites", ""))]
        req_ids = re.findall(r'"([^"]+)"', d.get("required_item_ids", ""))
        req_qty = [int(x) for x in re.findall(r"\d+", d.get("required_item_qty", ""))]
        pide = " + ".join(f"{req_qty[i] if i < len(req_qty) else 1}× {n}"
                          for i, n in enumerate(req_ids))
        hoja.append([
            sid, cadena(d.get("display_name", "")), entero(d.get("tier", "1")),
            " + ".join(prereq) or "—",
            ESTACION.get(entero(d.get("required_station_type", "0")), "?"),
            entero(d.get("coin_cost", "0")), pide or "—",
            entero(d.get("research_time", "0")),
            f"receta: {ref(d, 'recipe_to_unlock')}" if ref(d, "recipe_to_unlock") else "—",
            "✅ Implementado",
        ])
        nuevos += 1
    print(f"  Investigaciones  +{nuevos}")
    total += nuevos

    # --- Pedidos -----------------------------------------------------------
    # A hoja aparte, y no a `Pedidos_Tipos`: esa es de diseño, lista arquetipos
    # ("Pedido de la Realeza") con rangos ("3-5", "20-40"). Volcarle los pedidos
    # concretos mezclaría dos cosas distintas y la dejaría inservible.
    if "Pedidos_Datos" not in wb.sheetnames:
        h = wb.create_sheet("Pedidos_Datos")
        h.append(["ID", "Nombre", "Cliente típico", "Pide", "Cantidad",
                  "Coins reward", "Rep reward", "Tier", "Estado", "Notas"])
    hoja = wb["Pedidos_Datos"]
    ya = existentes(hoja)
    nuevos = 0
    for sid, d in ids_de("orders").items():
        if sid in ya:
            continue
        hoja.append([
            sid, cadena(d.get("display_name", "")), "—", ref(d, "requested_item"),
            entero(d.get("requested_quantity", "1"), 1),
            entero(d.get("coin_reward", "0")), entero(d.get("reputation_reward", "0")),
            entero(d.get("tier", "1")), "Implementado",
            f"min_rep {entero(d.get('min_reputation', '0'))}",
        ])
        nuevos += 1
    print(f"  Pedidos_Datos    +{nuevos}")
    total += nuevos

    if seco:
        print(f"\n(en seco: {total} filas se habrían añadido)")
        return
    wb.save(LIBRO)
    print(f"\n{total} filas añadidas a {LIBRO.name}")


if __name__ == "__main__":
    main()
