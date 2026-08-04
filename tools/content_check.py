#!/usr/bin/env python3
"""
Mystic Emporium — Economy Content Auditor
=========================================
Reads .tres files from godot/data/{items,recipes,orders,research},
parses them as text, and produces an audit report on stdout.

REGLA DURA: este script solo LEE. No modifica nada bajo godot/.
"""

import os
import sys
import re
from collections import defaultdict
from pathlib import Path

# ── config ────────────────────────────────────────────────────────────────
GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"
DATA_DIR = GODOT_DIR / "data"


def _build_harvestable_ids() -> set:
    """Deduce harvestable item IDs from generator scenes + game_bootstrap.gd.

    Steps:
    1. Parse global_enums.gd enum ResourceType → {number: enum_name}.
    2. Parse game_bootstrap.gd item_by_type → {enum_name: item_id}.
    3. Parse every resource_generator_*.tscn for its ``resource_type = N``.
    4. Cross-reference: generator resource_type → enum_name → item_id.
    """
    # ── 1. parse enum ResourceType ──
    enums_path = GODOT_DIR / "scripts" / "core" / "global_enums.gd"
    enum_text = enums_path.read_text(encoding="utf-8")
    # capture block "enum ResourceType { ... }"
    m_block = re.search(r"enum\s+ResourceType\s*\{([^}]+)\}", enum_text)
    if not m_block:
        print("ERROR: cannot find enum ResourceType in global_enums.gd")
        return set()
    number_to_name = {}
    idx = 0
    for line in m_block.group(1).splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # take the token before the first comma (or the whole line if no comma)
        name = stripped.split(",")[0].strip()
        if name:
            number_to_name[idx] = name
            idx += 1

    # ── 2. parse item_by_type dictionary ──
    bootstrap_path = GODOT_DIR / "scripts" / "core" / "game_bootstrap.gd"
    bootstrap_text = bootstrap_path.read_text(encoding="utf-8")
    # match: GameEnums.ResourceType.NAME: _find_item_by_id(&"item_id"),
    name_to_item = {}
    for m in re.finditer(
        r"GameEnums\.ResourceType\.(\w+)\s*:\s*_find_item_by_id\(&\"(\w+)\"\)",
        bootstrap_text,
    ):
        name_to_item[m.group(1)] = m.group(2)

    # ── 3. scan generator scenes ──
    scenes_dir = GODOT_DIR / "scenes" / "environment"
    generator_types = set()
    for fpath in scenes_dir.glob("resource_generator_*.tscn"):
        text = fpath.read_text(encoding="utf-8")
        m = re.search(r"resource_type\s*=\s*(\d+)", text)
        if m:
            generator_types.add(int(m.group(1)))

    # ── 4. cross-reference ──
    harvestable = set()
    for num in sorted(generator_types):
        enum_name = number_to_name.get(num)
        if enum_name:
            item_id = name_to_item.get(enum_name)
            if item_id:
                harvestable.add(item_id)
    return harvestable


HARVESTABLE_IDS = _build_harvestable_ids()

# ── helpers ────────────────────────────────────────────────────────────────

def read_file(path: Path) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def parse_tres(text: str) -> dict:
    """Parse a .tres file into:
    {
      'ext_resources': {id_str: {type, path?, uid?}, ...},
      'resource': {key: raw_value_str, ...},
      'raw_lines': [all lines in order],
    }
    """
    result = {"ext_resources": {}, "resource": {}, "raw_lines": text.splitlines()}
    lines = result["raw_lines"]

    mode = "header"
    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()

        # detect [ext_resource ...] sections
        if stripped.startswith("[ext_resource "):
            # parse attributes: type="X" path="Y" id="Z" uid="W"
            m = re.findall(r'(\w+)=\s*"(.*?)"', stripped)
            attrs = dict(m)
            eid = attrs.get("id", "")
            result["ext_resources"][eid] = {
                "type": attrs.get("type", ""),
                "path": attrs.get("path", ""),
                "uid": attrs.get("uid", ""),
            }
            continue

        # detect [resource] section
        if stripped == "[resource]":
            mode = "resource"
            continue

        # detect other sections — skip
        if stripped.startswith("[") and stripped.endswith("]"):
            mode = "other"
            continue

        # in resource section, parse key = value
        if mode == "resource" and "=" in stripped and not stripped.startswith(";"):
            key, _, value = stripped.partition("=")
            key = key.strip()
            value = value.strip()
            result["resource"][key] = value

    return result


