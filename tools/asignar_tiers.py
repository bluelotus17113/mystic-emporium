#!/usr/bin/env python3
"""
Asigna `tier = N` a recetas, pedidos e investigaciones que no lo tienen.

Reglas:
  - receta -> tier del item que produce (output_item)
  - pedido -> tier del item que pide (requested_item)
  - investigacion -> tier de la receta que desbloquea; si no desbloquea ninguna,
    el mayor tier de los items que exige.

Solo toca ficheros en godot/data/recipes/, godot/data/orders/, godot/data/research/.
Añade EXACTAMENTE una linea `tier = N` en la seccion [resource].
"""

import os
import re
import sys
from pathlib import Path
from collections import defaultdict

GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"
DATA_DIR = GODOT_DIR / "data"


def parse_tres(text: str) -> dict:
    """Parse a .tres file into structured data."""
    result = {"ext_resources": {}, "resource": {}, "raw_lines": text.splitlines()}
    lines = result["raw_lines"]
    mode = "header"

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("[ext_resource "):
            m = re.findall(r'(\w+)=\s*"(.*?)"', stripped)
            attrs = dict(m)
            eid = attrs.get("id", "")
            result["ext_resources"][eid] = {
                "type": attrs.get("type", ""),
                "path": attrs.get("path", ""),
                "uid": attrs.get("uid", ""),
            }
            continue

        if stripped == "[resource]":
            mode = "resource"
            continue

        if stripped.startswith("[") and stripped.endswith("]"):
            mode = "other"
            continue

        if mode == "resource" and "=" in stripped and not stripped.startswith(";"):
            key, _, value = stripped.partition("=")
            key = key.strip()
            value = value.strip()
            result["resource"][key] = value

    return result


def resolve_ext_resource_path(ext_resources: dict, ref_str: str) -> str:
    """Given 'ExtResource("2_mad")', return the path from ext_resources map."""
    m = re.match(r'ExtResource\("(.+?)"\)', ref_str)
    if not m:
        return ""
    eid = m.group(1)
    return ext_resources.get(eid, {}).get("path", "")


