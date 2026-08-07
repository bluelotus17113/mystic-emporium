#!/usr/bin/env python3
"""Los cinco iconos de la barra de acciones, dibujados nativos a 48×48.

Antes eran los iconos de 24×24 del juego ampliados ×2: no había detalle que
enseñar, solo píxeles el doble de grandes. Aquí se dibujan directamente a 48, que
es el tamaño al que se ven, así que caben tablas, herrajes, sombras y brillos.

Todo el color sale de `art_reference/paleta_minish_arcana.png`, la paleta del
juego, y al final se cuantiza contra ella: si un tono se me escapa, vuelve al
más cercano de la paleta en vez de meter un color de fuera.

    python3 tools/ui_action_icons.py
"""
import pathlib
from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
UI = RAIZ / "godot/art/sprites/ui"
GRANDE = UI / "big"
PALETA_REF = RAIZ / "art_reference/paleta_minish_arcana.png"

LADO = 48

# Paleta arcana Minish, por familias. Las claves cortas son para que las tablas
# de píxeles de abajo se lean como un dibujo.
C = {
    "K": "#21181b",  # contorno
    "k": "#1f1d25",  # contorno frío
    "d": "#52333f",  # sombra cálida
    "n": "#2f354f",  # sombra fría
    "w": "#753027",  # madera oscura
    "W": "#ab5130",  # madera media
    "o": "#d27d2c",  # madera clara
    "O": "#ee9e57",  # madera brillante
    "h": "#ffd196",  # madera al sol
    "g": "#855a14",  # oro oscuro
    "G": "#f0c060",  # oro medio
    "Y": "#f8e0a0",  # oro claro
    "b": "#404973",  # piedra oscura
    "c": "#656e97",  # piedra media
    "C": "#a3a7c2",  # piedra clara
    "P": "#dfe0e8",  # papel sombra
    "p": "#f5ffe8",  # papel
    "B": "#4fa4b8",  # azul
    "t": "#6dc2ca",  # turquesa
    "v": "#3a2058",  # violeta oscuro
    "V": "#6e3aa0",  # violeta
    "u": "#9d6dff",  # violeta claro
    "U": "#c89bff",  # violeta pálido
    "e": "#3b7d4f",  # verde oscuro
    "E": "#63ab3e",  # verde
    "m": "#92e8c0",  # menta
    "r": "#a02b63",  # granate
    "R": "#df5235",  # rojo
    "q": "#ff8933",  # naranja
    "s": "#f8a692",  # salmón
}


