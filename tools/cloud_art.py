#!/usr/bin/env python3
"""Bancos de nubes para la transición entre zonas.

Se dibujan a un tercio del tamaño al que se ven y el juego los amplía ×3, para
que el píxel de la nube tenga el mismo grosor que el del resto del arte. Si se
dibujaran ya a tamaño final, serían la única cosa suave de la pantalla.

Cada fichero es la MITAD IZQUIERDA del telón; la derecha es el mismo sprite
volteado, así que no hay que dibujarla ni guardarla dos veces.

Tres capas para dar profundidad: `near` es la que tapa de verdad, `mid` y `far`
se mueven a otra velocidad y hacen el volumen.

    python3 tools/cloud_art.py
"""
import math
import pathlib
import random
from PIL import Image, ImageChops, ImageDraw

DEST = pathlib.Path(__file__).resolve().parent.parent / "godot/art/sprites/fx"

# Grises de la paleta arcana del juego, de la luz a la sombra.
LUZ = (245, 255, 232, 255)      # #f5ffe8
CUERPO = (230, 239, 247, 255)   # #e6eff7
MEDIO = (223, 224, 232, 255)    # #dfe0e8
SOMBRA = (163, 167, 194, 255)   # #a3a7c2
HONDO = (101, 110, 151, 255)    # #656e97

# (nombre, ancho, alto, radio base, nº de bollos, semilla, tinte)
CAPAS = [
    ("cloud_near", 560, 440, 62, 26, 7, None),
    ("cloud_mid", 520, 400, 46, 30, 21, SOMBRA),
    ("cloud_far", 500, 380, 34, 34, 42, HONDO),
]

## Fracción del ancho que es masa maciza. El resto es el canto dentado que se ve
## en el centro de la pantalla. Tiene que ser generosa: el banco no solo tapa
## hasta el centro, también tiene que llegar al borde de la pantalla.
MACIZO = 0.72
## Columnas del borde exterior que se dejan de color liso, para que la cola de
## color que pone el juego empalme sin costura.
LISO = 24


def lobulos(ancho, alto, radio, cuantos, semilla):
    """Los círculos que forman la nube, ya ordenados de atrás hacia delante.

    No hay rectángulo macizo: la opacidad del lado que se pega al borde sale de
    amontonar lóbulos. Con un rectángulo, el sombreado lo trataba como un solo
    trozo y pintaba franjas horizontales de punta a punta.
    """
    rnd = random.Random(semilla)
    relleno = []
    dibujo = []

    # Relleno: rejilla al tresbolillo por la mitad que se pega al borde. El paso
    # es menor que el radio, así que los círculos siempre se solapan y no queda
    # ningún hueco por el que se vea el juego. Va en plano, sin sombrear: si se
    # sombrea, cada uno tapa la sombra del anterior y el interior sale liso.
    paso = int(radio * 0.62)
    fila = 0
    y = -radio // 2
    while y < alto + radio:
        x = -radio // 2 + (paso // 2 if fila % 2 else 0)
        while x < ancho * MACIZO:
            relleno.append((x, y, int(radio * (0.66 + 0.24 * rnd.random()))))
            x += paso
        y += paso
        fila += 1

    # Lóbulos de adorno repartidos por dentro, bien separados para que cada uno
    # se lea. Son los que dan el aspecto de nube al cuerpo del banco.
    # El temblor es grande a propósito: en rejilla limpia los lóbulos se leían
    # como escamas de pez en vez de como los bultos de una nube.
    sep = radio * 1.2
    y = -radio * 0.3
    fila = 0
    while y < alto + radio * 0.3:
        x = radio * 0.1 + (sep * 0.5 if fila % 2 else 0)
        while x < ancho * (MACIZO - 0.04):
            dibujo.append((
                int(x + rnd.uniform(-0.38, 0.38) * sep),
                int(y + rnd.uniform(-0.34, 0.34) * sep),
                int(radio * (0.42 + 0.62 * rnd.random()))))
            x += sep
        y += sep * 0.74
        fila += 1

    # Canto derecho: lóbulos grandes con dos frecuencias, para que el borde no
    # salga con un patrón reconocible al espejarlo.
    for hilera, (dentro, escala) in enumerate(((0.0, 1.0), (0.10, 0.74))):
        n = int(cuantos * (1.0 + hilera * 0.4))
        for i in range(n):
            t = (i + rnd.random() * 0.5) / max(1, n - 1)
            cy = int(alto * (-0.04 + 1.08 * t))
            onda = (math.sin(t * math.pi * 3.3 + semilla) * 0.62
                    + math.sin(t * math.pi * 7.9 + semilla * 2) * 0.38)
            cx = int(ancho * (MACIZO - dentro) + radio * (0.35 + 0.6 * onda))
            dibujo.append((cx, cy, int(radio * escala * (0.6 + 0.55 * rnd.random()))))

    # De abajo arriba: así los lóbulos de arriba quedan delante y su medialuna de
    # luz no la tapa el de al lado.
    dibujo.sort(key=lambda l: -l[1])
    return relleno, dibujo


