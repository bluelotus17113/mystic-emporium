#!/usr/bin/env python3
"""Generador de contenido endgame para Mystic Emporium.

Lee CSVs de tools/content/ y emite .tres a godot/data/{items,recipes,orders,research}.
Idempotente: si el .tres destino existe, lo salta.
NUNCA escribe uid= en los ficheros generados.
"""

import csv
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CONTENT_DIR = PROJECT_ROOT / "tools" / "content"
DATA_DIR = PROJECT_ROOT / "godot" / "data"

OUTPUT_DIRS = {
    "items": DATA_DIR / "items",
    "recipes": DATA_DIR / "recipes",
    "orders": DATA_DIR / "orders",
    "research": DATA_DIR / "research",
}


def load_csv(name: str) -> list[dict]:
    """Lee un CSV y devuelve lista de diccionarios. Omite lineas vacias y comentarios #."""
    path = CONTENT_DIR / f"{name}.csv"
    if not path.exists():
        print(f"  [AVISO] No existe {path}")
        return []
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # saltar filas vacias o comentadas
            if not any(v.strip() for v in row.values()):
                continue
            if row.get("id", "").strip().startswith("#"):
                continue
            # limpiar espacios
            cleaned = {k.strip(): v.strip() for k, v in row.items()}
            rows.append(cleaned)
    return rows


def parse_pipe_pairs(raw: str) -> list[tuple[str, int]]:
    """Parsea 'madera_arcana:2|sal_abisal:1' → [('madera_arcana', 2), ('sal_abisal', 1)]."""
    if not raw or not raw.strip():
        return []
    pairs = []
    for segment in raw.split("|"):
        segment = segment.strip()
        if not segment:
            continue
        if ":" in segment:
            key, val = segment.split(":", 1)
            pairs.append((key.strip(), int(val.strip())))
        else:
            pairs.append((segment.strip(), 1))
    return pairs


def parse_id_list(raw: str) -> list[str]:
    """Parsea 'res_destilacion|res_alquimia_avanzada' → ['res_destilacion', 'res_alquimia_avanzada']."""
    if not raw or not raw.strip():
        return []
    return [s.strip() for s in raw.split("|") if s.strip()]


def existing_ids() -> dict[str, set[str]]:
    """Escanea ficheros .tres existentes y devuelve un set de ids por tipo."""
    ids: dict[str, set[str]] = {}
    for kind, d in OUTPUT_DIRS.items():
        ids[kind] = set()
        for tres in d.glob("*.tres"):
            ids[kind].add(tres.stem)
    return ids


def count_ext_resource_lines(lines: list[str]) -> int:
    """Cuenta cuantas lineas [ext_resource ...] hay."""
    return sum(1 for line in lines if line.startswith("[ext_resource "))


def write_item(row: dict) -> tuple[bool, str]:
    """Escribe un .tres de ItemData. Sin icono, sin uid. Retorna (creado, path)."""
    item_id = row["id"]
    out_path = OUTPUT_DIRS["items"] / f"{item_id}.tres"

    if out_path.exists():
        return False, f"  [SKIP] items/{item_id}.tres ya existe"

    max_stack = int(row.get("max_stack", 99))
    category = int(row["category"])
    base_value = int(row["base_value"])
    tier = int(row["tier"])

    lines: list[str] = []

    # header
    lines.append('[gd_resource type="Resource" script_class="ItemData" load_steps=2 format=3]')
    lines.append("")
    # solo un ext_resource: el script
    lines.append('[ext_resource type="Script" path="res://scripts/data/item_data.gd" id="1_id"]')
    lines.append("")
    # resource block
    lines.append("[resource]")
    lines.append('script = ExtResource("1_id")')
    lines.append(f'id = &"{item_id}"')
    lines.append(f'display_name = "{row["display_name"]}"')
    lines.append(f'description = "{row["description"]}"')
    lines.append(f"max_stack = {max_stack}")
    lines.append(f"category = {category}")
    lines.append(f"base_value = {base_value}")
    lines.append(f"tier = {tier}")
    lines.append("")

    content = "\n".join(lines)
    out_path.write_text(content, encoding="utf-8")
    return True, f"  [OK] items/{item_id}.tres (t{tier} cat{category} val{base_value})"


