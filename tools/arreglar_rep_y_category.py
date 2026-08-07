#!/usr/bin/env python3
"""
1. Añade min_reputation a los 5 pedidos que no lo tienen.
2. Cambia category=5 → category=3 (CURRENCY) en 5 items.
"""

import re
from pathlib import Path

GODOT_DIR = Path(__file__).resolve().parent.parent / "godot"

# ── min_reputation ──
REP_MAP = {
    "pedido_cristal.tres": 0,    # tier 1
    "pedido_hierba.tres": 0,     # tier 1
    "pedido_polvo.tres": 5,      # tier 2
    "pedido_pocion.tres": 25,    # tier 3 (> tier 2 max=20)
    "pedido_daga.tres": 60,      # tier 4 (> tier 3 max=55)
}

# ── category 5 → 3 ──
CAT5_ITEMS = [
    "arcane_coin.tres",
    "cristal_reputacion.tres",
    "invitacion_vip.tres",
    "token_evento.tres",
    "vale_gremio.tres",
]

print("=" * 60)
print("  1. AÑADIENDO min_reputation A PEDIDOS")
print("=" * 60)

orders_dir = GODOT_DIR / "data" / "orders"
for fname, min_rep in REP_MAP.items():
    fpath = orders_dir / fname
    text = fpath.read_text(encoding="utf-8")

    if "min_reputation" in text:
        print(f"  SKIP {fname}: ya tiene min_reputation")
        continue

    # Insert min_reputation after tier line
    lines = text.splitlines()
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if line.strip().startswith("tier ="):
            new_lines.append(f"min_reputation = {min_rep}")

    fpath.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    print(f"  ✓ {fname}: min_reputation = {min_rep}")

print(f"\n{'='*60}")
print("  2. CAMBIANDO category=5 → category=3 (CURRENCY)")
print("=" * 60)

items_dir = GODOT_DIR / "data" / "items"
for fname in CAT5_ITEMS:
    fpath = items_dir / fname
    text = fpath.read_text(encoding="utf-8")

    old = "category = 5"
    new = "category = 3"
    if old in text:
        text = text.replace(old, new, 1)
        fpath.write_text(text, encoding="utf-8")
        print(f"  ✓ {fname}: category = 5 → 3")
    else:
        print(f"  ⚠️ {fname}: no se encontró 'category = 5'")

print("\n✅ Listo.")
