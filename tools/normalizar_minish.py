#!/usr/bin/env python3
"""Mete un sprite de escenario dentro del contrato Minish.

Hermano de `tools/normalizar_sprite.py`, que hace lo mismo para los items de
32×32 contra `paleta_items.json`. Éste va contra los 28 colores de
`art_reference/paleta_minish.png` y acepta cualquier tamaño: los sprites de
entorno van de 8×8 a 384×80.

Existe por un motivo medido: PixelLab respeta la paleta que se le describe pero
**se inventa el color del contorno**. En la tanda de items sacó #191420 en vez de
#21181b, y con 25 colores cuando el techo eran 21.

Determinista e idempotente: pasarlo dos veces da exactamente lo mismo.

    python3 tools/normalizar_minish.py [--seco] [--max N] <fichero.png | dir> ...
"""
import pathlib
import sys

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
PALETA = RAIZ / "art_reference/paleta_minish.png"
CONTORNO = (0x21, 0x18, 0x1B)
## Igual que en el normalizador de items: por debajo de esta luminancia un píxel
## de canto se considera contorno y se unifica. Por encima NO se toca — hay bordes
## claros a propósito (ventana iluminada, metal, cristal).
LUZ_CONTORNO = 60


def cargar_paleta() -> list:
    im = Image.open(PALETA).convert("RGB")
    px = im.load()
    vistos, orden = set(), []
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c not in vistos:
                vistos.add(c)
                orden.append(c)
    return orden


def _luz(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _cerca(c, paleta) -> tuple:
    return min(paleta, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def normalizar(ruta: pathlib.Path, paleta: list, maximo: int, seco: bool) -> dict:
    im = Image.open(ruta).convert("RGBA")
    W, H = im.size
    px = im.load()
    antes = len({px[x, y][:3] for y in range(H) for x in range(W) if px[x, y][3]})

    # 1) alpha binario
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)

    # 2) contorno: cantos oscuros al color de la casa
    cantos = 0
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0:
                continue
            borde = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H) or px[nx, ny][3] == 0:
                    borde = True
                    break
            if borde and _luz(px[x, y]) < LUZ_CONTORNO and px[x, y][:3] != CONTORNO:
                px[x, y] = CONTORNO + (255,)
                cantos += 1

    # 3) todo color fuera de la paleta, al más cercano
    dentro = set(paleta)
    remapeados = 0
    equiv: dict = {}
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0:
                continue
            c = px[x, y][:3]
            if c in dentro:
                continue
            if c not in equiv:
                equiv[c] = _cerca(c, paleta)
            px[x, y] = equiv[c] + (255,)
            remapeados += 1

    # 4) si aún sobran, se funden los menos usados en su vecino de la propia
    #    imagen. Empezar por el que menos píxeles ocupa es lo que menos se nota.
    fundidos = 0
    while maximo > 0:
        cuenta: dict = {}
        for y in range(H):
            for x in range(W):
                if px[x, y][3]:
                    cuenta[px[x, y][:3]] = cuenta.get(px[x, y][:3], 0) + 1
        if len(cuenta) <= maximo:
            break
        raro = min(cuenta, key=lambda c: cuenta[c])
        resto = [c for c in cuenta if c != raro]
        destino = _cerca(raro, resto)
        for y in range(H):
            for x in range(W):
                if px[x, y][3] and px[x, y][:3] == raro:
                    px[x, y] = destino + (255,)
        fundidos += 1

    despues = len({px[x, y][:3] for y in range(H) for x in range(W) if px[x, y][3]})
    if not seco:
        im.save(ruta)
    return {"fichero": ruta.name, "tam": f"{W}×{H}", "antes": antes, "despues": despues,
            "cantos": cantos, "remapeados": remapeados, "fundidos": fundidos}


def main() -> None:
    argv = sys.argv[1:]
    seco = "--seco" in argv
    maximo = 0
    if "--max" in argv:
        maximo = int(argv[argv.index("--max") + 1])
    args = [a for a in argv if not a.startswith("--") and not a.isdigit()]
    if not args:
        raise SystemExit(__doc__)
    rutas: list = []
    for a in args:
        p = pathlib.Path(a)
        rutas.extend(sorted(p.glob("*.png")) if p.is_dir() else [p])
    paleta = cargar_paleta()
    print(f"paleta minish: {len(paleta)} colores")
    for r in rutas:
        i = normalizar(r, paleta, maximo, seco)
        print(f"  {i['fichero']:34} {i['tam']:>8}  colores {i['antes']}→{i['despues']}"
              f"  cantos={i['cantos']} remap={i['remapeados']} fundidos={i['fundidos']}")
    print(f"\n{len(rutas)} {'analizados (en seco)' if seco else 'normalizados'}")


if __name__ == "__main__":
    main()