def write_recipe(row: dict) -> tuple[bool, str]:
    """Escribe un .tres de RecipeData sin uid. Retorna (creado, path)."""
    recipe_id = row["id"]
    out_path = OUTPUT_DIRS["recipes"] / f"{recipe_id}.tres"

    if out_path.exists():
        return False, f"  [SKIP] recipes/{recipe_id}.tres ya existe"

    ingredients = parse_pipe_pairs(row["ingredients"])
    output_item_id = row["output_item_id"]
    output_qty = int(row.get("output_quantity", 1))
    crafting_time = float(row["crafting_time"])
    station = int(row["required_station_type"])
    tier = int(row["tier"])
    unlocked = row.get("unlocked_by_default", "false").lower() == "true"
    display_name = row["display_name"]
    description = row.get("description", "")

    # Construir ext_resource lines
    ext_lines: list[str] = []
    # 1: script
    ext_lines.append('[ext_resource type="Script" path="res://scripts/data/recipe_data.gd" id="1_rd"]')
    # 2..N: ingredients
    ext_ids: list[str] = []
    ext_id_counter = 2
    for ing_id, _ in ingredients:
        ext_id = f"{ext_id_counter}_{ing_id[:4]}"
        ext_ids.append(ext_id)
        ext_lines.append(f'[ext_resource type="Resource" path="res://data/items/{ing_id}.tres" id="{ext_id}"]')
        ext_id_counter += 1
    # last: output item
    out_ext_id = f"{ext_id_counter}_out"
    ext_lines.append(f'[ext_resource type="Resource" path="res://data/items/{output_item_id}.tres" id="{out_ext_id}"]')

    n_ext = len(ext_lines)
    load_steps = 1 + n_ext

    lines: list[str] = []
    lines.append(f'[gd_resource type="Resource" script_class="RecipeData" load_steps={load_steps} format=3]')
    lines.append("")
    lines.extend(ext_lines)
    lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_rd")')
    lines.append(f'id = &"{recipe_id}"')
    lines.append(f'display_name = "{display_name}"')
    lines.append(f'description = "{description}"')

    # ingredients
    if len(ingredients) == 1:
        lines.append(f'ingredients = Array[ItemData]([ExtResource("{ext_ids[0]}")])')
    else:
        refs = ", ".join(f'ExtResource("{eid}")' for eid in ext_ids)
        lines.append(f"ingredients = Array[ItemData]([{refs}])")

    # quantities
    qty_str = ", ".join(str(q) for _, q in ingredients)
    if len(ingredients) == 1:
        lines.append(f"ingredient_quantities = Array[int]([{qty_str}])")
    else:
        lines.append(f"ingredient_quantities = Array[int]([{qty_str}])")

    lines.append(f'output_item = ExtResource("{out_ext_id}")')
    lines.append(f"output_quantity = {output_qty}")
    lines.append(f"crafting_time = {crafting_time}")
    lines.append(f"required_station_type = {station}")
    lines.append(f"unlocked_by_default = {'true' if unlocked else 'false'}")
    lines.append(f"tier = {tier}")
    lines.append("")

    content = "\n".join(lines)
    out_path.write_text(content, encoding="utf-8")
    return True, f"  [OK] recipes/{recipe_id}.tres (t{tier} st{station})"