def resolve_ext_resource(ext_resources: dict, ref_str: str) -> str:
    """Given 'ExtResource("2_mad")', return the path from ext_resources map."""
    m = re.match(r'ExtResource\("(.+?)"\)', ref_str)
    if not m:
        return ""
    eid = m.group(1)
    return ext_resources.get(eid, {}).get("path", "")


def resolve_all_ext_resources(value: str, ext_resources: dict) -> list:
    """Extract all ExtResource references from a string like
    'Array[ItemData]([ExtResource("2_mad"), ExtResource("3_ese")])' """
    return re.findall(r'ExtResource\("(.+?)"\)', value)


def ext_path_to_item_id(path: str, items_by_path: dict) -> str:
    """Given a res:// path, return the item id, or empty string."""
    return items_by_path.get(path, "")


def ext_path_to_research_id(path: str, research_by_path: dict) -> str:
    """Given a res:// path, return the research id, or empty string."""
    return research_by_path.get(path, "")


def ext_path_to_recipe_id(path: str, recipes_by_path: dict) -> str:
    """Given a res:// path, return the recipe id, or empty string."""
    return recipes_by_path.get(path, "")


# ── data loading ───────────────────────────────────────────────────────────

def load_items() -> dict:
    """Returns {item_id: {parsed fields, 'path': relative_path}}"""
    items_dir = DATA_DIR / "items"
    items = {}
    for fpath in sorted(items_dir.glob("*.tres")):
        text = read_file(fpath)
        parsed = parse_tres(text)
        res = parsed["resource"]
        item_id = res.get("id", "").strip('&"')
        rel = str(fpath.relative_to(GODOT_DIR))
        items[item_id] = {
            "path": f"res://{rel}",
            "file": str(fpath),
            "display_name": res.get("display_name", "").strip('"'),
            "category": int(res.get("category", 0)) if res.get("category", "").lstrip("-").isdigit() else -1,
            "tier": int(res.get("tier", 0)) if res.get("tier", "").lstrip("-").isdigit() else -1,
            "base_value": int(res.get("base_value", 0)) if res.get("base_value", "").lstrip("-").isdigit() else 0,
            "max_stack": int(res.get("max_stack", 99)) if res.get("max_stack", "").lstrip("-").isdigit() else 99,
        }
        # map paths to ids for resolution
    return items


def load_recipes(items_by_path: dict) -> dict:
    """Returns {recipe_id: {parsed fields, ...}}"""
    recipes_dir = DATA_DIR / "recipes"
    recipes = {}
    for fpath in sorted(recipes_dir.glob("*.tres")):
        text = read_file(fpath)
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]

        recipe_id = res.get("id", "").strip('&"')
        rel = str(fpath.relative_to(GODOT_DIR))

        # Resolve ingredients
        ingredients_raw = res.get("ingredients", "")
        ingredient_refs = resolve_all_ext_resources(ingredients_raw, ext)
        ingredient_paths = [ext[eid]["path"] for eid in ingredient_refs if eid in ext]
        ingredient_ids = [ext_path_to_item_id(p, items_by_path) for p in ingredient_paths]

        # Resolve quantities
        qtys_raw = res.get("ingredient_quantities", "")
        qtys = [int(x) for x in re.findall(r'\d+', qtys_raw)]

        # Resolve output
        output_raw = res.get("output_item", "")
        output_path = resolve_ext_resource(ext, output_raw)
        output_id = ext_path_to_item_id(output_path, items_by_path)

        output_qty = int(res.get("output_quantity", 1)) if res.get("output_quantity", "1").lstrip("-").isdigit() else 1

        recipes[recipe_id] = {
            "path": f"res://{rel}",
            "file": str(fpath),
            "display_name": res.get("display_name", "").strip('"'),
            "ingredient_ids": ingredient_ids,
            "ingredient_quantities": qtys,
            "output_id": output_id,
            "output_quantity": output_qty,
            "crafting_time": float(res.get("crafting_time", 0)) if res.get("crafting_time", "0").replace(".","",1).lstrip("-").isdigit() else 0.0,
            "unlocked_by_default": res.get("unlocked_by_default", "false").lower() == "true",
            "tier": int(res.get("tier", 0)) if res.get("tier", "").lstrip("-").isdigit() else -1,
            "required_station_type": int(res.get("required_station_type", 0)) if res.get("required_station_type", "").lstrip("-").isdigit() else 0,
        }
    return recipes


