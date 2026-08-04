#!/usr/bin/env python3
"""
estudio_progresion.py — Estudio de viabilidad económica de la progresión.

Simula una partida sobre los datos reales (items, recetas, pedidos,
investigaciones, expansiones de Patio Natural, generadores) y responde
con NÚMEROS:

  a) Cuellos de botella por tier
  b) Coste de entrada a cada tier
  c) Ingreso por hora estimado
  d) Veredicto: horas para costear cada tier vs diseño
  e) Los 3 últimos niveles del Patio

NO modifica ningún dato del juego. Solo LEE.
"""

import re
from collections import defaultdict
from pathlib import Path

GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"
DATA_DIR = GODOT_DIR / "data"


# ── harvestable discovery ────────────────────────────────────────────────────

def build_harvestable_ids() -> set:
    enums_path = GODOT_DIR / "scripts" / "core" / "global_enums.gd"
    enum_text = enums_path.read_text(encoding="utf-8")
    m_block = re.search(r"enum\s+ResourceType\s*\{([^}]+)\}", enum_text)
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
        m2 = re.search(r"min_natural_level\s*=\s*(\d+)", text)
        # not needed here

    harvestable = set()
    for num in sorted(generator_types):
        enum_name = number_to_name.get(num)
        if enum_name:
            item_id = name_to_item.get(enum_name)
            if item_id:
                harvestable.add(item_id)
    return harvestable


# ── enum name mapping (for worker preferences) ───────────────────────────────

def build_enum_number_to_name() -> dict:
    enums_path = GODOT_DIR / "scripts" / "core" / "global_enums.gd"
    enum_text = enums_path.read_text(encoding="utf-8")
    m_block = re.search(r"enum\s+ResourceType\s*\{([^}]+)\}", enum_text)
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
    return number_to_name


# ── .tres parsing ────────────────────────────────────────────────────────────

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


# ── data loading ─────────────────────────────────────────────────────────────

