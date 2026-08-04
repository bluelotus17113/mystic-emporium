#!/usr/bin/env python3
"""Alinea el `tier` de los recolectables con el nivel de Patio que los abre.

Cuatro de los nueve recolectables originales declaraban un tier que no cuadraba
con la puerta que hay que pagar para llegar a ellos: `esencia_espiritual` era
tier 1 detrás del nivel 4, que cuesta 3070⚜ acumulados. Eso hacía que una receta
etiquetada "tier 2" exigiese de hecho el patio a tope, y es la raíz de que el
tramo del tier 2 se atascase.

`tier` no es solo etiqueta: `order_manager.gd:129` saca de ahí la recompensa y la
reputación de los pedidos que el juego genera al vuelo. Por eso al mover un item
hay que arrastrar las recetas que lo producen, los pedidos que lo piden, y
recalcular esas recompensas con la fórmula del propio juego.

    python3 tools/coherencia_tiers.py [--seco]
"""
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
D = RAIZ / "godot/data"

# item -> tier nuevo, deducido del min_natural_level de su generador
NUEVO_TIER = {
    "esencia_espiritual": 3,   # Santuario Espiritual, nivel 4
    "agua_arcana": 2,          # Pozo Arcano, nivel 2
    "polvo_lunar": 3,          # Altar Lunar, nivel 3
    "lingote_hierro": 3,       # Veta Fundida, nivel 4
}

# Medianas observadas en los pedidos que ya existían de cada tier.
MIN_REP_POR_TIER = {1: 0, 2: 20, 3: 40, 4: 70, 5: 150}


def leer(f: pathlib.Path) -> str:
    return f.read_text(encoding="utf-8")


def ident(txt: str, defecto: str) -> str:
    m = re.search(r'^id = &"([^"]+)"', txt, re.M)
    return m.group(1) if m else defecto


def campo(txt: str, clave: str, defecto=None):
    m = re.search(rf"^{clave} = (.+)$", txt, re.M)
    return m.group(1).strip() if m else defecto


def poner(txt: str, clave: str, valor) -> str:
    return re.sub(rf"^{clave} = .+$", f"{clave} = {valor}", txt, count=1, flags=re.M)


def apunta_a(txt: str, clave: str) -> str:
    """Nombre del item al que apunta `clave = ExtResource("x")`."""
    m = re.search(rf'{clave} = ExtResource\("([^"]+)"\)', txt)
    if not m:
        return ""
    e = re.search(
        rf'\[ext_resource[^\]]*path="res://data/items/([^"]+)\.tres"[^\]]*id="{re.escape(m.group(1))}"',
        txt,
    )
    return e.group(1) if e else ""


def main() -> None:
    seco = "--seco" in sys.argv
    cambios = []

    # 1) los cuatro recolectables
    valores = {}
    for f in sorted((D / "items").glob("*.tres")):
        t = leer(f)
        sid = ident(t, f.stem)
        valores[sid] = int(campo(t, "base_value", "1"))
        if sid in NUEVO_TIER:
            viejo = int(campo(t, "tier", "1"))
            nuevo = NUEVO_TIER[sid]
            if viejo != nuevo:
                cambios.append(("item", sid, f"tier {viejo}→{nuevo}"))
                if not seco:
                    f.write_text(poner(t, "tier", nuevo), encoding="utf-8")

    # 2) recetas cuya salida es uno de ellos
    for f in sorted((D / "recipes").glob("*.tres")):
        t = leer(f)
        salida = apunta_a(t, "output_item")
        if salida not in NUEVO_TIER:
            continue
        viejo = int(campo(t, "tier", "1"))
        nuevo = NUEVO_TIER[salida]
        if viejo != nuevo:
            cambios.append(("receta", ident(t, f.stem), f"tier {viejo}→{nuevo}"))
            if not seco:
                f.write_text(poner(t, "tier", nuevo), encoding="utf-8")

    # 3) pedidos que piden uno de ellos: tier y, con él, la recompensa
    for f in sorted((D / "orders").glob("*.tres")):
        t = leer(f)
        pide = apunta_a(t, "requested_item")
        if pide not in NUEVO_TIER:
            continue
        viejo = int(campo(t, "tier", "1"))
        nuevo = NUEVO_TIER[pide]
        if viejo == nuevo:
            continue
        qty = int(campo(t, "requested_quantity", "1"))
        # La misma fórmula que order_manager.gd:437, para que los pedidos escritos
        # a mano y los generados al vuelo paguen igual.
        premio = int(valores.get(pide, 1) * qty * (1.0 + nuevo * 0.3))
        rep = max(1, nuevo)
        # `min_reputation` también sube con el tier: si no, un pedido que pasa a
        # tier 3 sigue apareciendo desde el minuto uno con premio de tier 3.
        # Las bandas son las medianas de los pedidos que ya había en cada tier.
        umbral = MIN_REP_POR_TIER.get(nuevo, 0)
        viejo_premio = int(campo(t, "coin_reward", "0"))
        viejo_umbral = int(campo(t, "min_reputation", "0"))
        cambios.append(("pedido", ident(t, f.stem),
                        f"tier {viejo}→{nuevo}, premio {viejo_premio}→{premio}, "
                        f"min_rep {viejo_umbral}→{umbral}"))
        if not seco:
            t = poner(t, "tier", nuevo)
            t = poner(t, "coin_reward", premio)
            t = poner(t, "reputation_reward", rep)
            t = poner(t, "min_reputation", umbral)
            f.write_text(t, encoding="utf-8")

    for tipo, sid, detalle in cambios:
        print(f"  {tipo:8} {sid:34} {detalle}")
    print(f"\n{len(cambios)} cambios{' (en seco)' if seco else ''}")


if __name__ == "__main__":
    main()