def rgb(clave):
    h = C[clave].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Lienzo:
    """Rejilla de píxeles con las primitivas justas. Coordenadas inclusivas."""

    def __init__(self, lado=LADO):
        self.lado = lado
        self.im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
        self.px = self.im.load()

    def p(self, x, y, c):
        if 0 <= x < self.lado and 0 <= y < self.lado:
            self.px[x, y] = rgb(c) if isinstance(c, str) else c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.p(x, y, c)

    def hl(self, y, x0, x1, c):
        self.rect(x0, y, x1, y, c)

    def vl(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def disco(self, cx, cy, r, c):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r * 0.4:
                    self.p(x, y, c)

    def anillo(self, cx, cy, r, c):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if r * r - r <= d <= r * r + r * 0.4:
                    self.p(x, y, c)

    def filas(self, x, y, mapa):
        """Pinta una tabla de texto. El punto es transparente."""
        for dy, fila in enumerate(mapa.strip("\n").split("\n")):
            for dx, ch in enumerate(fila):
                if ch != ".":
                    self.p(x + dx, y + dy, ch)

    def contorno(self, c="K"):
        """Contorno de 1 px alrededor de todo lo opaco, incluidas las diagonales
        exteriores: sin ellas las esquinas quedan dentadas."""
        vecinos = ((1, 0), (-1, 0), (0, 1), (0, -1))
        fuera = []
        for y in range(self.lado):
            for x in range(self.lado):
                if self.px[x, y][3]:
                    continue
                for dx, dy in vecinos:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.lado and 0 <= ny < self.lado and self.px[nx, ny][3]:
                        fuera.append((x, y))
                        break
        for x, y in fuera:
            self.p(x, y, c)


def cuantizar(im, paleta):
    """Devuelve la imagen con cada color llevado al más cercano de la paleta."""
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            if c not in cache:
                cache[c] = min(paleta, key=lambda q:
                               (q[0] - c[0]) ** 2 + (q[1] - c[1]) ** 2 + (q[2] - c[2]) ** 2)
            px[x, y] = cache[c] + (255,)
    return im


# ------------------------------------------------------------------ dibujos
def inventory():
    """Cofre abierto: la tapa echada atrás y el tesoro brillando dentro."""
    L = Lienzo()
    # Tapa, en perspectiva: se ve por dentro, así que el frente es madera oscura.
    L.rect(9, 7, 38, 9, "w")
    L.rect(8, 10, 39, 18, "W")
    L.hl(10, 9, 38, "o")            # canto iluminado
    L.rect(11, 12, 36, 17, "d")     # hueco interior de la tapa
    L.hl(12, 12, 35, "w")
    L.vl(23, 7, 18, "g")            # herraje central de la tapa
    L.vl(24, 7, 18, "G")
    L.vl(25, 7, 18, "g")

    # Interior en penumbra: el tesoro tiene que recortarse contra algo oscuro.
    L.rect(11, 18, 36, 22, "d")
    L.rect(12, 19, 35, 22, "n")

    # Tesoro asomando: monedas de canto con reflejo, y dos gemas.
    for cx in (15, 21, 29, 34):
        L.disco(cx, 21, 2, "g")
        L.disco(cx, 21, 1, "G")
        L.p(cx - 1, 20, "Y")
    L.rect(17, 19, 19, 21, "V")     # gema violeta
    L.rect(18, 19, 18, 20, "U")
    L.rect(25, 19, 27, 21, "B")     # gema azul
    L.rect(26, 19, 26, 20, "m")
    L.hl(18, 13, 34, "Y")           # el brillo que escapa por la ranura

    # Cuerpo del cofre.
    L.rect(9, 22, 38, 40, "W")
    L.hl(22, 10, 37, "o")           # borde superior al sol
    L.rect(10, 24, 37, 25, "o")
    L.rect(10, 30, 37, 31, "w")     # veta entre tablas
    L.rect(10, 36, 37, 39, "d")     # sombra de abajo
    for x in (14, 22, 30):          # tablas verticales
        L.vl(x, 23, 39, "w")
        L.vl(x + 1, 23, 39, "o")

    # Herrajes.
    L.rect(9, 26, 38, 27, "g")
    L.rect(9, 26, 38, 26, "G")
    L.vl(23, 22, 40, "g")
    L.vl(24, 22, 40, "G")
    L.vl(25, 22, 40, "g")

    # Cerradura.
    L.rect(20, 28, 28, 35, "g")
    L.rect(21, 29, 27, 34, "G")
    L.rect(22, 30, 26, 33, "Y")
    L.disco(24, 32, 1, "d")
    L.vl(24, 32, 34, "d")

    # Patas.
    L.rect(9, 40, 13, 42, "d")
    L.rect(34, 40, 38, 42, "d")
    L.contorno()
    return L.im


def commerce():
    """Puesto de mercado: toldo a rayas, mostrador y género. Antes era un saco de
    monedas, que decía «dinero» pero no «monta y mejora tu tienda»."""
    L = Lienzo()
    # Toldo. Seis rayas de 6 px cubren justo de 5 a 40; con un `range` abierto la
    # última se salía del lienzo y dejaba un pegote rojo suelto a la derecha.
    RAYAS = [(5 + i * 6, 5 + i * 6 + 5, "R" if i % 2 == 0 else "p") for i in range(6)]
    for x0, x1, c in RAYAS:
        L.rect(x0, 9, x1, 20, c)
    L.rect(5, 6, 40, 8, "w")        # barra de madera del toldo
    L.hl(6, 6, 39, "O")
    # Festón: cada raya termina en pico.
    for x0, x1, c in RAYAS:
        L.rect(x0, 21, x1, 21, c)
        L.rect(x0 + 1, 22, x1 - 1, 22, c)
        L.rect(x0 + 2, 23, x1 - 2, 23, c)
    L.hl(20, 5, 40, "d")            # sombra bajo el toldo

    # Postes.
    L.rect(6, 24, 9, 41, "w")
    L.vl(7, 24, 41, "W")
    L.rect(36, 24, 39, 41, "w")
    L.vl(37, 24, 41, "W")

    # Mostrador.
    L.rect(4, 32, 41, 35, "W")
    L.hl(32, 5, 40, "O")
    L.hl(35, 5, 40, "w")
    L.rect(9, 36, 36, 41, "d")      # el hueco oscuro de debajo
    L.rect(11, 37, 34, 40, "n")

    # Género encima del mostrador: una poción y dos monedas de canto.
    L.rect(13, 26, 17, 31, "V")
    L.rect(14, 27, 16, 30, "u")
    L.p(14, 28, "U")
    L.rect(14, 23, 16, 25, "C")
    L.rect(15, 22, 15, 23, "P")
    # Las monedas se dibujan píxel a píxel: con `disco` de radio 2-3 salían dos
    # manchas doradas pegadas en vez de dos monedas.
    L.filas(22, 25, """
.ggg.
gYYGg
gYGGg
gGGgg
.ggg.
""")
    L.filas(29, 28, """
.gg.
gYGg
gGGg
.gg.
""")
    L.contorno()
    return L.im


def orders():
    """Pergamino desenrollado con lacre. El de antes era un rollo plano sin
    escritura: a 48 px cabe el texto y el sello."""
    L = Lienzo()
    # Cuerpo del pergamino.
    L.rect(10, 8, 37, 41, "P")
    L.rect(11, 9, 36, 40, "p")
    L.vl(35, 10, 39, "P")           # sombra del canto derecho

    # Renglones.
    for y in (16, 20, 24, 28):
        L.rect(15, y, 32, y, "c")
        L.rect(15, y, 26, y, "b")
    L.rect(15, 32, 24, 32, "c")

    # Rodillos arriba y abajo, con su madera.
    for y0 in (5, 39):
        L.rect(7, y0, 40, y0 + 3, "W")
        L.hl(y0, 8, 39, "O")
        L.hl(y0 + 3, 8, 39, "w")
        L.rect(5, y0, 7, y0 + 3, "w")
        L.rect(40, y0, 42, y0 + 3, "w")

    # Lacre.
    L.disco(31, 35, 5, "r")
    L.disco(31, 35, 4, "R")
    L.disco(30, 34, 2, "s")
    L.p(29, 33, "p")
    L.contorno()
    return L.im


def archive():
    """Pila de tres tomos con cinta. Antes era una hoja suelta con una pluma, que
    es «notas»: este botón abre recetario, progreso, álbum y armario."""
    L = Lienzo()

    def tomo(y, lomo, tapa, brillo, dx=0):
        L.rect(6 + dx, y, 41 + dx, y + 8, tapa)
        L.hl(y, 7 + dx, 40 + dx, brillo)      # canto superior
        L.rect(6 + dx, y, 10 + dx, y + 8, lomo)   # lomo
        L.vl(8 + dx, y + 1, y + 7, brillo)
        L.rect(11 + dx, y + 1, 41 + dx, y + 7, "P")   # hojas
        L.rect(11 + dx, y + 2, 41 + dx, y + 2, "p")
        L.rect(11 + dx, y + 5, 41 + dx, y + 5, "p")
        L.hl(y + 8, 7 + dx, 40 + dx, lomo)

    tomo(31, "e", "E", "m", dx=0)      # el de abajo, verde
    tomo(21, "b", "B", "t", dx=2)      # el de en medio, azul
    tomo(11, "v", "V", "u", dx=-1)     # el de arriba, violeta

    # Chapa dorada en la tapa del de arriba.
    L.rect(20, 13, 30, 17, "g")
    L.rect(21, 14, 29, 16, "G")
    L.rect(23, 15, 27, 15, "Y")

    # Cinta marcapáginas del tomo de en medio, colgando por la derecha.
    L.rect(36, 22, 38, 34, "R")
    L.vl(37, 22, 34, "s")
    L.rect(36, 35, 38, 36, "r")
    L.p(36, 35, "R")
    L.p(38, 35, "R")
    L.contorno()
    return L.im


def siege():
    """Torreón con estandarte y sillería. El anterior era un bloque gris con dos
    ventanas: aquí hay piedra por hiladas, almenas con sombra y bandera al vuelo."""
    L = Lienzo()
    # Asta y estandarte al vuelo, con la cola ondeando y el pliegue en sombra.
    L.vl(23, 1, 13, "w")
    L.vl(24, 1, 13, "W")
    L.p(23, 0, "G")
    L.p(24, 0, "G")
    L.filas(25, 2, """
RRRRRRRRR.
RRRRRRRRRR
RRRRRRRRRR
rrRRRRRRRR
..rrRRRRRR
....rrRRRR
""")

    # Almenas.
    for x in (7, 15, 23, 31):
        L.rect(x, 12, x + 6, 18, "C")
        L.rect(x, 12, x + 6, 13, "P")
        L.vl(x + 6, 12, 18, "c")

    # Cuerpo del torreón.
    L.rect(6, 18, 41, 44, "C")
    L.rect(6, 18, 41, 19, "P")      # cornisa iluminada
    L.rect(6, 20, 41, 21, "c")      # sombra bajo la cornisa
    L.vl(40, 20, 44, "c")
    L.vl(41, 20, 44, "b")
    L.vl(6, 20, 44, "P")            # el lado que da la luz

    # Sillería: hiladas trabadas, una fila sí y otra no.
    for i, y in enumerate(range(24, 45, 5)):
        L.hl(y, 7, 40, "c")
        inicio = 9 if i % 2 == 0 else 15
        for x in range(inicio, 40, 11):
            L.vl(x, y + 1, y + 4, "c")

    # Ventanas con luz dentro.
    for cx in (13, 34):
        L.rect(cx - 2, 25, cx + 2, 32, "n")
        L.rect(cx - 1, 26, cx + 1, 31, "q")
        L.rect(cx - 1, 26, cx + 1, 27, "G")

    # Portón, con arco y remaches.
    L.rect(19, 32, 29, 44, "n")
    L.rect(20, 33, 28, 44, "w")
    L.rect(21, 35, 27, 44, "W")
    L.rect(21, 30, 27, 33, "w")     # arco
    L.rect(22, 29, 26, 31, "w")
    L.vl(24, 31, 44, "d")
    for y in (36, 40):
        L.p(22, y, "g")
        L.p(26, y, "g")
    L.contorno()
    return L.im


ICONOS = {
    "inventory": inventory,
    "commerce": commerce,
    "orders": orders,
    "archive": archive,
    "siege": siege,
}


def main():
    ref = Image.open(PALETA_REF).convert("RGB")
    paleta = sorted({ref.getpixel((x, y)) for y in range(ref.height) for x in range(ref.width)})
    GRANDE.mkdir(parents=True, exist_ok=True)
    for nombre, fn in ICONOS.items():
        cuantizar(fn(), paleta).save(GRANDE / f"{nombre}.png")
    print(f"{len(ICONOS)} iconos de 48×48 en {GRANDE} ({len(paleta)} colores de paleta)")


if __name__ == "__main__":
    main()
