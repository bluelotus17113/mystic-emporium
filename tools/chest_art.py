#!/usr/bin/env python3
"""Cofre de Almacenamiento, versión minimalista.

El anterior era una mancha malva sin silueta clara: no se distinguía de un
arbusto a la distancia a la que se juega, y no pegaba con los otros dos cofres
del juego, que sí están dibujados de frente y con las patas marcadas.

Este se dibuja con lo mínimo para que un cofre se lea como cofre: tapa, cuerpo,
fleje central, cerradura y patas. Sin tablas, sin remaches, sin herrajes en las
esquinas. Cuatro tonos de madera y dos de oro.

Se queda en 32×32 exactos: `storage_chest.tscn` lo pinta centrado y a escala ×2,
y cualquier otro tamaño movería el cofre respecto a su casilla y a su colisión.

    python3 tools/chest_art.py
"""
import pathlib
from PIL import Image, ImageDraw

DEST = pathlib.Path(__file__).resolve().parent.parent / "godot/art/sprites/environment/chest.png"
LADO = 32

# Contorno del arte del MUNDO (#2b1b35), que no es el de los iconos de interfaz.
CONTORNO = (43, 27, 53, 255)
C = {
    "w": (117, 48, 39, 255),    # madera en sombra   #753027
    "W": (171, 81, 48, 255),    # madera             #ab5130
    "o": (210, 125, 44, 255),   # madera al sol      #d27d2c
    "h": (238, 158, 87, 255),   # filo iluminado     #ee9e57
    "g": (133, 90, 20, 255),    # oro en sombra      #855a14
    "G": (240, 192, 96, 255),   # oro                #f0c060
    "Y": (248, 224, 160, 255),  # brillo del oro     #f8e0a0
    "k": (58, 32, 88, 255),     # hueco oscuro       #3a2058
}


class Lienzo:
    def __init__(self):
        self.im = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle([x0, y0, x1, y1], fill=C[c])

    def fila(self, y, x0, x1, c):
        self.rect(x0, y, x1, y, c)

    def contorno(self):
        """Contorno de 1 px alrededor de todo lo opaco."""
        px = self.im.load()
        fuera = []
        for y in range(LADO):
            for x in range(LADO):
                if px[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < LADO and 0 <= ny < LADO and px[nx, ny][3]:
                        fuera.append((x, y))
                        break
        for p in fuera:
            px[p] = CONTORNO


def cofre() -> Image.Image:
    L = Lienzo()

    # --- Patas. Van primero para que el cuerpo las tape por arriba.
    for x0 in (8, 20):
        L.rect(x0, 22, x0 + 3, 25, "w")
        L.rect(x0, 22, x0, 25, "W")

    # --- Tapa. Va un píxel más ancha que el cuerpo por cada lado: ese vuelo es
    # lo que hace que se lea como tapa y no como la mitad de arriba de una caja.
    # Toda la tapa en tonos claros y todo el cuerpo en oscuros; alternando bandas
    # de luz en los dos, el conjunto parecía un barril a rayas.
    L.fila(8, 9, 22, "h")
    L.fila(9, 7, 24, "h")
    L.rect(6, 10, 25, 12, "o")
    L.fila(13, 6, 25, "W")
    L.fila(14, 6, 25, "w")          # canto de la tapa, en sombra

    # --- Cuerpo, más oscuro y más estrecho.
    L.rect(7, 15, 24, 20, "W")
    L.rect(7, 21, 24, 23, "w")
    L.fila(24, 8, 23, "w")          # esquinas de abajo recortadas

    # --- Fleje central de oro, de la tapa al suelo.
    L.rect(14, 8, 17, 24, "G")
    L.rect(17, 8, 17, 24, "g")      # canto derecho en sombra
    L.rect(14, 8, 14, 24, "Y")      # canto izquierdo al sol

    # --- Cerradura: la chapa se pasa un poco del fleje para que se lea a tamaño
    # real; el bocallave es un solo hueco oscuro. Va justo bajo el canto de la
    # tapa, que es donde cierra un cofre de verdad.
    L.rect(12, 15, 19, 20, "g")
    L.rect(13, 16, 18, 19, "G")
    L.rect(15, 17, 16, 18, "k")

    L.contorno()
    return L.im


def main():
    im = cofre()
    assert im.size == (32, 32), im.size
    im.save(DEST)
    colores = len({p for p in im.getdata() if p[3]})
    print(f"{DEST.name}  {im.size[0]}×{im.size[1]}  {colores} colores")


if __name__ == "__main__":
    main()
