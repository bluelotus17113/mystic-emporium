#!/usr/bin/env python3
"""
Arregla margenes de recetas que estan fuera de [15%, 40%].

Reglas:
- Sube base_value del item de SALIDA para margenes negativos
- Baja base_value del item de SALIDA para margenes inflados (>+200%)
- NO toca items que son recolectables primarios (harvestable)
- Target: +25% de margen, ajustado para quedar en [15%, 40%]
"""

import re
import sys
from pathlib import Path

GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"
DATA_DIR = GODOT_DIR / "data"


def build_harvestable_ids() -> set:
    """Same logic as content_check.py."""
    enums_path = GODOT_DIR / "scripts" / "core" / "global_enums.gd"
    enum_text = enums_path.read_text(encoding="utf-8")
    m_block = re.search(r"enum\s+ResourceType\s*\{([^}]+)\}", enum_text)
    if not m_block:
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

    bootstrap_path = GODOT_DIR / "scripts" / "core" / "game_bootstrap.gd"
    bootstrap_text = bootstrap_path.read_text(encoding="utf-8")
    name_to_item = {}
    for m in re.finditer(
        r"GameEnums\.ResourceType\.(\w+)\s*:\s*_find_item_by_id\(&\"(\w+)\"\)",
        bootstrap_text,
    ):
        name_to_item[m.group(1)] = m.group(2)

    scenes_dir = GODOT_DIR / "scenes" / "environment"
    generator_types = set()
    for fpath in scenes_dir.glob("resource_generator_*.tscn"):
        text = fpath.read_text(encoding="utf-8")
        m = re.search(r"resource_type\s*=\s*(\d+)", text)
        if m:
            generator_types.add(int(m.group(1)))

    harvestable = set()
    for num in sorted(generator_types):
        enum_name = number_to_name.get(num)
        if enum_name:
            item_id = name_to_item.get(enum_name)
            if item_id:
                harvestable.add(item_id)
    return harvestable


def parse_tres(text: str) -> dict:
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
    m = re.match(r'ExtResource\("(.+?)"\)', ref_str)
    if not m:
        return ""
    return ext_resources.get(m.group(1), {}).get("path", "")


def resolve_all_ext_resources(value: str, ext_resources: dict) -> list:
    return re.findall(r'ExtResource\("(.+?)"\)', value)


def load_items():
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
            "base_value": int(res.get("base_value", 0)) if res.get("base_value", "0").lstrip("-").isdigit() else 0,
            "display_name": res.get("display_name", "").strip('"'),
        }
    return items


def load_recipes(items_by_path):
    recipes = {}
    for fpath in sorted((DATA_DIR / "recipes").glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]
        recipe_id = res.get("id", "").strip('&"')

        ingredients_raw = res.get("ingredients", "")
        ingredient_refs = resolve_all_ext_resources(ingredients_raw, ext)
        ingredient_paths = [ext[eid]["path"] for eid in ingredient_refs if eid in ext]
        ingredient_ids = [items_by_path.get(p, "") for p in ingredient_paths]

        qtys_raw = res.get("ingredient_quantities", "")
        qtys = [int(x) for x in re.findall(r"\d+", qtys_raw)]

        output_raw = res.get("output_item", "")
        output_path = resolve_ext_resource(ext, output_raw)
        output_id = items_by_path.get(output_path, "")

        output_qty = int(res.get("output_quantity", 1)) if res.get("output_quantity", "1").lstrip("-").isdigit() else 1

        recipes[recipe_id] = {
            "file": str(fpath),
            "display_name": res.get("display_name", "").strip('"'),
            "ingredient_ids": ingredient_ids,
            "ingredient_quantities": qtys,
            "output_id": output_id,
            "output_quantity": output_qty,
        }
    return recipes


