#!/usr/bin/env python3
"""
Generador del lote 2: los 17 objetos de naturaleza para Mystic Emporium.
Emite PNG RGBA a un directorio de staging — NUNCA a godot/art/.

Diseñador 1: silueta, estructura y tres tonos por material. El detalle fino
(vetas, lunares, pétalos, musgo) lo pone el diseñador 2.

Contrato de este lote (art_reference/contrato_rediseno.json + encargo):
  - Los tamaños son CONTRATO DURO: las escenas llevan offset/scale calibrados.
  - Contorno #000000 PURO, 1 px, dibujado POR DEBAJO de los rellenos.
  - Elipse de sombra de contacto bajo objetos altos; nunca una base sólida.
  - Luz arriba-izquierda: brillo/luz en esa esquina, sombra abajo-derecha.
  - Copas en HILERAS FESTONEADAS: filas de arcos apiladas, con el borde
    inferior de cada hilera en el tono oscuro.
  - Las 5 especies se diferencian por SILUETA, no por color.
"""

import argparse
import math
import os
import sys

from PIL import Image

# ── Contrato duro: tamaños exactos ──────────────────────────────────────
# Las escenas de Godot llevan offset y scale calibrados a mano. Cambiar un
# tamaño rompe la escena.

TAMANOS = {
    "tree_oak":               (64, 64),
    "tree_birch":             (64, 64),
    "tree_pine":              (64, 64),
    "tree_cherry":            (64, 64),
    "tree_willow":            (64, 64),
    "tree_bush_big":          (64, 64),
    "decoration_apple_tree":  (32, 32),
    "tree_dead":              (48, 48),
    "flower_bush":            (32, 32),
    "bush":                   (32, 32),
    "biome_rock":             (48, 48),
    "decoration_stone_cairn": (32, 32),
    "mushroom_red":           (32, 32),
    "hay_bale":               (32, 32),
    "decoration_fallen_log":  (32, 16),
    "decoration_log_stump":   (32, 32),
    "decoration_grass_tuft":  (16, 16),
}

NOMBRES = list(TAMANOS.keys())

# ── Paleta: rampas del contrato_rediseno.json (tres tonos por material) ─

NEGRO = (0x00, 0x00, 0x00, 0xFF)          # contorno puro #000000

FOLLAJE = {
    "sombra": (0x21, 0x36, 0x2C),          # #21362c
    "medio":  (0x3E, 0xA0, 0x6C),          # #3ea06c
    "luz":    (0x5D, 0xCF, 0x81),          # #5dcf81
    "brillo": (0x9E, 0xEF, 0xC1),          # #9eefc1 (lo pone el diseñador 2)
}
FOLLAJE_ROSA = {
    "sombra": (0x3C, 0x1A, 0x20),          # #3c1a20
    "medio":  (0xD1, 0x69, 0x84),          # #d16984
    "luz":    (0xF5, 0xB3, 0xC5),          # #f5b3c5
    "brillo": (0xFC, 0xDC, 0xDF),          # #fcdcdf (diseñador 2)
}
MADERA = {
    "sombra": (0x5D, 0x42, 0x3A),          # #5d423a
    "medio":  (0x95, 0x64, 0x47),          # #956447
    "luz":    (0xBC, 0x80, 0x50),          # #bc8050
    "brillo": (0xDE, 0xBF, 0x88),          # #debf88 (diseñador 2)
}
PIEDRA = {
    "sombra": (0x74, 0x4B, 0x48),          # #744b48
    "medio":  (0x80, 0x74, 0x66),          # #807466
    "luz":    (0x99, 0xA7, 0x92),          # #99a792
    "brillo": (0xD1, 0xD1, 0xC0),          # #d1d1c0 (diseñador 2)
}
PAJA = {
    "sombra": (0x8F, 0x5F, 0x43),          # #8f5f43
    "medio":  (0xB0, 0x78, 0x55),          # #b07855
    "luz":    (0xCB, 0x91, 0x63),          # #cb9163
    "brillo": (0xD8, 0xAD, 0x7A),          # #d8ad7a (diseñador 2)
}
TIERRA = {
    "sombra": (0x55, 0x43, 0x3B),          # #55433b
    "medio":  (0xBB, 0x81, 0x53),          # #bb8153
    "luz":    (0xE8, 0xBB, 0x84),          # #e8bb84
    "brillo": (0xF4, 0xDF, 0xBD),          # #f4dfbd (diseñador 2)
}
HIERBA = {
    "oscura": (0x5A, 0xC9, 0x6B),          # #5ac96b
    "base":   (0x7C, 0xF2, 0xB6),          # #7cf2b6
    "clara":  (0x92, 0xCB, 0x98),          # #92cb98
}
ARENA = {
    "sombra": (0x45, 0x3F, 0x36),          # #453f36
    "medio":  (0xE8, 0xBB, 0x84),          # #e8bb84
    "luz":    (0xF7, 0xCB, 0xC4),          # #f7cbc4
    "brillo": (0xFC, 0xEB, 0xE2),          # #fcebe2 (diseñador 2)
}
BLANCO = {
    "sombra": (0xE0, 0xDD, 0xD4),          # #e0ddd4 (sombra de la corteza)
    "medio":  (0xFF, 0xFF, 0xFF),          # #ffffff (corteza de abedul)
    "luz":    (0xFF, 0xFF, 0xFF),          # #ffffff
    "brillo": (0xFF, 0xFF, 0xFF),          # #ffffff (diseñador 2)
}
ROJO = {
    "sombra": (0x8E, 0x1F, 0x1C),          # #8e1f1c
    "medio":  (0xD2, 0x30, 0x2F),          # #d2302f (manzanas, seta)
    "luz":    (0xF0, 0x6A, 0x5A),          # #f06a5a
    "brillo": (0xF8, 0xA5, 0x8B),          # #f8a58b (diseñador 2)
}

# Elipse de contacto cocida: DECISIÓN del usuario — quitada. La dibuja
# SunShadows en el juego (sun_shadows.gd). Si se quiere volver a cocerla,
# poner CON_SOMBRA_COCIDA = True (los parámetros de cada sprite se quedan).
CON_SOMBRA_COCIDA = False

# ── Hash espacial determinista ──────────────────────────────────────────

def h(x: int, y: int, s: int = 0) -> int:
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100


# ── Helpers de dibujo ───────────────────────────────────────────────────

def _canvas(w: int, h_img: int):
    """Lienzo RGBA transparente."""
    import numpy as np
    return np.zeros((h_img, w, 4), dtype=np.uint8)


def _opaque(rgb) -> tuple:
    return (rgb[0], rgb[1], rgb[2], 0xFF)


def _scallop(x: int, cx: float, lay: dict) -> float:
    """Borde inferior festoneado de una hilera en la columna x.

    Fila de arcos pequeños (escalas/tejas): en el centro de cada arco el
    borde cuelga `amp` px más abajo que en las juntas. `sag_edge` (sauce)
    hace que los arcos del borde cuelguen más que los del centro.
    """
    dx = x - cx
    w = 0.5 - 0.5 * math.cos(2.0 * math.pi * dx / lay["arcw"])
    sag = lay.get("sag", 1.0)
    if lay.get("sag_edge"):
        sag *= 1.0 + lay["sag_edge"] * abs(dx) / max(1.0, lay["halfw"])
    return lay["base"] + lay["amp"] * w * sag


def _cima_hilera(x: int, cx: float, lay: dict) -> float:
    """Cima de la hilera en la columna x. Con `topb` la cima TAMBIÉN es
    festoneada (picos hacia arriba): el borde superior de la copa no es una
    línea recta sino una fila de bultos redondos."""
    if not lay.get("topb"):
        return lay["top"]
    dx = x - cx
    w = 0.5 - 0.5 * math.cos(2.0 * math.pi * dx / lay["arcw"])
    return lay["top"] - lay["topb"] * w


