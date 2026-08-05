#!/usr/bin/env python3
"""Los 22 items de endgame de forma simple: primarios y procesados.

Se dibujan por código y no con PixelLab por dos motivos. Uno, son arquetipos
repetitivos —lingotes, polvos, cristales, frascos— donde la aritmética acierta
siempre y el generativo se va por las ramas: pidiéndole un lingote devolvió una
gema. Y dos, salen gratis, que con 357 generaciones de suscripción restantes no
es poca cosa.

Los 23 items "Final" (armas, armaduras, amuletos) sí van por PixelLab: ahí su
detalle luce y una forma dibujada por fórmula se quedaría sosa.

Contrato, medido sobre los 86 sprites que ya existen (NO el de `Guia_Estilo`,
que describe un estilo anterior): 32×32 exactos, contorno #21181b, alpha binario,
paleta de 53 colores, entre 6 y 21 colores por sprite.

    python3 tools/items_endgame.py [--solo <id>]
"""
import pathlib
import sys

from PIL import Image, ImageDraw

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DEST = RAIZ / "godot/art/sprites/items"
LADO = 32
CONTORNO = (0x21, 0x18, 0x1B, 255)


def c(h: str) -> tuple:
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# Cada item: (arquetipo, sombra, base, luz, brillo). Todos los colores salen de
# art_reference/paleta_items.json.
ITEMS = {
    "aleacion_estelar":    ("lingote", "855a14", "c49260", "f0c060", "f8e0a0"),
    "amalgama_arcana":     ("amalgama", "3a2058", "6e3aa0", "9d6dff", "c89bff"),
    "balsamo_lunar":       ("frasco",  "404973", "656e97", "a3a7c2", "f0e8ff"),
    "ceniza_estelar":      ("polvo",   "6a4e28", "b09050", "f0c060", "f8e0a0"),
    "corazon_magmatico":   ("nucleo",  "753027", "d04648", "ff8933", "ffd196"),
    "cristal_abisal":      ("gema",    "2f5753", "4fa4b8", "92e8c0", "f5ffe8"),
    "escarcha_eterna":     ("escarcha", "404973", "656e97", "a3a7c2", "f4f0e8"),
    "esencia_wyvern":      ("vial",    "3b7d4f", "63ab3e", "c8d45d", "f5ffe8"),
    "extracto_umbrio":     ("frasco",  "2b1b35", "3a2058", "6b2058", "a02b63"),
    "fibra_dragon":        ("madeja",  "753027", "9c3038", "d04648", "f8a692"),
    "filamento_estelar":   ("madeja",  "6a4e28", "b09050", "f0c060", "f8e0a0"),
    "fragmento_celestial": ("esquirla", "404973", "656e97", "a3a7c2", "f5ffe8"),
    "incienso_espiritual": ("incienso", "3a2058", "6e3aa0", "9d6dff", "f0e8ff"),
    "nucleo_obsidiana":    ("roca",    "1f1d25", "2f354f", "404973", "656e97"),
    "polvo_celestial":     ("polvo",   "656e97", "a3a7c2", "d8dce8", "f5ffe8"),
    "polvo_espectro":      ("polvo",   "2f5753", "4fa4b8", "92e8c0", "f5ffe8"),
    "raiz_umbria":         ("raiz",    "3a2415", "563620", "7c5030", "a27044"),
    "rayo_cristalizado":   ("rayo",    "6a4e28", "f0c060", "f8e0a0", "4fa4b8"),
    "sal_abisal":          ("sal",     "2f5753", "4fa4b8", "a3a7c2", "f5ffe8"),
    "savia_ancestral":     ("resina",  "7c5030", "a27044", "d27d2c", "ee9e57"),
    "tinta_celestial":     ("frasco",  "1f1d25", "2f354f", "404973", "9d6dff"),
    "vidrio_obsidiana":    ("placa",   "2b1b35", "3a2058", "6e3aa0", "a3a7c2"),
    # --- "Final" que también son arquetipo claro ---------------------------
    # De los 23 items Final, estos 16 son formas reconocibles que la aritmética
    # clava. A PixelLab se le dejan solo los 7 donde su detalle gana: las dos
    # armaduras, la capa, el círculo de invocación, el bastón y los dos cetros.
    "amuleto_constelacion": ("amuleto", "855a14", "c49260", "f0c060", "9d6dff"),
    "amuleto_fenix":       ("amuleto", "753027", "d04648", "ff8933", "ffd196"),
    "corona_runica":       ("corona",  "855a14", "b09050", "f0c060", "9d6dff"),
    "corona_escarcha":     ("corona",  "404973", "656e97", "a3a7c2", "f4f0e8"),
    "escudo_dragon":       ("escudo",  "753027", "9c3038", "d04648", "f0c060"),
    "espada_astral":       ("espada",  "404973", "656e97", "a3a7c2", "92e8c0"),
    "martillo_obsidiana":  ("martillo", "1f1d25", "2f354f", "656e97", "7c5030"),
    "orbe_astral":         ("orbe",    "3a2058", "6e3aa0", "9d6dff", "f0e8ff"),
    "orbe_fusion":         ("orbe",    "753027", "d27d2c", "f0c060", "f8e0a0"),
    "reloj_celestial":     ("reloj",   "6a4e28", "b09050", "f0c060", "f8e0a0"),
    "tomo_astral":         ("tomo",    "2f354f", "404973", "656e97", "f0c060"),
    "mapa_constelaciones": ("mapa",    "8a6a3a", "b8a890", "e8dcc0", "f4f0e8"),
    "piedra_abisal":       ("gema",    "1f1d25", "2f354f", "3a2058", "6e3aa0"),
    "polvo_constelaciones": ("polvo",  "3a2058", "6e3aa0", "c89bff", "f0e8ff"),
    "elixir_sombrio":      ("frasco",  "1f1d25", "2b1b35", "3a2058", "6b2058"),
    "tonico_abisal":       ("frasco",  "2f5753", "4fa4b8", "92e8c0", "f5ffe8"),
}


