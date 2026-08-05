#!/usr/bin/env python3
"""Mete cualquier sprite de item dentro del contrato medido del juego.

Los 45 sprites nuevos vienen de dos sitios: unos dibujados por código y otros de
PixelLab. PixelLab respeta la paleta que se le pasa pero **se inventa el color del
contorno**: en la primera prueba usó #191420 en vez de #21181b y sacó 25 colores
cuando el techo son 21.

Es determinista e idempotente: pasarlo dos veces da exactamente lo mismo.

    python3 tools/normalizar_sprite.py [--seco] <fichero.png | directorio> ...
"""
import json
import pathlib
import sys

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
PALETA = RAIZ / "art_reference/paleta_items.json"
CONTORNO = (0x21, 0x18, 0x1B)
LADO = 32
MAX_COLORES = 21
## Por debajo de esta luminancia, un píxel de canto se considera "contorno" y se
## unifica. Por encima NO se toca: hay sprites cuyo borde es un color claro a
## propósito (metal brillante, cristal), y forzarlos los estropearía.
LUZ_CONTORNO = 60


def _cargar_paleta() -> list:
    datos = json.loads(PALETA.read_text(encoding="utf-8"))
    return [(int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)) for h in datos["colores"]]


def _luz(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _cerca(c, paleta) -> tuple:
    return min(paleta, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def normalizar(ruta: pathlib.Path, paleta: list, seco: bool) -> dict:
    im = Image.open(ruta).convert("RGBA")
    if im.size != (LADO, LADO):
        # A propósito NO se redimensiona: reescalar pixel art lo destruye, y en
        # este proyecto ya pasó una vez (bajar de 64 a 16 rompió los dibujos).
        return {"fichero": ruta.name, "error": f"tamaño {im.size}, se esperaba ({LADO}, {LADO})"}

    px = im.load()
    antes = len({px[x, y][:3] for y in range(LADO) for x in range(LADO) if px[x, y][3]})

    # 1) alpha binario
    for y in range(LADO):
        for x in range(LADO):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)

    # 2) contorno: cantos oscuros al color de la casa
    cantos = 0
    for y in range(LADO):
        for x in range(LADO):
            if px[x, y][3] == 0:
                continue
            borde = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < LADO and 0 <= ny < LADO) or px[nx, ny][3] == 0:
                    borde = True
                    break
            if borde and _luz(px[x, y]) < LUZ_CONTORNO and px[x, y][:3] != CONTORNO:
                px[x, y] = CONTORNO + (255,)
                cantos += 1

    # 3) todo color fuera de la paleta, al más cercano
    dentro = set(paleta)
    remapeados = 0
    equiv: dict = {}
    for y in range(LADO):
        for x in range(LADO):
            if px[x, y][3] == 0:
                continue
            c = px[x, y][:3]
            if c in dentro:
                continue
            if c not in equiv:
                equiv[c] = _cerca(c, paleta)
            px[x, y] = equiv[c] + (255,)
            remapeados += 1

    # 4) si aún sobran colores, se funden los menos usados en su vecino de la
    #    propia imagen: empezar por el que menos píxeles ocupa es lo que menos se nota.
    fundidos = 0
    while True:
        cuenta: dict = {}
        for y in range(LADO):
            for x in range(LADO):
                if px[x, y][3]:
                    cuenta[px[x, y][:3]] = cuenta.get(px[x, y][:3], 0) + 1
        if len(cuenta) <= MAX_COLORES:
            break
        raro = min(cuenta, key=lambda c: cuenta[c])
        resto = [c for c in cuenta if c != raro]
        destino = _cerca(raro, resto)
        for y in range(LADO):
            for x in range(LADO):
                if px[x, y][3] and px[x, y][:3] == raro:
                    px[x, y] = destino + (255,)
        fundidos += 1

    despues = len({px[x, y][:3] for y in range(LADO) for x in range(LADO) if px[x, y][3]})
    if not seco:
        im.save(ruta)
    return {"fichero": ruta.name, "antes": antes, "despues": despues,
            "cantos": cantos, "remapeados": remapeados, "fundidos": fundidos}


def main() -> None:
    args = [a for a in sys.argv[1:] if a != "--seco"]
    seco = "--seco" in sys.argv
    if not args:
        raise SystemExit(__doc__)
    rutas: list = []
    for a in args:
        p = pathlib.Path(a)
        rutas.extend(sorted(p.glob("*.png")) if p.is_dir() else [p])
    paleta = _cargar_paleta()
    tocados = 0
    for r in rutas:
        info = normalizar(r, paleta, seco)
        if "error" in info:
            print(f"  ✗ {info['fichero']}: {info['error']}")
            continue
        cambia = info["cantos"] or info["remapeados"] or info["fundidos"]
        if cambia:
            tocados += 1
            print(f"  {info['fichero']:26} colores {info['antes']}→{info['despues']}"
                  f"  cantos={info['cantos']} remap={info['remapeados']} fundidos={info['fundidos']}")
    print(f"\n{tocados} de {len(rutas)} {'cambiarían' if seco else 'normalizados'}"
          f"{' (en seco)' if seco else ''}")


if __name__ == "__main__":
    main()