def _band_owner(x: int, y: int, cx: float, layers) -> dict:
    """Devuelve la hilera que posee el píxel (la más alta cuya banda lo cubre)."""
    for lay in layers:
        if abs(x - cx) > lay["halfw"] + lay["amp"] + 1:
            continue
        bot = _scallop(x, cx, lay)
        cima = _cima_hilera(x, cx, lay)
        if bot < cima:
            continue
        if cima <= y <= bot:
            return lay
    return None


def _tone(lay: dict, x: int, y: int, cx: float, tones: dict) -> tuple:
    """Tono con sombra abrazando el contorno de abajo-derecha.

    La frontera luz/sombra es DIAGONAL (no vertical): combina la posición
    horizontal (más sombra a la derecha) con la vertical (más sombra abajo,
    incluyendo el canto festoneado). El resultado es una media luna de sombra
    pegada al borde inferior derecho — ~30 % del área, nunca la mitad.
    """
    bot = _scallop(x, cx, lay)
    cima = _cima_hilera(x, cx, lay)
    span = max(1.0, bot - cima)
    hw = max(1.0, lay["halfw"])

    # ── Canto festoneado: forzado a sombra (autosombreado de la capa) ──
    edge_dist = bot - y
    if edge_dist < 1.2:
        return tones["sombra"]

    # ── Factor de sombra: mezcla de posición horizontal y vertical ──
    # frac_x: 0 = borde izquierdo, 1 = borde derecho
    # frac_y: 0 = cima de la capa, 1 = borde inferior (ya cubierto por edge_dist)
    frac_x = (x - (cx - hw)) / (2.0 * hw)   # 0..1
    frac_y = (y - cima) / span              # 0..1
    # La sombra crece hacia abajo-derecha (diagonal)
    shadow = 0.45 * frac_x + 0.55 * frac_y  # 0..1 aprox

    if shadow < 0.30:
        return tones["luz"]
    elif shadow < 0.66:
        return tones["medio"]
    else:
        return tones["sombra"]


def _dome_env(cx: float, y_top: float, y_bot: float, rx_max: float,
              extra=None):
    """Envolvente de cúpula (semielipse apoyada en el suelo): ancho máximo
    abajo, redondeando hacia arriba. `extra(x,y)` añade ancho (sauce que
    cuelga por los lados)."""
    ry = max(1.0, y_bot - y_top)

    def env(x, y):
        if y < y_top or y > y_bot + 8:
            return False
        dy = y_bot - y
        lim = rx_max * math.sqrt(max(0.0, 1.0 - (dy / ry) ** 2))
        if extra:
            lim += extra(x, y)
        return abs(x - cx) <= lim

    return env


def _tri_env(cx: float, y_top: float, y_bot: float, rx_max: float):
    """Envolvente triangular (pino): estrecha arriba, ancha abajo."""
    span = max(1.0, y_bot - y_top)

    def env(x, y):
        if y < y_top or y > y_bot + 8:
            return False
        t = (y - y_top) / span
        return abs(x - cx) <= rx_max * t

    return env


def _pintar_copa(img, cx: float, layers, tones, env) -> None:
    """Rellena la copa: por cada píxel dentro de la envolvente y de una
    hilera, su tono. El resto queda transparente."""
    h_img, w = img.shape[:2]
    for y in range(h_img):
        for x in range(w):
            if not env(x, y):
                continue
            lay = _band_owner(x, y, cx, layers)
            if lay is None:
                continue
            img[y, x] = _opaque(_tone(lay, x, y, cx, tones))


def _pintar_puffs(img, cx: float, puffs, tones) -> None:
    """Masa de pomos iluminada con sombra abajo-derecha (diagonal).

    El borde inferior (1.5 px) va en sombra (autosombreado). Por encima,
    la iluminación usa una mezcla diagonal de posición horizontal y vertical:
    luz arriba-izquierda, medio al centro, sombra abajo-derecha.
    La frontera es diagonal — no un corte vertical recto.
    """
    h_img, w = img.shape[:2]
    cols_top = [None] * w
    cols_bot = [-1] * w
    for pcx, pcy, pr in puffs:
        for x in range(max(0, int(pcx - pr)), min(w, int(pcx + pr) + 1)):
            dx = x - pcx
            dy = math.sqrt(max(0.0, pr * pr - dx * dx))
            t = int(pcy - dy)
            b = int(pcy + dy)
            cols_top[x] = t if cols_top[x] is None else min(cols_top[x], t)
            cols_bot[x] = max(cols_bot[x], b)

    # Extremos globales para normalizar frac_x
    x_min = min(x for x in range(w) if cols_top[x] is not None)
    x_max = max(x for x in range(w) if cols_top[x] is not None)
    total_w = max(1.0, float(x_max - x_min))

    for x in range(w):
        if cols_top[x] is None:
            continue
        span = max(1.0, cols_bot[x] - cols_top[x])
        for y in range(cols_top[x], cols_bot[x] + 1):
            dentro = False
            for pcx, pcy, pr in puffs:
                if (x - pcx) ** 2 + (y - pcy) ** 2 <= pr * pr:
                    dentro = True
                    break
            if not dentro:
                continue

            # ── Borde inferior: SIEMPRE sombra ──
            edge_dist = cols_bot[x] - y
            if edge_dist < 1.5:
                img[y, x] = _opaque(tones["sombra"])
                continue

            # ── Mezcla diagonal (misma lógica que _tone) ──
            frac_x = (x - x_min) / total_w       # 0 izq .. 1 der
            frac_y = (y - cols_top[x]) / span     # 0 arriba .. 1 abajo
            shadow = 0.45 * frac_x + 0.55 * frac_y

            if shadow < 0.30:
                img[y, x] = _opaque(tones["luz"])
            elif shadow < 0.66:
                img[y, x] = _opaque(tones["medio"])
            else:
                img[y, x] = _opaque(tones["sombra"])


def _tronco(img, cx: float, y0: int, y1: int, halfw: float, tones: dict,
            base=None) -> None:
    """Tronco corto y estrecho: luz a la izquierda, medio centro, sombra a la
    derecha. `base` reemplaza el tono del centro (abedul blanco)."""
    for y in range(y0, y1 + 1):
        for x in range(int(math.ceil(cx - halfw)), int(cx + halfw) + 1):
            if x < 0 or x >= img.shape[1] or y < 0 or y >= img.shape[0]:
                continue
            if x < cx:
                img[y, x] = _opaque(tones["luz"])
            elif x > cx:
                img[y, x] = _opaque(tones["sombra"])
            else:
                img[y, x] = _opaque(base if base else tones["medio"])


def _sombra(img, cx: float, cy: float, rx: float, ry: float) -> None:
    """Elipse de sombra de contacto, semitransparente (nunca base sólida).
    Solo rellena píxeles aún transparentes: queda BAJO el objeto, nunca por
    encima (no pisa tronco ni copa). Dos anillos: núcleo más oscuro y borde.
    Desactivada por decisión del usuario (la cubre SunShadows)."""
    if not CON_SOMBRA_COCIDA:
        return
    h_img, w = img.shape[:2]
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if x < 0 or x >= w or y < 0 or y >= h_img:
                continue
            if img[y, x, 3] != 0:
                continue
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                a = 70 if d < 0.70 else 42
                img[y, x] = (0, 0, 0, a)


def _contorno(img) -> None:
    """Contorno #000000 puro, 1 px, POR DEBAJO de los rellenos: los píxeles
    opacos del borde de la silueta quedan negros."""
    h_img, w = img.shape[:2]
    opaca = img[..., 3] == 0xFF
    for y in range(h_img):
        for x in range(w):
            if not opaca[y, x]:
                continue
            if x == 0 or x == w - 1 or y == 0 or y == h_img - 1:
                img[y, x] = NEGRO
                continue
            if (not opaca[y - 1, x] or not opaca[y + 1, x]
                    or not opaca[y, x - 1] or not opaca[y, x + 1]
                    or not opaca[y - 1, x - 1] or not opaca[y - 1, x + 1]
                    or not opaca[y + 1, x - 1] or not opaca[y + 1, x + 1]):
                img[y, x] = NEGRO


def _imagen(np_img):
    from PIL import Image as _I
    return _I.fromarray(np_img, "RGBA")