def load_all_items():
    """Returns {item_path: {tier, id, ...}} and {item_id: {tier, ...}}"""
    items_by_path = {}
    items_by_id = {}
    items_dir = DATA_DIR / "items"
    for fpath in sorted(items_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        item_id = res.get("id", "").strip('&"')
        tier_raw = res.get("tier", "-1")
        tier = int(tier_raw) if tier_raw.lstrip("-").isdigit() else -1
        rel = str(fpath.relative_to(GODOT_DIR))
        path = f"res://{rel}"
        items_by_path[path] = {"id": item_id, "tier": tier}
        items_by_id[item_id] = {"path": path, "tier": tier}
    return items_by_path, items_by_id


def load_all_recipes(items_by_path):
    """Returns {recipe_id: {tier, file, ...}} and {recipe_path: recipe_id}"""
    recipes = {}
    recipes_by_path = {}
    recipes_dir = DATA_DIR / "recipes"
    for fpath in sorted(recipes_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]
        recipe_id = res.get("id", "").strip('&"')
        tier_raw = res.get("tier", "-1")
        tier = int(tier_raw) if tier_raw.lstrip("-").isdigit() else -1

        # resolve output item
        output_raw = res.get("output_item", "")
        output_path = resolve_ext_resource_path(ext, output_raw)
        output_item = items_by_path.get(output_path, {})

        rel = str(fpath.relative_to(GODOT_DIR))
        path = f"res://{rel}"

        recipes[recipe_id] = {
            "file": str(fpath),
            "tier": tier,
            "output_item_path": output_path,
            "output_item_tier": output_item.get("tier", -1),
            "output_item_id": output_item.get("id", ""),
        }
        recipes_by_path[path] = recipe_id
    return recipes, recipes_by_path


def load_all_orders(items_by_path):
    """Returns {order_id: {tier, file, ...}}"""
    orders = {}
    orders_dir = DATA_DIR / "orders"
    for fpath in sorted(orders_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]
        order_id = res.get("id", "").strip('&"')
        tier_raw = res.get("tier", "-1")
        tier = int(tier_raw) if tier_raw.lstrip("-").isdigit() else -1

        requested_raw = res.get("requested_item", "")
        requested_path = resolve_ext_resource_path(ext, requested_raw)
        requested_item = items_by_path.get(requested_path, {})

        orders[order_id] = {
            "file": str(fpath),
            "tier": tier,
            "requested_item_path": requested_path,
            "requested_item_tier": requested_item.get("tier", -1),
        }
    return orders


def load_all_research(items_by_path, recipes_by_path):
    """Returns {research_id: {tier, file, ...}}"""
    research = {}
    research_dir = DATA_DIR / "research"
    for fpath in sorted(research_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]
        research_id = res.get("id", "").strip('&"')
        tier_raw = res.get("tier", "-1")
        tier = int(tier_raw) if tier_raw.lstrip("-").isdigit() else -1

        recipe_raw = res.get("recipe_to_unlock", "")
        recipe_path = resolve_ext_resource_path(ext, recipe_raw)
        recipe_id = recipes_by_path.get(recipe_path, "")

        # required_item_ids for fallback tier
        req_ids_raw = res.get("required_item_ids", "")
        # Parse PackedStringArray("id1", "id2")
        req_ids = re.findall(r'"([^"]+)"', req_ids_raw)

        research[research_id] = {
            "file": str(fpath),
            "tier": tier,
            "recipe_to_unlock_path": recipe_path,
            "recipe_to_unlock_id": recipe_id,
            "required_item_ids": req_ids,
        }
    return research


def find_tier_position(lines: list) -> int:
    """
    Find the right position to insert `tier = N`.
    Strategy: insert after the last non-tier property line before a blank line
    or at the end. But to be consistent with sibling files, find where tier
    appears in similar files and match that position.

    Actually simpler: insert right before the first blank line in the [resource]
    section, or at the end of the file if no blank line.
    """
    in_resource = False
    last_non_blank_resource_line = -1

    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "[resource]":
            in_resource = True
            continue
        if in_resource and stripped.startswith("[") and stripped.endswith("]"):
            break
        if in_resource and stripped != "":
            last_non_blank_resource_line = i

    # Insert after the last non-blank line in resource section
    if last_non_blank_resource_line >= 0:
        return last_non_blank_resource_line + 1
    return len(lines)


def add_tier_to_file(filepath: str, tier: int):
    """Add `tier = N` line to a .tres file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()

    # Check if tier already exists
    for line in lines:
        if re.match(r'^\s*tier\s*=', line):
            print(f"  SKIP {filepath}: ya tiene tier")
            return False

    insert_at = find_tier_position(lines)
    new_line = f"tier = {tier}"
    lines.insert(insert_at, new_line)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    return True


def main():
    print("=" * 72)
    print("  ASIGNAR TIERS — Diagnóstico")
    print("=" * 72)

    items_by_path, items_by_id = load_all_items()
    recipes, recipes_by_path = load_all_recipes(items_by_path)
    orders = load_all_orders(items_by_path)
    research = load_all_research(items_by_path, recipes_by_path)

    # ── Recetas sin tier ──
    missing_recipes = [(rid, r) for rid, r in recipes.items() if r["tier"] == -1]
    print(f"\n📋 Recetas sin tier: {len(missing_recipes)}")
    print(f"   {'ID':<40} {'Output Item':<30} {'Item Tier':>10}")
    print(f"   {'─'*40} {'─'*30} {'─'*10}")
    for rid, r in missing_recipes:
        oid = r["output_item_id"]
        otier = r["output_item_tier"]
        print(f"   {rid:<40} {oid:<30} {otier:>10}")

    # ── Pedidos sin tier ──
    missing_orders = [(oid, o) for oid, o in orders.items() if o["tier"] == -1]
    print(f"\n📋 Pedidos sin tier: {len(missing_orders)}")
    print(f"   {'ID':<40} {'Requested Item Path':<50} {'Item Tier':>10}")
    print(f"   {'─'*40} {'─'*50} {'─'*10}")
    for oid, o in missing_orders:
        print(f"   {oid:<40} {o['requested_item_path']:<50} {o['requested_item_tier']:>10}")

    # ── Investigaciones sin tier ──
    missing_research = [(rid, r) for rid, r in research.items() if r["tier"] == -1]
    print(f"\n📋 Investigaciones sin tier: {len(missing_research)}")
    print(f"   {'ID':<40} {'Unlocks Recipe':<40} {'Required Items':<40}")
    print(f"   {'─'*40} {'─'*40} {'─'*40}")
    for rid, r in missing_research:
        recipe_id = r["recipe_to_unlock_id"]
        recipe_tier = recipes.get(recipe_id, {}).get("tier", -1)
        req_str = ", ".join(r["required_item_ids"][:3])
        print(f"   {rid:<40} {recipe_id:<40} (recipe_tier={recipe_tier}) req: {req_str}")

    # ── Calcular tiers ──
    print("\n" + "=" * 72)
    print("  APLICANDO CAMBIOS")
    print("=" * 72)

    changes = []

    # Recipes: tier = output item tier
    for rid, r in missing_recipes:
        otier = r["output_item_tier"]
        if otier <= 0:
            print(f"  ❌ {rid}: output item tier={otier}, no se puede asignar")
            continue
        changes.append((r["file"], otier, f"receta {rid} → output item tier={otier}"))

    # Orders: tier = requested item tier
    for oid, o in missing_orders:
        itier = o["requested_item_tier"]
        if itier <= 0:
            print(f"  ❌ {oid}: requested item tier={itier}, no se puede asignar")
            continue
        changes.append((o["file"], itier, f"pedido {oid} → requested item tier={itier}"))

    # Research: tier = tier of recipe_to_unlock, or max tier of required items
    for rid, r in missing_research:
        recipe_id = r["recipe_to_unlock_id"]
        assigned_tier = -1
        method = ""

        if recipe_id and recipe_id in recipes:
            rtier = recipes[recipe_id]["tier"]
            if rtier > 0:
                assigned_tier = rtier
                method = f"recipe_to_unlock '{recipe_id}' tier={rtier}"

        if assigned_tier <= 0:
            # Fallback: max tier of required items
            max_tier = -1
            for req_id in r["required_item_ids"]:
                it = items_by_id.get(req_id, {}).get("tier", -1)
                if it > max_tier:
                    max_tier = it
            if max_tier > 0:
                assigned_tier = max_tier
                method = f"max tier de required_items = {max_tier}"

        if assigned_tier <= 0:
            print(f"  ❌ {rid}: no se pudo determinar tier (recipe_tier={recipes.get(recipe_id, {}).get('tier', '?')}, req_items={r['required_item_ids']})")
            continue

        changes.append((r["file"], assigned_tier, f"investigación {rid} → {method}"))

    # ── Mostrar tabla de cambios ──
    print(f"\n📋 Cambios a aplicar ({len(changes)}):")
    print(f"   {'Archivo':<60} {'Tier':>5}  {'Razón'}")
    print(f"   {'─'*60} {'─'*5}  {'─'*40}")
    for filepath, tier, reason in changes:
        fname = os.path.basename(filepath)
        print(f"   {fname:<60} {tier:>5}  {reason}")

    # ── Aplicar ──
    print(f"\n⏳ Aplicando {len(changes)} cambios...")
    applied = 0
    for filepath, tier, reason in changes:
        if add_tier_to_file(filepath, tier):
            applied += 1
            print(f"  ✓ {os.path.basename(filepath)}: tier = {tier}")

    print(f"\n✅ {applied}/{len(changes)} cambios aplicados.")


if __name__ == "__main__":
    main()
