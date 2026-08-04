#!/usr/bin/env python3
"""
afinar_puertas.py — Ajusta los sumideros de oro del juego.

Tres palancas:
  1. NATURAL_LEVELS en zone_expansion_manager.gd (campo "cost")
  2. coin_cost en godot/data/research/*.tres
  3. cost en godot/data/buildables/*.tres

Modo:
  --dry-run    Muestra la tabla de cambios sin escribir nada (por defecto)
  --apply      Aplica los cambios a los archivos
"""

import argparse
import re
import sys
from pathlib import Path

GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"
DATA_DIR = GODOT_DIR / "data"

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN — editá estos valores para ajustar la progresión
# ═══════════════════════════════════════════════════════════════════════════════

# 1. Nuevos costes del Patio Natural (8 niveles, índice 0 = Pradera)
NUEVOS_COSTES_PATIO = [0, 130, 400, 900, 2200, 10000, 25000, 60000]

# 2. Multiplicadores de coin_cost de research por tier
#    tier N → multiplica el coste actual por este factor
RESEARCH_TIER_MULT = {
    1: 0.7,   # reducir para que la apertura sea más ágil (<45 min)
    2: 1.0,
    3: 3.0,
    4: 5.0,
    5: 7.0,
}

# 3. Multiplicadores de cost de buildables (generadores) por min_natural_level
#    Los buildables sin min_natural_level se tratan como nivel 0
GENERATOR_LEVEL_MULT = {
    0: 1.0,   # sin min_natural_level (tier 1-2)
    1: 1.0,
    2: 1.0,
    3: 2.5,
    4: 3.0,
    5: 5.0,
    6: 7.0,
    7: 8.0,
}

# Multiplicador para buildables QUE NO SON generadores (decoración, etc.)
# El estudio no los mide, pero afectan a la economía real
DECO_COST_MULT = 1.5


# ═══════════════════════════════════════════════════════════════════════════════
# LÓGICA
# ═══════════════════════════════════════════════════════════════════════════════

def parse_tres(text: str) -> dict:
    """Parse a Godot .tres file into sections."""
    result = {"ext_resources": {}, "resource": {}, "header": []}
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


def get_generator_levels():
    """Return dict: buildable_filename -> min_natural_level (or 0 if unset)."""
    buildables_dir = DATA_DIR / "buildables"
    levels = {}
    for fpath in sorted(buildables_dir.glob("generador_*.tres")):
        text = fpath.read_text(encoding="utf-8")
        m = re.search(r"min_natural_level\s*=\s*(\d+)", text)
        levels[fpath.name] = int(m.group(1)) if m else 0
    return levels