def mascara(tam, circulos):
    m = Image.new("L", tam, 0)
    d = ImageDraw.Draw(m)
    for cx, cy, r in circulos:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m.point(lambda v: 255 if v > 127 else 0)


def banda(m, dy):
    """El borde de `m` por arriba (dy>0) o por abajo (dy<0), de `abs(dy)` px.

    Es la máscara menos ella misma desplazada: lo que queda es justo el filo por
    el que entra la luz. Da una banda de grosor constante, que es lo que hace que
    la nube tenga una sola dirección de luz."""
    return ImageChops.subtract(m, ImageChops.offset(m, 0, dy))


def banda_circulo(r, dy):
    """Lo mismo para un círculo suelto. Devuelve (máscara, desplazamiento) para
    pegarla en el sitio.

    Hace falta por lóbulo y no sobre la unión de todos: los lóbulos de dentro se
    solapan tanto que su unión es una masa sin bordes interiores, y el relieve
    desaparecía."""
    pad = abs(dy)
    m = Image.new("L", (2 * r + 2, 2 * r + 2 + pad), 0)
    ImageDraw.Draw(m).ellipse([0, 0, 2 * r, 2 * r], fill=255)
    # El lienzo lleva `pad` de más por abajo, así que el desplazamiento circular
    # de `offset` cae en la zona vacía y no reaparece por el otro lado.
    return banda(m, dy), (-r, -r)


def banco(ancho, alto, radio, cuantos, semilla, tinte):
    def mezcla(c):
        if tinte is None:
            return c
        # Las capas de atrás van tiradas hacia la sombra, no oscurecidas a saco:
        # con un multiply plano perdían el matiz azulado de la paleta.
        return tuple(int(a * 0.55 + b * 0.45) for a, b in zip(c, tinte))

    relleno, dibujo = lobulos(ancho, alto, radio, cuantos, semilla)
    tam = (ancho, alto)
    m_todo = mascara(tam, relleno + dibujo)
    luz = max(3, int(radio * 0.24))
    som = max(3, int(radio * 0.26))

    im = Image.new("RGBA", tam, (0, 0, 0, 0))

    def capa(color, m, en=(0, 0)):
        im.paste(Image.new("RGBA", m.size, mezcla(color)), en, m)

    capa(CUERPO, m_todo)
    # Relieve interior: cada lóbulo pone su medialuna. Van de abajo arriba, así
    # que el de arriba queda delante y su filo de luz no lo tapa el vecino.
    for cx, cy, r in dibujo:
        lz = max(2, int(r * 0.34))
        sm = max(2, int(r * 0.36))
        m, off = banda_circulo(r, -sm)
        capa(SOMBRA, m, (cx + off[0], cy + off[1]))
        m, off = banda_circulo(r, lz)
        capa(LUZ, m, (cx + off[0], cy + off[1]))
    # Y encima la silueta entera, para que el canto exterior mande siempre.
    capa(SOMBRA, banda(m_todo, -som))
    capa(HONDO, banda(m_todo, -2))
    capa(LUZ, banda(m_todo, luz))
    return im


def comprobar_opacidad(im, hasta=0.45):
    """El telón cerrado no puede tener agujeros. Devuelve cuántos píxeles
    transparentes quedan en la franja que debe tapar la pantalla."""
    px = im.load()
    huecos = 0
    for y in range(im.height):
        for x in range(int(im.width * hasta)):
            if px[x, y][3] == 0:
                huecos += 1
    return huecos


def borde_liso(im):
    """Deja las primeras columnas de color plano. Ahí el juego pega una cola de
    ColorRect hasta el borde de la pantalla, porque el banco por sí solo no llega
    a taparlo entero en pantallas anchas; si el borde tuviera relieve, se vería
    la costura entre la textura y la cola."""
    px = im.load()
    for y in range(im.height):
        color = px[LISO, y]
        for x in range(LISO):
            px[x, y] = color
    # Y la fila de referencia, entera del mismo tono: es la que lee el juego para
    # saber de qué color pintar la cola.
    plano = px[LISO, im.height // 2]
    for x in range(LISO):
        for y in range(im.height):
            px[x, y] = plano
    return im


def recortar_alfa(im):
    """Alfa a dos valores: opaco o nada. El antialias de PIL deja un halo gris
    de medio píxel que, ampliado ×3, se ve como una orla sucia."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a > 128 else 0)
    return im


def solido(im):
    """Hasta qué columna es la textura opaca de arriba abajo. Es el dato que usa
    el juego para colocar los bancos."""
    px = im.load()
    for x in range(im.width - 1, -1, -1):
        if all(px[x, y][3] > 128 for y in range(im.height)):
            return x + 1
    return 0


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for nombre, w, h, r, n, s, tinte in CAPAS:
        im = borde_liso(recortar_alfa(banco(w, h, r, n, s, tinte)))
        huecos = comprobar_opacidad(im)
        im.save(DEST / f"{nombre}.png")
        print(f"  {nombre}.png  {w}×{h}  huecos={huecos}  macizo hasta {solido(im)}")
    print(f"3 bancos en {DEST}")


if __name__ == "__main__":
    main()