def load_orders(items_by_path: dict) -> dict:
    """Returns {order_id: {parsed fields}}"""
    orders_dir = DATA_DIR / "orders"
    orders = {}
    for fpath in sorted(orders_dir.glob("*.tres")):
        text = read_file(fpath)
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]

        order_id = res.get("id", "").strip('&"')
        rel = str(fpath.relative_to(GODOT_DIR))

        requested_raw = res.get("requested_item", "")
        requested_path = resolve_ext_resource(ext, requested_raw)
        requested_id = ext_path_to_item_id(requested_path, items_by_path)

        orders[order_id] = {
            "path": f"res://{rel}",
            "file": str(fpath),
            "display_name": res.get("display_name", "").strip('"'),
            "requested_item_id": requested_id,
            "requested_item_path": requested_path,
            "requested_quantity": int(res.get("requested_quantity", 0)) if res.get("requested_quantity", "0").lstrip("-").isdigit() else 0,
            "coin_reward": int(res.get("coin_reward", 0)) if res.get("coin_reward", "0").lstrip("-").isdigit() else 0,
            "tier": int(res.get("tier", 0)) if res.get("tier", "").lstrip("-").isdigit() else -1,
            "min_reputation": int(res.get("min_reputation", 0)) if res.get("min_reputation", "0").lstrip("-").isdigit() else 0,
        }
    return orders


def load_research(items_by_path: dict, recipes_by_path: dict) -> dict:
    """Returns {research_id: {parsed fields}}"""
    research_dir = DATA_DIR / "research"
    research = {}
    for fpath in sorted(research_dir.glob("*.tres")):
        text = read_file(fpath)
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]

        research_id = res.get("id", "").strip('&"')
        rel = str(fpath.relative_to(GODOT_DIR))

        # Prerequisites
        prereqs_raw = res.get("prerequisites", "")
        prereq_refs = resolve_all_ext_resources(prereqs_raw, ext)
        prereq_paths = [ext[eid]["path"] for eid in prereq_refs if eid in ext]

        # recipe_to_unlock
        recipe_raw = res.get("recipe_to_unlock", "")
        recipe_path = resolve_ext_resource(ext, recipe_raw)

        # buildable_to_unlock
        buildable_raw = res.get("buildable_to_unlock", "")
        buildable_path = resolve_ext_resource(ext, buildable_raw)

        research[research_id] = {
            "path": f"res://{rel}",
            "file": str(fpath),
            "display_name": res.get("display_name", "").strip('"'),
            "prerequisite_paths": prereq_paths,
            "recipe_to_unlock_path": recipe_path,
            "buildable_to_unlock_path": buildable_path,
            "research_time": float(res.get("research_time", 0)) if res.get("research_time", "0").replace(".","",1).lstrip("-").isdigit() else 0.0,
            "coin_cost": int(res.get("coin_cost", 0)) if res.get("coin_cost", "").lstrip("-").isdigit() else 0,
            "tier": int(res.get("tier", 0)) if res.get("tier", "").lstrip("-").isdigit() else -1,
        }
    return research


# ── check 1: integrity ─────────────────────────────────────────────────────

def check_integrity(items, recipes, orders, research):
    """Check every res:// path reference exists on disk."""
    broken = []

    def check_path(path_str, context):
        if not path_str.startswith("res://"):
            return
        rel = path_str[len("res://"):]
        full = GODOT_DIR / rel
        if not full.exists():
            broken.append((context, path_str))

    # Items self-reference their own resources (script, icon) — not needed for economy
    # Recipes
    for rid, r in recipes.items():
        for iid in r["ingredient_ids"]:
            if iid and iid not in items:
                broken.append((f"recipe {rid}: ingredient '{iid}' not found", r["file"]))
        if r["output_id"] and r["output_id"] not in items:
            broken.append((f"recipe {rid}: output '{r['output_id']}' not found", r["file"]))

    # Orders
    for oid, o in orders.items():
        if o["requested_item_id"] and o["requested_item_id"] not in items:
            broken.append((f"order {oid}: requested_item '{o['requested_item_id']}' not found", o["file"]))

    # Research
    for rid, r in research.items():
        if r["recipe_to_unlock_path"]:
            recipe_id = ext_path_to_recipe_id(r["recipe_to_unlock_path"], recipes_by_path)
            if not recipe_id:
                broken.append((f"research {rid}: recipe_to_unlock '{r['recipe_to_unlock_path']}' not found", r["file"]))
        if r["buildable_to_unlock_path"]:
            full = GODOT_DIR / r["buildable_to_unlock_path"][len("res://"):]
            if not full.exists():
                broken.append((f"research {rid}: buildable_to_unlock '{r['buildable_to_unlock_path']}' not found", r["file"]))
        for pp in r["prerequisite_paths"]:
            prereq_id = ext_path_to_research_id(pp, research_by_path)
            if not prereq_id:
                broken.append((f"research {rid}: prerequisite '{pp}' not found in research", r["file"]))

    return broken


