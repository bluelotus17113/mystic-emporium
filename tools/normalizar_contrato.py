#!/usr/bin/env python3
"""Mete un sprite dentro del contrato NUEVO: rampas medidas + contorno negro puro.

Tercer normalizador del proyecto, y conviene saber por qué hay tres:

  normalizar_sprite.py    items 32×32 contra paleta_items.json, contorno #21181b
  normalizar_minish.py    escenario contra paleta_minish.png,   contorno #21181b
  éste                    contra art_reference/contrato_rediseno.json, contorno #000000

El contrato nuevo se midió sobre la referencia que dio el usuario y **cambia el
contorno a negro puro**. Los otros dos siguen valiendo para el arte que no se ha
rediseñado todavía; mezclarlos es lo que dejó el proyecto con dos negros distintos
conviviendo (#21181b y #2b1b35) hasta el lote 2.

Existe sobre todo para PixelLab: dibuja bien pero **se inventa el color del contorno**
y saca 30-80 colores donde el contrato pide una decena.

    python3 tools/normalizar_contrato.py [--seco] [--max N] <fichero.png | dir> ...
"""
import json
import pathlib
import sys

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
CONTRATO = RAIZ / "art_reference/contrato_rediseno.json"
NEGRO = (0, 0, 0)
## Igual que en los otros dos: por debajo de esta luminancia un píxel de canto se
## considera contorno. Por encima NO se toca — hay bordes claros a propósito.
LUZ_CONTORNO = 60


def cargar_paleta(solo: list = None) -> list:
    """Colores de las rampas del contrato, más el negro.

    `solo` limita a unas rampas concretas, y hace falta más de lo que parece. Al
    normalizar follaje de PixelLab con la paleta ENTERA, sus verdes claros y
    desaturados caían más cerca de `arena` y `piedra` que de `follaje_verde`, y los
    arbustos salían con manchas beige, como enfermos. Con `--rampas follaje_verde,
    hierba,madera` el mismo sprite queda limpio: si el color correcto no está
    disponible, el vecino más cercano puede ser de otro material.
    """
    d = json.loads(CONTRATO.read_text(encoding="utf-8"))
    cols = {NEGRO}
    for nombre, rampa in d["paleta"].items():
        if not isinstance(rampa, dict):
            continue
        if solo and nombre not in solo:
            continue
        for k, v in rampa.items():
            if k.startswith("_"):
                continue
            vals = v if isinstance(v, list) else [v]
            for h in vals:
                if isinstance(h, str) and h.startswith("#") and len(h) == 7:
                    cols.add((int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)))
    return sorted(cols)


def _luz(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _cerca(c, paleta) -> tuple:
    return min(paleta, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def normalizar(ruta: pathlib.Path, paleta: list, maximo: int, seco: bool) -> dict:
    im = Image.open(ruta).convert("RGBA")
    W, H = im.size
    px = im.load()
    antes = len({px[x, y][:3] for y in range(H) for x in range(W) if px[x, y][3]})

    for y in range(H):  # alpha binario
        for x in range(W):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)

    cantos = 0  # contorno: cantos oscuros a negro puro
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0:
                continue
            borde = any(not (0 <= x + dx < W and 0 <= y + dy < H) or px[x + dx, y + dy][3] == 0
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if borde and _luz(px[x, y]) < LUZ_CONTORNO and px[x, y][:3] != NEGRO:
                px[x, y] = NEGRO + (255,)
                cantos += 1

    dentro = set(paleta)  # todo color fuera de contrato, al más cercano
    remapeados = 0
    equiv: dict = {}
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0 or px[x, y][:3] in dentro:
                continue
            c = px[x, y][:3]
            if c not in equiv:
                equiv[c] = _cerca(c, paleta)
            px[x, y] = equiv[c] + (255,)
            remapeados += 1

    fundidos = 0  # si sobran colores, se funden los menos usados
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
        if not resto:
            break
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
    maximo = int(argv[argv.index("--max") + 1]) if "--max" in argv else 0
    solo = None
    consumidos = set()
    if "--rampas" in argv:
        i = argv.index("--rampas")
        solo = [r.strip() for r in argv[i + 1].split(",") if r.strip()]
        consumidos.add(argv[i + 1])
    if "--max" in argv:
        consumidos.add(argv[argv.index("--max") + 1])
    args = [a for a in argv if not a.startswith("--") and a not in consumidos]
    if not args:
        raise SystemExit(__doc__)
    rutas: list = []
    for a in args:
        p = pathlib.Path(a)
        rutas.extend(sorted(p.glob("*.png")) if p.is_dir() else [p])
    paleta = cargar_paleta(solo)
    print(f"contrato: {len(paleta)} colores (contorno #000000)"
          + (f" — solo rampas: {', '.join(solo)}" if solo else ""))
    for r in rutas:
        i = normalizar(r, paleta, maximo, seco)
        print(f"  {i['fichero']:26} {i['tam']:>8}  colores {i['antes']}→{i['despues']}"
              f"  cantos={i['cantos']} remap={i['remapeados']} fundidos={i['fundidos']}")
    print(f"\n{len(rutas)} {'analizados (en seco)' if seco else 'normalizados'}")


if __name__ == "__main__":
    main()