def main():
    harvestable = build_harvestable_ids()
    print(f"Recolectables primarios: {len(harvestable)}")
    for h in sorted(harvestable):
        print(f"  • {h}")

    items = load_items()
    items_by_path = {i["path"]: iid for iid, i in items.items()}
    recipes = load_recipes(items_by_path)

    changes = []
    skipped_harvestable = []

    for rid, r in sorted(recipes.items()):
        cost = 0
        cost_breakdown = []
        for iid, qty in zip(r["ingredient_ids"], r["ingredient_quantities"]):
            if iid and iid in items:
                val = items[iid]["base_value"]
                cost += val * qty
                cost_breakdown.append(f"{iid}×{qty}@{val}={val*qty}")

        if cost == 0:
            continue

        oid = r["output_id"]
        if oid not in items:
            continue

        revenue = items[oid]["base_value"] * r["output_quantity"]
        margin_pct = (revenue - cost) / cost * 100
        old_value = items[oid]["base_value"]

        if 15 <= margin_pct <= 40:
            continue  # already OK

        if oid in harvestable:
            skipped_harvestable.append((rid, oid, margin_pct, cost, revenue))
            continue

        # Target: +25% margin, clamped to [15%, 40%]
        target_margin = 0.25
        new_revenue = cost * (1 + target_margin)
        new_base_value = max(1, round(new_revenue / r["output_quantity"]))

        resulting_margin = (new_base_value * r["output_quantity"] - cost) / cost * 100
        if resulting_margin < 15:
            new_base_value = max(new_base_value, round(cost * 1.15 / r["output_quantity"] + 0.4999))
            resulting_margin = (new_base_value * r["output_quantity"] - cost) / cost * 100
        elif resulting_margin > 40:
            new_base_value = int(cost * 1.40 / r["output_quantity"])
            resulting_margin = (new_base_value * r["output_quantity"] - cost) / cost * 100

        if new_base_value == old_value:
            continue

        changes.append({
            "recipe": rid,
            "item": oid,
            "item_display": items[oid]["display_name"],
            "file": items[oid]["file"],
            "old_value": old_value,
            "new_value": new_base_value,
            "cost": cost,
            "cost_breakdown": " + ".join(cost_breakdown),
            "old_margin": margin_pct,
            "new_margin": resulting_margin,
        })

    # Print table
    print(f"\n{'='*100}")
    print(f"  TABLA DE CAMBIOS — {len(changes)} items a modificar")
    print(f"{'='*100}")
    print(f"  {'Recipe':<40} {'Item':<25} {'OldVal':>7} {'NewVal':>7} {'Cost':>7} {'OldMargin':>10} {'NewMargin':>10}")
    print(f"  {'─'*40} {'─'*25} {'─'*7} {'─'*7} {'─'*7} {'─'*10} {'─'*10}")
    for ch in changes:
        print(f"  {ch['recipe']:<40} {ch['item']:<25} {ch['old_value']:>7} {ch['new_value']:>7} {ch['cost']:>7} {ch['old_margin']:>9.1f}% {ch['new_margin']:>9.1f}%")

    if skipped_harvestable:
        print(f"\n  ⚠️  SALTADAS (output es recolectable primario):")
        for rid, oid, margin, cost, revenue in skipped_harvestable:
            print(f"     {rid}: {oid}  margin={margin:+.1f}%  cost={cost} revenue={revenue}")

    # Apply
    if changes:
        print(f"\n⏳ Aplicando {len(changes)} cambios...")
        for ch in changes:
            fpath = Path(ch["file"])
            text = fpath.read_text(encoding="utf-8")
            old_text = text
            text = re.sub(
                r"^base_value\s*=\s*\d+",
                f"base_value = {ch['new_value']}",
                text,
                count=1,
                flags=re.MULTILINE,
            )
            if text != old_text:
                fpath.write_text(text, encoding="utf-8")
                print(f"  ✓ {ch['item']}: base_value {ch['old_value']} → {ch['new_value']} (margin {ch['old_margin']:+.1f}% → {ch['new_margin']:+.1f}%)")
            else:
                print(f"  ❌ {ch['item']}: no se encontró base_value")

    print(f"\n✅ Listo. {len(changes)} items modificados, {len(skipped_harvestable)} saltados.")


if __name__ == "__main__":
    main()