def _paleta() -> list:
    import json
    datos = json.loads((RAIZ / "art_reference/paleta_items.json").read_text(encoding="utf-8"))
    return [(int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)) for h in datos["colores"]]


def _luz(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _mas_oscuro(col, paleta: list) -> tuple:
    """El color de la paleta más parecido pero más oscuro. Se elige de la paleta
    real y no restando a ojo, para no meter colores que luego el checker rechace."""
    objetivo = _luz(col) * 0.62
    cand = [p for p in paleta if _luz(p) < _luz(col) - 8]
    if not cand:
        return col
    return min(cand, key=lambda p: abs(_luz(p) - objetivo)
               + 0.35 * sum((p[i] - col[i]) ** 2 for i in range(3)) ** 0.5)


class Lienzo:
    """32×32 con lo justo para dibujar. La luz siempre viene de arriba-izquierda,
    que es la regla de la casa, así que los `brillo` van a ese lado."""

    def __init__(self):
        self.im = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, col):
        self.d.rectangle([x0, y0, x1, y1], fill=col)

    def elipse(self, x0, y0, x1, y1, col):
        self.d.ellipse([x0, y0, x1, y1], fill=col)

    def poli(self, puntos, col):
        self.d.polygon(puntos, fill=col)

    def punto(self, x, y, col):
        if 0 <= x < LADO and 0 <= y < LADO:
            self.im.putpixel((x, y), col)

    def sombra_interna(self, paleta: list):
        """Oscurece el canto inferior-derecho, que es el lado opuesto a la luz.

        Además de asentar el objeto, sube el número de colores: sin esto cada
        sprite se quedaba en 5 (cuatro tonos y el contorno) y el contrato pide
        entre 6 y 21, que es lo que miden los 86 que ya existen.
        """
        px = self.im.load()
        cambios = []
        for y in range(LADO):
            for x in range(LADO):
                if not px[x, y][3]:
                    continue
                # ¿toca el vacío por abajo o por la derecha?
                for dx, dy in ((1, 0), (0, 1), (1, 1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < LADO and 0 <= ny < LADO) or not px[nx, ny][3]:
                        cambios.append((x, y, px[x, y][:3]))
                        break
        cache = {}
        for x, y, col in cambios:
            if col not in cache:
                cache[col] = _mas_oscuro(col, paleta)
            px[x, y] = cache[col] + (255,)

    def contorno(self):
        """1 px de #21181b alrededor de todo lo opaco."""
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


# --- arquetipos -----------------------------------------------------------
# Cada uno recibe el lienzo y los cuatro tonos ya convertidos a RGBA.

def lingote(L, s, b, l, h):
    L.poli([(7, 18), (24, 18), (27, 25), (4, 25)], s)      # cara frontal
    L.poli([(9, 11), (22, 11), (24, 17), (7, 17)], b)      # cara superior
    L.poli([(10, 12), (21, 12), (22, 14), (9, 14)], l)
    L.rect(11, 12, 16, 12, h)                              # filo iluminado
    L.rect(6, 19, 25, 21, b)
    L.rect(6, 19, 14, 19, l)


def gema(L, s, b, l, h):
    """La gema tallada clásica. Es la ÚNICA que tiene esta silueta: siete items de
    esta tanda eran mineral, y con un solo arquetipo salían siete rombos iguales
    que no se distinguían en el inventario."""
    L.poli([(16, 3), (26, 14), (16, 29), (6, 14)], s)
    L.poli([(16, 5), (23, 14), (16, 26), (9, 14)], b)
    L.poli([(16, 6), (16, 24), (11, 14)], l)               # facetas: izquierda al sol
    L.poli([(16, 7), (20, 14), (16, 20)], h)
    L.rect(13, 11, 14, 15, h)


def sal(L, s, b, l, h):
    """Racimo de cubos: la sal cristaliza en cubo, no en gema tallada."""
    cubos = [(6, 16, 9), (14, 12, 10), (20, 19, 8), (11, 22, 7), (21, 8, 6)]
    for x, y, t in cubos:
        L.rect(x, y, x + t, y + t, s)
        L.rect(x + 1, y + 1, x + t - 1, y + t - 1, b)
        L.rect(x + 1, y + 1, x + t // 2, y + t // 2, l)    # cara al sol
        L.punto(x + 2, y + 2, h)


def escarcha(L, s, b, l, h):
    """Estrella de hielo: seis púas desde el centro."""
    L.rect(15, 4, 16, 27, s)
    L.rect(15, 4, 15, 27, b)
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        for i in range(11):
            L.punto(16 + dx * i, 16 + dy * i, s if i > 7 else b)
    L.rect(5, 15, 26, 16, s)
    L.rect(5, 15, 26, 15, b)
    for x, y in ((16, 9), (16, 22), (10, 16), (22, 16), (11, 11), (21, 21)):
        L.punto(x, y, l)
    L.rect(14, 14, 17, 17, l)
    L.rect(14, 14, 15, 15, h)


def roca(L, s, b, l, h):
    """Pedrusco angular sin tallar: caras planas y ninguna simetría."""
    L.poli([(5, 20), (9, 8), (19, 5), (27, 13), (25, 25), (11, 27)], s)
    L.poli([(8, 19), (11, 10), (18, 8), (24, 14), (22, 23), (12, 24)], b)
    L.poli([(11, 10), (18, 8), (16, 16), (10, 17)], l)     # cara superior al sol
    L.poli([(18, 8), (24, 14), (17, 16)], b)
    L.punto(13, 11, h)
    L.punto(14, 12, h)


def esquirla(L, s, b, l, h):
    """Astilla irregular: se ha desprendido de algo, no la ha tallado nadie."""
    L.poli([(19, 3), (25, 17), (14, 29), (9, 20), (13, 10)], s)
    L.poli([(19, 6), (23, 17), (15, 26), (12, 20), (15, 11)], b)
    L.poli([(19, 7), (16, 24), (14, 19), (16, 11)], l)
    L.poli([(18, 9), (17, 18), (16, 14)], h)


def placa(L, s, b, l, h):
    """Lámina de vidrio volcánico: plana, con el canto marcado y un lascado."""
    L.poli([(4, 12), (20, 6), (28, 17), (12, 25)], s)
    L.poli([(7, 13), (19, 9), (25, 17), (13, 22)], b)
    L.poli([(8, 13), (18, 10), (15, 15), (9, 16)], l)      # reflejo alargado
    L.poli([(20, 12), (24, 17), (19, 18)], b)
    L.d.line([(10, 14), (16, 12)], fill=h, width=1)
    L.poli([(21, 20), (26, 18), (23, 23)], s)              # lasca desprendida
    L.poli([(22, 20), (25, 19), (23, 22)], b)


def amalgama(L, s, b, l, h):
    """Dos materiales fundidos: un bulto irregular con vetas del otro color."""
    L.elipse(5, 8, 26, 27, s)
    L.elipse(7, 10, 24, 25, b)
    L.elipse(9, 12, 18, 20, l)
    for x0, y0, x1, y1 in ((10, 22, 20, 24), (18, 11, 23, 14), (12, 9, 16, 11)):
        L.elipse(x0, y0, x1, y1, l)                        # burbujas del otro metal
    L.elipse(11, 13, 15, 17, h)
    L.punto(20, 12, h)


def polvo(L, s, b, l, h):
    L.poli([(4, 25), (28, 25), (24, 17), (8, 17)], s)      # montoncito
    L.poli([(7, 24), (25, 24), (22, 18), (10, 18)], b)
    L.poli([(10, 23), (21, 23), (19, 20), (13, 20)], l)
    for x, y in ((13, 21), (17, 21), (15, 19), (19, 22), (11, 22)):
        L.punto(x, y, h)
    for x, y in ((8, 13), (23, 11), (14, 9), (19, 14), (10, 8)):   # motas al vuelo
        L.punto(x, y, h)


def frasco(L, s, b, l, h):
    L.rect(13, 4, 18, 8, s)                                # cuello
    L.rect(14, 4, 15, 8, l)
    L.rect(12, 3, 19, 4, l)                                # tapón
    L.elipse(7, 9, 24, 27, s)                              # panza
    L.elipse(9, 12, 22, 25, b)                             # líquido
    L.elipse(10, 14, 17, 21, l)
    L.elipse(11, 15, 14, 18, h)                            # reflejo


def vial(L, s, b, l, h):
    L.rect(12, 3, 19, 5, s)
    L.rect(13, 3, 14, 5, l)
    L.poli([(11, 6), (20, 6), (22, 27), (9, 27)], s)       # tubo cónico
    L.poli([(13, 12), (18, 12), (20, 25), (11, 25)], b)
    L.poli([(13, 16), (16, 16), (16, 24), (12, 24)], l)
    L.rect(13, 8, 14, 14, h)                               # brillo del vidrio


def madeja(L, s, b, l, h):
    L.elipse(5, 9, 26, 24, s)                              # ovillo
    L.elipse(7, 11, 24, 22, b)
    for i in range(4):                                     # hebras cruzadas
        L.d.line([(8, 13 + i * 3), (23, 11 + i * 3)], fill=l, width=1)
    L.d.line([(9, 12), (22, 21)], fill=h, width=1)
    L.rect(24, 15, 28, 16, b)                              # cabo suelto
    L.rect(26, 16, 28, 19, l)


def raiz(L, s, b, l, h):
    """Tubérculo con raicillas. Antes era un palo recto y parecía leña; el bulbo
    y las barbas colgando son lo que lo hace raíz."""
    L.elipse(9, 6, 22, 21, s)                              # bulbo
    L.elipse(11, 8, 20, 19, b)
    L.elipse(12, 9, 16, 14, l)
    L.punto(13, 10, h)
    L.rect(14, 3, 17, 7, s)                                # brote de arriba
    L.rect(15, 4, 16, 7, l)
    for x0, dx in ((11, -1), (15, 0), (19, 1)):            # barbas
        for i in range(7):
            L.punto(x0 + dx * (i // 2), 20 + i, s if i > 4 else b)
    L.punto(12, 24, b)
    L.punto(20, 25, b)


def resina(L, s, b, l, h):
    L.poli([(16, 4), (23, 18), (16, 28), (9, 18)], s)      # gota
    L.elipse(10, 14, 22, 27, s)
    L.elipse(11, 16, 21, 26, b)
    L.elipse(12, 17, 18, 23, l)
    L.elipse(13, 18, 15, 20, h)
    L.poli([(16, 6), (18, 14), (14, 14)], b)               # cuello de la gota
    L.punto(15, 8, h)


def incienso(L, s, b, l, h):
    L.rect(14, 10, 17, 28, s)                              # barrita
    L.rect(15, 10, 16, 28, b)
    L.rect(15, 12, 15, 26, l)
    L.rect(10, 26, 21, 28, s)                              # base
    L.rect(11, 26, 20, 26, b)
    for i, (x, y) in enumerate(((16, 8), (14, 6), (17, 4), (15, 2))):   # humo
        L.punto(x, y, h if i % 2 else l)
        L.punto(x + 1, y, l)


def nucleo(L, s, b, l, h):
    L.elipse(4, 4, 27, 27, s)                              # roca
    L.elipse(6, 6, 25, 25, b)
    for a in ((9, 10, 14, 13), (17, 9, 22, 12), (12, 17, 19, 21), (8, 15, 12, 18)):
        L.rect(a[0], a[1], a[2], a[3], l)                  # grietas incandescentes
    L.elipse(12, 12, 19, 19, l)
    L.elipse(13, 13, 17, 17, h)
    L.punto(10, 9, h)


def rayo(L, s, b, l, h):
    L.poli([(9, 3), (22, 3), (25, 16), (16, 29), (7, 16)], h)   # cristal cian
    L.poli([(11, 5), (21, 5), (23, 16), (16, 26), (9, 16)], s)
    L.poli([(18, 5), (13, 16), (17, 16), (12, 26), (20, 14), (16, 14), (20, 5)], b)
    L.poli([(17, 6), (14, 15), (16, 15), (13, 23), (18, 14), (15, 14), (18, 6)], l)


def amuleto(L, s, b, l, h):
    """Colgante con cadena. La cadena es lo que lo separa de una gema suelta."""
    for i in range(6):                                     # cadena en V
        L.punto(11 + i, 3 + i, b)
        L.punto(21 - i, 3 + i, b)
    L.punto(11, 3, l)
    L.punto(21, 3, l)
    L.elipse(9, 9, 23, 25, s)                              # engaste
    L.elipse(11, 11, 21, 23, b)
    L.elipse(13, 13, 19, 21, h)                            # piedra
    L.elipse(14, 14, 16, 17, l)
    L.rect(14, 8, 18, 10, s)                               # anilla
    L.rect(15, 8, 16, 9, l)


def corona(L, s, b, l, h):
    """Diadema de tres puntas, con gema en la del medio."""
    L.poli([(5, 24), (27, 24), (27, 15), (22, 20), (16, 9), (10, 20), (5, 15)], s)
    L.poli([(7, 22), (25, 22), (25, 18), (22, 22), (16, 12), (10, 22), (7, 18)], b)
    L.rect(6, 24, 26, 27, s)                               # aro
    L.rect(6, 24, 26, 25, b)
    L.rect(7, 24, 15, 24, l)
    for x in (7, 16, 25):                                  # remates
        L.punto(x, 15 if x == 16 else 17, h)
    L.elipse(14, 16, 18, 21, h)                            # gema central
    L.punto(15, 17, l)


def escudo(L, s, b, l, h):
    """Rodela con refuerzo en cruz."""
    L.poli([(5, 4), (27, 4), (27, 17), (16, 29), (5, 17)], s)
    L.poli([(7, 6), (25, 6), (25, 17), (16, 26), (7, 17)], b)
    L.poli([(8, 7), (16, 7), (16, 24), (8, 17)], l)        # mitad al sol
    L.rect(14, 7, 17, 25, h)                               # refuerzo vertical
    L.rect(7, 12, 24, 15, h)                               # travesaño
    L.elipse(13, 11, 18, 17, s)                            # bollón central
    L.elipse(14, 12, 17, 16, h)


def espada(L, s, b, l, h):
    """Hoja recta con guarda y pomo."""
    L.poli([(14, 2), (18, 2), (18, 19), (16, 22), (14, 19)], s)
    L.rect(15, 3, 17, 19, b)
    L.rect(15, 3, 15, 19, h)                               # filo al sol
    L.punto(16, 4, h)
    L.rect(9, 20, 23, 22, s)                               # guarda
    L.rect(10, 20, 22, 20, l)
    L.rect(15, 23, 17, 27, s)                              # empuñadura
    L.rect(15, 23, 15, 27, b)
    L.elipse(13, 27, 19, 30, s)                            # pomo
    L.elipse(14, 28, 17, 30, l)


def martillo(L, s, b, l, h):
    """Maza de cabeza cuadrada: masa arriba, mango fino abajo."""
    L.rect(5, 5, 27, 16, s)                                # cabeza
    L.rect(7, 7, 25, 14, b)
    L.rect(7, 7, 15, 10, l)                                # cara al sol
    L.rect(8, 8, 12, 9, l)
    L.rect(14, 16, 18, 30, h)                              # mango
    L.rect(15, 17, 16, 29, b)
    L.rect(12, 15, 20, 17, s)                              # virola
    L.rect(13, 15, 19, 15, l)


def orbe(L, s, b, l, h):
    """Esfera con soporte. El brillo va arriba-izquierda, como manda la luz."""
    L.elipse(4, 3, 27, 26, s)
    L.elipse(6, 5, 25, 24, b)
    L.elipse(8, 7, 20, 19, l)
    L.elipse(10, 9, 15, 14, h)                             # reflejo
    for x, y in ((19, 17), (21, 11), (14, 21)):            # chispas internas
        L.punto(x, y, h)
    L.poli([(9, 25), (22, 25), (25, 30), (6, 30)], s)      # peana
    L.rect(9, 26, 21, 27, b)
    L.rect(9, 26, 14, 26, l)


def reloj(L, s, b, l, h):
    """Reloj de bolsillo abierto: caja, esfera y manecillas."""
    L.rect(14, 2, 18, 5, s)                                # anilla
    L.rect(15, 2, 16, 4, l)
    L.elipse(4, 5, 27, 28, s)                              # caja
    L.elipse(6, 7, 25, 26, b)
    L.elipse(8, 9, 23, 24, l)                              # esfera
    L.elipse(9, 10, 16, 17, h)
    L.d.line([(16, 17), (16, 12)], fill=s, width=1)        # manecillas
    L.d.line([(16, 17), (20, 19)], fill=s, width=1)
    L.punto(16, 17, s)
    for x, y in ((16, 10), (22, 17), (16, 23), (10, 17)):  # marcas horarias
        L.punto(x, y, s)


def tomo(L, s, b, l, h):
    """Libro cerrado de canto, con broche."""
    L.rect(5, 5, 26, 27, s)                                # tapa
    L.rect(7, 7, 24, 25, b)
    L.rect(7, 7, 15, 25, l)                                # mitad al sol
    L.rect(5, 5, 9, 27, s)                                 # lomo
    L.rect(6, 7, 7, 25, b)
    L.rect(24, 8, 27, 24, h)                               # canto de hojas
    L.rect(25, 9, 26, 23, l)
    L.elipse(13, 12, 19, 19, h)                            # emblema
    L.elipse(15, 14, 17, 17, s)
    L.rect(22, 14, 27, 17, s)                              # broche
    L.rect(23, 15, 26, 16, h)


def mapa(L, s, b, l, h):
    """Pergamino desenrollado, con los rodillos a los lados."""
    L.rect(7, 8, 24, 24, s)                                # hoja
    L.rect(8, 9, 23, 23, l)
    L.rect(8, 9, 15, 16, h)                                # zona al sol
    for x, y in ((11, 13), (17, 12), (14, 18), (20, 17), (12, 20)):
        L.punto(x, y, s)                                   # estrellas del mapa
    L.d.line([(11, 13), (17, 12)], fill=b, width=1)
    L.d.line([(17, 12), (20, 17)], fill=b, width=1)
    L.rect(4, 6, 8, 26, s)                                 # rodillo izquierdo
    L.rect(5, 7, 6, 25, b)
    L.rect(5, 7, 5, 25, h)
    L.rect(23, 6, 27, 26, s)                               # rodillo derecho
    L.rect(24, 7, 26, 25, b)


ARQUETIPOS = {
    "lingote": lingote, "polvo": polvo, "frasco": frasco, "vial": vial,
    "madeja": madeja, "raiz": raiz, "resina": resina, "incienso": incienso,
    "nucleo": nucleo, "rayo": rayo,
    # La familia mineral, con una silueta propia cada una.
    "gema": gema, "sal": sal, "escarcha": escarcha, "roca": roca,
    "esquirla": esquirla, "placa": placa, "amalgama": amalgama,
    # Objetos acabados.
    "amuleto": amuleto, "corona": corona, "escudo": escudo, "espada": espada,
    "martillo": martillo, "orbe": orbe, "reloj": reloj, "tomo": tomo, "mapa": mapa,
}


def dibujar(sid: str, paleta: list) -> Image.Image:
    arq, s, b, l, h = ITEMS[sid]
    L = Lienzo()
    ARQUETIPOS[arq](L, c(s), c(b), c(l), c(h))
    L.sombra_interna(paleta)
    L.contorno()
    return L.im


def main() -> None:
    solo = None
    if "--solo" in sys.argv:
        solo = sys.argv[sys.argv.index("--solo") + 1]
    DEST.mkdir(parents=True, exist_ok=True)
    paleta = _paleta()
    n = 0
    for sid in sorted(ITEMS):
        if solo and sid != solo:
            continue
        im = dibujar(sid, paleta)
        assert im.size == (LADO, LADO), im.size
        im.save(DEST / f"{sid}.png")
        cols = len({p[:3] for p in im.getdata() if p[3]})
        bb = im.getbbox()
        print(f"  {sid:22} {ITEMS[sid][0]:9} {cols:2} colores  bbox {bb[2]-bb[0]}×{bb[3]-bb[1]}")
        n += 1
    print(f"\n{n} sprites escritos en {DEST.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