def get_research_data():
    """Return dict: research_filename -> {tier, coin_cost}."""
    research_dir = DATA_DIR / "research"
    data = {}
    for fpath in sorted(research_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        tier = int(res.get("tier", 0)) if res.get("tier", "").lstrip("-").isdigit() else -1
        coin = int(res.get("coin_cost", 0)) if res.get("coin_cost", "").lstrip("-").isdigit() else 0
        data[fpath.name] = {"tier": tier, "coin_cost": coin}
    return data


def get_buildable_data():
    """Return dict: buildable_filename -> {cost, is_generator, min_natural_level}."""
    buildables_dir = DATA_DIR / "buildables"
    data = {}
    for fpath in sorted(buildables_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        is_gen = fpath.name.startswith("generador_")
        m_cost = re.search(r"^cost\s*=\s*(\d+)", text, re.MULTILINE)
        if not m_cost:
            continue
        cost = int(m_cost.group(1))
        m_level = re.search(r"min_natural_level\s*=\s*(\d+)", text)
        level = int(m_level.group(1)) if m_level else 0
        data[fpath.name] = {
            "cost": cost,
            "is_generator": is_gen,
            "min_natural_level": level,
        }
    return data


def compute_changes():
    """Compute all changes and return a list of (what, old_value, new_value) tuples."""
    changes = []

    # ── 1. Patio Natural ──
    gd_path = GODOT_DIR / "scripts" / "managers" / "zone_expansion_manager.gd"
    gd_text = gd_path.read_text(encoding="utf-8")
    # Extract current costs
    current_costs = []
    for m in re.finditer(r'\{"width":\s*[\d.]+\s*,\s*"height":\s*[\d.]+\s*,\s*"cost":\s*(\d+)\s*,', gd_text):
        current_costs.append(int(m.group(1)))

    labels = ["Pradera", "Claro", "Bosquecillo", "Arboleda", "Espesura", "Fronda", "Selva", "Bosque Ancestral"]
    for i, (old, new) in enumerate(zip(current_costs, NUEVOS_COSTES_PATIO)):
        if old != new:
            changes.append((f"Patio Nv{i} ({labels[i]})", old, new))

    # ── 2. Research ──
    research = get_research_data()
    for fname, rdata in sorted(research.items()):
        tier = rdata["tier"]
        old = rdata["coin_cost"]
        mult = RESEARCH_TIER_MULT.get(tier, 1.0)
        new = max(1, round(old * mult))
        if old != new:
            changes.append((f"Research {fname}", old, new))

    # ── 3. Buildables ──
    buildables = get_buildable_data()
    for fname, bdata in sorted(buildables.items()):
        old = bdata["cost"]
        if bdata["is_generator"]:
            level = bdata["min_natural_level"]
            mult = GENERATOR_LEVEL_MULT.get(level, 1.0)
        else:
            mult = DECO_COST_MULT
        new = max(1, round(old * mult))
        if old != new:
            what = f"Buildable {fname}" + (" [gen]" if bdata["is_generator"] else " [deco]")
            changes.append((what, old, new))

    return changes


def apply_changes():
    """Write all changes to disk."""
    # ── 1. Patio Natural ──
    gd_path = GODOT_DIR / "scripts" / "managers" / "zone_expansion_manager.gd"
    gd_text = gd_path.read_text(encoding="utf-8")

    for i, new_cost in enumerate(NUEVOS_COSTES_PATIO):
        # Replace the cost for level i
        pattern = re.compile(
            r'(\{"width":\s*[\d.]+\s*,\s*"height":\s*[\d.]+\s*,\s*"cost":\s*)(\d+)(\s*,)'
        )
        matches = list(pattern.finditer(gd_text))
        if i < len(matches):
            m = matches[i]
            gd_text = gd_text[:m.start(2)] + str(new_cost) + gd_text[m.end(2):]

    gd_path.write_text(gd_text, encoding="utf-8")

    # ── 2. Research ──
    research = get_research_data()
    for fname, rdata in research.items():
        tier = rdata["tier"]
        mult = RESEARCH_TIER_MULT.get(tier, 1.0)
        new = max(1, round(rdata["coin_cost"] * mult))
        if new == rdata["coin_cost"]:
            continue
        fpath = DATA_DIR / "research" / fname
        text = fpath.read_text(encoding="utf-8")
        text = re.sub(r"(coin_cost\s*=\s*)(\d+)", f"\\g<1>{new}", text, count=1)
        fpath.write_text(text, encoding="utf-8")

    # ── 3. Buildables ──
    buildables = get_buildable_data()
    for fname, bdata in buildables.items():
        if bdata["is_generator"]:
            level = bdata["min_natural_level"]
            mult = GENERATOR_LEVEL_MULT.get(level, 1.0)
        else:
            mult = DECO_COST_MULT
        new = max(1, round(bdata["cost"] * mult))
        if new == bdata["cost"]:
            continue
        fpath = DATA_DIR / "buildables" / fname
        text = fpath.read_text(encoding="utf-8")
        text = re.sub(r"(^cost\s*=\s*)(\d+)", f"\\g<1>{new}", text, count=1, flags=re.MULTILINE)
        fpath.write_text(text, encoding="utf-8")

    # También actualizar NATURAL_LEVELS en el propio estudio para que coincida
    estudio_path = Path(__file__).resolve().parent / "estudio_progresion.py"
    estudio_text = estudio_path.read_text(encoding="utf-8")
    # Replace the NATURAL_LEVELS array in the study
    for i, new_cost in enumerate(NUEVOS_COSTES_PATIO):
        pattern = re.compile(
            r'(\{"label":\s*"[^"]+",\s*"cost":\s*)(\d+)(\})'
        )
        matches = list(pattern.finditer(estudio_text))
        if i < len(matches):
            m = matches[i]
            estudio_text = estudio_text[:m.start(2)] + str(new_cost) + estudio_text[m.end(2):]
    estudio_path.write_text(estudio_text, encoding="utf-8")


def print_table(changes):
    """Print a formatted table of changes."""
    if not changes:
        print("✅ No hay cambios pendientes.")
        return

    print(f"\n{'QUÉ':<55s} {'VIEJO':>8s} {'NUEVO':>8s} {'Δ':>8s}")
    print("-" * 80)
    total_old = 0
    total_new = 0
    for what, old, new in changes:
        delta = new - old
        print(f"{what:<55s} {old:>8d} {new:>8d} {delta:>+8d}")
        total_old += old
        total_new += new
    print("-" * 80)
    delta_total = total_new - total_old
    print(f"{'TOTAL (' + str(len(changes)) + ' cambios)':<55s} {total_old:>8d} {total_new:>8d} {delta_total:>+8d}")

    # Group by category
    patio = sum(new - old for w, old, new in changes if w.startswith("Patio"))
    research_c = sum(new - old for w, old, new in changes if w.startswith("Research"))
    buildable_c = sum(new - old for w, old, new in changes if w.startswith("Buildable"))
    print(f"\n  → Patio: +{patio}  |  Research: +{research_c}  |  Buildables: +{buildable_c}")


def main():
    parser = argparse.ArgumentParser(description="Afina los sumideros de Mystic Emporium")
    parser.add_argument("--apply", action="store_true", help="Aplicar los cambios a los archivos")
    args = parser.parse_args()

    changes = compute_changes()
    print_table(changes)

    if args.apply:
        print("\n⚠️  Aplicando cambios...")
        apply_changes()
        print("✅ Cambios aplicados. Ejecutá `python3 tools/estudio_progresion.py` para ver el efecto.")
    else:
        print(f"\n🔍 DRY RUN — {len(changes)} cambios pendientes. Usá --apply para escribirlos.")


if __name__ == "__main__":
    main()