def write_order(row: dict) -> tuple[bool, str]:
    """Escribe un .tres de OrderData sin uid. Retorna (creado, path)."""
    order_id = row["id"]
    out_path = OUTPUT_DIRS["orders"] / f"{order_id}.tres"

    if out_path.exists():
        return False, f"  [SKIP] orders/{order_id}.tres ya existe"

    item_id = row["requested_item_id"]
    qty = int(row.get("requested_quantity", 1))
    coin = int(row["coin_reward"])
    rep = int(row["reputation_reward"])
    time_lim = float(row.get("time_limit", 0.0))
    tier = int(row["tier"])
    min_rep = int(row.get("min_reputation", 0))
    display_name = row["display_name"]

    lines: list[str] = []
    lines.append('[gd_resource type="Resource" script_class="OrderData" load_steps=3 format=3]')
    lines.append("")
    lines.append('[ext_resource type="Script" path="res://scripts/data/order_data.gd" id="1_od"]')
    lines.append(f'[ext_resource type="Resource" path="res://data/items/{item_id}.tres" id="2_it"]')
    lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_od")')
    lines.append(f'id = &"{order_id}"')
    lines.append(f'display_name = "{display_name}"')
    lines.append(f'requested_item = ExtResource("2_it")')
    lines.append(f"requested_quantity = {qty}")
    lines.append(f"coin_reward = {coin}")
    lines.append(f"reputation_reward = {rep}")
    lines.append(f"time_limit = {time_lim}")
    lines.append(f"tier = {tier}")
    lines.append(f"min_reputation = {min_rep}")
    lines.append("")

    content = "\n".join(lines)
    out_path.write_text(content, encoding="utf-8")
    return True, f"  [OK] orders/{order_id}.tres (t{tier} rep{min_rep})"


def write_research(row: dict) -> tuple[bool, str]:
    """Escribe un .tres de ResearchData sin uid. Retorna (creado, path)."""
    res_id = row["id"]
    out_path = OUTPUT_DIRS["research"] / f"{res_id}.tres"

    if out_path.exists():
        return False, f"  [SKIP] research/{res_id}.tres ya existe"

    display_name = row["display_name"]
    description = row.get("description", "")
    prereq_ids = parse_id_list(row.get("prerequisites", ""))
    station = int(row["required_station_type"])
    research_time = float(row["research_time"])
    coin_cost = int(row["coin_cost"])
    req_item_pairs = parse_pipe_pairs(row.get("required_item_ids", ""))
    recipe_unlock = row.get("recipe_to_unlock_id", "")
    extra_recipes = parse_id_list(row.get("extra_recipes_to_unlock_ids", ""))
    tier = int(row["tier"])

    # Construir ext_resource lines
    ext_lines: list[str] = []
    ext_lines.append('[ext_resource type="Script" path="res://scripts/data/research_data.gd" id="1_re"]')

    ext_id_counter = 2
    prereq_ext_ids: list[str] = []

    # prerequisites → ext_resource a otros research
    for pr_id in prereq_ids:
        eid = f"{ext_id_counter}_pre"
        prereq_ext_ids.append(eid)
        ext_lines.append(f'[ext_resource type="Resource" path="res://data/research/{pr_id}.tres" id="{eid}"]')
        ext_id_counter += 1

    # recipe_to_unlock → ext_resource a recipe
    recipe_ext_id = ""
    if recipe_unlock:
        recipe_ext_id = f"{ext_id_counter}_rcp"
        ext_lines.append(f'[ext_resource type="Resource" path="res://data/recipes/{recipe_unlock}.tres" id="{recipe_ext_id}"]')
        ext_id_counter += 1

    # extra_recipes_to_unlock
    extra_ext_ids: list[str] = []
    for er_id in extra_recipes:
        eid = f"{ext_id_counter}_erc"
        extra_ext_ids.append(eid)
        ext_lines.append(f'[ext_resource type="Resource" path="res://data/recipes/{er_id}.tres" id="{eid}"]')
        ext_id_counter += 1

    n_ext = len(ext_lines)
    load_steps = 1 + n_ext

    lines: list[str] = []
    lines.append(f'[gd_resource type="Resource" script_class="ResearchData" load_steps={load_steps} format=3]')
    lines.append("")
    lines.extend(ext_lines)
    lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_re")')
    lines.append(f'id = &"{res_id}"')
    lines.append(f'display_name = "{display_name}"')
    lines.append(f'description = "{description}"')

    # prerequisites
    if prereq_ext_ids:
        if len(prereq_ext_ids) == 1:
            lines.append(f'prerequisites = Array[ResearchData]([ExtResource("{prereq_ext_ids[0]}")])')
        else:
            refs = ", ".join(f'ExtResource("{eid}")' for eid in prereq_ext_ids)
            lines.append(f"prerequisites = Array[ResearchData]([{refs}])")

    lines.append(f"required_station_type = {station}")
    lines.append(f"research_time = {research_time}")
    lines.append(f"coin_cost = {coin_cost}")
    lines.append("")

    # unlock
    if recipe_ext_id:
        lines.append(f'recipe_to_unlock = ExtResource("{recipe_ext_id}")')
    if extra_ext_ids:
        refs = ", ".join(f'ExtResource("{eid}")' for eid in extra_ext_ids)
        lines.append(f"extra_recipes_to_unlock = Array[RecipeData]([{refs}])")

    # required items
    if req_item_pairs:
        ids_str = ", ".join(f'"{p[0]}"' for p in req_item_pairs)
        qtys_str = ", ".join(str(p[1]) for p in req_item_pairs)
        lines.append(f"required_item_ids = PackedStringArray({ids_str})")
        lines.append(f"required_item_qty = PackedInt32Array({qtys_str})")

    lines.append(f"tier = {tier}")
    lines.append("")

    content = "\n".join(lines)
    out_path.write_text(content, encoding="utf-8")
    return True, f"  [OK] research/{res_id}.tres (t{tier} prereqs:{len(prereq_ids)})"