# ── D2: helpers de detalle fino ─────────────────────────────────────────

def _brillo_copa(img, cx, layers, env, tono_brillo, semilla=101, densidad=10):
    """Puntos de brillo en la zona iluminada (arriba-izquierda).
    Solo en píxeles que caerían en la zona luz (shadow < 0.32),
    nunca en el borde festoneado."""
    h_img, w = img.shape[:2]
    for y in range(h_img):
        for x in range(w):
            if img[y, x, 3] != 0xFF:
                continue
            if not env(x, y):
                continue
            lay = _band_owner(x, y, cx, layers)
            if lay is None:
                continue
            bot = _scallop(x, cx, lay)
            cima = _cima_hilera(x, cx, lay)
            span = max(1.0, bot - cima)
            hw = max(1.0, lay["halfw"])
            # Saltar borde festoneado
            if bot - y < 1.5:
                continue
            # Misma lógica de sombra que _tone
            frac_x = (x - (cx - hw)) / (2.0 * hw)
            frac_y = (y - cima) / span
            shadow = 0.45 * frac_x + 0.55 * frac_y
            if shadow > 0.30:   # solo en la zona luz
                continue
            if h(x, y, semilla) < densidad:
                img[y, x] = _opaque(tono_brillo)


def _veta_tronco(img, cx, y0, y1, halfw, tono_brillo):
    """Vetas verticales sutiles en el tronco (hash determinista).
    Solo en el lado iluminado y centro; el lado en sombra queda intacto."""
    for y in range(y0, y1 + 1):
        for x in range(int(cx - halfw) + 1, int(cx + halfw)):
            if x < 0 or x >= img.shape[1] or y < 0 or y >= img.shape[0]:
                continue
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 77) < 22:
                if x < cx:
                    img[y, x] = _opaque(tono_brillo)
                elif x == int(cx):
                    img[y, x] = _opaque(tono_brillo)