# ── check 2: ranges ─────────────────────────────────────────────────────────

def check_ranges(items):
    """Check category 0-3, tier 1-5."""
    violations = []
    category5 = []

    for iid, item in items.items():
        cat = item["category"]
        tier = item["tier"]
        if cat != -1 and cat not in (0, 1, 2, 3):
            if cat == 5:
                category5.append((iid, item["display_name"]))
            else:
                violations.append((f"item {iid}: category={cat} out of range [0-3]", item["file"]))
        if tier != -1 and tier not in (1, 2, 3, 4, 5):
            violations.append((f"item {iid}: tier={tier} out of range [1-5]", item["file"]))

    return violations, category5


# ── check 3: recipe margins ─────────────────────────────────────────────────

def check_recipe_margins(recipes, items):
    """Compute margin for each recipe. Flag negative and >+200%."""
    results = []
    negative = []
    inflated = []

    for rid, r in recipes.items():
        cost = 0
        for i, (iid, qty) in enumerate(zip(r["ingredient_ids"], r["ingredient_quantities"])):
            if iid in items:
                cost += items[iid]["base_value"] * qty

        revenue = 0
        if r["output_id"] in items:
            revenue = items[r["output_id"]]["base_value"] * r["output_quantity"]

        if cost == 0:
            margin_pct = float("inf") if revenue > 0 else 0.0
            margin_str = "∞ (coste cero)"
        else:
            margin_pct = (revenue - cost) / cost * 100
            margin_str = f"{margin_pct:+.1f}%"

        entry = {
            "id": rid,
            "display_name": r["display_name"],
            "cost": cost,
            "revenue": revenue,
            "margin_pct": margin_pct if cost > 0 else (9999.0 if revenue > 0 else 0.0),
            "margin_str": margin_str,
            "tier": r["tier"],
        }

        if cost > 0 and margin_pct < 0:
            negative.append(entry)
        elif cost > 0 and margin_pct > 200:
            inflated.append(entry)

        results.append(entry)

    negative.sort(key=lambda x: x["margin_pct"])
    inflated.sort(key=lambda x: x["margin_pct"], reverse=True)

    return negative, inflated, results


# ── check 4: reachability ───────────────────────────────────────────────────

def check_reachability(items, recipes, orders):
    """Find items neither harvestable nor recipe output, and dead-end items.

    Items with category=3 (CURRENCY) are rewards, not crafted — they are
    excluded from both unreachability and dead-end checks.
    """
    harvestable = HARVESTABLE_IDS

    # Items that are output of some recipe
    recipe_outputs = set()
    for r in recipes.values():
        if r["output_id"]:
            recipe_outputs.add(r["output_id"])

    # Reachable items
    reachable = harvestable | recipe_outputs

    unreachable = []
    for iid in sorted(items.keys()):
        if iid not in reachable:
            # category 3 (CURRENCY) / 5 (SPECIAL) items are rewards, not crafted
            if items[iid].get("category") in (3, 5):
                continue
            unreachable.append((iid, items[iid]["display_name"], items[iid]["file"]))

    # Dead-end items: not used as ingredient in any recipe, and not requested in any order
    used_as_ingredient = set()
    for r in recipes.values():
        for iid in r["ingredient_ids"]:
            if iid:
                used_as_ingredient.add(iid)

    used_in_orders = set()
    for o in orders.values():
        if o["requested_item_id"]:
            used_in_orders.add(o["requested_item_id"])

    dead_ends = []
    for iid in sorted(items.keys()):
        if iid not in used_as_ingredient and iid not in used_in_orders:
            # category 3 (CURRENCY) / 5 (SPECIAL) items are rewards, they don't need recipes/orders
            if items[iid].get("category") in (3, 5):
                continue
            dead_ends.append((iid, items[iid]["display_name"], items[iid]["file"]))

    return unreachable, dead_ends


# ── check 5: research ───────────────────────────────────────────────────────

