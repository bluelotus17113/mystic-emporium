#!/usr/bin/env python3
"""Genera los iconos de línea de la interfaz (dirección «cristal oscuro»).

Regla de estilo del juego: el pixel art es para las COSAS DEL MUNDO (items,
recursos, lo que pide un cliente) y la línea limpia es para los CONTROLES (chips
de la banda, pestañas, interruptores). Antes los controles eran emoji del sistema
operativo, que los dibujaba la fuente del SO a otra escala y otro estilo.

Se dibuja a 4× y se reduce con LANCZOS, así el trazo queda suave sin depender de
que Godot filtre bien. Salida en godot/art/sprites/ui/glyph/.

    python3 tools/ui_icons.py
"""
import math
import pathlib
from PIL import Image, ImageDraw

DEST = pathlib.Path(__file__).resolve().parent.parent / "godot/art/sprites/ui/glyph"
LADO = 32          # tamaño final en píxeles
SS = 4             # supermuestreo
U = LADO * SS / 24.0   # unidad: los dibujos se piensan sobre una rejilla de 24

TRAZO = (238, 232, 246, 255)   # UIPalette.TEXT
ORO = (246, 194, 106, 255)     # UIPalette.GOLD
ARC = (168, 140, 255, 255)     # UIPalette.ARCANE
VERDE = (126, 214, 148, 255)   # UIPalette.OK
ROJO = (232, 119, 107, 255)    # UIPalette.BAD

GRUESO = 2.1   # ancho de trazo en unidades de la rejilla de 24