def main():
    print("=== Mystic Emporium Content Generator ===\n")

    # Escanear IDs existentes
    print("[1/5] Escaneando IDs existentes...")
    prev_ids = existing_ids()
    for kind in ["items", "recipes", "orders", "research"]:
        print(f"  {kind}: {len(prev_ids[kind])} existentes")
    print()

    count_created = {"items": 0, "recipes": 0, "orders": 0, "research": 0}
    count_skipped = {"items": 0, "recipes": 0, "orders": 0, "research": 0}

    # Items
    print("[2/5] Generando items...")
    for row in load_csv("items"):
        created, msg = write_item(row)
        print(msg)
        if created:
            count_created["items"] += 1
        else:
            count_skipped["items"] += 1
    print()

    # Recipes
    print("[3/5] Generando recetas...")
    for row in load_csv("recipes"):
        created, msg = write_recipe(row)
        print(msg)
        if created:
            count_created["recipes"] += 1
        else:
            count_skipped["recipes"] += 1
    print()

    # Orders
    print("[4/5] Generando pedidos...")
    for row in load_csv("orders"):
        created, msg = write_order(row)
        print(msg)
        if created:
            count_created["orders"] += 1
        else:
            count_skipped["orders"] += 1
    print()

    # Research
    print("[5/5] Generando investigaciones...")
    for row in load_csv("research"):
        created, msg = write_research(row)
        print(msg)
        if created:
            count_created["research"] += 1
        else:
            count_skipped["research"] += 1
    print()

    # Resumen
    print("=== RESUMEN ===")
    total_new = sum(count_created.values())
    total_skip = sum(count_skipped.values())
    print(f"  Creados: {total_new}  |  Saltados (ya existen): {total_skip}")
    for kind in ["items", "recipes", "orders", "research"]:
        print(f"    {kind}: +{count_created[kind]} nuevos, {count_skipped[kind]} saltados")

    if total_new == 0:
        print("\n  Nada que generar — todo el contenido ya existe.")
    else:
        print(f"\n  {total_new} ficheros .tres generados en godot/data/.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
