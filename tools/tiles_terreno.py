#!/usr/bin/env python3
"""
Generador del lote 1: los 14 tiles de terreno (16×16) para Mystic Emporium.
Emite PNG a un directorio de staging — NUNCA a godot/art/.

Diseñador 1: silueta, estructura y tres tonos. Sin detalle fino.
Diseñador 2: textura agrupada (briznas en matas, terrones, ramilletes),
             cuarto tono de brillo, destellos en agua, espuma e
             irregularidad en orillas.
"""

import argparse
import math
import os
import sys

from PIL import Image

# ── Constantes ──────────────────────────────────────────────────────────

T = 16  # tamaño del tile en píxeles

# Las orillas N/S solo repiten en horizontal (a lo largo de la costa);
# las E/W solo en vertical. El resto repite en ambas direcciones.
CHEQUEO_COSTURA = {
    "shore_N": "h", "shore_S": "h",
    "shore_E": "v", "shore_W": "v",
}

# ── Paleta: todas las rampas del contrato_rediseno.json ─────────────────

HIERBA = {
    "base":   (0x7C, 0xF2, 0xB6),  # #7cf2b6 — menta brillante, domina el tile
    "v1":     (0x76, 0xEC, 0xB0),  # #76ecb0
    "v2":     (0x9B, 0xF4, 0xC7),  # #9bf4c7 — variación clara (brizna clara)
    "v3":     (0x8D, 0xDE, 0xAE),  # #8ddeae
    "oscura": (0x5A, 0xC9, 0x6B),  # #5ac96b — mata oscura (brizna oscura)
    "clara":  (0x92, 0xCB, 0x98),  # #92cb98
}

FOLLAJE = {
    "sombra": (0x21, 0x36, 0x2C),  # #21362c
    "medio":  (0x3E, 0xA0, 0x6C),  # #3ea06c
    "luz":    (0x5D, 0xCF, 0x81),  # #5dcf81
    "brillo": (0x9E, 0xEF, 0xC1),  # #9eefc1
}

FOLLAJE_ROSA = {
    "sombra": (0x3C, 0x1A, 0x20),  # #3c1a20
    "medio":  (0xD1, 0x69, 0x84),  # #d16984
    "luz":    (0xF5, 0xB3, 0xC5),  # #f5b3c5
    "brillo": (0xFC, 0xDC, 0xDF),  # #fcdcdf
}

TIERRA = {
    "sombra": (0x55, 0x43, 0x3B),  # #55433b — mota oscura de tierra
    "medio":  (0xBB, 0x81, 0x53),  # #bb8153 — base de tierra
    "luz":    (0xE8, 0xBB, 0x84),  # #e8bb84 — mota clara de tierra
    "brillo": (0xF4, 0xDF, 0xBD),  # #f4dfbd
}

# Rampa AGUA nueva (derivada, ver _ojo en el JSON). Los anclajes medidos son
# #52b9fe (el agua del pozo) y #224851 (su sombra); los intermedios interpolados.
AGUA = {
    "sombra": (0x22, 0x48, 0x51),  # #224851
    "medio":  (0x2F, 0x7F, 0x9E),  # #2f7f9e
    "luz":    (0x52, 0xB9, 0xFE),  # #52b9fe
    "brillo": (0xA8, 0xE4, 0xFF),  # #a8e4ff
}

AGUA_PROFUNDA = {
    "sombra": (0x10, 0x2A, 0x33),  # #102a33
    "medio":  (0x17, 0x3A, 0x45),  # #173a45
    "luz":    (0x22, 0x48, 0x51),  # #224851
}

ARENA = {
    "sombra": (0x45, 0x3F, 0x36),  # #453f36 — mota oscura de arena
    "medio":  (0xE8, 0xBB, 0x84),  # #e8bb84 — base de la banda de orilla
    "luz":    (0xF7, 0xCB, 0xC4),  # #f7cbc4 — mota clara de arena
    "brillo": (0xFC, 0xEB, 0xE2),  # #fcebe2
}


# ── Hash espacial determinista ──────────────────────────────────────────

def h(x: int, y: int, s: int = 0) -> int:
    """Hash espacial determinista, 0..99. Mismo (x,y,s) → mismo valor."""
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100