def load_items():
    items = {}
    for fpath in sorted((DATA_DIR / "items").glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        item_id = res.get("id", "").strip('&"')
        items[item_id] = {
            "path": f"res://{fpath.relative_to(GODOT_DIR)}",
            "base_value": (
                int(res.get("base_value", 0))
                if res.get("base_value", "0").lstrip("-").isdigit()
                else 0
            ),
            "display_name": res.get("display_name", "").strip('"'),
            "tier": (
                int(res.get("tier", 0))
                if res.get("tier", "").lstrip("-").isdigit()
                else -1
            ),
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
            "crafting_time": (
                float(res.get("crafting_time", 0))
                if res.get("crafting_time", "0").replace(".", "", 1).lstrip("-").isdigit()
                else 0.0
            ),
        }
    return recipes


def load_orders(items_by_path):
    orders = {}
    for fpath in sorted((DATA_DIR / "orders").glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]
        order_id = res.get("id", "").strip('&"')

        requested_raw = res.get("requested_item", "")
        requested_path = resolve_ext_resource(ext, requested_raw)
        requested_id = items_by_path.get(requested_path, "")

        orders[order_id] = {
            "display_name": res.get("display_name", "").strip('"'),
            "requested_item_id": requested_id,
            "requested_quantity": (
                int(res.get("requested_quantity", 0))
                if res.get("requested_quantity", "0").lstrip("-").isdigit()
                else 0
            ),
            "coin_reward": (
                int(res.get("coin_reward", 0))
                if res.get("coin_reward", "0").lstrip("-").isdigit()
                else 0
            ),
            "tier": (
                int(res.get("tier", 0))
                if res.get("tier", "").lstrip("-").isdigit()
                else -1
            ),
            "min_reputation": (
                int(res.get("min_reputation", 0))
                if res.get("min_reputation", "0").lstrip("-").isdigit()
                else 0
            ),
        }
    return orders


def load_research(items_by_path, recipes_by_path):
    research = {}
    for fpath in sorted((DATA_DIR / "research").glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res_parsed = parsed["resource"]
        ext = parsed["ext_resources"]
        research_id = res_parsed.get("id", "").strip('&"')

        research[research_id] = {
            "display_name": res_parsed.get("display_name", "").strip('"'),
            "coin_cost": (
                int(res_parsed.get("coin_cost", 0))
                if res_parsed.get("coin_cost", "").lstrip("-").isdigit()
                else 0
            ),
            "research_time": (
                float(res_parsed.get("research_time", 0))
                if res_parsed.get("research_time", "0").replace(".", "", 1).lstrip("-").isdigit()
                else 0.0
            ),
            "tier": (
                int(res_parsed.get("tier", 0))
                if res_parsed.get("tier", "").lstrip("-").isdigit()
                else -1
            ),
        }
    return research


# ── generator data ───────────────────────────────────────────────────────────

def load_generator_data():
    """Return dict: item_id -> {min_natural_level, build_cost}."""
    enum_num_to_name = build_enum_number_to_name()

    bootstrap_path = GODOT_DIR / "scripts" / "core" / "game_bootstrap.gd"
    bootstrap_text = bootstrap_path.read_text(encoding="utf-8")
    name_to_item = {}
    for m in re.finditer(
        r"GameEnums\.ResourceType\.(\w+)\s*:\s*_find_item_by_id\(&\"(\w+)\"\)",
        bootstrap_text,
    ):
        name_to_item[m.group(1)] = m.group(2)

    # Read min_natural_level from each generator scene
    scenes_dir = GODOT_DIR / "scenes" / "environment"
    gen_info = {}  # item_id -> {min_level, build_cost}
    for fpath in scenes_dir.glob("resource_generator_*.tscn"):
        text = fpath.read_text(encoding="utf-8")
        m_type = re.search(r"resource_type\s*=\s*(\d+)", text)
        m_level = re.search(r"min_natural_level\s*=\s*(\d+)", text)
        if m_type:
            rtype = int(m_type.group(1))
            enum_name = enum_num_to_name.get(rtype, "")
            item_id = name_to_item.get(enum_name, "")
            if item_id:
                gen_info[item_id] = {
                    "min_natural_level": int(m_level.group(1)) if m_level else 0,
                    "resource_type": rtype,
                }

    # Read build costs from buildable data files (only 8 exist)
    buildables_dir = DATA_DIR / "buildables"
    for fpath in buildables_dir.glob("generador_*.tres"):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        # Find which scene it references
        ext = parsed["ext_resources"]
        for eid, edata in ext.items():
            spath = edata.get("path", "")
            if "resource_generator_" in spath:
                # Read the scene to get resource_type
                scene_path = GODOT_DIR / spath[len("res://"):]
                if scene_path.exists():
                    stext = scene_path.read_text(encoding="utf-8")
                    m_type = re.search(r"resource_type\s*=\s*(\d+)", stext)
                    if m_type:
                        rtype = int(m_type.group(1))
                        enum_name = enum_num_to_name.get(rtype, "")
                        item_id = name_to_item.get(enum_name, "")
                        if item_id and item_id in gen_info:
                            cost = int(res.get("cost", 0)) if res.get("cost", "0").lstrip("-").isdigit() else 0
                            gen_info[item_id]["build_cost"] = cost

    # Estimate missing costs based on pattern (cost = 30 * (min_natural_level + 1) * multiplier)
    # Actual costs: herbs(0)=30, crystal(0)=60, iron(0)=110, pozo(2)=220,
    #               altar(3)=320, geoda(3)=380, forja(4)=480, santuario(4)=560
    # Rough formula: cost ≈ 50 + 130*min_natural_level
    for item_id, info in gen_info.items():
        if "build_cost" not in info:
            level = info["min_natural_level"]
            # Approximate based on known data
            info["build_cost"] = 30 + 130 * level
            if level >= 5:
                info["build_cost"] = 300 + 200 * level  # steeper for high levels

    return gen_info


# ── worker data ──────────────────────────────────────────────────────────────

WORKER_PREFERENCES = {
    "Duende": ["hierba_lunar"],
    "Golem": ["cristal_cuarzo", "mena_hierro", "sal_abisal", "nucleo_obsidiana", "corazon_magmatico", "rayo_cristalizado"],
    "Lenador": ["madera_arcana", "raiz_umbria", "savia_ancestral"],
    "Espiritu": ["agua_arcana", "polvo_lunar", "fragmento_amatista", "esencia_espiritual", "lingote_hierro", "ceniza_estelar", "polvo_espectro", "fragmento_celestial", "escarcha_eterna"],
}

# ── Patio Natural expansion ──────────────────────────────────────────────────

# From zone_expansion_manager.gd, NATURAL_LEVELS constant
NATURAL_LEVELS = [
    {"label": "Pradera", "cost": 0},
    {"label": "Claro", "cost": 130},
    {"label": "Bosquecillo", "cost": 400},
    {"label": "Arboleda", "cost": 900},
    {"label": "Espesura", "cost": 2200},
    {"label": "Fronda", "cost": 10000},
    {"label": "Selva", "cost": 25000},
    {"label": "Bosque Ancestral", "cost": 60000},
]


# ── main analysis ────────────────────────────────────────────────────────────

def main():
    print("=" * 90)
    print("  MYSTIC EMPORIUM — ESTUDIO DE PROGRESIÓN")
    print("=" * 90)

    # ── Load data ──
    items = load_items()
    items_by_path = {i["path"]: iid for iid, i in items.items()}
    recipes = load_recipes(items_by_path)
    orders = load_orders(items_by_path)
    research = load_research(
        items_by_path,
        {f"res://{str(rfile.relative_to(GODOT_DIR))}": rid
         for rid, rfile in [(rid, Path(r["file"])) for rid, r in recipes.items()]},
    )
    harvestable = build_harvestable_ids()
    gen_info = load_generator_data()

    print(f"\nDatos: {len(items)} items, {len(recipes)} recetas, {len(orders)} pedidos, {len(research)} investigaciones")
    print(f"Recolectables: {len(harvestable)}, Generadores con datos: {len(gen_info)}")

    # ── Group content by tier ──
    tiers = defaultdict(lambda: {"items": [], "recipes": [], "orders": [], "research": []})
    for iid, item in items.items():
        t = item["tier"]
        if t > 0:
            tiers[t]["items"].append(iid)
    for rid, r in recipes.items():
        t = r["tier"]
        if t > 0:
            tiers[t]["recipes"].append(rid)
    for oid, o in orders.items():
        t = o["tier"]
        if t > 0:
            tiers[t]["orders"].append(oid)
    for rid, r in research.items():
        t = r["tier"]
        if t > 0:
            tiers[t]["research"].append(rid)

    # ═══════════════════════════════════════════════════════════════════════════
    # a) CUELLOS DE BOTELLA
    # ═══════════════════════════════════════════════════════════════════════════
    print("\n" + "=" * 90)
    print("  a) CUELLOS DE BOTELLA — Consumo de recolectables por tier")
    print("=" * 90)

    for tier in sorted(tiers):
        if tier == -1:
            continue
        # For this tier, sum up ingredient usage across all recipes
        # Estimate crafting frequency: simpler recipes craft faster, so normalize by crafting_time
        resource_demand = defaultdict(float)  # item_id -> demand per hour
        for rid in tiers[tier]["recipes"]:
            r = recipes[rid]
            ct = r["crafting_time"]
            if ct <= 0:
                ct = 10.0  # default
            crafts_per_hour = 3600.0 / ct
            for iid, qty in zip(r["ingredient_ids"], r["ingredient_quantities"]):
                if iid in harvestable:
                    resource_demand[iid] += qty * crafts_per_hour

        if resource_demand:
            print(f"\n── Tier {tier} ──")
            sorted_demands = sorted(resource_demand.items(), key=lambda x: x[1], reverse=True)
            for iid, demand in sorted_demands:
                # Which workers can collect this?
                workers = [w for w, prefs in WORKER_PREFERENCES.items() if iid in prefs]
                worker_str = ", ".join(workers) if workers else "❓ ninguno"
                bar = "█" * min(40, int(demand / max(1, sorted_demands[0][1]) * 40))
                print(f"  {iid:<28s} {demand:>8.1f}/h  {bar}  [{worker_str}]")

            # Highlight bottleneck: resource with highest demand that only one worker type collects
            solo_workers = {}
            for iid, demand in resource_demand.items():
                workers = [w for w, prefs in WORKER_PREFERENCES.items() if iid in prefs]
                if len(workers) == 1:
                    solo_workers[iid] = (demand, workers[0])

            if solo_workers:
                print(f"\n  ⚠️  CUELLOS DE BOTELLA (1 solo tipo de ayudante):")
                for iid, (demand, worker) in sorted(solo_workers.items(), key=lambda x: x[1][0], reverse=True):
                    print(f"     • {iid}: {demand:.0f}/h → SOLO {worker}")
        else:
            print(f"\n── Tier {tier}: sin recetas que usen recolectables ──")

    # ═══════════════════════════════════════════════════════════════════════════
    # b) COSTE DE ENTRADA A CADA TIER
    # ═══════════════════════════════════════════════════════════════════════════
    print("\n" + "=" * 90)
    print("  b) COSTE DE ENTRADA A CADA TIER")
    print("=" * 90)

    # Determine which patio levels are needed to unlock generators for each tier
    # Map: tier -> set of harvestable items used as ingredients by recipes of that tier
    tier_harvestables = {}
    for tier in sorted(tiers):
        needed = set()
        for rid in tiers[tier]["recipes"]:
            r = recipes[rid]
            for iid in r["ingredient_ids"]:
                if iid in harvestable:
                    needed.add(iid)
        tier_harvestables[tier] = needed

    # For each tier, find max natural_level needed to unlock those generators
    # Plus sum of research coin_cost for that tier
    # Plus generator build costs

    for tier in sorted(tiers):
        if tier == -1:
            continue

        # Research cost for this tier
        research_cost = sum(
            research[rid]["coin_cost"]
            for rid in tiers[tier]["research"]
            if rid in research
        )

        # Generator costs for harvestables used in this tier
        gen_cost = 0
        max_nat_level = 0
        for iid in tier_harvestables.get(tier, set()):
            if iid in gen_info:
                gi = gen_info[iid]
                gen_cost += gi.get("build_cost", 0)
                max_nat_level = max(max_nat_level, gi.get("min_natural_level", 0))

        # Patio cost: cumulative to reach max_nat_level
        patio_cost = sum(lvl["cost"] for lvl in NATURAL_LEVELS[: max_nat_level + 1])

        total_entry = research_cost + gen_cost + patio_cost

        print(f"\n── Tier {tier} ──")
        print(f"  Recolectables necesarios: {', '.join(sorted(tier_harvestables.get(tier, set()))) or 'ninguno'}")
        print(f"  Investigaciones: {len(tiers[tier]['research'])} — coste total: {research_cost} monedas")
        print(f"  Generadores: {len([i for i in tier_harvestables.get(tier, set()) if i in gen_info])} — coste total: {gen_cost} monedas")
        print(f"  Patio Natural nivel {max_nat_level} — coste acumulado: {patio_cost} monedas")
        print(f"  COSTE TOTAL DE ENTRADA: {total_entry} monedas")

    # ═══════════════════════════════════════════════════════════════════════════
    # c) INGRESO POR HORA
    # ═══════════════════════════════════════════════════════════════════════════
    print("\n" + "=" * 90)
    print("  c) INGRESO POR HORA ESTIMADO")
    print("=" * 90)

    # Orders are filtered by min_reputation. We assume the player's reputation
    # reaches the threshold for each tier. Orders have a coin_reward.
    # We estimate 2 active orders at a time, each taking ~5-10 min to fulfill.
    # Income = sum(coin_reward for orders in this tier) / avg_fulfillment_time * active_slots

    # Simpler model: all orders in a tier are available once rep threshold is met.
    # Average order reward × orders_per_hour
    # Assume 3 active order slots, average 3 min to fulfill = 60 orders/h capacity
    # But realistically: player fulfills 10-20 orders per hour

    ORDERS_PER_HOUR = 15  # reasonable estimate for mid-game

    for tier in sorted(tiers):
        if tier == -1:
            continue

        tier_orders = [orders[oid] for oid in tiers[tier]["orders"] if oid in orders]
        if not tier_orders:
            print(f"\n── Tier {tier}: sin pedidos ──")
            continue

        avg_reward = sum(o["coin_reward"] for o in tier_orders) / len(tier_orders)
        total_rewards = sum(o["coin_reward"] for o in tier_orders)

        # Income from orders
        order_income_h = avg_reward * ORDERS_PER_HOUR

        # Income from direct sales (crafting margin ~25% after fixes)
        # Average recipe at this tier
        tier_recipes_list = [recipes[rid] for rid in tiers[tier]["recipes"] if rid in recipes]
        avg_craft_profit = 0
        if tier_recipes_list:
            profits = []
            for r in tier_recipes_list:
                cost = sum(
                    items[iid]["base_value"] * qty
                    for iid, qty in zip(r["ingredient_ids"], r["ingredient_quantities"])
                    if iid in items
                )
                revenue = items[r["output_id"]]["base_value"] * r["output_quantity"] if r["output_id"] in items else 0
                if cost > 0:
                    profits.append(revenue - cost)
            if profits:
                avg_craft_profit = sum(profits) / len(profits)

        print(f"\n── Tier {tier} ──")
        print(f"  Pedidos disponibles: {len(tier_orders)}")
        print(f"  Recompensa media por pedido: {avg_reward:.0f} monedas")
        print(f"  Recompensa total del tier: {total_rewards} monedas")
        print(f"  Ingreso estimado (pedidos, {ORDERS_PER_HOUR}/h): {order_income_h:.0f} monedas/hora")
        if avg_craft_profit > 0:
            print(f"  Beneficio medio por crafteo: {avg_craft_profit:.0f} monedas")
            print(f"  Ingreso estimado (craft + pedidos): {order_income_h + avg_craft_profit * 5:.0f} monedas/hora (aprox)")

    # ═══════════════════════════════════════════════════════════════════════════
    # d) EL VEREDICTO
    # ═══════════════════════════════════════════════════════════════════════════
    print("\n" + "=" * 90)
    print("  d) VEREDICTO — Horas para costear cada tier")
    print("=" * 90)

    # Design targets:
    #   t1 0:00-0:45  t2 0:45-3:00  t3 3:00-8:00  t4 8:00-13:00  t5 13:00-20:00
    design_hours = {
        1: (0, 0.75),
        2: (0.75, 3.0),
        3: (3.0, 8.0),
        4: (8.0, 13.0),
        5: (13.0, 20.0),
    }

    # Compute estimated income per hour for each tier (from orders)
    tier_income = {}
    for tier in sorted(tiers):
        if tier == -1:
            continue
        tier_orders_list = [orders[oid] for oid in tiers[tier]["orders"] if oid in orders]
        if tier_orders_list:
            avg_reward = sum(o["coin_reward"] for o in tier_orders_list) / len(tier_orders_list)
            tier_income[tier] = avg_reward * ORDERS_PER_HOUR
        else:
            tier_income[tier] = 50  # fallback for tier 1

    # Compute entry costs (cumulative)
    entry_costs = {}
    for tier in sorted(tiers):
        if tier == -1:
            continue
        needed_harv = tier_harvestables.get(tier, set())
        research_cost = sum(
            research[rid]["coin_cost"]
            for rid in tiers[tier]["research"]
            if rid in research
        )
        gen_cost = 0
        max_nat = 0
        for iid in needed_harv:
            if iid in gen_info:
                gi = gen_info[iid]
                gen_cost += gi.get("build_cost", 0)
                max_nat = max(max_nat, gi.get("min_natural_level", 0))
        patio_cost = sum(lvl["cost"] for lvl in NATURAL_LEVELS[: max_nat + 1])
        entry_costs[tier] = research_cost + gen_cost + patio_cost

    print(f"\n  {'Tier':<6} {'Coste entrada':>14} {'Ingreso/h':>10} {'Horas p/costear':>16} {'Rango diseño':>15} {'Veredicto'}")
    print(f"  {'─'*6} {'─'*14} {'─'*10} {'─'*16} {'─'*15} {'─'*30}")

    cumulative_hours = 0
    total_hours = 0
    verdicts = []

    for tier in sorted(entry_costs):
        cost = entry_costs[tier]
        income = tier_income.get(tier, 100)

        # New entry cost (incremental for this tier)
        prev_cost = entry_costs.get(tier - 1, 0)
        incremental_cost = cost - prev_cost

        hours = incremental_cost / income if income > 0 else 999
        cumulative_hours += hours
        total_hours = max(total_hours, cumulative_hours)

        design_lo, design_hi = design_hours.get(tier, (0, 0))

        if cumulative_hours <= design_hi:
            verdict = "✅ EN RANGO"
        elif cumulative_hours <= design_hi * 1.3:
            verdict = "⚠️  LIGERAMENTE TARDE"
        elif cumulative_hours <= design_hi * 1.8:
            verdict = "🔶 TARDE"
        else:
            verdict = "🔴 MUY TARDE — SE ATASCA"

        if hours < 0.1:
            verdict = "✅ TRIVIAL"

        verdicts.append((tier, cumulative_hours, verdict))

        print(f"  {tier:<6} {cost:>14.0f} {income:>10.0f} {cumulative_hours:>15.1f}h {'(' + str(design_lo) + '-' + str(design_hi) + 'h)':>15} {verdict}")

    print(f"\n  ── DURACIÓN TOTAL ESTIMADA: {total_hours:.1f} horas ──")

    # ═══════════════════════════════════════════════════════════════════════════
    # e) LOS TRES ÚLTIMOS NIVELES DEL PATIO
    # ═══════════════════════════════════════════════════════════════════════════
    print("\n" + "=" * 90)
    print("  e) ANÁLISIS DE LOS 3 ÚLTIMOS NIVELES DEL PATIO")
    print("=" * 90)

    # Last 3: levels 5 (Fronda, 4000), 6 (Selva, 9000), 7 (Bosque Ancestral, 20000)
    # These unlock the new harvestables (levels 5, 6, 7)

    last_three = [
        (5, NATURAL_LEVELS[5]),
        (6, NATURAL_LEVELS[6]),
        (7, NATURAL_LEVELS[7]),
    ]

    # Which generators unlock at each level?
    for level, ldata in last_three:
        unlocked_gens = [
            (iid, gi) for iid, gi in gen_info.items()
            if gi["min_natural_level"] == level
        ]
        print(f"\n── Nivel {level} — {ldata['label']} (coste: {ldata['cost']} monedas) ──")
        if unlocked_gens:
            print(f"  Generadores desbloqueados:")
            for iid, gi in unlocked_gens:
                workers = [w for w, prefs in WORKER_PREFERENCES.items() if iid in prefs]
                print(f"     • {iid} (coste build: {gi['build_cost']} ⚜) — recolectado por: {', '.join(workers) if workers else '❓'}")

        # Cumulative cost to reach this level
        cum_cost = sum(lvl["cost"] for lvl in NATURAL_LEVELS[: level + 1])
        # Which tier does this level correspond to?
        # Levels 5-7 are ~tier 4-5
        corresponding_tier = 4 if level == 5 else 5
        est_income = tier_income.get(corresponding_tier, 500)

        hours_to_reach = cum_cost / est_income if est_income > 0 else 999
        design_lo, design_hi = design_hours.get(corresponding_tier, (5, 10))

        print(f"  Coste acumulado de patio: {cum_cost} monedas")
        print(f"  Ingreso estimado en tier {corresponding_tier}: {est_income:.0f}/h")
        print(f"  Horas hasta costearlo: {hours_to_reach:.1f}h")
        print(f"  Rango diseño para tier {corresponding_tier}: {design_lo}-{design_hi}h")

        if hours_to_reach <= design_hi:
            print(f"  ✅ ALCANZABLE dentro del rango de diseño")
        elif hours_to_reach <= design_hi * 1.5:
            print(f"  ⚠️  TARDE pero factible")
        elif hours_to_reach <= design_hi * 2.5:
            print(f"  🔶 MUY TARDE — posible muro")
        else:
            print(f"  🔴 MURO — {hours_to_reach:.1f}h vs {design_hi}h de diseño")

    # ── Final summary ──
    print("\n" + "=" * 90)
    print("  RESUMEN FINAL")
    print("=" * 90)
    print(f"\n  Duración total estimada: {total_hours:.1f} horas")
    print(f"  Diseño declarado: 18-20 horas")
    for tier, cum_h, verdict in verdicts:
        print(f"    Tier {tier}: alcanzado a las {cum_h:.1f}h — {verdict}")


if __name__ == "__main__":
    main()
