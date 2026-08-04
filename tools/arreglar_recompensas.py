#!/usr/bin/env python3
"""
Arregla los coin_reward de todos los pedidos usando la formula del juego:
    coin_reward = int(item.base_value * qty * (1.0 + tier * 0.3))

Fuente: godot/scripts/managers/order_manager.gd linea 437

Solo toca la linea `coin_reward = N` de ficheros en godot/data/orders/.
"""

import os
import re
import sys
from pathlib import Path

GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"
DATA_DIR = GODOT_DIR / "data"


def parse_tres(text: str) -> dict:
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
    m = re.match(r'ExtResource\("(.+?)"\)', ref_str)
    if not m:
        return ""
    eid = m.group(1)
    return ext_resources.get(eid, {}).get("path", "")


def load_items():
    items_by_path = {}
    items_dir = DATA_DIR / "items"
    for fpath in sorted(items_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        rel = str(fpath.relative_to(GODOT_DIR))
        path = f"res://{rel}"
        items_by_path[path] = {
            "id": res.get("id", "").strip('&"'),
            "display_name": res.get("display_name", "").strip('"'),
            "base_value": int(res.get("base_value", 0)) if res.get("base_value", "0").lstrip("-").isdigit() else 0,
            "tier": int(res.get("tier", 0)) if res.get("tier", "0").lstrip("-").isdigit() else -1,
        }
    return items_by_path


def compute_reward(base_value: int, qty: int, tier: int) -> int:
    return int(base_value * qty * (1.0 + tier * 0.3))


def main():
    print("=" * 72)
    print("  ARREGLAR RECOMPENSAS — Diagnóstico")
    print("=" * 72)

    items_by_path = load_items()
    orders_dir = DATA_DIR / "orders"

    changes = []

    print(f"\n📋 Todos los pedidos y su ratio actual vs. formula:")
    print(f"   {'ID':<35} {'Item':<25} {'Qty':>4} {'Tier':>4} {'Value':>7} {'Coin Actual':>12} {'Coin Formula':>13} {'Ratio':>7} {'NuevoRatio':>10}")
    print(f"   {'─'*35} {'─'*25} {'─'*4} {'─'*4} {'─'*7} {'─'*12} {'─'*13} {'─'*7} {'─'*10}")

    for fpath in sorted(orders_dir.glob("*.tres")):
        text = fpath.read_text(encoding="utf-8")
        parsed = parse_tres(text)
        res = parsed["resource"]
        ext = parsed["ext_resources"]

        order_id = res.get("id", "").strip('&"')
        display_name = res.get("display_name", "").strip('"')
        tier_raw = res.get("tier", "-1")
        tier = int(tier_raw) if tier_raw.lstrip("-").isdigit() else -1
        qty_raw = res.get("requested_quantity", "0")
        qty = int(qty_raw) if qty_raw.lstrip("-").isdigit() else 0
        coin_raw = res.get("coin_reward", "0")
        current_coin = int(coin_raw) if coin_raw.lstrip("-").isdigit() else 0

        requested_raw = res.get("requested_item", "")
        item_path = resolve_ext_resource_path(ext, requested_raw)
        item = items_by_path.get(item_path, {})
        base_value = item.get("base_value", 0)

        if tier <= 0:
            print(f"   {order_id:<35} {item.get('id', '?'):<25} {qty:>4} {'?':>4} {base_value:>7} {current_coin:>12} {'─':>13} {'─':>7} {'sin tier':>10}")
            continue

        if base_value <= 0:
            print(f"   {order_id:<35} {item.get('id', '?'):<25} {qty:>4} {tier:>4} {base_value:>7} {current_coin:>12} {'─':>13} {'─':>7} {'value=0':>10}")
            continue

        new_coin = compute_reward(base_value, qty, tier)
        total_value = base_value * qty
        old_ratio = current_coin / total_value if total_value > 0 else 0
        new_ratio = new_coin / total_value if total_value > 0 else 0

        status = ""
        if current_coin != new_coin:
            status = "🔧"
            changes.append((str(fpath), order_id, current_coin, new_coin, display_name))

        print(f"   {order_id:<35} {item.get('id', '?'):<25} {qty:>4} {tier:>4} {base_value:>7} {current_coin:>12} {new_coin:>13} {old_ratio:>7.2f} {new_ratio:>10.2f} {status}")

    print(f"\n📋 Cambios a aplicar ({len(changes)}):")
    print(f"   {'Archivo':<35} {'Coin Actual':>12} {'Coin Nuevo':>12} {'Pedido'}")
    print(f"   {'─'*35} {'─'*12} {'─'*12} {'─'*30}")
    for filepath, oid, old, new, dname in changes:
        fname = os.path.basename(filepath)
        print(f"   {fname:<35} {old:>12} {new:>12} {dname}")

    # ── Aplicar ──
    print(f"\n⏳ Aplicando {len(changes)} cambios...")
    applied = 0
    for filepath, oid, old_coin, new_coin, dname in changes:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        # Replace the exact coin_reward line
        old_line = f"coin_reward = {old_coin}"
        new_line = f"coin_reward = {new_coin}"
        if old_line in content:
            content = content.replace(old_line, new_line, 1)
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
            applied += 1
            print(f"  ✓ {os.path.basename(filepath)}: {old_coin} → {new_coin}")
        else:
            # Try regex match
            pattern = re.compile(r'^(\s*)coin_reward\s*=\s*\d+', re.MULTILINE)
            match = pattern.search(content)
            if match:
                indent = match.group(1)
                content = pattern.sub(f"{indent}coin_reward = {new_coin}", content, count=1)
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                applied += 1
                print(f"  ✓ {os.path.basename(filepath)}: {old_coin} → {new_coin} (regex)")
            else:
                print(f"  ❌ {os.path.basename(filepath)}: no se encontró coin_reward = {old_coin}")

    print(f"\n✅ {applied}/{len(changes)} cambios aplicados.")


if __name__ == "__main__":
    main()