def check_research(research, recipes):
    """Detect cycles, compute depths, check duplicate unlocks."""
    # Build adjacency: research_id -> list of prerequisite research_ids (by path resolution)
    adj = {}
    for rid, r in research.items():
        prereqs = []
        for pp in r["prerequisite_paths"]:
            prereq_id = ext_path_to_research_id(pp, research_by_path)
            if prereq_id:
                prereqs.append(prereq_id)
        adj[rid] = prereqs

    # Detect cycles via DFS
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {rid: WHITE for rid in research}
    cycles = []

    def dfs_cycle(node, path_stack):
        color[node] = GRAY
        path_stack.append(node)
        for neighbor in adj.get(node, []):
            if neighbor not in color:
                continue
            if color[neighbor] == GRAY:
                # Found cycle
                cycle_start = path_stack.index(neighbor)
                cycle = path_stack[cycle_start:] + [neighbor]
                cycles.append(cycle)
            elif color[neighbor] == WHITE:
                dfs_cycle(neighbor, path_stack)
        path_stack.pop()
        color[node] = BLACK

    for rid in research:
        if color[rid] == WHITE:
            dfs_cycle(rid, [])

    # Compute depths (longest path from root = 0 prereqs)
    memo = {}
    def compute_depth(node):
        if node in memo:
            return memo[node]
        if node not in adj or not adj[node]:
            memo[node] = 0
            return 0
        max_d = 0
        for neighbor in adj[node]:
            if neighbor in adj:  # only if it's a known research node
                d = compute_depth(neighbor)
                if d + 1 > max_d:
                    max_d = d + 1
        memo[node] = max_d
        return max_d

    depths = {}
    for rid in research:
        try:
            depths[rid] = compute_depth(rid)
        except RecursionError:
            depths[rid] = -1

    # Depth histogram
    depth_histogram = defaultdict(int)
    for d in depths.values():
        if d >= 0:
            depth_histogram[d] += 1

    # Research that unlocks recipes already unlocked_by_default
    duplicate_unlocks = []
    for rid, r in research.items():
        recipe_path = r["recipe_to_unlock_path"]
        if recipe_path:
            recipe_id = ext_path_to_recipe_id(recipe_path, recipes_by_path)
            if recipe_id and recipe_id in recipes:
                if recipes[recipe_id]["unlocked_by_default"]:
                    duplicate_unlocks.append((
                        rid,
                        r["display_name"],
                        recipe_id,
                        recipes[recipe_id]["display_name"],
                    ))

    return cycles, depths, depth_histogram, duplicate_unlocks


# ── check 6: orders ─────────────────────────────────────────────────────────

def check_orders(orders, items):
    """Check coin ratios and min_reputation progression."""
    ratio_violations = []
    tier_min_rep = defaultdict(list)

    for oid, o in orders.items():
        iid = o["requested_item_id"]
        if iid and iid in items:
            base = items[iid]["base_value"] * o["requested_quantity"]
            if base > 0:
                ratio = o["coin_reward"] / base
                if ratio < 1.2 or ratio > 2.5:
                    ratio_violations.append((oid, o["display_name"], round(ratio, 2)))
            else:
                ratio_violations.append((oid, o["display_name"], "∞ (base_value=0)"))

        if o["tier"] > 0:
            tier_min_rep[o["tier"]].append(o["min_reputation"])

    # Check min_reputation grows with tier
    rep_problems = []
    tier_avg_rep = {}
    for tier in sorted(tier_min_rep):
        vals = tier_min_rep[tier]
        tier_avg_rep[tier] = {"min": min(vals), "max": max(vals), "avg": sum(vals)/len(vals)}

    for i in range(1, len(sorted(tier_min_rep)) + 1):
        tiers_sorted = sorted(tier_min_rep)
        if i < len(tiers_sorted):
            t1, t2 = tiers_sorted[i-1], tiers_sorted[i]
            min_t2 = min(tier_min_rep[t2])
            max_t1 = max(tier_min_rep[t1])
            if min_t2 <= max_t1:
                rep_problems.append(
                    f"tier {t1} max_rep={max_t1} >= tier {t2} min_rep={min_t2} — min_reputation no crece con tier"
                )

    return ratio_violations, rep_problems, tier_avg_rep


# ── viability report ────────────────────────────────────────────────────────