class Lienzo:
    def __init__(self):
        self.im = Image.new("RGBA", (LADO * SS, LADO * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def p(self, *pts):
        return [(x * U, y * U) for x, y in pts]

    def linea(self, *pts, col=TRAZO, w=GRUESO):
        self.d.line(self.p(*pts), fill=col, width=max(1, int(w * U)), joint="curve")
        # PIL no redondea los extremos: los tapamos con un punto en cada vértice.
        for x, y in pts:
            self.punto(x, y, w / 2, col)

    def punto(self, x, y, r, col=TRAZO):
        self.d.ellipse([(x - r) * U, (y - r) * U, (x + r) * U, (y + r) * U], fill=col)

    def circ(self, x, y, r, col=TRAZO, w=GRUESO, relleno=None):
        caja = [(x - r) * U, (y - r) * U, (x + r) * U, (y + r) * U]
        if relleno:
            self.d.ellipse(caja, fill=relleno)
        if w:
            self.d.ellipse(caja, outline=col, width=max(1, int(w * U)))

    def arco(self, x, y, r, a0, a1, col=TRAZO, w=GRUESO):
        self.d.arc([(x - r) * U, (y - r) * U, (x + r) * U, (y + r) * U],
                   a0, a1, fill=col, width=max(1, int(w * U)))

    def caja(self, x0, y0, x1, y1, r=2, col=TRAZO, w=GRUESO, relleno=None):
        b = [x0 * U, y0 * U, x1 * U, y1 * U]
        self.d.rounded_rectangle(b, r * U, fill=relleno,
                                 outline=col if w else None,
                                 width=max(1, int(w * U)))

    def poli(self, *pts, col=TRAZO, w=GRUESO, relleno=None):
        if relleno:
            self.d.polygon(self.p(*pts), fill=relleno)
        if w:
            self.d.polygon(self.p(*pts), outline=col, width=max(1, int(w * U)))

    def salida(self):
        return self.im.resize((LADO, LADO), Image.LANCZOS)


# --------------------------------------------------------------- dibujos
def auto(c):
    """Automatización: engranaje con destello. No un robot."""
    for i in range(6):
        a = math.radians(i * 60)
        c.punto(12 + 7.4 * math.cos(a), 12 + 7.4 * math.sin(a), 1.9)
    c.circ(12, 12, 6.2, w=0, relleno=TRAZO)
    c.circ(12, 12, 2.7, w=0, relleno=(0, 0, 0, 0))
    # El agujero se hace borrando, no pintando: el icono va sobre fondos distintos.
    hueco = Image.new("RGBA", c.im.size, (0, 0, 0, 0))
    ImageDraw.Draw(hueco).ellipse([(12 - 2.9) * U, (12 - 2.9) * U,
                                   (12 + 2.9) * U, (12 + 2.9) * U], fill=(0, 0, 0, 255))
    c.im.paste((0, 0, 0, 0), (0, 0), hueco)


def _chevron(c, hacia):
    f = -1 if hacia == "izq" else 1
    c.linea((12 - 2.5 * f, 5), (12 + 3 * f, 12), (12 - 2.5 * f, 19), w=2.6)


def zone_prev(c):
    _chevron(c, "izq")


def zone_next(c):
    _chevron(c, "der")


def follow(c):
    """Seguir a la protagonista: retícula, no una lupa."""
    c.circ(12, 12, 5.4, w=2.0)
    c.punto(12, 12, 1.8, ORO)
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        c.linea((12 + dx * 8.6, 12 + dy * 8.6), (12 + dx * 6.4, 12 + dy * 6.4), w=2.0)


def research(c):
    """Matraz. Sustituye a 🔬, que en la banda se veía como una mancha."""
    c.linea((9.5, 3.5), (14.5, 3.5), w=2.0)
    c.poli((10, 4), (14, 4), (19, 20), (5, 20), relleno=ARC, w=0)
    c.poli((10, 4), (14, 4), (19, 20), (5, 20), w=2.0)
    c.punto(10.5, 15.5, 1.1, TRAZO)
    c.punto(14, 17.5, 0.9, TRAZO)


def siege(c):
    """Torre almenada."""
    c.caja(6.5, 9, 17.5, 20.5, r=1, relleno=ORO, w=2.0)
    for x in (5.5, 9.8, 14.1):
        c.caja(x, 3.5, x + 4.4, 9.5, r=1, relleno=ORO, w=2.0)
    c.caja(10.2, 14, 13.8, 20.5, r=1, relleno=(0, 0, 0, 0), w=1.8)


def quest(c):
    """Misión del día: tablilla con visto."""
    c.caja(5, 4.5, 19, 20.5, r=2.4, w=2.0)
    c.caja(9, 2.5, 15, 6.5, r=1.4, relleno=TRAZO, w=0)
    c.linea((8.5, 13), (11, 15.6), (16, 9.5), col=ORO, w=2.4)


def save(c):
    """Guardado: disco."""
    c.caja(4.5, 4.5, 19.5, 19.5, r=2.4, w=2.0)
    c.caja(8.5, 4.5, 15.5, 10, r=0.8, relleno=TRAZO, w=0)
    c.caja(8, 13, 16, 19.5, r=0.8, w=1.8)


def phase_dawn(c):
    """Amanecer. Se distingue del atardecer por la FLECHA, no solo por el color:
    a 20 px en la banda, oro y naranja son el mismo color."""
    c.arco(12, 15.5, 5.6, 180, 360, col=ORO, w=2.3)
    c.linea((4.5, 15.5), (19.5, 15.5), col=ORO, w=2.0)
    c.linea((3, 19.5), (21, 19.5), w=2.0)
    c.linea((12, 8.5), (12, 3.5), col=ORO, w=2.0)
    c.linea((9.4, 5.8), (12, 3.2), (14.6, 5.8), col=ORO, w=2.0)


def phase_day(c):
    c.circ(12, 12, 4.6, w=0, relleno=ORO)
    for i in range(8):
        a = math.radians(i * 45)
        c.linea((12 + 7.2 * math.cos(a), 12 + 7.2 * math.sin(a)),
                (12 + 9.8 * math.cos(a), 12 + 9.8 * math.sin(a)), col=ORO, w=1.9)


def phase_dusk(c):
    """Atardecer: el mismo sol tras el horizonte, pero la flecha baja."""
    naranja = (228, 146, 92, 255)
    c.arco(12, 15.5, 5.6, 180, 360, col=naranja, w=2.3)
    c.linea((4.5, 15.5), (19.5, 15.5), col=naranja, w=2.0)
    c.linea((3, 19.5), (21, 19.5), w=2.0)
    c.linea((12, 3.5), (12, 8.5), col=naranja, w=2.0)
    c.linea((9.4, 6.2), (12, 8.8), (14.6, 6.2), col=naranja, w=2.0)


def phase_night(c):
    """Luna creciente: se dibuja el disco y se le muerde otro encima."""
    c.circ(12.5, 12, 7.2, w=0, relleno=ARC)
    mordisco = Image.new("RGBA", c.im.size, (0, 0, 0, 0))
    ImageDraw.Draw(mordisco).ellipse([(16.6 - 7.0) * U, (10.2 - 7.0) * U,
                                      (16.6 + 7.0) * U, (10.2 + 7.0) * U],
                                     fill=(0, 0, 0, 255))
    c.im.paste((0, 0, 0, 0), (0, 0), mordisco)
    c.punto(6.2, 5.6, 1.0, TRAZO)
    c.punto(19.4, 18.4, 0.8, TRAZO)


def season_spring(c):
    for i in range(5):
        a = math.radians(i * 72 - 90)
        c.circ(12 + 5.2 * math.cos(a), 12 + 5.2 * math.sin(a), 3.4,
               w=0, relleno=(244, 160, 200, 255))
    c.punto(12, 12, 2.4, ORO)


def season_summer(c):
    c.circ(12, 12, 5.0, w=0, relleno=ORO)
    for i in range(6):
        a = math.radians(i * 60 + 15)
        c.linea((12 + 7.4 * math.cos(a), 12 + 7.4 * math.sin(a)),
                (12 + 10.2 * math.cos(a), 12 + 10.2 * math.sin(a)), col=ORO, w=2.0)


def season_autumn(c):
    """Hoja. El contorno son dos arcos que se cruzan en la punta y en el rabillo;
    con un rombo de cuatro vértices parecía una cometa."""
    hoja, vena = (226, 138, 74, 255), (150, 78, 38, 255)
    pts = []
    for t in [i / 40.0 for i in range(41)]:      # borde derecho, hacia abajo
        pts.append((12 + 6.2 * math.sin(math.pi * t), 3.5 + 14.5 * t))
    for t in [i / 40.0 for i in range(41)]:      # borde izquierdo, de vuelta
        pts.append((12 - 6.2 * math.sin(math.pi * t), 18.0 - 14.5 * t))
    c.d.polygon(c.p(*pts), fill=hoja)
    c.linea((12, 4.5), (12, 21), col=vena, w=1.5)
    for y, dx in ((8.5, 3.4), (12, 3.6), (15.5, 2.8)):
        c.linea((12, y), (12 - dx, y + 2.4), col=vena, w=1.2)
        c.linea((12, y), (12 + dx, y + 2.4), col=vena, w=1.2)


def season_winter(c):
    """Copo."""
    for i in range(3):
        a = math.radians(i * 60)
        dx, dy = 9.0 * math.cos(a), 9.0 * math.sin(a)
        c.linea((12 - dx, 12 - dy), (12 + dx, 12 + dy), col=(150, 214, 246, 255), w=1.9)
        for s in (-1, 1):
            bx, by = 12 + dx * 0.62, 12 + dy * 0.62
            b = a + s * math.radians(45)
            c.linea((bx, by), (bx + 3.0 * math.cos(b), by + 3.0 * math.sin(b)),
                    col=(150, 214, 246, 255), w=1.6)


def tab_build(c):
    """Construir: escuadra y ladrillo."""
    c.caja(3.5, 12.5, 12, 20.5, r=1, relleno=ORO, w=1.9)
    c.caja(12, 12.5, 20.5, 20.5, r=1, w=1.9)
    c.caja(7.5, 4.5, 16.5, 12.5, r=1, w=1.9)


def tab_workers(c):
    """Ayudantes: dos siluetas."""
    c.circ(9, 8, 3.4, w=0, relleno=TRAZO)
    c.d.pieslice([2.6 * U, 12.4 * U, 15.4 * U, 25 * U], 180, 360, fill=TRAZO)
    c.circ(17, 9.5, 2.7, w=0, relleno=ORO)
    c.d.pieslice([11.8 * U, 13.6 * U, 22.2 * U, 24 * U], 180, 360, fill=ORO)


def tab_upgrade(c):
    """Mejoras: flecha arriba sobre base."""
    c.poli((12, 3.5), (20, 12), (15.5, 12), (15.5, 17), (8.5, 17), (8.5, 12), (4, 12),
           relleno=ORO, w=0)
    c.linea((6.5, 20.5), (17.5, 20.5), w=2.2)


def tab_recipes(c):
    """Recetario: libro abierto."""
    c.poli((12, 6), (4, 4), (4, 18.5), (12, 20.5), relleno=(0, 0, 0, 0), w=2.0)
    c.poli((12, 6), (20, 4), (20, 18.5), (12, 20.5), relleno=(0, 0, 0, 0), w=2.0)
    c.linea((12, 6), (12, 20.5), col=ORO, w=1.8)


def tab_progress(c):
    """Progreso: medalla."""
    c.linea((8, 3), (11, 10), w=2.0)
    c.linea((16, 3), (13, 10), w=2.0)
    c.circ(12, 15.5, 5.8, w=2.0, relleno=ORO)


def tab_album(c):
    """Álbum: lámina con montaña."""
    c.caja(3.5, 5, 20.5, 19, r=2.2, w=2.0)
    c.punto(8.5, 9.5, 1.5, ORO)
    c.poli((6, 18), (12, 11), (18, 18), relleno=TRAZO, w=0)


def tab_wardrobe(c):
    """Armario: camiseta."""
    c.poli((9, 4), (15, 4), (20.5, 7.5), (17.5, 11), (17.5, 20.5), (6.5, 20.5),
           (6.5, 11), (3.5, 7.5), relleno=(0, 0, 0, 0), w=2.0)
    c.arco(12, 3.2, 3.2, 20, 160, w=1.8)


def auto_craft(c):
    """Crafteo: martillo."""
    c.caja(4, 4.5, 15, 10, r=1.6, relleno=ORO, w=1.9)
    c.linea((9.5, 10), (9.5, 20.5), w=2.4)


def auto_orders(c):
    """Entregas: caja."""
    c.poli((12, 3.5), (20.5, 8), (20.5, 17), (12, 21.5), (3.5, 17), (3.5, 8), w=2.0)
    c.linea((3.5, 8), (12, 12.5), (20.5, 8), w=1.8)
    c.linea((12, 12.5), (12, 21.5), w=1.8)


def auto_research(c):
    """Investigación: pila de libros."""
    c.caja(3.5, 15, 20.5, 20.5, r=1.4, relleno=ARC, w=1.9)
    c.caja(5.5, 9.5, 18.5, 15, r=1.4, w=1.9)
    c.caja(3.5, 4, 20.5, 9.5, r=1.4, relleno=ORO, w=1.9)


def auto_shop(c):
    """Ayudantes a sueldo: carrito."""
    c.linea((2.5, 4.5), (5.5, 4.5), (8.5, 15.5), (18.5, 15.5), (20.5, 7.5), (6.2, 7.5), w=2.0)
    c.punto(10, 19.5, 1.9, ORO)
    c.punto(17, 19.5, 1.9, ORO)


ICONOS = {
    "auto": auto, "zone_prev": zone_prev, "zone_next": zone_next, "follow": follow,
    "research": research, "siege": siege, "quest": quest, "save": save,
    "phase_dawn": phase_dawn, "phase_day": phase_day,
    "phase_dusk": phase_dusk, "phase_night": phase_night,
    "season_spring": season_spring, "season_summer": season_summer,
    "season_autumn": season_autumn, "season_winter": season_winter,
    "tab_build": tab_build, "tab_workers": tab_workers, "tab_upgrade": tab_upgrade,
    "tab_recipes": tab_recipes, "tab_progress": tab_progress,
    "tab_album": tab_album, "tab_wardrobe": tab_wardrobe,
    "auto_craft": auto_craft, "auto_orders": auto_orders,
    "auto_research": auto_research, "auto_shop": auto_shop,
}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for nombre, fn in ICONOS.items():
        c = Lienzo()
        fn(c)
        c.salida().save(DEST / f"{nombre}.png")
    print(f"{len(ICONOS)} iconos en {DEST}")


if __name__ == "__main__":
    main()