# ── Funciones de píxel por material ─────────────────────────────────────
# Todas reciben (x, y) absolutos y envuelven con %T: la estructura repite
# con periodo T, así que el tileado se mantiene en los cuatro bordes.

def hierba_pixel(x: int, y: int, base, oscura, clara, brillo, seed: int) -> tuple:
    """Base plana + matas de briznas agrupadas.

    3-4 matas por tile, una por cuadrante (8×8) con posición jittered.
    Cada mata: 2-3 briznas verticales de 2 px (oscura). Alguna (~15 %)
    es una «v» de 3 px con las puntas abiertas. Unas pocas briznas llevan
    un píxel de `brillo` encima como punto de luz (muy escaso, ~2-4 px/tile).

    El cuadrante + jitter garantiza zonas peladas entre matas (>=2 px).
    El hash espacial envuelto (%T) mantiene el tileado seamless.
    """
    wx, wy = x % T, y % T

    # Cuántas matas: 3 o 4, según seed → grass y grass2 difieren de verdad
    num_matas = h(0, 0, seed + 700) % 2 + 3  # 3 o 4

    # Elegir qué cuadrantes se usan (si son 3, se descarta uno al azar)
    cuadrantes = list(range(4))
    if num_matas == 3:
        descarte = h(0, 1, seed + 701) % 4
        cuadrantes.remove(descarte)

    for qi in cuadrantes:
        # Centro de la mata dentro de su cuadrante 8×8, con jitter 1..6
        qx_base = (qi % 2) * 8
        qy_base = (qi // 2) * 8
        cx = (qx_base + h(qi, 0, seed) % 5 + 1) % T
        cy = (qy_base + h(qi, 1, seed + 1) % 5 + 1) % T

        # Briznas en esta mata: 2 o 3
        num_briznas = h(qi, 2, seed + 2) % 2 + 2

        for bi in range(num_briznas):
            # Posición de la brizna: centro de mata ±2 px
            bx = (cx + h(qi, bi + 3, seed + 3) % 5 - 2) % T
            by = (cy + h(qi, bi + 10, seed + 4) % 5 - 2) % T

            # ── Brillo: punto de luz justo encima de algunas briznas ──
            # Se comprueba antes que la brizna para que el brillo tenga prioridad.
            if wx == bx and wy == (by - 1 + T) % T:
                if h(bx, by, seed + 500) % 100 < 45:
                    return brillo

            # ── ¿Brizna de tono claro? ~25 % de las briznas usan `clara`
            #     en el píxel superior, dando variedad de hierba joven/vieja.
            usa_clara = h(qi, bi, seed + 800) % 100 < 25
            color_brizna = clara if usa_clara else oscura

            # ── Brizna en «v» muy abierta (3 px): ~15 % de las briznas ──
            if h(qi, bi, seed + 600) % 100 < 15:
                # Centro arriba + dos puntas abajo separadas 1 columna
                if wx == bx and wy == by:
                    return color_brizna
                if wy == (by + 1) % T:
                    if wx == (bx - 1 + T) % T or wx == (bx + 1) % T:
                        return oscura  # puntas de la V siempre oscuras
            else:
                # ── Brizna normal: par vertical de 2 px ──
                if wx == bx and wy == by:
                    return color_brizna
                if wx == bx and wy == (by + 1) % T:
                    return oscura  # base de la brizna siempre oscura

    # ── Brillo de respaldo: 2-4 px sueltos por hash, independientes
    #     de las briznas. Garantiza que siempre haya al menos algún
    #     píxel de brillo en el tile (4.º tono). ──
    if h(wx, wy, seed + 900) % 100 < 2:
        return brillo

    return base


def grass_pixel(x: int, y: int, seed: int = 0) -> tuple:
    """Hierba: base #7cf2b6, briznas con mata_oscura (#5ac96b) y v2 (#9bf4c7).
    Brillo: HIERBA['clara'] (#92cb98) como punto de luz muy escaso."""
    return hierba_pixel(x, y, HIERBA["base"], HIERBA["oscura"], HIERBA["v2"],
                        HIERBA["clara"], seed)


def grass_dark_pixel(x: int, y: int, seed: int = 0) -> tuple:
    """grass con la rampa bajada un tono: misma estructura (mismas briznas),
    colores de la rampa follaje_verde. NO un dibujo distinto.
    Brillo: FOLLAJE['brillo'] (#9eefc1)."""
    return hierba_pixel(x, y, FOLLAJE["medio"], FOLLAJE["sombra"], FOLLAJE["luz"],
                        FOLLAJE["brillo"], seed)


def grass_flowers_pixel(x: int, y: int) -> tuple:
    """Hierba con flores en ramilletes (no en rejilla).

    Fondo: hierba con briznas (hierba_pixel, misma estructura que grass).
    Flores: 2-3 ramilletes de 2-3 florecillas cada uno, en posiciones
    irregulares (hash). Las flores que tocan el borde (x=0, x=15, y=0, y=15)
    se empujan 3 px hacia dentro para que al repetir en mosaico 3×3 no
    formen franjas ni diagonales continuas a través de las fronteras.
    Cada florecilla es una L de 3 px (centro luz + derecha medio + abajo luz).
    """
    wx, wy = x % T, y % T

    # ── Flores: 2-3 ramilletes de 2-3 florecillas ──
    num_ramilletes = h(0, 0, 60) % 2 + 2  # 2 o 3
    for ri in range(num_ramilletes):
        rx = h(ri, 10, 61) % T
        ry = h(ri, 11, 62) % T
        num_flores = h(ri, 12, 63) % 2 + 2  # 2 o 3 por ramillete
        for fi in range(num_flores):
            # Flor dentro del ramillete: centro ±2 px
            fx = (rx + h(ri, fi + 20, 64) % 5 - 2) % T
            fy = (ry + h(ri, fi + 30, 65) % 5 - 2) % T

            # ── Anti-borde: si la flor (con su L) toca x=0, x=15,
            #     y=0 o y=15, empujarla 3 px hacia dentro. La L ocupa
            #     (fx,fy), (fx+1,fy), (fx,fy+1). Detectamos los 3 casos:
            #     centro en borde (fx==0,15), pixel derecho en borde
            #     (fx==14 → fx+1=15), pixel inferior en borde (fy==14 → fy+1=15).
            #     El empuje solo afecta al ~60 % de las flores de borde
            #     (hash determinista); el resto se quedan para evitar un
            #     borde completamente pelado.
            toca_x0 = (fx == 0)                         # centro en izq
            toca_x15 = (fx == 15 or fx == 14)           # centro o der en dcha
            toca_y0 = (fy == 0)                         # centro arriba
            toca_y15 = (fy == 15 or fy == 14)           # centro o abajo en borde inf
            toca_borde = toca_x0 or toca_x15 or toca_y0 or toca_y15
            if toca_borde and h(ri, fi, 66) % 100 < 65:
                # Empujar hacia el interior
                if toca_x0:
                    fx = (fx + 3) % T
                elif toca_x15:
                    fx = (fx - 3) % T
                if toca_y0:
                    fy = (fy + 3) % T
                elif toca_y15:
                    fy = (fy - 3) % T

            # L de 3 px
            if (wx, wy) == (fx % T, fy % T):
                return FOLLAJE_ROSA["luz"]
            if (wx, wy) == ((fx + 1) % T, fy % T):
                return FOLLAJE_ROSA["medio"]
            if (wx, wy) == (fx % T, (fy + 1) % T):
                return FOLLAJE_ROSA["luz"]

    # ── Fondo: hierba con briznas ──
    return hierba_pixel(x, y, HIERBA["base"], HIERBA["oscura"], HIERBA["v2"],
                        HIERBA["clara"], seed=0)


def dirt_pixel(x: int, y: int) -> tuple:
    """Tierra labrada con terrones y piedrecitas.

    Terrones: 4-5 grupitos de 2-3 px del tono sombra (#55433b), formando
    pequeñas masas irregulares (nunca píxeles sueltos). Piedrecitas: 3-5 px
    del tono luz (#e8bb84) dispersos. Brillo (#f4dfbd): 1-2 px muy escasos
    en los cantos altos de algún terrón. Base: medio (#bb8153), ~90 %.
    """
    wx, wy = x % T, y % T

    # ── Terrones: 4 grupos de 2-3 px de sombra, en forma de mini-bloques ──
    for ti in range(4):
        tx = h(ti, 0, 30) % T
        ty = h(ti, 1, 31) % T
        n = h(ti, 2, 32) % 2 + 2  # 2 o 3 px por terrón
        # Forma: centro + vecinos (derecha y/o abajo)
        offsets = [(0, 0), (1, 0), (0, 1)]
        for oi in range(n):
            ox, oy = offsets[oi]
            if wx == (tx + ox) % T and wy == (ty + oy) % T:
                return TIERRA["sombra"]

    # ── Piedrecitas: 3-5 px sueltos del tono luz ──
    for pi in range(h(0, 0, 33) % 3 + 3):  # 3-5
        px = h(pi, 3, 34) % T
        py = h(pi, 4, 35) % T
        if wx == px and wy == py:
            return TIERRA["luz"]

    # ── Brillo: 1-2 px muy escasos en bordes altos ──
    for bi in range(2):
        bx = h(bi, 5, 36) % T
        by = h(bi, 6, 37) % T
        if wx == bx and wy == by:
            return TIERRA["brillo"]

    return TIERRA["medio"]


def arena_pixel(x: int, y: int) -> tuple:
    """Arena de la banda de orilla: base #e8bb84 + grano fino + brillo escaso."""
    wx, wy = x % T, y % T
    v = h(wx, wy, 40)
    if v < 4:            # ~10 motas claras
        return ARENA["luz"]
    elif v < 12:         # ~20 motas oscuras
        return ARENA["sombra"]
    elif v < 13:         # ~3 motas de brillo muy escaso
        return ARENA["brillo"]
    return ARENA["medio"]


def water_pixel(x: int, y: int, frame: int = 0) -> tuple:
    """Agua de bajío con ondas horizontales y destellos.

    Las ondas viajan en y con periodo 16 (ciclo de 4 frames, shift = frame*4).
    Los destellos son píxeles SUELTOS de brillo (#a8e4ff) sobre las crestas
    (~2-3 por tile), determinados por hash — no una banda continua.
    Se desplazan con la onda porque la cresta cambia de posición cada frame.
    El ciclo cierra: frame 0 ≡ frame 4 (shift=16 ≡ 0). Las transiciones
    conservan la magnitud de 59.55 del diseñador 1 porque la estructura de
    onda base no se toca.
    """
    wx, wy = x % T, y % T
    shift = frame * 4.0
    fase_x = 0.6 * math.sin(2.0 * math.pi * wx / 16.0 + 0.7)
    wave = math.sin(2.0 * math.pi * (wy + shift) / 16.0 + fase_x)

    # Destellos: píxeles sueltos de brillo sobre las crestas (~2-3 por tile)
    if wave > 0.85 and h(wx, wy, 100 + frame * 7) % 100 < 10:
        return AGUA["brillo"]

    # Cuerpo del agua: umbrales del diseñador 1 (sin cambios)
    if wave > -0.30:
        return AGUA["luz"]      # cuerpo del agua (~45 %)
    elif wave > -0.85:
        return AGUA["medio"]
    else:
        return AGUA["sombra"]   # valles


def water_deep_pixel(x: int, y: int) -> tuple:
    """Agua profunda: 3 tonos oscuros de la rampa agua_profunda, sin animación,
    ondas horizontales muy suaves (menos contraste que el bajío)."""
    wx, wy = x % T, y % T
    fase_x = 0.4 * math.sin(2.0 * math.pi * wx / 16.0 + 2.1)
    wave = math.sin(2.0 * math.pi * wy / 16.0 + 1.0 + fase_x)
    if wave > 0.30:
        return AGUA_PROFUNDA["luz"]
    elif wave > -0.55:
        return AGUA_PROFUNDA["medio"]
    else:
        return AGUA_PROFUNDA["sombra"]


# ── Generadores de tiles completos ──────────────────────────────────────

def _make_tile(pixel_fn):
    """Crea un tile T×T llamando pixel_fn(x, y) para cada píxel."""
    img = Image.new("RGB", (T, T))
    px = img.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = pixel_fn(x, y)
    return img


def gen_grass():
    return _make_tile(lambda x, y: grass_pixel(x, y, seed=0))


def gen_grass2():
    return _make_tile(lambda x, y: grass_pixel(x, y, seed=5))


def gen_grass_flowers():
    return _make_tile(grass_flowers_pixel)


def gen_grass_dark():
    return _make_tile(lambda x, y: grass_dark_pixel(x, y, seed=0))


def gen_dirt():
    return _make_tile(dirt_pixel)


def gen_water(frame: int):
    return _make_tile(lambda x, y: water_pixel(x, y, frame))


def gen_water_deep():
    return _make_tile(water_deep_pixel)


# ── Orillas ─────────────────────────────────────────────────────────────
# UNA función raíz (shore_N). Las otras tres se obtienen por rotación:
#   shore_S = rot180(shore_N)          agua arriba → agua abajo
#   shore_E = rot90_CW(shore_N)        agua arriba → agua a la derecha
#   shore_W = rot90_CCW(shore_N)       agua arriba → agua a la izquierda

def gen_shore_n():
    """Orilla con agua al NORTE (arriba) y hierba al SUR (abajo).

    Banda de arena nominal en filas 8-10. El canto es irregular: ±1 px
    en ambas fronteras (agua/arena y arena/hierba), decidido columna a
    columna por hash espacial. Para que el borde izquierdo (x=0) empalme
    con el derecho (x=15) la altura de arena se fuerza igual en ambas
    columnas (solo 2 columnas de 16).

    Espuma: 2-3 px de AGUA['brillo'] (#a8e4ff) pegados al borde arena/agua
    en columnas escogidas por hash (~15 % de las columnas), no a lo largo
    de todo el borde.
    """
    img = Image.new("RGB", (T, T))
    px = img.load()

    # ── Precálculo: bordes de arena por columna ──
    sand_top = [8] * T     # primera fila de arena
    sand_bot = [10] * T    # última fila de arena

    for wx in range(T):
        top = 8
        bot = 10
        # Irregularidad del borde agua/arena
        if h(wx, 99, 50) < 30:
            top = 7   # la arena sube 1 px (come agua)
        elif h(wx, 99, 51) < 15:
            top = 9   # la arena baja 1 px (agua avanza)
        # Irregularidad del borde arena/hierba
        if h(wx, 98, 52) < 25:
            bot = 11  # la arena baja 1 px (come hierba)
        elif h(wx, 98, 53) < 15:
            bot = 9   # la arena sube 1 px (hierba avanza)
        # Garantía: al menos 1 px de arena
        if bot < top:
            bot = top
        sand_top[wx] = top
        sand_bot[wx] = bot

    # Forzar costura horizontal: columna 0 y columna T-1 comparten borde
    sand_top[0] = sand_top[T - 1]
    sand_bot[0] = sand_bot[T - 1]

    # ── Relleno base (agua / arena / hierba) ──
    for y in range(T):
        for x in range(T):
            wx = x % T
            if y < sand_top[wx]:
                px[x, y] = water_pixel(x, y, frame=0)
            elif y <= sand_bot[wx]:
                px[x, y] = arena_pixel(x, y)
            else:
                px[x, y] = grass_pixel(x, y, seed=0)

    # ── Espuma: 2-3 px de AGUA['brillo'] en el borde arena/agua ──
    # Columnas candidatas (~15 %)
    candidatas = []
    for wx in range(T):
        if h(wx, 200, 54) < 15:
            candidatas.append(wx)
    # Si salen menos de 2, forzar al menos 2 (sin tocarlas si ya hay)
    while len(candidatas) < 2:
        wx = h(len(candidatas), 201, 55) % T
        if wx not in candidatas:
            candidatas.append(wx)

    for wx in candidatas:
        top = sand_top[wx]
        # Espuma justo encima de la arena (primera fila de agua)
        fy = (top - 1) % T
        if fy >= 0 and h(wx, fy, 56) < 70:
            px[wx, fy] = AGUA["brillo"]
        # A veces un segundo px de espuma tocando la arena
        if h(wx, 202, 57) < 30 and top < T:
            px[wx, top] = AGUA["brillo"]

    return img


def gen_shore(direction: str) -> Image.Image:
    """Orilla en la dirección indicada. Ver _orilla() en biome_map.gd:
    el nombre dice dónde queda el agua."""
    base = gen_shore_n()
    if direction == 'N':
        return base
    elif direction == 'S':
        return base.transpose(Image.ROTATE_180)
    elif direction == 'E':
        return base.transpose(Image.ROTATE_270)
    elif direction == 'W':
        return base.transpose(Image.ROTATE_90)
    else:
        raise ValueError(f"Dirección desconocida: {direction}")


# ── Verificación ────────────────────────────────────────────────────────

def _colores_en_paleta() -> set:
    """Conjunto de todos los colores RGB definidos en las rampas del JSON."""
    rampas = [HIERBA, FOLLAJE, FOLLAJE_ROSA, TIERRA, AGUA, AGUA_PROFUNDA, ARENA]
    colores = set()
    for rampa in rampas:
        colores.update(rampa.values())
    return colores


def verificar(directorio: str) -> dict:
    """Comprueba tamaño, paleta, costura, % color dominante y ciclo de agua."""
    import numpy as np

    PALETA = _colores_en_paleta()

    # Tiles que exigen base dominante > 65 % (los de hierba y la tierra).
    EXIGE_DOMINANTE = {"grass", "grass2", "grass_flowers", "grass_dark", "dirt"}

    resultado: dict = {
        "tamaño": {},
        "colores_unicos": {},
        "fuera_de_paleta": {},
        "dominante_pct": {},
        "costura_h": {},
        "costura_v": {},
        "errores": [],
    }

    nombres = [
        "grass", "grass2", "grass_flowers", "grass_dark", "dirt",
        "shore_N", "shore_S", "shore_E", "shore_W",
        "water_0", "water_1", "water_2", "water_3", "water_deep",
    ]

    for nombre in nombres:
        ruta = os.path.join(directorio, f"{nombre}.png")
        if not os.path.exists(ruta):
            resultado["errores"].append(f"Falta {ruta}")
            continue
        img = Image.open(ruta).convert("RGB")
        arr = np.asarray(img, dtype=int)

        # Tamaño
        w, h_img = img.size
        resultado["tamaño"][nombre] = f"{w}×{h_img}"
        if w != T or h_img != T:
            resultado["errores"].append(
                f"{nombre}: tamaño {w}×{h_img}, se esperaba {T}×{T}"
            )

        # Colores únicos y su frecuencia
        conteo = {}
        for y in range(T):
            for x in range(T):
                c = tuple(arr[y, x])
                conteo[c] = conteo.get(c, 0) + 1
        resultado["colores_unicos"][nombre] = len(conteo)

        # Fuera de paleta
        fuera = [c for c in conteo if c not in PALETA]
        if fuera:
            hex_fuera = ["#{:02x}{:02x}{:02x}".format(*c) for c in fuera]
            resultado["fuera_de_paleta"][nombre] = hex_fuera
            resultado["errores"].append(
                f"{nombre}: colores fuera de paleta: {hex_fuera}"
            )
        else:
            resultado["fuera_de_paleta"][nombre] = "ninguno"

        # % del color más frecuente
        dominante = max(conteo.values()) / (T * T) * 100.0
        resultado["dominante_pct"][nombre] = round(dominante, 1)
        if nombre in EXIGE_DOMINANTE and dominante < 65:
            resultado["errores"].append(
                f"{nombre}: color dominante {dominante:.1f}% < 65% — manchas, "
                f"no base plana"
            )

        # Costura
        diff_h = float(np.abs(arr[:, -1] - arr[:, 0]).mean())
        diff_v = float(np.abs(arr[-1, :] - arr[0, :]).mean())
        resultado["costura_h"][nombre] = round(diff_h, 1)
        resultado["costura_v"][nombre] = round(diff_v, 1)

        chequeo = CHEQUEO_COSTURA.get(nombre, "ambas")
        if chequeo in ("h", "ambas") and diff_h >= 40:
            resultado["errores"].append(
                f"{nombre}: costura horizontal {diff_h:.1f} >= 40 — FALLA"
            )
        if chequeo in ("v", "ambas") and diff_v >= 40:
            resultado["errores"].append(
                f"{nombre}: costura vertical {diff_v:.1f} >= 40 — FALLA"
            )

    # ── Ciclo de agua: las 4 transiciones deben tener magnitud similar.
    diffs = []
    for i in range(4):
        ruta = os.path.join(directorio, f"water_{i}.png")
        ruta_next = os.path.join(directorio, f"water_{(i+1)%4}.png")
        if os.path.exists(ruta) and os.path.exists(ruta_next):
            a = np.asarray(Image.open(ruta).convert("RGB"), dtype=int)
            b = np.asarray(Image.open(ruta_next).convert("RGB"), dtype=int)
            diff = float(np.abs(a - b).mean())
            diffs.append(diff)
            resultado.setdefault("ciclo_agua", {})[f"{i}→{(i+1)%4}"] = round(diff, 1)

    if diffs:
        mediana = sorted(diffs)[len(diffs) // 2]
        cierre = diffs[-1]
        if mediana > 0 and (cierre > mediana * 2.5 or cierre < mediana * 0.3):
            resultado["errores"].append(
                f"Ciclo agua: transición 3→0 ({cierre:.1f}) es outlier "
                f"respecto a la mediana ({mediana:.1f}) — el ciclo no cierra"
            )
        if any(d < 1.0 for d in diffs):
            resultado["errores"].append(
                "Ciclo agua: alguna transición tiene dif < 1 (sin animación)"
            )

    resultado["PASA"] = len(resultado["errores"]) == 0
    return resultado


# ── main ─────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Generador de los 14 tiles de terreno (16×16) — lote 1"
    )
    ap.add_argument(
        "--salida", default="staging_arte/tiles",
        help="Directorio donde escribir los PNG (default: staging_arte/tiles)"
    )
    ap.add_argument(
        "--solo-verificar", action="store_true",
        help="Solo ejecuta verificación, no regenera nada"
    )
    args = ap.parse_args()

    salida = os.path.abspath(args.salida)
    os.makedirs(salida, exist_ok=True)

    if not args.solo_verificar:
        generadores = {
            "grass.png":          gen_grass,
            "grass2.png":         gen_grass2,
            "grass_flowers.png":  gen_grass_flowers,
            "grass_dark.png":     gen_grass_dark,
            "dirt.png":           gen_dirt,
            "shore_N.png":        lambda: gen_shore('N'),
            "shore_S.png":        lambda: gen_shore('S'),
            "shore_E.png":        lambda: gen_shore('E'),
            "shore_W.png":        lambda: gen_shore('W'),
            "water_0.png":        lambda: gen_water(0),
            "water_1.png":        lambda: gen_water(1),
            "water_2.png":        lambda: gen_water(2),
            "water_3.png":        lambda: gen_water(3),
            "water_deep.png":     gen_water_deep,
        }

        for nombre, gen in generadores.items():
            ruta = os.path.join(salida, nombre)
            img = gen()
            img.save(ruta, "PNG")
            print(f"  {nombre} → {ruta}")

        print(f"\n14 tiles escritos en {salida}/")

    # ── Verificación ──
    print("\n" + "=" * 60)
    print("VERIFICACIÓN")
    print("=" * 60)
    res = verificar(salida)

    for nombre in sorted(res["tamaño"]):
        print(f"\n── {nombre} ──")
        print(f"  tamaño:        {res['tamaño'][nombre]}")
        print(f"  colores:       {res['colores_unicos'][nombre]}")
        print(f"  fuera paleta:  {res['fuera_de_paleta'][nombre]}")
        print(f"  % dominante:   {res['dominante_pct'][nombre]}%")
        chk = CHEQUEO_COSTURA.get(nombre, "ambas")
        if chk in ("h", "ambas"):
            print(f"  costura H:     {res['costura_h'][nombre]:.1f}")
        if chk in ("v", "ambas"):
            print(f"  costura V:     {res['costura_v'][nombre]:.1f}")

    if "ciclo_agua" in res:
        print("\n── ciclo de agua ──")
        for trans, val in res["ciclo_agua"].items():
            print(f"  {trans}:        {val:.1f}")

    print(f"\n{'PASA' if res['PASA'] else 'FALLA'}: {len(res['errores'])} error(es)")
    if res["errores"]:
        for e in res["errores"]:
            print(f"  ⚠ {e}")

    return 0 if res["PASA"] else 1


if __name__ == "__main__":
    sys.exit(main())