def viability_report(items, recipes, orders, research):
    """Table by tier with counts, times, costs, and value averages."""
    tiers = defaultdict(lambda: {
        "items": 0, "recipes": 0, "orders": 0, "research": 0,
        "crafting_time": 0.0, "research_time": 0.0, "coin_cost": 0,
        "item_values": [],
    })

    for item in items.values():
        t = item["tier"]
        tiers[t]["items"] += 1
        tiers[t]["item_values"].append(item["base_value"])

    for r in recipes.values():
        t = r["tier"]
        tiers[t]["recipes"] += 1
        tiers[t]["crafting_time"] += r["crafting_time"]

    for o in orders.values():
        t = o["tier"]
        tiers[t]["orders"] += 1

    for r in research.values():
        t = r["tier"]
        tiers[t]["research"] += 1
        tiers[t]["research_time"] += r["research_time"]
        tiers[t]["coin_cost"] += r["coin_cost"]

    return tiers


# ── main report ─────────────────────────────────────────────────────────────

def main():
    print("=" * 72)
    print("  MYSTIC EMPORIUM — AUDITORÍA DE ECONOMÍA")
    print("=" * 72)

    # ── load data ──
    print("\n── CARGANDO DATOS ──")
    items = load_items()
    print(f"  items:     {len(items)}")
    recipes = load_recipes({i["path"]: iid for iid, i in items.items()})
    print(f"  recetas:   {len(recipes)}")
    orders = load_orders({i["path"]: iid for iid, i in items.items()})
    print(f"  pedidos:   {len(orders)}")
    research = load_research(
        {i["path"]: iid for iid, i in items.items()},
        {r["path"]: rid for rid, r in recipes.items()},
    )
    print(f"  investigaciones: {len(research)}")

    # Track missing tier fields
    missing_tier_items = [iid for iid, i in items.items() if i["tier"] == -1]
    missing_tier_recipes = [rid for rid, r in recipes.items() if r["tier"] == -1]
    missing_tier_orders = [oid for oid, o in orders.items() if o["tier"] == -1]
    missing_tier_research = [rid for rid, r in research.items() if r["tier"] == -1]

    if any([missing_tier_items, missing_tier_recipes, missing_tier_orders, missing_tier_research]):
        print("\n  ⚠️  CAMPOS 'tier' AUSENTES:")
        if missing_tier_items:
            print(f"     items: {len(missing_tier_items)} — {', '.join(missing_tier_items)}")
        if missing_tier_recipes:
            print(f"     recetas: {len(missing_tier_recipes)} — {', '.join(missing_tier_recipes)}")
        if missing_tier_orders:
            print(f"     pedidos: {len(missing_tier_orders)} — {', '.join(missing_tier_orders)}")
        if missing_tier_research:
            print(f"     investigaciones: {len(missing_tier_research)} — {', '.join(missing_tier_research)}")

    # Build global lookup dicts for path resolution
    global items_by_path, recipes_by_path, research_by_path
    items_by_path = {i["path"]: iid for iid, i in items.items()}
    recipes_by_path = {r["path"]: rid for rid, r in recipes.items()}
    research_by_path = {r["path"]: rid for rid, r in research.items()}

    # ── 1. integrity ──
    print("\n" + "=" * 72)
    print("  1. INTEGRIDAD — Referencias Rotas")
    print("=" * 72)
    broken = check_integrity(items, recipes, orders, research)
    if broken:
        for msg, ctx in broken:
            print(f"  ❌ {msg}")
            print(f"     en: {ctx}")
        print(f"\n  Total: {len(broken)} referencias rotas")
    else:
        print("  ✅ Todas las referencias resuelven correctamente.")

    # ── 2. ranges ──
    print("\n" + "=" * 72)
    print("  2. RANGOS — category / tier")
    print("=" * 72)
    violations, category5 = check_ranges(items)
    if violations:
        for msg, ctx in violations:
            print(f"  ❌ {msg}")
    else:
        print("  ✅ Todos los category/tier en rango.")

    if category5:
        print(f"\n  ⚠️  category=5 (fuera de enum 0-3, pero conocido):")
        for iid, dname in category5:
            print(f"     • {iid} ({dname})")
        print(f"  Total category=5: {len(category5)}")

    # ── 3. margins ──
    print("\n" + "=" * 72)
    print("  3. MARGEN DE RECETAS")
    print("=" * 72)
    negative, inflated, all_margins = check_recipe_margins(recipes, items)

    if negative:
        print(f"\n  🔴 RECETAS CON MARGEN NEGATIVO (pierden dinero): {len(negative)}")
        for e in negative:
            print(f"     {e['margin_str']:>10s}  {e['id']:<40s}  coste={e['cost']} ingreso={e['revenue']}  ({e['display_name']})")
    else:
        print("\n  ✅ Ninguna receta pierde dinero.")

    if inflated:
        print(f"\n  🟡 RECETAS CON MARGEN >+200% (inflación): {len(inflated)}")
        for e in inflated:
            print(f"     {e['margin_str']:>10s}  {e['id']:<40s}  coste={e['cost']} ingreso={e['revenue']}  ({e['display_name']})")
    else:
        print("  ✅ Ninguna receta supera el +200%.")

    # Margin distribution
    finite_margins = [m for m in all_margins if m["margin_pct"] != float("inf") and m["cost"] > 0]
    if finite_margins:
        avg_margin = sum(m["margin_pct"] for m in finite_margins) / len(finite_margins)
        print(f"\n  📊 Margen medio: {avg_margin:+.1f}%  (sobre {len(finite_margins)} recetas con coste>0)")

    # ── 4. reachability ──
    print("\n" + "=" * 72)
    print("  4. ALCANZABILIDAD")
    print("=" * 72)
    unreachable, dead_ends = check_reachability(items, recipes, orders)

    if unreachable:
        print(f"\n  🔴 ITEMS INALCANZABLES (ni recolectables ni salida de receta): {len(unreachable)}")
        for iid, dname, fpath in unreachable:
            print(f"     • {iid} ({dname})")
    else:
        print("\n  ✅ Todos los items son alcanzables.")

    if dead_ends:
        print(f"\n  🟡 CALLEJONES SIN SALIDA (ni ingrediente ni pedido): {len(dead_ends)}")
        for iid, dname, fpath in dead_ends:
            print(f"     • {iid} ({dname})")
    else:
        print("  ✅ Ningún item es callejón sin salida.")

    # ── 5. research ──
    print("\n" + "=" * 72)
    print("  5. INVESTIGACIONES")
    print("=" * 72)
    cycles, depths, depth_histogram, duplicate_unlocks = check_research(research, recipes)

    if cycles:
        print(f"\n  🔴 CICLOS DETECTADOS ({len(cycles)}):")
        for cycle in cycles:
            print(f"     {' → '.join(cycle)}")
    else:
        print("\n  ✅ Sin ciclos en el grafo de investigación.")

    print(f"\n  📊 Histograma de profundidades:")
    for d in sorted(depth_histogram):
        bar = "█" * depth_histogram[d]
        print(f"     profundidad {d}: {depth_histogram[d]:2d} nodos  {bar}")

    # Nodes at each depth
    max_depth = max(depth_histogram) if depth_histogram else 0
    print(f"\n  📐 Profundidad máxima: {max_depth}")

    if duplicate_unlocks:
        print(f"\n  🟡 INVESTIGACIONES QUE DESBLOQUEAN RECETAS YA DESBLOQUEADAS:")
        for rid, rname, recipe_id, recipe_name in duplicate_unlocks:
            print(f"     • {rid} ({rname}) → {recipe_id} ({recipe_name}) unlocked_by_default=true")

    # ── 6. orders ──
    print("\n" + "=" * 72)
    print("  6. PEDIDOS")
    print("=" * 72)
    ratio_violations, rep_problems, tier_avg_rep = check_orders(orders, items)

    if ratio_violations:
        print(f"\n  🔴 PEDIDOS CON RATIO coin/(value×qty) FUERA DE [1.2, 2.5]:")
        for oid, dname, ratio in ratio_violations:
            print(f"     • {oid}: ratio={ratio}  ({dname})")
    else:
        print("\n  ✅ Todos los ratios están en [1.2, 2.5].")

    if rep_problems:
        print(f"\n  🟡 PROBLEMAS CON min_reputation:")
        for p in rep_problems:
            print(f"     {p}")
    else:
        print("  ✅ min_reputation crece con el tier.")

    if tier_avg_rep:
        print(f"\n  📊 min_reputation por tier:")
        for tier in sorted(tier_avg_rep):
            d = tier_avg_rep[tier]
            print(f"     tier {tier}: min={d['min']} max={d['max']} avg={d['avg']:.1f}")

    # ── viability ──
    print("\n" + "=" * 72)
    print("  INFORME DE VIABILIDAD POR TIER")
    print("=" * 72)

    tiers = viability_report(items, recipes, orders, research)

    design_hours = {
        1: (0, 0.5),     # 0:00-0:30
        2: (0.5, 2.0),   # 0:30-2:00
        3: (2.0, 5.0),   # 2:00-5:00
        4: (5.0, 8.0),   # 5:00-8:00
        5: (8.0, 10.0),  # 8:00-10:00+
    }

    print(f"\n  {'Tier':<6} {'Items':>6} {'Recetas':>8} {'Pedidos':>8} {'Invest.':>8} {'Craft(s)':>9} {'Research(s)':>11} {'Coste(mon)':>10} {'ValorMed':>9}  {'Horas diseño':>14}  Diagnóstico")
    print(f"  {'─'*6} {'─'*6} {'─'*8} {'─'*8} {'─'*8} {'─'*9} {'─'*11} {'─'*10} {'─'*9}  {'─'*14}  {'─'*20}")

    for tier in sorted(tiers):
        if tier == -1:
            continue  # handled separately below
        t = tiers[tier]
        vals = t["item_values"]
        avg_val = sum(vals) / len(vals) if vals else 0
        h_range = design_hours.get(tier, (0, 0))
        h_span = h_range[1] - h_range[0]
        h_label = f"{h_range[0]:.1f}-{h_range[1]:.1f}h"

        # Rough diagnosis: does this tier have enough content for its time span?
        content_score = t["recipes"] + t["orders"] + t["research"]
        diagnosis = ""
        if content_score < 5:
            diagnosis = "⚠️  CONTENIDO ESCASO"
        elif content_score < 10:
            diagnosis = "⚡ bajo"
        elif content_score < 20:
            diagnosis = "✓ aceptable"
        else:
            diagnosis = "✓✓ denso"

        print(f"  {tier:<6} {t['items']:>6} {t['recipes']:>8} {t['orders']:>8} {t['research']:>8} {t['crafting_time']:>9.0f} {t['research_time']:>11.0f} {t['coin_cost']:>10} {avg_val:>9.1f}  {h_label:>14}  {diagnosis}")

    # Show items/recipes with missing tier
    tier_minus1 = tiers.get(-1)
    if tier_minus1:
        print(f"\n  ⚠️  SIN TIER ASIGNADO: {tier_minus1['recipes']} recetas, {tier_minus1['orders']} pedidos, {tier_minus1['research']} investigaciones")
        print(f"     (excluidos del contraste por tier)")

    # Summary
    print(f"\n  ── CONTRASTE CON DISEÑO ──")
    for tier in sorted(tiers):
        if tier == -1:
            continue
        t = tiers[tier]
        h_range = design_hours.get(tier, (0, 0))
        h_span = h_range[1] - h_range[0]
        content = t["recipes"] + t["orders"] + t["research"]
        # How many content pieces per hour of gameplay?
        if h_span > 0:
            density = content / h_span
            print(f"  tier {tier}: {content} contenidos / {h_span:.1f}h = {density:.1f} piezas/hora")
            if density < 5:
                print(f"     ⚠️  BAJA DENSIDAD — este tramo de {h_span:.1f}h necesita más contenido")
            if t["recipes"] == 0:
                print(f"     ⚠️  SIN RECETAS en este tier")
            if t["orders"] == 0:
                print(f"     ⚠️  SIN PEDIDOS en este tier")

    # ── final tally ──
    print("\n" + "=" * 72)
    print("  RECUENTO FINAL DE FALLOS")
    print("=" * 72)

    # Correctly count: negative margins + inflated margins are separate from other fail types
    cat_counts = {
        "integridad": len(broken),
        "rangos": len(violations),
        "falta campo 'tier'": len(missing_tier_recipes) + len(missing_tier_orders) + len(missing_tier_research),
        "margen negativo": len(negative),
        "margen inflado >+200%": len(inflated),
        "inalcanzables": len(unreachable),
        "callejones sin salida": len(dead_ends),
        "ciclos research": len(cycles),
        "unlock duplicado": len(duplicate_unlocks),
        "ratio pedidos": len(ratio_violations),
        "rep problems": len(rep_problems),
    }

    total_failures = sum(cat_counts.values())

    for cat, count in sorted(cat_counts.items(), key=lambda x: x[1], reverse=True):
        icon = "🔴" if count > 0 else "✅"
        print(f"  {icon}  {cat:30s}: {count:3d}")

    print(f"\n  {'─'*40}")
    print(f"  TOTAL FALLOS: {total_failures}")

    if total_failures == 0:
        print("\n  🎉 ECONOMÍA PERFECTA. Cero fallos.")
    else:
        print(f"\n  📋 Hay {total_failures} incidencia(s) que revisar.")

    print("\nINFORME LISTO")


if __name__ == "__main__":
    main()