def _hojas_borde(img, cx, layers, env, tono, semilla=201):
    """Pequeños racimos de un tono en el borde inferior de la copa
    (hojas sueltas, pétalos). Mínimo 2×2 para sobrevivir al contorno."""
    h_img, w = img.shape[:2]
    colocados = set()
    # Recorremos de abajo hacia arriba para encontrar el borde inferior
    for y in range(h_img - 1, -1, -1):
        for x in range(w):
            if img[y, x, 3] != 0xFF:
                continue
            if not env(x, y):
                continue
            # ¿Es un píxel de borde inferior? (abajo es transparente o fuera)
            if y + 1 < h_img and img[y + 1, x, 3] == 0xFF:
                continue
            if y + 1 >= h_img:
                continue
            lay = _band_owner(x, y, cx, layers)
            if lay is None:
                continue
            # Solo en los valles de los festones (centro de los arcos)
            dx = x - cx
            fase = (dx / lay["arcw"]) % 1.0
            if not (0.3 < fase < 0.7):
                continue
            if h(x, y, semilla) < 30 and (x // 2, y // 2) not in colocados:
                # Bloque 2×2 centrado aquí (hacia arriba para no salir)
                for dy in range(-1, 1):
                    for dx2 in range(2):
                        xx, yy = x + dx2, y + dy
                        if 0 <= xx < w and 0 <= yy < h_img and env(xx, yy):
                            img[yy, xx] = _opaque(tono)
                colocados.add((x // 2, y // 2))


def _petalos_copa(img, cx, layers, env, tono_petalo, semilla=301):
    """Pétalos/bloques decorativos de 2×2 dentro de la copa (cerezo).
    Incrustados en la masa opaca para que el contorno no se los coma."""
    h_img, w = img.shape[:2]
    colocados = set()
    for y in range(h_img):
        for x in range(w):
            if img[y, x, 3] != 0xFF:
                continue
            if not env(x, y):
                continue
            lay = _band_owner(x, y, cx, layers)
            if lay is None:
                continue
            bot = _scallop(x, cx, lay)
            frac = (y - lay["top"]) / max(1.0, bot - lay["top"])
            # Solo en la zona medio-luz (ni borde ni sombra)
            if frac < 0.1 or frac > 0.55:
                continue
            if h(x, y, semilla) < 6 and (x // 2, y // 2) not in colocados:
                ok = True
                for dy in range(2):
                    for dx in range(2):
                        xx, yy = x + dx, y + dy
                        if xx >= w or yy >= h_img or img[yy, xx, 3] != 0xFF or not env(xx, yy):
                            ok = False
                if ok:
                    for dy in range(2):
                        for dx in range(2):
                            xx, yy = x + dx, y + dy
                            img[yy, xx] = _opaque(tono_petalo)
                    colocados.add((x // 2, y // 2))


def _motas_brillo(img, tono_brillo, semilla=401, densidad=8):
    """Motas de brillo dispersas sobre la superficie ya pintada (piedra, madera)."""
    h_img, w = img.shape[:2]
    for y in range(h_img):
        for x in range(w):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, semilla) < densidad:
                img[y, x] = _opaque(tono_brillo)


def _grietas(img, tono_oscuro, semilla=501):
    """Líneas de grieta sutiles (1 px) sobre superficie de roca."""
    h_img, w = img.shape[:2]
    for y in range(1, h_img - 1):
        for x in range(1, w - 1):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, semilla) < 4:
                # Trazo en diagonal: marca la grieta en 2-3 px consecutivos
                for d in range(-1, 2):
                    xx, yy = x + d, y + d
                    if 0 <= xx < w and 0 <= yy < h_img and img[yy, xx, 3] == 0xFF:
                        img[yy, xx] = _opaque(tono_oscuro)


# ── Árboles de 64×64 ────────────────────────────────────────────────────
# Copas en hileras festoneadas apiladas. Cada especie tiene envolvente y
# hileras propias: se diferencian por SILUETA, no por color.

def gen_tree_oak():
    img = _canvas(64, 64)
    cx = 32.0
    # Cúpula ANCHA, más ancha que alta, con 2-3 bultos redondos arriba (nube
    # gorda). Pomos superpuestos: borde festoneado e irregular, jamás una
    # cúpula lisa ni rayas. Tronco corto y grueso.
    puffs = [
        (32, 29, 17), (18, 33, 13), (46, 33, 13),
        (8, 39, 8), (56, 39, 8),
        (26, 21, 8), (38, 21, 8),
        (32, 16, 7),
    ]
    _pintar_puffs(img, cx, puffs, FOLLAJE)
    # Brillo en la zona iluminada (arriba-izquierda, cerca del foco)
    for y in range(64):
        for x in range(64):
            if img[y, x, 3] == 0xFF and x < 24 and y < 38 and h(x, y, 101) < 10:
                img[y, x] = _opaque(FOLLAJE["brillo"])
    # Hojitas sueltas en el borde inferior festoneado (2×2 dentro de la masa)
    for (px, py) in [(12, 42), (24, 44), (42, 43), (52, 42), (34, 45)]:
        if img[py, px, 3] == 0xFF:
            img[py, px] = _opaque(FOLLAJE["brillo"])
    _tronco(img, cx, 45, 55, 3.5, MADERA)
    _veta_tronco(img, cx, 45, 55, 3.5, MADERA["brillo"])
    _sombra(img, cx, cy=58.0, rx=16, ry=3.5)
    _contorno(img)
    return _imagen(img)


def gen_tree_pine():
    img = _canvas(64, 64)
    cx = 32.0
    layers = [
        {"top": 8,  "base": 18, "halfw": 5,  "arcw": 5, "amp": 2},
        {"top": 16, "base": 28, "halfw": 10, "arcw": 6, "amp": 2},
        {"top": 25, "base": 38, "halfw": 15, "arcw": 7, "amp": 2},
        {"top": 34, "base": 46, "halfw": 20, "arcw": 8, "amp": 3},
        {"top": 42, "base": 52, "halfw": 23, "arcw": 9, "amp": 3},
    ]
    env = _tri_env(cx, y_top=6, y_bot=52, rx_max=23)
    _pintar_copa(img, cx, layers, FOLLAJE, env)
    _brillo_copa(img, cx, layers, env, FOLLAJE["brillo"], semilla=102, densidad=10)
    _hojas_borde(img, cx, layers, env, FOLLAJE["brillo"], semilla=202)
    _tronco(img, cx, 51, 56, 2.0, MADERA)
    _veta_tronco(img, cx, 51, 56, 2, MADERA["brillo"])
    _sombra(img, cx, cy=58.0, rx=12, ry=3.5)
    _contorno(img)
    return _imagen(img)


def gen_tree_birch():
    img = _canvas(64, 64)
    cx = 32.0
    # Copa ESTRECHA y ALTA (casi óvalo vertical), pequeña respecto al tronco.
    # Lo que identifica al abedul es el TRONCO: largo, blanco, con marcas
    # negras horizontales cortas. Que se vea bastante tronco.
    layers = [
        {"top": 7,  "topb": 2, "base": 15, "halfw": 5,  "arcw": 8, "amp": 3},
        {"top": 12, "base": 24, "halfw": 7,  "arcw": 9,  "amp": 3},
        {"top": 19, "base": 33, "halfw": 8,  "arcw": 10, "amp": 3},
    ]
    env = _dome_env(cx, y_top=6, y_bot=34, rx_max=9)
    _pintar_copa(img, cx, layers, FOLLAJE, env)
    _brillo_copa(img, cx, layers, env, FOLLAJE["brillo"], semilla=103, densidad=10)
    _hojas_borde(img, cx, layers, env, FOLLAJE["brillo"], semilla=203)
    # Tronco largo y delgado: corteza blanca con marcas horizontales CORTAS.
    for y in range(26, 57):
        for x in range(29, 36):
            img[y, x] = _opaque(BLANCO["medio"])
    # Marcas negras horizontales de largos variados (no cruzan todo el tronco)
    marcas = [
        (27, 3), (32, 4), (34, 2), (36, 3),   # arriba: cortas y medias
        (41, 4), (44, 2), (47, 5), (49, 2),   # medio: largas y cortas
        (52, 4), (55, 3),                      # abajo
    ]
    for my, largo in marcas:
        # Centradas en el tronco, variable en largo
        x0 = max(30, 33 - largo // 2)
        for x in range(x0, min(35, x0 + largo)):
            if 0 <= my < 57 and img[my, x, 3] == 0xFF:
                img[my, x] = _opaque(MADERA["sombra"])
    # Veta sutil en la corteza (lado iluminado)
    for y in range(26, 57):
        for x in range(29, 36):
            if img[y, x, 3] == 0xFF and h(x, y, 78) < 12 and x <= cx + 1:
                img[y, x] = _opaque(BLANCO["sombra"])
    _sombra(img, cx, cy=58.0, rx=10, ry=3.0)
    _contorno(img)
    return _imagen(img)


def gen_tree_cherry():
    img = _canvas(64, 64)
    cx = 32.0
    # Redonda, rosa, con borde irregular y esponjoso: pomos superpuestos que
    # dejan entrantes y salientes (nunca una cúpula lisa). Pétalos cayendo.
    puffs = [
        (32, 30, 17), (18, 26, 10), (46, 26, 10),
        (20, 38, 9), (44, 38, 9),
        (32, 18, 7), (14, 34, 7), (50, 34, 7),
    ]
    _pintar_puffs(img, cx, puffs, FOLLAJE_ROSA)
    # Esponjado: brillo rosa claro cerca del foco (arriba-izquierda)
    for y in range(64):
        for x in range(64):
            if img[y, x, 3] == 0xFF and x < 26 and y < 42 and h(x, y, 104) < 10:
                img[y, x] = _opaque(FOLLAJE_ROSA["brillo"])
    # Pétalos cayendo: gotas de 3×3 fuera de la copa (parte de la silueta).
    # Mínimo 3×3: con contorno de 1 px, un detalle suelto menor muere entero.
    for (px, py) in [(19, 51), (26, 54), (43, 50)]:
        for dy in range(3):
            for dx in range(3):
                if 0 <= px + dx < 64 and 0 <= py + dy < 64:
                    img[py + dy, px + dx] = _opaque(FOLLAJE_ROSA["luz"])
    _tronco(img, cx, 46, 55, 2.5, MADERA)
    _veta_tronco(img, cx, 46, 55, 3, MADERA["brillo"])
    _sombra(img, cx, cy=58.0, rx=13, ry=3.5)
    _contorno(img)
    return _imagen(img)


def gen_tree_willow():
    img = _canvas(64, 64)
    cx = 32.0
    # Copa BAJA y ancha, y lo que lo identifica: MECHONES que cuelgan por los
    # lados por debajo de la línea de la copa (tiras verticales de 8-10 px).
    layers = [
        {"top": 18, "topb": 2, "base": 28, "halfw": 16, "arcw": 11, "amp": 3},
        {"top": 25, "base": 38, "halfw": 23, "arcw": 13, "amp": 3},
        {"top": 32, "base": 45, "halfw": 27, "arcw": 15, "amp": 3, "sag_edge": 0.6},
    ]

    def extra(x, y):
        return 0.35 * max(0.0, y - 40.0)

    env = _dome_env(cx, y_top=16, y_bot=44, rx_max=28, extra=extra)
    _pintar_copa(img, cx, layers, FOLLAJE, env)
    _brillo_copa(img, cx, layers, env, FOLLAJE["brillo"], semilla=105, densidad=10)
    # Mechones colgantes: tiras verticales gruesas (3 px) en los lados,
    # desde el borde de la copa hacia abajo. Se estrechan hacia la punta.
    # Con 3 px de ancho sobreviven al contorno (núcleo de color visible).
    # Color de follaje, NO negro: medio arriba, sombra abajo.
    mechones = [
        (10, 46, 11, 1), (17, 47, 10, 0), (23, 48, 8, 1),
        (40, 48, 8, -1), (47, 47, 10, 0), (54, 46, 11, -1),
    ]
    for (sx, sy, ln, drift) in mechones:
        for i in range(ln):
            yy = sy + i
            x0 = sx + (i // 3) * drift
            # 3 px de ancho para que el contorno deje núcleo de color
            ancho = 3 if i < ln - 2 else 2
            # Degradado: medio arriba, sombra abajo
            if i < 3:
                tono = FOLLAJE["medio"]
            elif i < 6:
                tono = FOLLAJE["sombra"]
            else:
                tono = FOLLAJE["sombra"]
            for xx in range(x0, x0 + ancho):
                if 0 <= xx < 64 and 0 <= yy < 64:
                    img[yy, xx] = _opaque(tono)
    _tronco(img, cx, 50, 57, 2.5, MADERA)
    _veta_tronco(img, cx, 50, 57, 3, MADERA["brillo"])
    _sombra(img, cx, cy=59.0, rx=16, ry=3.5)
    _contorno(img)
    return _imagen(img)


def gen_tree_bush_big():
    img = _canvas(64, 64)
    cx = 32.0
    # SIN tronco: masa irregular, más ancha abajo que arriba, con el contorno
    # lleno de entrantes y salientes. Pomos superpuestos, sin cúpula lisa.
    puffs = [
        (32, 32, 14), (18, 36, 11), (46, 36, 11),
        (8, 40, 7), (56, 40, 7),
        (26, 27, 7), (38, 28, 7),
    ]
    _pintar_puffs(img, cx, puffs, FOLLAJE)
    for y in range(64):
        for x in range(64):
            if img[y, x, 3] == 0xFF and x < 26 and y < 42 and h(x, y, 106) < 10:
                img[y, x] = _opaque(FOLLAJE["brillo"])
    _sombra(img, cx, cy=57.0, rx=16, ry=3.5)
    _contorno(img)
    return _imagen(img)


# ── Pequeños de 32×32 ───────────────────────────────────────────────────

def gen_bush():
    img = _canvas(32, 32)
    cx = 16.0
    # Masa pequeña e irregular: unos pomos con entrantes (mordiscos) en el
    # contorno, nada de media cúpula perfecta.
    puffs = [
        (16, 17, 8), (10, 19, 5.5), (22, 19, 5.5),
        (14, 14, 3.5), (18, 15, 3.5),
    ]
    _pintar_puffs(img, cx, puffs, FOLLAJE)
    for y in range(32):
        for x in range(32):
            if img[y, x, 3] == 0xFF and x < 12 and y < 22 and h(x, y, 107) < 10:
                img[y, x] = _opaque(FOLLAJE["brillo"])
    _sombra(img, cx, cy=27.0, rx=9, ry=2.5)
    _contorno(img)
    return _imagen(img)


def gen_flower_bush():
    img = _canvas(32, 32)
    cx = 16.0
    # El MISMO cuerpo que `bush` + florecillas que asoman por el borde.
    puffs = [
        (16, 17, 8), (10, 19, 5.5), (22, 19, 5.5),
        (14, 14, 3.5), (18, 15, 3.5),
    ]
    _pintar_puffs(img, cx, puffs, FOLLAJE)
    # Florecillas incrustadas 2×2 en la copa (color rosa, no cambian silueta)
    colocadas = set()
    for y in range(32):
        for x in range(32):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 401) < 8 and (x // 2, y // 2) not in colocadas:
                tono = FOLLAJE_ROSA["luz"] if h(x, y, 402) < 50 else FOLLAJE_ROSA["medio"]
                ok = True
                for dy in range(2):
                    for dx in range(2):
                        xx, yy = x + dx, y + dy
                        if xx >= 32 or yy >= 32 or img[yy, xx, 3] != 0xFF:
                            ok = False
                if ok:
                    for dy in range(2):
                        for dx in range(2):
                            img[y + dy, x + dx] = _opaque(tono)
                    colocadas.add((x // 2, y // 2))
    # Florecillas que ASOMAN por el borde del arbusto (arriba y lados): pomos
    # de 3×3 ENGANCHADOS al cuerpo (fila de abajo dentro de la masa) para que
    # el contorno deje núcleo de color. Cambian la silueta: se leen como flores.
    for (fx, fy) in [(11, 9), (16, 8), (21, 9), (6, 14), (25, 14),
                     (6, 17), (26, 17), (12, 7), (16, 6), (20, 7)]:
        enganchado = False
        for dx in range(3):
            if 0 <= fx + dx < 32 and 0 <= fy + 3 < 32 and img[fy + 3, fx + dx, 3] == 0xFF:
                enganchado = True
        if not enganchado:
            continue
        for dy in range(3):
            for dx in range(3):
                xx, yy = fx + dx, fy + dy
                if 0 <= xx < 32 and 0 <= yy < 32:
                    img[yy, xx] = _opaque(FOLLAJE_ROSA["medio"])
        if 0 <= fx + 1 < 32 and 0 <= fy + 1 < 32:
            img[fy + 1, fx + 1] = _opaque(FOLLAJE_ROSA["luz"])
    _sombra(img, cx, cy=27.0, rx=10, ry=2.5)
    _contorno(img)
    return _imagen(img)


def gen_decoration_apple_tree():
    img = _canvas(32, 32)
    cx = 16.0
    layers = [
        {"top": 4,  "base": 11, "halfw": 6,  "arcw": 5, "amp": 1},
        {"top": 9,  "base": 18, "halfw": 10, "arcw": 7, "amp": 2},
    ]
    env = _dome_env(cx, y_top=4, y_bot=19, rx_max=10)
    _pintar_copa(img, cx, layers, FOLLAJE, env)
    _brillo_copa(img, cx, layers, env, FOLLAJE["brillo"], semilla=109, densidad=10)
    _tronco(img, cx, 18, 25, 2.0, MADERA)
    _veta_tronco(img, cx, 18, 25, 2, MADERA["brillo"])
    # Frutos: manzanas rojas de 3×3 incrustadas en la copa, con brillo.
    colocadas = set()
    for (px, py) in [(8, 12), (16, 14), (13, 16), (18, 11), (10, 15)]:
        if (px // 3, py // 3) in colocadas:
            continue
        ok = True
        for dy in range(3):
            for dx in range(3):
                if px + dx >= 32 or py + dy >= 32 or img[py + dy, px + dx, 3] != 0xFF:
                    ok = False
        if not ok:
            continue
        for dy in range(3):
            for dx in range(3):
                img[py + dy, px + dx] = _opaque(ROJO["medio"])
        img[py, px] = _opaque(ROJO["luz"])
        colocadas.add((px // 3, py // 3))
    _sombra(img, cx, cy=28.0, rx=8, ry=2.5)
    _contorno(img)
    return _imagen(img)


def gen_biome_rock():
    img = _canvas(48, 48)
    cx = 24.0
    # Roca irregular: forma angulosa con caras planas de distinto tamaño,
    # algún saliente y el contorno quebrado. Nada de pentágono simétrico.
    # Vértices en sentido horario desde arriba-centro.
    pts = [
        (26, 6),                         # cima (ligeramente a la derecha)
        (32, 10), (35, 16),              # hombro derecho con saliente
        (39, 23), (38, 28),              # flanco derecho
        (40, 34), (37, 39),              # base derecha
        (32, 42), (24, 43), (16, 42),    # base (ancha, irregular)
        (10, 39), (7, 34),               # base izquierda
        (5, 28), (6, 22),                # flanco izquierdo
        (8, 16), (12, 11), (18, 8),      # hombro izquierdo
    ]

    def en_roca(x, y):
        n = len(pts)
        dentro = False
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
                dentro = not dentro
            j = i
        return dentro

    for y in range(48):
        for x in range(48):
            if not en_roca(x, y):
                continue
            # Facetas múltiples: varias bandas verticales de distinto ancho
            # para simular caras planas de una roca real.
            if x < cx - 7:
                img[y, x] = _opaque(PIEDRA["luz"])       # cara izquierda (iluminada)
            elif x < cx - 2:
                img[y, x] = _opaque(PIEDRA["luz"])       # transición
            elif x < cx + 3:
                img[y, x] = _opaque(PIEDRA["medio"])     # cara central
            elif x < cx + 9:
                img[y, x] = _opaque(PIEDRA["sombra"])    # cara derecha (sombra)
            else:
                img[y, x] = _opaque(PIEDRA["sombra"])    # borde derecho

    # D2: grietas sutiles en diagonal
    _grietas(img, PIEDRA["sombra"], semilla=501)
    # D2: motas de brillo dispersas
    _motas_brillo(img, PIEDRA["brillo"], semilla=401, densidad=6)
    # D2: musgo discreto en la base (lado iluminado)
    for y in range(28, 43):
        for x in range(4, 44):
            if not en_roca(x, y):
                continue
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 701) < 10 and x < cx + 5:
                img[y, x] = _opaque(FOLLAJE["medio"])
    _sombra(img, cx, cy=44.0, rx=18, ry=3.0)
    _contorno(img)
    return _imagen(img)


def gen_decoration_stone_cairn():
    img = _canvas(32, 32)
    # Mojón de 3 piedras apiladas, cada una con su propia forma y contorno.
    # La más grande abajo, la más pequeña arriba. Ligeramente descentradas
    # para que se lean como piedras sueltas apiladas, no como un bulto.
    # Cada piedra se contornea ANTES de dibujar la siguiente para que el
    # contorno negro SEPARE unas de otras.
    piedras = [
        # Piedra base: grande, ovalada y ancha, centrada
        {"cx": 16, "cy": 25, "rx": 11.5, "ry": 4.5, "t": "medio"},
        # Piedra media: más pequeña, ladeada a la derecha
        {"cx": 17, "cy": 18, "rx": 8.0, "ry": 3.5, "t": "luz"},
        # Piedra superior: la más pequeña, centrada arriba
        {"cx": 15, "cy": 11, "rx": 5.5, "ry": 3.0, "t": "medio"},
    ]
    for p in piedras:
        for y in range(int(p["cy"] - p["ry"]) - 2, int(p["cy"] + p["ry"]) + 3):
            for x in range(int(p["cx"] - p["rx"]) - 2, int(p["cx"] + p["rx"]) + 3):
                if x < 0 or x >= 32 or y < 0 or y >= 32:
                    continue
                d = ((x - p["cx"]) / p["rx"]) ** 2 + ((y - p["cy"]) / p["ry"]) ** 2
                if d <= 1.05:  # ligero sobre-relleno para solapar con la de abajo
                    # Iluminación: izquierda luz, centro medio, derecha sombra
                    if x <= p["cx"] - 2:
                        img[y, x] = _opaque(PIEDRA["luz"])
                    elif x >= p["cx"] + 2:
                        img[y, x] = _opaque(PIEDRA["sombra"])
                    else:
                        img[y, x] = _opaque(PIEDRA[p["t"]])
        _contorno(img)  # contornea esta piedra antes de dibujar la siguiente

    # D2: grietas en las piedras grandes (solo base y media, no la pequeña)
    for y in range(18, 31):
        for x in range(4, 29):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 502) < 5:
                # Grieta corta horizontal/diagonal
                for dx in range(-1, 2):
                    xx = x + dx
                    if 0 <= xx < 32 and img[y, xx, 3] == 0xFF:
                        img[y, xx] = _opaque(PIEDRA["sombra"])

    # D2: motas de brillo sobre el lado iluminado de las piedras
    _motas_brillo(img, PIEDRA["brillo"], semilla=402, densidad=8)

    _sombra(img, 16.0, cy=32.0, rx=13, ry=3.0)
    _contorno(img)  # contorno exterior final
    return _imagen(img)


def gen_mushroom_red():
    img = _canvas(32, 32)
    cx = 16.0
    # Seta: sombrero ancho sobre un pie corto. Silueta: cúpula + pie.
    layers = [
        {"top": 6,  "base": 13, "halfw": 9,  "arcw": 6, "amp": 1},
        {"top": 10, "base": 19, "halfw": 11, "arcw": 7, "amp": 2},
    ]
    env = _dome_env(cx, y_top=6, y_bot=19, rx_max=11)
    _pintar_copa(img, cx, layers, ROJO, env)
    # Borde inferior del sombrero en sombra (la umbra).
    for x in range(5, 28):
        for y in range(18, 21):
            if img[y, x, 3] == 0xFF:
                img[y, x] = _opaque(ROJO["sombra"])
    # Lunares blancos 2×2 sobre el sombrero rojo (incrustados, no en el borde).
    colocados = set()
    for y in range(6, 17):
        for x in range(6, 27):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 501) < 8 and (x // 2, y // 2) not in colocados:
                ok = True
                for dy in range(2):
                    for dx in range(2):
                        xx, yy = x + dx, y + dy
                        if xx >= 32 or yy >= 32 or img[yy, xx, 3] != 0xFF:
                            ok = False
                # No colocar lunares en el borde del sombrero
                if ok:
                    for dy in range(-1, 2):
                        for dx in range(-1, 2):
                            nx, ny = x + dx + 1, y + dy + 1
                            if 0 <= nx < 32 and 0 <= ny < 32 and img[ny, nx, 3] == 0:
                                ok = False
                if ok:
                    for dy in range(2):
                        for dx in range(2):
                            img[y + dy, x + dx] = _opaque(BLANCO["medio"])
                    colocados.add((x // 2, y // 2))
    # D2: lunares de brillo rojo claro sobre el lado iluminado del sombrero
    for y in range(7, 18):
        for x in range(7, 25):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 503) < 6 and x < cx:
                img[y, x] = _opaque(ROJO["brillo"])
    # Pie corto y claro.
    for y in range(20, 27):
        for x in range(14, 19):
            img[y, x] = _opaque(ARENA["luz"])
    _sombra(img, cx, cy=28.0, rx=8, ry=2.5)
    _contorno(img)
    return _imagen(img)


def gen_hay_bale():
    img = _canvas(32, 32)
    cx = 16.0
    # Bala: cápsula horizontal (redondeada). Luces arriba, sombra abajo.
    y0, y1 = 11, 24
    x0, x1 = 4, 27
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            # Esquinas redondeadas
            if (x < x0 + 2 and y < y0 + 2 and (x - x0) + (y - y0) < 3):
                continue
            if (x > x1 - 2 and y < y0 + 2 and (x1 - x) + (y - y0) < 3):
                continue
            if (x < x0 + 2 and y > y1 - 2 and (x - x0) + (y1 - y) < 3):
                continue
            if (x > x1 - 2 and y > y1 - 2 and (x1 - x) + (y1 - y) < 3):
                continue
            if x <= cx - 3:
                img[y, x] = _opaque(PAJA["luz"])
            elif x >= cx + 3:
                img[y, x] = _opaque(PAJA["sombra"])
            else:
                img[y, x] = _opaque(PAJA["medio"])
    # Cinchas: dos bandas verticales oscuras de paja (identidad de la bala).
    for y in range(y0 + 1, y1):
        img[y, 11] = _opaque(PAJA["sombra"])
        img[y, 12] = _opaque(PAJA["sombra"])
        img[y, 21] = _opaque(PAJA["sombra"])
        img[y, 22] = _opaque(PAJA["sombra"])
    # Fibras de brillo sobre la paja: hebras horizontales sutiles
    for y in range(y0 + 1, y1):
        for x in range(x0 + 1, x1):
            if img[y, x, 3] != 0xFF:
                continue
            if x in (11, 12, 21, 22):
                continue  # no pisar las cinchas
            if h(x, y, 601) < 18:
                img[y, x] = _opaque(PAJA["brillo"])
    # Refuerzo de sombra en la base para el volumen
    for x in range(x0 + 1, x1):
        if img[y1 - 1, x, 3] == 0xFF:
            img[y1 - 1, x] = _opaque(PAJA["sombra"])
        if img[y1, x, 3] == 0xFF:
            img[y1, x] = _opaque(PAJA["sombra"])
    _sombra(img, cx, cy=28.0, rx=11, ry=2.5)
    _contorno(img)
    return _imagen(img)


def gen_decoration_fallen_log():
    img = _canvas(32, 16)
    cx = 16.0
    y0, y1 = 3, 12
    x0, x1 = 2, 29
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x < x0 + 2 and (y < y0 + 2 or y > y1 - 2)
                    and ((x - x0) + min(y - y0, y1 - y)) < 3):
                continue
            if (x > x1 - 2 and (y < y0 + 2 or y > y1 - 2)
                    and ((x1 - x) + min(y - y0, y1 - y)) < 3):
                continue
            if x <= cx - 3:
                img[y, x] = _opaque(MADERA["luz"])
            elif x >= cx + 3:
                img[y, x] = _opaque(MADERA["sombra"])
            else:
                img[y, x] = _opaque(MADERA["medio"])
    # Corteza: grietas y vetas de brillo
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 801) < 12:
                img[y, x] = _opaque(MADERA["brillo"])
            if h(x, y, 802) < 5 and x < cx:
                img[y, x] = _opaque(MADERA["sombra"])
    # Cara del corte (izquierda): círculo con anillos de TIERRA.
    ecy, ecx, r = 8, 6, 4
    for y in range(ecy - r, ecy + r + 1):
        for x in range(ecx - r, ecx + r + 1):
            d = (x - ecx) ** 2 + (y - ecy) ** 2
            if r * r - 2 <= d <= r * r:
                img[y, x] = _opaque(MADERA["sombra"])
            elif d <= (r - 1) * (r - 1):
                if abs(x - ecx) + abs(y - ecy) <= 3:
                    img[y, x] = _opaque(TIERRA["luz"])
                else:
                    img[y, x] = _opaque(TIERRA["medio"])
            # Anillos internos con TIERRA y PAJA
            if d <= (r - 1.5) ** 2 and d > (r - 2.5) ** 2 and img[y, x, 3] == 0xFF:
                img[y, x] = _opaque(TIERRA["sombra"])
            if d <= (r - 3) ** 2 and img[y, x, 3] == 0:
                img[y, x] = _opaque(TIERRA["luz"])
    # Punto central de médula (PAJA)
    if img[ecy, ecx - 1, 3] == 0xFF:
        img[ecy, ecx - 1] = _opaque(PAJA["medio"])
        img[ecy, ecx] = _opaque(PAJA["luz"])
    _sombra(img, cx, cy=13.5, rx=14, ry=1.8)
    _contorno(img)
    return _imagen(img)


def gen_decoration_log_stump():
    img = _canvas(32, 32)
    cx = cy = 16.0
    rmax = 13
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - cx, y - cy)
            if d > rmax:
                continue
            # Corteza (anillo exterior)
            if d > rmax - 2:
                img[y, x] = _opaque(MADERA["sombra"])
            else:
                # Anillos concéntricos de la madera
                anillo = int(d) % 3
                if anillo == 0:
                    img[y, x] = _opaque(TIERRA["luz"])
                elif anillo == 1:
                    img[y, x] = _opaque(TIERRA["medio"])
                else:
                    img[y, x] = _opaque(TIERRA["sombra"])
            # Luz arriba-izquierda en la corteza
            if d > rmax - 2 and x < cx and y < cy:
                img[y, x] = _opaque(MADERA["medio"])
    # D2: brillo en la corteza (lado iluminado)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - cx, y - cy)
            if d > rmax - 2 and img[y, x, 3] == 0xFF and x < cx:
                if h(x, y, 901) < 20:
                    img[y, x] = _opaque(MADERA["brillo"])
    # D2: anillo interno de PAJA y punto central
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - cx, y - cy)
            if 3.0 < d < 4.5 and img[y, x, 3] == 0xFF:
                if h(x, y, 902) < 30:
                    img[y, x] = _opaque(PAJA["medio"])
            if d < 2.0 and img[y, x, 3] == 0xFF:
                img[y, x] = _opaque(TIERRA["brillo"])
    # D2: grietas radiales en la cara cortada
    for y in range(32):
        for x in range(32):
            if img[y, x, 3] != 0xFF:
                continue
            d = math.hypot(x - cx, y - cy)
            if d > 5 or d < 2:
                continue
            ang = math.atan2(y - cy, x - cx)
            if abs(math.sin(ang * 5)) < 0.3 and h(x, y, 903) < 20:
                img[y, x] = _opaque(TIERRA["sombra"])
    _sombra(img, cx, cy=28.0, rx=13, ry=2.5)
    _contorno(img)
    return _imagen(img)


def gen_decoration_grass_tuft():
    img = _canvas(16, 16)
    cx = 8.0
    # Mata compacta de briznas gruesas (2 px) que solapan: el interior queda
    # con núcleo de color tras el contorno. Puntas claras, base oscura.
    briznas = [
        (4, 8, 12), (5, 6, 12), (7, 5, 13), (9, 6, 12), (10, 8, 12),
        (6, 7, 13), (8, 7, 13),
    ]
    for bx, ty, by in briznas:
        for y in range(ty, by + 1):
            for dx in (0, 1):
                xx = bx + dx
                if 0 <= xx < 16 and 0 <= y < 16:
                    if y == ty:
                        img[y, xx] = _opaque(HIERBA["clara"])
                    elif y == by:
                        img[y, xx] = _opaque(HIERBA["oscura"])
                    else:
                        img[y, xx] = _opaque(HIERBA["base"])
                    # Variación dentro de la brizna: alternancia clara/base
                    if ty < y < by and h(xx, y, 1101) < 30:
                        img[y, xx] = _opaque(HIERBA["clara"])
    # D2: segunda capa de briznas cortas (variedad de alturas, tono base)
    briznas_cortas = [
        (5, 9, 12), (8, 8, 12), (3, 10, 13), (11, 9, 13),
    ]
    for bx, ty, by in briznas_cortas:
        for y in range(ty, by + 1):
            for dx in (0, 1):
                xx = bx + dx
                if 0 <= xx < 16 and 0 <= y < 16:
                    if img[y, xx, 3] == 0:  # no pisar briznas existentes
                        img[y, xx] = _opaque(HIERBA["base"])
    # D2: brillo extra en las puntas (hash determinista, tono claro)
    for y in range(16):
        for x in range(16):
            if img[y, x, 3] != 0xFF:
                continue
            if h(x, y, 1102) < 15 and y < 10:
                img[y, x] = _opaque(HIERBA["clara"])
    _sombra(img, cx, cy=14.0, rx=5, ry=1.5)
    _contorno(img)
    return _imagen(img)


def gen_tree_dead():
    img = _canvas(48, 48)
    cx = 24.0
    # Árbol seco: tronco retorcido + ramas desnudas (silueta esquelética).
    # Pincel cuadrado (estampa (2w+1)²): en diagonal el trazo perpendicular no
    # engrosa (la perpendicular de una diagonal es otra diagonal), y el
    # contorno de 8 vecinos se come cualquier cadena de 1 px. Con estampa
    # cuadrada el interior sobrevive al contorno.
    def rama(x0, y0, x1, y1, w=1):
        n = max(abs(x1 - x0), abs(y1 - y0)) or 1
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for by in range(-w, w + 1):
                for bx in range(-w, w + 1):
                    xx, yy = x + bx, y + by
                    if 0 <= xx < 48 and 0 <= yy < 48:
                        img[yy, xx] = _opaque(MADERA["medio"])

    rama(24, 42, 24, 20, w=2)                  # tronco (5 px)
    rama(24, 26, 14, 18)                       # rama izq
    rama(14, 18, 8, 15, w=0)
    rama(14, 18, 13, 11, w=0)
    rama(24, 23, 34, 16)                       # rama der
    rama(34, 16, 40, 13, w=0)
    rama(34, 16, 33, 9, w=0)
    rama(24, 21, 24, 12)                       # horquilla central
    rama(24, 20, 18, 10, w=0)
    rama(24, 20, 30, 10, w=0)
    # Iluminación global (luz arriba-izquierda): el lado izquierdo del árbol
    # queda en medio, el derecho en sombra. Los tonos sobreviven al contorno
    # porque viven en el interior de los trazos, no en sus bordes.
    for y in range(48):
        for x in range(48):
            if img[y, x, 3] == 0xFF and x > cx + 1:
                img[y, x] = _opaque(MADERA["sombra"])
    # D2: luz en las ramas gruesas del lado izquierdo
    for y in range(48):
        for x in range(48):
            if img[y, x, 3] != 0xFF:
                continue
            if x > cx + 1:
                continue  # ya está en sombra
            # Solo en zonas gruesas (interior de trazos)
            if h(x, y, 1001) < 25 and x <= cx:
                img[y, x] = _opaque(MADERA["luz"])
    # D2: nudillos (parches más claros en las uniones de ramas)
    nudillos = [(24, 23), (14, 18), (34, 16), (24, 20)]
    for nx, ny in nudillos:
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                xx, yy = nx + dx, ny + dy
                if 0 <= xx < 48 and 0 <= yy < 48 and img[yy, xx, 3] == 0xFF:
                    img[yy, xx] = _opaque(MADERA["luz"])
    _sombra(img, cx, cy=44.0, rx=9, ry=2.5)
    _contorno(img)
    return _imagen(img)


# ── Verificación ────────────────────────────────────────────────────────

def _colores_rampas() -> set:
    colores = set()
    for rampa in [FOLLAJE, FOLLAJE_ROSA, MADERA, PIEDRA, PAJA, TIERRA, ARENA,
                  BLANCO, ROJO]:
        colores.update(rampa.values())
    colores.add(HIERBA["base"])
    colores.add(HIERBA["oscura"])
    colores.add(HIERBA["clara"])
    return colores


def _hex(c) -> str:
    return "#{:02x}{:02x}{:02x}".format(c[0], c[1], c[2])


def verificar(directorio: str) -> dict:
    """Comprueba tamaño, paleta, % de borde en #000000, IoU entre hermanos
    del mismo tamaño y coherencia de la silueta."""
    import numpy as np

    PALETA = _colores_rampas()
    NEGRO_RGB = (0, 0, 0)

    res = {
        "tamaño": {}, "colores": {}, "fuera": {},
        "borde_negro": {}, "errores": [],
    }

    imgs = {}
    for nombre in NOMBRES:
        ruta = os.path.join(directorio, f"{nombre}.png")
        if not os.path.exists(ruta):
            res["errores"].append(f"Falta {ruta}")
            continue
        im = Image.open(ruta).convert("RGBA")
        arr = np.asarray(im, dtype=np.uint8)
        imgs[nombre] = arr
        w, h = im.size

        res["tamaño"][nombre] = f"{w}×{h}"
        if (w, h) != TAMANOS[nombre]:
            res["errores"].append(
                f"{nombre}: tamaño {w}×{h}, contrato duro {TAMANOS[nombre]}"
            )

        # Colores únicos (RGB) entre los píxeles visibles
        visibles = arr[arr[..., 3] > 0]
        unicos = set()
        fuera = []
        for c in visibles:
            rgb = (int(c[0]), int(c[1]), int(c[2]))
            unicos.add(rgb)
        for c in unicos:
            if c != NEGRO_RGB and c not in PALETA:
                fuera.append(_hex(c))
        res["colores"][nombre] = len(unicos)
        if fuera:
            res["fuera"][nombre] = fuera
            res["errores"].append(f"{nombre}: fuera de paleta {fuera}")
        else:
            res["fuera"][nombre] = "ninguno"

        # % de píxeles de borde (silueta opaca) en #000000 puro
        opaca = arr[..., 3] == 0xFF
        hh, ww = opaca.shape
        borde = 0
        negro = 0
        for y in range(hh):
            for x in range(ww):
                if not opaca[y, x]:
                    continue
                es_borde = False
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        ny, nx = y + dy, x + dx
                        if ny < 0 or ny >= hh or nx < 0 or nx >= ww:
                            es_borde = True
                            break
                        if not opaca[ny, nx]:
                            es_borde = True
                            break
                    if es_borde:
                        break
                if es_borde:
                    borde += 1
                    c = arr[y, x]
                    if c[0] == 0 and c[1] == 0 and c[2] == 0 and c[3] == 0xFF:
                        negro += 1
        pct = 100.0 * negro / borde if borde else 100.0
        res["borde_negro"][nombre] = round(pct, 1)
        if pct < 80.0:
            res["errores"].append(
                f"{nombre}: borde #000000 {pct:.1f}% < 80%"
            )

    # IoU de máscaras alfa entre hermanos del mismo tamaño (no consigo mismo).
    por_tamano = {}
    for nombre, arr in imgs.items():
        por_tamano.setdefault(TAMANOS[nombre], []).append(nombre)

    for tam, grupo in por_tamano.items():
        for i in range(len(grupo)):
            for j in range(i + 1, len(grupo)):
                a = imgs[grupo[i]][..., 3] > 128
                b = imgs[grupo[j]][..., 3] > 128
                inter = np.logical_and(a, b).sum()
                union = np.logical_or(a, b).sum()
                if union == 0:
                    continue
                iou = inter / union
                if iou > 0.90:
                    res["errores"].append(
                        f"IoU alfa {grupo[i]} vs {grupo[j]}: {iou:.2f} >= 0.90 — "
                        f"misma silueta"
                    )

    # Coincidencia de máscaras alfa normalizadas al MISMO ALTO (los seis de
    # copa). Ningún par por encima del 85 % de píxeles coincidentes.
    COPA = ["tree_oak", "tree_birch", "tree_pine", "tree_cherry",
            "tree_willow", "tree_bush_big"]
    res["coincidencia_alfa"] = {}
    for i in range(len(COPA)):
        for j in range(i + 1, len(COPA)):
            a = _mascara_alfa(imgs[COPA[i]])
            b = _mascara_alfa(imgs[COPA[j]])
            pct = _coincidencia_alfa(a, b)
            res["coincidencia_alfa"][f"{COPA[i]} vs {COPA[j]}"] = round(pct, 1)
            if pct >= 85.0:
                res["errores"].append(
                    f"Coincidencia alfa {COPA[i]} vs {COPA[j]}: {pct:.1f}% >= 85% "
                    f"— son el mismo árbol"
                )

    res["PASA"] = len(res["errores"]) == 0
    return res


def _mascara_alfa(arr):
    """Máscara alfa normalizada al MISMO ALTO (48) conservando la proporción."""
    import numpy as np
    a = arr[..., 3] > 128
    h, w = a.shape
    H = 48
    nw = max(1, round(w * H / h))
    im = Image.fromarray((a.astype(np.uint8)) * 255).resize((nw, H), Image.NEAREST)
    return np.asarray(im) > 0


def _coincidencia_alfa(a, b) -> float:
    """% de píxeles coincidentes entre dos máscaras alineadas por el centro X."""
    import numpy as np
    W = max(a.shape[1], b.shape[1])
    A = np.zeros((a.shape[0], W), dtype=bool)
    B = np.zeros((b.shape[0], W), dtype=bool)
    A[:, (W - a.shape[1]) // 2:(W - a.shape[1]) // 2 + a.shape[1]] = a
    B[:, (W - b.shape[1]) // 2:(W - b.shape[1]) // 2 + b.shape[1]] = b
    inter = np.logical_and(A, B).sum()
    union = np.logical_or(A, B).sum()
    if union == 0:
        return 0.0
    return 100.0 * inter / union


# ── main ────────────────────────────────────────────────────────────────

GENERADORES = {
    "tree_oak":               gen_tree_oak,
    "tree_birch":             gen_tree_birch,
    "tree_pine":              gen_tree_pine,
    "tree_cherry":            gen_tree_cherry,
    "tree_willow":            gen_tree_willow,
    "tree_bush_big":          gen_tree_bush_big,
    "decoration_apple_tree":  gen_decoration_apple_tree,
    "tree_dead":              gen_tree_dead,
    "flower_bush":            gen_flower_bush,
    "bush":                   gen_bush,
    "biome_rock":             gen_biome_rock,
    "decoration_stone_cairn": gen_decoration_stone_cairn,
    "mushroom_red":           gen_mushroom_red,
    "hay_bale":               gen_hay_bale,
    "decoration_fallen_log":  gen_decoration_fallen_log,
    "decoration_log_stump":   gen_decoration_log_stump,
    "decoration_grass_tuft":  gen_decoration_grass_tuft,
}


def main():
    ap = argparse.ArgumentParser(
        description="Generador de los 17 objetos de naturaleza — lote 2"
    )
    ap.add_argument("--salida", default="staging_arte/objetos",
                    help="Directorio de salida (default: staging_arte/objetos)")
    ap.add_argument("--solo-verificar", action="store_true")
    args = ap.parse_args()

    salida = os.path.abspath(args.salida)
    os.makedirs(salida, exist_ok=True)

    if not args.solo_verificar:
        for nombre, gen in GENERADORES.items():
            ruta = os.path.join(salida, f"{nombre}.png")
            gen().save(ruta, "PNG")
            print(f"  {nombre}.png → {ruta}")
        print(f"\n{len(GENERADORES)} objetos escritos en {salida}/")

    print("\n" + "=" * 60)
    print("VERIFICACIÓN")
    print("=" * 60)
    res = verificar(salida)

    for nombre in NOMBRES:
        if nombre not in res["tamaño"]:
            continue
        print(f"\n── {nombre} ──")
        print(f"  tamaño:       {res['tamaño'][nombre]}  (contrato {TAMANOS[nombre][0]}×{TAMANOS[nombre][1]})")
        print(f"  colores:      {res['colores'][nombre]}")
        print(f"  fuera paleta: {res['fuera'][nombre]}")
        print(f"  borde #000:   {res['borde_negro'][nombre]}%")

    print("\nCoincidencia alfa entre los seis de copa (mismo alto, umbral 85%):")
    for par, pct in res["coincidencia_alfa"].items():
        marca = "  OK" if pct < 85.0 else "  ⚠"
        print(f"  {par}: {pct:5.1f}%{marca}")

    print(f"\n{'PASA' if res['PASA'] else 'FALLA'}: {len(res['errores'])} error(es)")
    if res["errores"]:
        for e in res["errores"]:
            print(f"  ⚠ {e}")

    return 0 if res["PASA"] else 1


if __name__ == "__main__":
    sys.exit(main())
