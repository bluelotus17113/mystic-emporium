#!/usr/bin/env python3
"""Deriva la tira animada de 6 fotogramas a partir del sprite estático.

Lo que el jugador ve en el taller **no es el estático**: `workstation_cauldron.tscn`
usa `cauldron_anim.png` y `workstation_forge.tscn` usa `forge_anim.png`. El estático
solo es el icono del menú de construcción. Así que rediseñar el estático sin rehacer
la tira deja el juego igual que estaba.

PixelLab no sirve aquí: genera cada imagen por separado y seis fotogramas
independientes no encadenan — saltan. La tira se deriva del estático y el movimiento
se dibuja encima, que es como se hicieron las originales.

Los efectos son deterministas y **cíclicos**: el fotograma 5 encadena con el 0. Si no,
se ve un tirón cada vuelta, igual que pasaba con el agua del lote 1.

    python3 tools/animar_estacion.py <estatico.png> --efecto burbujas --salida <tira.png>
    python3 tools/animar_estacion.py <estatico.png> --efecto ascuas   --salida <tira.png>
"""
import math
import pathlib
import sys

from PIL import Image

N = 6  # fotogramas, fijo: es lo que esperan las escenas

BURBUJA_CLARA = (0xC8, 0x9B, 0xFF)
BURBUJA_MEDIA = (0x9D, 0x6D, 0xFF)
ASCUA_CLARA = (0xF8, 0xA5, 0x8B)
ASCUA_MEDIA = (0xF0, 0x6A, 0x5A)
ASCUA_BRILLO = (0xF0, 0xC0, 0x60)


def _h(x: int, y: int, s: int = 0) -> int:
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100


def _banda_liquida(im: Image.Image) -> tuple:
    """Encuentra la superficie del líquido: la banda ancha del tono más claro del
    interior. Se busca en vez de fijarla a mano para que siga valiendo si el estático
    cambia de proporciones."""
    W, H = im.size
    px = im.load()
    mejor, mejor_y = 0, H // 3
    for y in range(H // 5, H * 3 // 5):
        n = sum(1 for x in range(W) if px[x, y][3] and px[x, y][:3] in
                (BURBUJA_MEDIA, BURBUJA_CLARA, (0x6E, 0x3A, 0xA0)))
        if n > mejor:
            mejor, mejor_y = n, y
    xs = [x for x in range(W) if px[x, mejor_y][3]]
    return (mejor_y, xs[0], xs[-1]) if xs else (mejor_y, W // 4, W * 3 // 4)


def burbujas(base: Image.Image, k: int) -> Image.Image:
    """Burbujas que suben del líquido y salen POR ENCIMA del borde. Ciclo de N.

    Ojo con la trampa del primer intento: dibujarlas dentro del líquido y en su mismo
    tono no se ve. La sensación de hervor la da que **escapen del caldero** y floten
    sobre el borde, que es lo que hacía el sprite original.
    """
    im = base.copy()
    px = im.load()
    W, H = im.size
    y0, x0, x1 = _banda_liquida(base)
    ancho = max(1, x1 - x0 - 4)
    for i in range(6):
        fase = (k + i) % N          # cada una en su fase: no suben a la vez
        bx = x0 + 2 + (_h(i, 0, 71) % ancho)
        by = y0 - 1 - fase * 2      # sube dos píxeles por fotograma
        if by < 1:
            continue
        # las de arriba se apagan: dan la sensación de estallar
        c = BURBUJA_CLARA if fase < 3 else BURBUJA_MEDIA
        for dx, dy in ((0, 0), (1, 0), (0, -1), (1, -1)):
            x, y = bx + dx, by + dy
            if 0 <= x < W and 0 <= y < H:
                # a diferencia del primer intento, se pinta también FUERA de la
                # silueta: la burbuja tiene que despegarse del caldero
                px[x, y] = c + (255,)
    return im


def ascuas(base: Image.Image, k: int) -> Image.Image:
    """Llama que late en la boca del horno, más chispas que suben. Ciclo de N."""
    im = base.copy()
    px = im.load()
    W, H = im.size
    # la boca es donde hay tonos de fuego
    fuego = [(x, y) for y in range(H) for x in range(W)
             if px[x, y][3] and px[x, y][:3] in (ASCUA_MEDIA, ASCUA_CLARA, ASCUA_BRILLO)]
    if not fuego:
        return im
    fx = sum(p[0] for p in fuego) / len(fuego)
    fy = sum(p[1] for p in fuego) / len(fuego)
    # Latido del corazón de la llama. Ojo con el seno "obvio": con
    # sin(2πk/6) los seis valores salen repetidos por parejas (k=1 y k=2 dan lo
    # mismo, k=4 y k=5 también), y entonces dos de las seis transiciones son casi
    # cero y el bucle se ve a tirones. Medio paso de desfase los separa: los seis
    # quedan distintos y el ciclo cierra parejo.
    pulso = 0.5 + 0.5 * math.sin(2.0 * math.pi * (k + 0.5) / N)
    for x, y in fuego:
        d = math.hypot(x - fx, y - fy)
        if d < 2.5 + pulso * 2.0:
            px[x, y] = ASCUA_BRILLO + (255,)
        elif d < 4.5 + pulso * 2.0:
            px[x, y] = ASCUA_CLARA + (255,)
    for i in range(3):  # chispas subiendo por encima de la boca
        fase = (k + i * 2) % N
        sx = int(fx) - 2 + (_h(i, 1, 83) % 5)
        sy = int(fy) - 2 - fase * 2
        if 0 <= sx < W and 2 <= sy < H and fase < 4:
            px[sx, sy] = (ASCUA_CLARA if fase < 2 else ASCUA_MEDIA) + (255,)
    return im


EFECTOS = {"burbujas": burbujas, "ascuas": ascuas}


def main() -> None:
    argv = sys.argv[1:]
    args = [a for a in argv if not a.startswith("--")]
    if not args or "--efecto" not in argv:
        raise SystemExit(__doc__)
    base = Image.open(pathlib.Path(args[0])).convert("RGBA")
    efecto = EFECTOS[argv[argv.index("--efecto") + 1]]
    salida = pathlib.Path(argv[argv.index("--salida") + 1])
    W, H = base.size
    tira = Image.new("RGBA", (W * N, H), (0, 0, 0, 0))
    for k in range(N):
        tira.alpha_composite(efecto(base, k), (k * W, 0))
    salida.parent.mkdir(parents=True, exist_ok=True)
    tira.save(salida)
    # el cierre del ciclo importa: si 5→0 salta, se ve un tirón cada vuelta
    import numpy as np
    fr = [np.asarray(tira.crop((k * W, 0, (k + 1) * W, H)), dtype=int) for k in range(N)]
    difs = [float(np.abs(fr[i] - fr[(i + 1) % N]).mean()) for i in range(N)]
    print(f"{salida.name}  {tira.size[0]}×{tira.size[1]}  {N} fotogramas")
    print("  transiciones: " + "  ".join(f"{i}→{(i+1)%N}={d:.2f}" for i, d in enumerate(difs)))
    peor = max(difs) / max(0.001, min(difs))
    print(f"  cierre {'OK' if peor < 3.0 else 'DESCUADRADO'} (peor/mejor = {peor:.1f})")


if __name__ == "__main__":
    main()
