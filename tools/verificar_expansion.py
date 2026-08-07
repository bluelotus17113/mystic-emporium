#!/usr/bin/env python3
"""Verifica la geometría de la expansión del Patio Natural.

Lee las constantes directamente del GDScript (sin copiarlas aquí) y comprueba
5 afirmaciones sobre los rects de los 8 niveles. Si mañana cambian los números
en zone_expansion_manager.gd, este script sigue diciendo la verdad.
"""

import re
import sys
from pathlib import Path


def parse_gdscript(path: str) -> dict:
    """Extrae las constantes y niveles del GDScript usando regex."""
    text = Path(path).read_text(encoding="utf-8")

    def _float(name: str) -> float:
        m = re.search(rf"const\s+{name}\s*:\s*float\s*=\s*([-\d.]+)", text)
        if not m:
            raise ValueError(f"No se encontró {name} en {path}")
        return float(m.group(1))

    map_right_x = _float("MAP_RIGHT_X")
    map_w = _float("MAP_W")
    map_h = _float("MAP_H")
    map_margin = _float("MAP_MARGIN")

    # Extraer el array NATURAL_LEVELS
    m = re.search(r"const\s+NATURAL_LEVELS\s*:\s*Array\s*=\s*\[(.*?)\]", text, re.DOTALL)
    if not m:
        raise ValueError("No se encontró NATURAL_LEVELS")
    levels_text = m.group(1)

    # Parsear cada diccionario {"width": X, "height": Y, "cost": Z, "label": "..."}
    levels = []
    for d in re.finditer(
        r'\{\s*"width"\s*:\s*([\d.]+)\s*,\s*"height"\s*:\s*([\d.]+)\s*,\s*"cost"\s*:\s*(\d+)\s*,\s*"label"\s*:\s*"([^"]+)"\s*\}',
        levels_text,
    ):
        levels.append(
            {
                "width": float(d.group(1)),
                "height": float(d.group(2)),
                "cost": int(d.group(3)),
                "label": d.group(4),
            }
        )

    if len(levels) != 8:
        raise ValueError(f"Se esperaban 8 niveles, se encontraron {len(levels)}")

    return {
        "MAP_RIGHT_X": map_right_x,
        "MAP_W": map_w,
        "MAP_H": map_h,
        "MAP_MARGIN": map_margin,
        "levels": levels,
    }


def compute_rects(data: dict) -> list[tuple[int, "Rect2"]]:
    """Reproduce la fórmula del GDScript: devuelve (nivel, Rect2)."""
    import math

    Rect2 = type("Rect2", (), {})  # namespace mínimo

    def make_rect(x, y, w, h):
        r = Rect2()
        r.x = x
        r.y = y
        r.w = w
        r.h = h
        r.position = type("Vec2", (), {"x": x, "y": y})()
        r.end = type("Vec2", (), {"x": x + w, "y": y + h})()
        r.size = type("Vec2", (), {"x": w, "y": h})()
        r.get_center = lambda self=r: type("Vec2", (), {
            "x": self.x + self.w / 2,
            "y": self.y + self.h / 2,
        })()
        return r

    m = make_rect(
        data["MAP_RIGHT_X"] - data["MAP_W"],
        -data["MAP_H"] / 2,
        data["MAP_W"],
        data["MAP_H"],
    )
    center = m.get_center()

    rects = []
    for i, lvl in enumerate(data["levels"]):
        w = min(float(lvl["width"]), m.w - 2.0 * data["MAP_MARGIN"])
        h = min(float(lvl["height"]), m.h - 2.0 * data["MAP_MARGIN"])
        r = make_rect(center.x - w / 2, center.y - h / 2, w, h)
        rects.append((i, r))

    return rects


