#!/usr/bin/env python3
"""Deriva arbustos y sauce de las copas buenas, en vez de generarlos aparte.

PixelLab clava el roble, el pino, el cerezo, el abedul y el árbol seco: dibuja hojas
individuales, que es justo lo que al código le costaba. Pero con arbustos falla de
forma insistente —el arbustón salió tres veces con manchas beige, como enfermo— y el
sauce sale con un estallido claro en la copa y una base de suelo horneada.

En vez de seguir tirando generaciones, estos cuatro se derivan del roble, que ya está
bien:

    bush            copa del roble recortada, escalada y mordida
    tree_bush_big   igual pero grande y más ancho que alto
    flower_bush     el `bush` con florecillas encima
    tree_willow     copa del roble + mechones colgantes dibujados aquí

Sale mejor de lo que parece: al venir todos de la misma copa, el bosque entero comparte
grano y paleta, cosa que cuatro generaciones independientes no garantizan.

    python3 tools/derivar_follaje.py <dir_origen> [--salida <dir>]
"""
import math
import pathlib
import sys

from PIL import Image

VERDE_CLARO = (0x5D, 0xCF, 0x81)
VERDE_MEDIO = (0x3E, 0xA0, 0x6C)
VERDE_OSC = (0x21, 0x36, 0x2C)
MADERA_M = (0x95, 0x64, 0x47)
MADERA_D = (0x5D, 0x42, 0x3A)
ROSA_L = (0xF5, 0xB3, 0xC5)
ROSA_M = (0xD1, 0x69, 0x84)
BLANCO = (0xFF, 0xFF, 0xFF)
NEGRO = (0, 0, 0)


def _h(x: int, y: int, s: int = 0) -> int:
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100


def _copa(roble: Image.Image) -> Image.Image:
    """Recorta solo la copa del roble: la mitad de arriba, sin tronco ni raíces."""
    W, H = roble.size
    px = roble.load()
    # el tronco es la madera de abajo; la copa acaba donde deja de haber verde ancho
    ultimo = 0
    for y in range(H):
        ancho = sum(1 for x in range(W) if px[x, y][3] and px[x, y][:3] not in
                    (MADERA_M, MADERA_D, NEGRO))
        if ancho > W * 0.30:
            ultimo = y
    return roble.crop(roble.crop((0, 0, W, ultimo + 1)).getbbox() or (0, 0, W, ultimo + 1))


def _contornear(im: Image.Image) -> Image.Image:
    """Contorno negro de 1 px por debajo. Tras recortar y escalar hace falta rehacerlo:
    el original queda cortado por los cantos nuevos."""
    W, H = im.size
    px = im.load()
    nuevos = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3]:
                continue
            if any(0 <= x + dx < W and 0 <= y + dy < H and px[x + dx, y + dy][3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                nuevos.append((x, y))
    for x, y in nuevos:
        px[x, y] = NEGRO + (255,)
    return im


def _encajar(src: Image.Image, w: int, h: int, semilla: int) -> Image.Image:
    """Escala la copa a w×h dejando 1 px de aire para el contorno, y le da mordiscos
    desiguales al canto para que no se note que es la misma copa reescalada."""
    s = src.resize((w - 2, h - 2), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(s, (1, 1))
    px = out.load()
    for y in range(h):
        xs = [x for x in range(w) if px[x, y][3]]
        if not xs:
            continue
        # semillas distintas por lado: con la misma, el mordisco sale simétrico
        for n, x0, paso in ((_h(y, 0, semilla) % 3, xs[0], 1),
                            (_h(y, 1, semilla + 977) % 3, xs[-1], -1)):
            for k in range(n):
                xx = x0 + k * paso
                if 0 <= xx < w:
                    px[xx, y] = (0, 0, 0, 0)
    return _contornear(out)


def _sin_madera(im: Image.Image) -> Image.Image:
    """Borra los píxeles de tronco. Los arbustos no tienen tronco, y el recorte de la
    copa arrastra un resto de las raíces del roble por abajo."""
    px = im.load()
    W, H = im.size
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and px[x, y][:3] in (MADERA_M, MADERA_D):
                px[x, y] = (0, 0, 0, 0)
    # el contorno que rodeaba al tronco queda flotando: fuera también
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and px[x, y][:3] == NEGRO:
                vecinos = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                              if 0 <= x + dx < W and 0 <= y + dy < H
                              and px[x + dx, y + dy][3] and px[x + dx, y + dy][:3] != NEGRO)
                if vecinos == 0:
                    px[x, y] = (0, 0, 0, 0)
    return im


def bush(copa, tam=32):
    return _sin_madera(_encajar(copa, tam, tam, 101))


def bush_big(copa, w=64, h=52):
    return _sin_madera(_encajar(copa, w, h, 202))


def flower_bush(copa, tam=32):
    im = bush(copa, tam)
    px = im.load()
    puestas = 0
    for y in range(2, tam - 2):
        for x in range(2, tam - 2):
            if px[x, y][3] == 0 or px[x, y][:3] == NEGRO:
                continue
            if _h(x, y, 303) < 7 and puestas < 22:
                c = ROSA_L if _h(x, y, 304) < 55 else BLANCO
                px[x, y] = c + (255,)
                if px[x + 1, y][3] and px[x + 1, y][:3] != NEGRO:
                    px[x + 1, y] = ROSA_M + (255,)
                puestas += 1
    return im


def willow(copa, w=64, h=64):
    """Copa ancha y baja, con mechones colgando por debajo del canto."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cop = _encajar(copa, w, 34, 404)
    im.paste(cop, (0, 4), cop)
    px = im.load()
    # mechones: tiras verticales que salen del canto inferior de la copa
    for x in range(3, w - 3):
        col = [y for y in range(h) if px[x, y][3] and px[x, y][:3] != NEGRO]
        if not col:
            continue
        base = max(col)
        if _h(x, 0, 505) > 55:
            continue
        largo = 6 + _h(x, 1, 506) % 14
        for k in range(largo):
            y = base + k
            if y >= h - 2:
                break
            px[x, y] = (VERDE_MEDIO if k < largo - 3 else VERDE_OSC) + (255,)
    # tronco corto asomando en el centro
    cx = w // 2
    for y in range(h - 16, h - 4):
        for x in (cx - 2, cx - 1, cx, cx + 1):
            if px[x, y][3] == 0:
                px[x, y] = (MADERA_M if x < cx else MADERA_D) + (255,)
    return _contornear(im)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    origen = pathlib.Path(args[0])
    salida = pathlib.Path(sys.argv[sys.argv.index("--salida") + 1]) if "--salida" in sys.argv else origen
    salida.mkdir(parents=True, exist_ok=True)
    roble = Image.open(origen / "tree_oak.png").convert("RGBA")
    copa = _copa(roble)
    print(f"copa extraída del roble: {copa.size}")
    for nombre, im in (("bush", bush(copa)), ("tree_bush_big", bush_big(copa)),
                       ("flower_bush", flower_bush(copa)), ("tree_willow", willow(copa))):
        im.save(salida / f"{nombre}.png")
        cols = len({p[:3] for p in im.get_flattened_data() if p[3]})
        print(f"  {nombre:16} {im.size[0]}×{im.size[1]}  {cols} colores")


if __name__ == "__main__":
    main()
