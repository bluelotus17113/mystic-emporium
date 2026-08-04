#!/usr/bin/env python3
"""
arreglar_margenes.py — Fix negative-margin recipes by raising output base_value.

Reglas:
- SOLO modifica `base_value = N` en godot/data/items/*.tres
- NO toca recolectables primarios (19 items con generador)
- ORDEN TOPOLÓGICO: arregla primero recetas que solo usan recolectables
- Recalcula tras cada nivel para que las dependencias vean valores nuevos
- Reporta ciclos si los hay
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"
DATA_DIR = GODOT_DIR / "data"


# ── harvestable discovery (same logic as content_check.py) ──────────────────

def build_harvestable_ids() -> set:
    """Deduce harvestable item IDs from generator scenes + game_bootstrap.gd."""
    # 1. parse enum ResourceType → {number: enum_name}
    enums_path = GODOT_DIR / "scripts" / "core" / "global_enums.gd"
    enum_text = enums_path.read_text(encoding="utf-8")
    m_block = re.search(r"enum\s+ResourceType\s*\{([^}]+)\}", enum_text)
    if not m_block:
        print("ERROR: cannot find enum ResourceType")
        return set()
    number_to_name = {}
    idx = 0
    for line in m_block.group(1).splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        name = stripped.split(",")[0].strip()
        if name:
            number_to_name[idx] = name
            idx += 1

    # 2. parse item_by_type → {enum_name: item_id}
    bootstrap_path = GODOT_DIR / "scripts" / "core" / "game_bootstrap.gd"
    bootstrap_text = bootstrap_path.read_text(encoding="utf-8")
    name_to_item = {}
    for m in re.finditer(
        r"GameEnums\.ResourceType\.(\w+)\s*:\s*_find_item_by_id\(&\"(\w+)\"\)",
        bootstrap_text,
    ):
        name_to_item[m.group(1)] = m.group(2)

    # 3. scan generator scenes for resource_type numbers
    scenes_dir = GODOT_DIR / "scenes" / "environment"
    generator_types = set()
    for fpath in scenes_dir.glob("resource_generator_*.tscn"):
        text = fpath.read_text(encoding="utf-8")
        m = re.search(r"resource_type\s*=\s*(\d+)", text)
        if m:
            generator_types.add(int(m.group(1)))

    # 4. cross-reference
    harvestable = set()
    for num in sorted(generator_types):
        enum_name = number_to_name.get(num)
        if enum_name:
            item_id = name_to_item.get(enum_name)
            if item_id:
                harvestable.add(item_id)
    return harvestable


# ── .tres parsing (same logic as content_check.py) ──────────────────────────

def parse_tres(text: str) -> dict:
    """Parse a .tres file into {ext_resources: {id: {type, path, uid}}, resource: {key: value}}."""
    result = {"ext_resources": {}, "resource": {}}
    mode = "header"
    for line in text.splitlines():
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
        elif stripped == "[resource]":
            mode = "resource"
        elif stripped.startswith("[") and stripped.endswith("]"):
            mode = "other"
        elif mode == "resource" and "=" in stripped and not stripped.startswith(";"):
            key, _, value = stripped.partition("=")
            result["resource"][key.strip()] = value.strip()
    return result


def resolve_ext_resource(ext_resources: dict, ref_str: str) -> str:
    """Given 'ExtResource("2_mad")', return the path."""
    m = re.match(r'ExtResource\("(.+?)"\)', ref_str)
    if not m:
        return ""
    return ext_resources.get(m.group(1), {}).get("path", "")


def resolve_all_ext_resources(value: str, ext_resources: dict) -> list:
    """Extract all ExtResource references from a string."""
    return re.findall(r'ExtResource\("(.+?)"\)', value)


# ── data loading ────────────────────────────────────────────────────────────

def load_items() -> dict:
    """Returns {item_id: {base_value, file, path, display_name, tier, ...}}."""
    items = {}
    for fpath in sorted((DATA_DIR / "items").glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        item_id = res.get("id", "").strip('&"')
        rel = str(fpath.relative_to(GODOT_DIR))
        items[item_id] = {
            "path": f"res://{rel}",
            "file": str(fpath),
            "base_value": int(res.get("base_value", 0))
            if res.get("base_value", "0").lstrip("-").isdigit()
            else 0,
            "display_name": res.get("display_name", "").strip('"'),
            "tier": (
                int(res.get("tier", 0))
                if res.get("tier", "").lstrip("-").isdigit()
                else -1
            ),
        }
    return items


def load_recipes(items_by_path: dict) -> dict:
    """Returns {recipe_id: {ingredient_ids, ingredient_quantities, output_id, output_quantity, ...}}."""
    recipes = {}
    for fpath in sorted((DATA_DIR / "recipes").glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]

        recipe_id = res.get("id", "").strip('&"')

        ingredients_raw = res.get("ingredients", "")
        ingredient_refs = resolve_all_ext_resources(ingredients_raw, ext)
        ingredient_paths = [
            ext[eid]["path"] for eid in ingredient_refs if eid in ext
        ]
        ingredient_ids = [
            items_by_path.get(p, "") for p in ingredient_paths
        ]

        qtys_raw = res.get("ingredient_quantities", "")
        qtys = [int(x) for x in re.findall(r"\d+", qtys_raw)]

        output_raw = res.get("output_item", "")
        output_path = resolve_ext_resource(ext, output_raw)
        output_id = items_by_path.get(output_path, "")

        output_qty = (
            int(res.get("output_quantity", 1))
            if res.get("output_quantity", "1").lstrip("-").isdigit()
            else 1
        )

        recipes[recipe_id] = {
            "file": str(fpath),
            "display_name": res.get("display_name", "").strip('"'),
            "ingredient_ids": ingredient_ids,
            "ingredient_quantities": qtys,
            "output_id": output_id,
            "output_quantity": output_qty,
            "tier": (
                int(res.get("tier", 0))
                if res.get("tier", "").lstrip("-").isdigit()
                else -1
            ),
        }
    return recipes


# ── main ─────────────────────────────────────────────────────────────────────

def main():
    harvestable = build_harvestable_ids()
    print(f"Recolectables primarios detectados: {len(harvestable)}")
    for h in sorted(harvestable):
        print(f"  • {h}")

    items = load_items()
    print(f"\nItems cargados: {len(items)}")

    items_by_path = {i["path"]: iid for iid, i in items.items()}
    recipes = load_recipes(items_by_path)
    print(f"Recetas cargadas: {len(recipes)}")

    # ── Build item → recipe mapping ──
    item_to_recipe = {}  # item_id → recipe_id that produces it
    for rid, r in recipes.items():
        if r["output_id"]:
            item_to_recipe[r["output_id"]] = rid

    # ── Compute item depths (longest path from harvestables) ──
    item_depth = {}
    for iid in harvestable:
        item_depth[iid] = 0

    # Iterate until stable (topological levels)
    changed = True
    iteration = 0
    while changed:
        changed = False
        iteration += 1
        for iid in items:
            if iid in item_depth:
                continue
            if iid not in item_to_recipe:
                # Not harvestable, not craftable → unreachable, depth = -1
                item_depth[iid] = -1
                continue
            rid = item_to_recipe[iid]
            r = recipes[rid]
            max_ing_depth = 0
            all_known = True
            for ing_id in r["ingredient_ids"]:
                if not ing_id:
                    continue
                if ing_id in item_depth:
                    if item_depth[ing_id] >= 0:
                        max_ing_depth = max(max_ing_depth, item_depth[ing_id])
                else:
                    all_known = False
                    break
            if all_known:
                item_depth[iid] = max_ing_depth + 1
                changed = True

    # Report items that never got a depth (cycles or missing data)
    unresolved_items = [
        iid for iid in items if iid not in item_depth
    ]
    if unresolved_items:
        print(f"\n⚠️  Items sin profundidad (posible ciclo o dato faltante): {len(unresolved_items)}")
        for iid in sorted(unresolved_items):
            print(f"  • {iid}")

    # ── Group recipes by output item depth ──
    recipes_by_depth = defaultdict(list)
    for rid, r in recipes.items():
        oid = r["output_id"]
        if oid and oid in item_depth and item_depth[oid] > 0:
            recipes_by_depth[item_depth[oid]].append(rid)

    max_depth = max(recipes_by_depth) if recipes_by_depth else 0
    print(f"\nProfundidad máxima de recetas: {max_depth}")
    for d in range(1, max_depth + 1):
        if d in recipes_by_depth:
            print(f"  profundidad {d}: {len(recipes_by_depth[d])} recetas")

    # ── Process depth by depth ──
    all_changes = []
    skipped_harvestable = []
    skipped_positive = []

    for depth in range(1, max_depth + 1):
        if depth not in recipes_by_depth:
            continue

        for rid in sorted(recipes_by_depth[depth]):
            r = recipes[rid]

            # Compute cost with CURRENT item values (may have been updated by lower depths)
            cost = 0
            cost_breakdown = []
            for iid, qty in zip(r["ingredient_ids"], r["ingredient_quantities"]):
                if iid and iid in items:
                    val = items[iid]["base_value"]
                    cost += val * qty
                    cost_breakdown.append(f"{iid}×{qty}@{val}={val*qty}")

            if cost == 0:
                continue

            revenue = items[r["output_id"]]["base_value"] * r["output_quantity"]
            margin_pct = (revenue - cost) / cost * 100

            if margin_pct >= 0:
                skipped_positive.append((rid, margin_pct))
                continue

            # Check if output is harvestable → cannot touch
            if r["output_id"] in harvestable:
                skipped_harvestable.append((rid, r["output_id"], margin_pct, cost, revenue))
                continue

            # ── Fix: raise base_value to target +25% margin ──
            target_margin = 0.25
            new_revenue_target = cost * (1 + target_margin)
            new_base_value = max(1, round(new_revenue_target / r["output_quantity"]))

            # Ensure resulting margin is in [15%, 40%]
            resulting_margin = (new_base_value * r["output_quantity"] - cost) / cost * 100
            if resulting_margin < 15:
                # Push up to 15%
                new_base_value = max(
                    new_base_value,
                    round(cost * 1.15 / r["output_quantity"] + 0.4999),
                )
                resulting_margin = (new_base_value * r["output_quantity"] - cost) / cost * 100
            elif resulting_margin > 40:
                # Cap at 40%
                new_base_value = int(cost * 1.40 / r["output_quantity"])
                resulting_margin = (new_base_value * r["output_quantity"] - cost) / cost * 100

            old_value = items[r["output_id"]]["base_value"]

            if new_base_value == old_value:
                continue  # no change needed (shouldn't happen for negative margins)

            all_changes.append({
                "recipe": rid,
                "item": r["output_id"],
                "item_display": items[r["output_id"]]["display_name"],
                "old_value": old_value,
                "new_value": new_base_value,
                "cost": cost,
                "ingredients": " + ".join(cost_breakdown),
                "old_margin": margin_pct,
                "new_margin": resulting_margin,
                "depth": depth,
            })

            # Update in-memory so higher-depth recipes see new value
            items[r["output_id"]]["base_value"] = new_base_value

    # ── Print changes table ──
    if all_changes:
        print(f"\n{'='*100}")
        print(f"  TABLA DE CAMBIOS — {len(all_changes)} items modificados")
        print(f"{'='*100}")
        print(
            f"{'Recipe':<38s} {'Item':<25s} {'OldVal':>7s} {'NewVal':>7s} "
            f"{'Cost':>7s} {'OldMargin':>10s} {'NewMargin':>10s} {'Depth':>5s}"
        )
        print(f"{'─'*38} {'─'*25} {'─'*7} {'─'*7} {'─'*7} {'─'*10} {'─'*10} {'─'*5}")
        for ch in all_changes:
            print(
                f"{ch['recipe']:<38s} {ch['item']:<25s} {ch['old_value']:>7d} {ch['new_value']:>7d} "
                f"{ch['cost']:>7d} {ch['old_margin']:>9.1f}% {ch['new_margin']:>9.1f}% {ch['depth']:>5d}"
            )
    else:
        print("\n⚠️  NO se encontraron cambios que aplicar.")

    if skipped_harvestable:
        print(f"\n{'─'*80}")
        print(f"  ⚠️  RECETAS NO ARREGLADAS (output es recolectable primario): {len(skipped_harvestable)}")
        for rid, oid, margin, cost, revenue in skipped_harvestable:
            print(f"     {rid}: {oid}  margin={margin:+.1f}%  cost={cost} revenue={revenue}")

    # ── Write changes to disk ──
    if all_changes:
        print(f"\n{'─'*80}")
        print(f"  ESCRIBIENDO CAMBIOS A DISCO...")
        # Group changes by item (one file per item)
        files_to_update = {}
        for ch in all_changes:
            item_id = ch["item"]
            fpath = items[item_id]["file"]
            files_to_update[fpath] = (item_id, ch["new_value"])

        for fpath, (item_id, new_val) in sorted(files_to_update.items()):
            text = Path(fpath).read_text(encoding="utf-8")
            # Only change base_value line
            old_text = text
            text = re.sub(
                r"^base_value\s*=\s*\d+",
                f"base_value = {new_val}",
                text,
                count=1,
                flags=re.MULTILINE,
            )
            if text != old_text:
                Path(fpath).write_text(text, encoding="utf-8")
                print(f"  ✓ {item_id}: base_value → {new_val}  ({fpath})")
            else:
                print(f"  ✗ {item_id}: NO SE ENCONTRÓ base_value en {fpath}")

    print(f"\n{'='*60}")
    print(f"  RESUMEN")
    print(f"  Items modificados: {len(all_changes)}")
    print(f"  Recetas saltadas (harvestable): {len(skipped_harvestable)}")
    print(f"  Recetas ya positivas: {len(skipped_positive)}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