def main() -> None:
    gd_path = "godot/scripts/managers/zone_expansion_manager.gd"
    data = parse_gdscript(gd_path)

    map_right_x = data["MAP_RIGHT_X"]
    map_w = data["MAP_W"]
    map_h = data["MAP_H"]
    margin = data["MAP_MARGIN"]
    levels = data["levels"]

    rects = compute_rects(data)

    # --- Mapa ---
    map_x = map_right_x - map_w
    map_y = -map_h / 2
    map_cx = map_x + map_w / 2
    map_cy = map_y + map_h / 2
    map_area = map_w * map_h

    print("=" * 72)
    print("VERIFICACIÓN GEOMÉTRICA — Patio Natural (centrado)")
    print("=" * 72)
    print(f"Mapa:    Rect2({map_x:.0f}, {map_y:.0f}, {map_w:.0f}, {map_h:.0f})")
    print(f"Centro:  ({map_cx:.0f}, {map_cy:.0f})")
    print(f"Margen:  {margin:.0f} px")
    print()

    # === 1. CENTRADOS ===
    print("─── 1. ¿Están centrados los 8 rects? ───")
    all_centered = True
    for i, r in rects:
        c = r.get_center()
        dx = abs(c.x - map_cx)
        dy = abs(c.y - map_cy)
        ok = dx <= 0.5 and dy <= 0.5
        if not ok:
            all_centered = False
        print(
            f"  nivel {i} centro=({c.x:7.1f}, {c.y:7.1f})  "
            f"Δ=({dx:.1f}, {dy:.1f})  {'✓' if ok else '✗ DESVIADO'}"
        )
    print(f"  => {'PASA' if all_centered else 'FALLA'}")
    print()

    # === 2. ANIDADOS ===
    print("─── 2. ¿Cada nivel contiene al anterior? ───")
    all_nested = True
    for i in range(1, len(rects)):
        _, prev = rects[i - 1]
        _, curr = rects[i]
        violations = []
        if curr.x > prev.x + 0.5:
            violations.append(f"borde izq retrocede ({prev.x:.1f} → {curr.x:.1f})")
        if curr.y > prev.y + 0.5:
            violations.append(f"borde sup retrocede ({prev.y:.1f} → {curr.y:.1f})")
        if curr.end.x < prev.end.x - 0.5:
            violations.append(f"borde der retrocede ({prev.end.x:.1f} → {curr.end.x:.1f})")
        if curr.end.y < prev.end.y - 0.5:
            violations.append(f"borde inf retrocede ({prev.end.y:.1f} → {curr.end.y:.1f})")
        if violations:
            all_nested = False
            for v in violations:
                print(f"  nivel {i-1} → {i}: {v}")
        else:
            print(f"  nivel {i-1} → {i}: ✓ contiene")
    print(f"  => {'PASA' if all_nested else 'FALLA'}")
    print()

    # === 3. DENTRO DE LA ISLA ===
    print("─── 3. ¿Los 8 caben en el mapa con margen? ───")
    all_inside = True
    for i, r in rects:
        violations = []
        gap_left = r.x - map_x
        gap_top = r.y - map_y
        gap_right = (map_x + map_w) - r.end.x
        gap_bottom = (map_y + map_h) - r.end.y
        for side, gap, name in [
            (gap_left, margin, "izq"),
            (gap_top, margin, "sup"),
            (gap_right, margin, "der"),
            (gap_bottom, margin, "inf"),
        ]:
            if gap < margin - 0.5:
                violations.append(f"{name} solo {gap:.1f} px (mín {margin:.0f})")
        if violations:
            all_inside = False
            for v in violations:
                print(f"  nivel {i}: ✗ {v}")
        else:
            print(
                f"  nivel {i}: ✓ holgura L={gap_left:5.0f} T={gap_top:5.0f} "
                f"R={gap_right:5.0f} B={gap_bottom:5.0f}"
            )
    print(f"  => {'PASA' if all_inside else 'FALLA'}")
    print()

    # === 4. ÚLTIMO NIVEL TOCA LA ORILLA ===
    print("─── 4. ¿El último nivel toca la orilla (MAP_MARGIN)? ───")
    _, last = rects[-1]
    lvl = levels[-1]
    raw_w = float(lvl["width"])
    raw_h = float(lvl["height"])
    max_w = map_w - 2 * margin
    max_h = map_h - 2 * margin
    recortado_w = raw_w > max_w
    recortado_h = raw_h > max_h

    gap_left = last.x - map_x
    gap_top = last.y - map_y
    gap_right = (map_x + map_w) - last.end.x
    gap_bottom = (map_y + map_h) - last.end.y

    tol = 0.5
    toca_left = abs(gap_left - margin) <= tol
    toca_right = abs(gap_right - margin) <= tol
    toca_top = abs(gap_top - margin) <= tol
    toca_bottom = abs(gap_bottom - margin) <= tol

    print(f"  Nivel 7 declara {raw_w:.0f}×{raw_h:.0f}")
    print(f"  Máximo usable:       {max_w:.0f}×{max_h:.0f}")
    print(f"  Rect efectivo:       {last.w:.0f}×{last.h:.0f}")
    print(f"  Recortado:           W={'sí' if recortado_w else 'no'}, H={'sí' if recortado_h else 'no'}")
    print(f"  Holguras: L={gap_left:.1f} T={gap_top:.1f} R={gap_right:.1f} B={gap_bottom:.1f}")
    print(f"  Toca orilla: L={'✓' if toca_left else '✗'} T={'✓' if toca_top else '✗'} "
          f"R={'✓' if toca_right else '✗'} B={'✓' if toca_bottom else '✗'}")

    if recortado_w or recortado_h:
        print(f"  ⚠ El último nivel ESTÁ RECORTADO por el mapa (toca la orilla).")
    else:
        print(f"  ⚠ El último nivel NO está recortado: se queda corto y no llega al límite.")
    print(f"  => {'PASA' if (toca_left and toca_right and toca_top and toca_bottom) else 'FALLA'}")
    print()

    # === 5. CRECIMIENTO ===
    print("─── 5. Tabla de crecimiento ───")
    print(f"{'Niv':>3} {'Label':<20} {'W×H':>12} {'Área px²':>10} {'% isla':>7} "
          f"{'ΔL':>6} {'ΔT':>6} {'ΔR':>6} {'ΔB':>6}")
    print("-" * 78)
    for i, r in rects:
        pct = r.w * r.h / map_area * 100
        if i == 0:
            dl = dt = dr = db = 0
        else:
            _, prev = rects[i - 1]
            dl = int(prev.x - r.x)
            dt = int(prev.y - r.y)
            dr = int(r.end.x - prev.end.x)
            db = int(r.end.y - prev.end.y)
        print(
            f"{i:>3} {levels[i]['label']:<20} {r.w:>5.0f}×{r.h:<5.0f} "
            f"{r.w * r.h:>10.0f} {pct:>6.1f}% "
            f"{dl:>+5d} {dt:>+5d} {dr:>+5d} {db:>+5d}"
        )
    print()

    # === TABLA FINAL ===
    print("─── Tabla final ───")
    print(f"{'Niv':>3} {'Etiqueta':<20} {'Coste':>7} {'W×H':>12} {'Área px²':>10} {'% isla':>7}")
    print("-" * 64)
    for i, r in rects:
        pct = r.w * r.h / map_area * 100
        print(
            f"{i:>3} {levels[i]['label']:<20} {levels[i]['cost']:>7} "
            f"{r.w:>5.0f}×{r.h:<5.0f} {r.w * r.h:>10.0f} {pct:>6.1f}%"
        )


if __name__ == "__main__":
    main()
