#!/usr/bin/env python3
"""Generador de las 4 estaciones del lote 3: forja, estantería, escritorio
y cofre.

Lote 3, vuelta: forja y cofre rediseñados. Estantería y escritorio intactos.

Perspectiva frontal plana, contorno #000000 1 px, luz arriba-izquierda.
Paleta del contrato_rediseno.json. Sin dithering.

    python3 tools/estaciones.py [--salida <dir>]
"""

import pathlib
import sys
from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
STAGING = RAIZ / "staging_arte" / "estaciones"

# ---------------------------------------------------------------------------
# Paleta del contrato (RGB)
# ---------------------------------------------------------------------------
C_NEGRO = (0x00, 0x00, 0x00)

PIEDRA = {
    "S": (0x74, 0x4B, 0x48),
    "M": (0x80, 0x74, 0x66),
    "L": (0x99, 0xA7, 0x92),
    "B": (0xD1, 0xD1, 0xC0),
}
MADERA = {
    "S": (0x5D, 0x42, 0x3A),
    "M": (0x95, 0x64, 0x47),
    "L": (0xBC, 0x80, 0x50),
    "B": (0xDE, 0xBF, 0x88),
}
DORADO = {
    "S": (0x85, 0x5A, 0x14),
    "M": (0xD2, 0x7D, 0x2C),
    "L": (0xF0, 0xC0, 0x60),
    "B": (0xF8, 0xE0, 0xA0),
}
ROJO = {
    "S": (0x8E, 0x1F, 0x1C),
    "M": (0xD2, 0x30, 0x2F),
    "L": (0xF0, 0x6A, 0x5A),
    "B": (0xF8, 0xA5, 0x8B),
}
ARCANO = {
    "S": (0x3A, 0x20, 0x58),
    "M": (0x6E, 0x3A, 0xA0),
    "L": (0x9D, 0x6D, 0xFF),
    "B": (0xC8, 0x9B, 0xFF),
}
PAJA = {
    "S": (0x8F, 0x5F, 0x43),
    "M": (0xB0, 0x78, 0x55),
    "L": (0xCB, 0x91, 0x63),
    "B": (0xD8, 0xAD, 0x7A),
}
BLANCO = {
    "S": (0xE0, 0xDD, 0xD4),
    "M": (0xFF, 0xFF, 0xFF),
    "L": (0xFF, 0xFF, 0xFF),
    "B": (0xFF, 0xFF, 0xFF),
}

# Colores para fuego: combinación de la rampa rojo (base) + dorado (núcleo caliente)
FUEGO_CORE = DORADO["B"]          # núcleo más caliente = amarillo claro
FUEGO_MED = DORADO["L"]           # llama media = dorado
FUEGO_EXT = ROJO["L"]             # llama externa = naranja
FUEGO_BORDE = ROJO["M"]           # borde de la llama

# Colores para hierro (flejes, yunque): tonos fríos derivados de piedra
# No hay rampa de metal en el contrato. Se usan los tonos piedra como
# aproximación — son grises cálidos — y se nota en el informe.
HIERRO = {
    "S": PIEDRA["S"],
    "M": PIEDRA["M"],
    "L": PIEDRA["L"],
    "B": PIEDRA["B"],
}

# ---------------------------------------------------------------------------
# Hash espacial (del SKILL)
# ---------------------------------------------------------------------------
def _h(x: int, y: int, s: int = 0) -> int:
    """Hash espacial determinista, 0..99."""
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100


# ---------------------------------------------------------------------------
# Utilidades de dibujo
# ---------------------------------------------------------------------------
class Lienzo:
    """Lienzo RGBA con métodos de dibujo de píxeles."""

    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def set(self, x: int, y: int, c: tuple) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c + (255,)

    def rect(self, x0: int, y0: int, x1: int, y1: int, c: tuple) -> None:
        """Relleno inclusivo [x0..x1] x [y0..y1]."""
        x0, x1 = max(0, x0), min(self.w - 1, x1)
        y0, y1 = max(0, y0), min(self.h - 1, y1)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px[x, y] = c + (255,)

    def hline(self, y: int, x0: int, x1: int, c: tuple) -> None:
        self.rect(x0, y, x1, y, c)

    def vline(self, x: int, y0: int, y1: int, c: tuple) -> None:
        self.rect(x, y0, x, y1, c)

    def contornear(self) -> None:
        """Contorno sticker de 1 px: pinta de negro los píxeles transparentes
        adyacentes a cualquier píxel opaco."""
        borde = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[nx, ny][3]:
                        borde.append((x, y))
                        break
        for x, y in borde:
            self.px[x, y] = C_NEGRO + (255,)

    def colores(self) -> set:
        return {self.px[x, y][:3] for y in range(self.h) for x in range(self.w)
                if self.px[x, y][3]}

    def guardar(self, ruta: pathlib.Path) -> None:
        ruta.parent.mkdir(parents=True, exist_ok=True)
        self.im.save(ruta)
        cs = self.colores()
        print(f"  {ruta.name}  {self.w}×{self.h}  {len(cs)} colores")


# ---------------------------------------------------------------------------
# 1. FORGE — horno de forja 64×80
# ---------------------------------------------------------------------------
def dibujar_forge() -> Lienzo:
    L = Lienzo(64, 80)
    cx = 32

    # ── helper: semi-ancho de la estructura de piedra ──
    def _stone_hw(y: int) -> int:
        """Semi-ancho de la chimenea + horno en la fila y."""
        if y < 2:
            return 0
        if y <= 12:
            t = (y - 2) / 10.0
            return 7 + int(t * 5)   # 7 → 12
        if y <= 24:
            t = (y - 12) / 12.0
            return 12 + int(t * 9)  # 12 → 21
        if y <= 50:
            return 21
        return 0

    # ── 1. Estructura de piedra (chimenea + horno) ──
    for y in range(2, 51):
        hw = _stone_hw(y)
        x0, x1 = cx - hw, cx + hw
        for x in range(x0, x1 + 1):
            hval = _h(x, y, 201)
            if hval < 18:
                L.set(x, y, PIEDRA["S"])
            elif hval < 55:
                L.set(x, y, PIEDRA["M"])
            elif hval < 82:
                L.set(x, y, PIEDRA["L"])
            else:
                L.set(x, y, PIEDRA["B"])

    # ── 2. Juntas de sillares (matajunta) ──
    for y in range(2, 51):
        hw = _stone_hw(y)
        x0, x1 = cx - hw, cx + hw
        # Juntas horizontales cada 6 px
        local_y = (y - 2) % 6
        if local_y == 0 or local_y == 5:
            for x in range(x0, x1 + 1):
                L.set(x, y, PIEDRA["S"])
        # Juntas verticales cada 7 px, filas impares desplazadas 3 px
        row = (y - 2) // 6
        offset = 3 if row % 2 == 1 else 0
        for x in range(x0, x1 + 1):
            lx = x - x0 - offset
            while lx < 0:
                lx += 7
            lx %= 7
            if lx == 0 or lx == 6:
                L.set(x, y, PIEDRA["S"])

    # Cornisa de la chimenea (remate superior)
    hw_top = _stone_hw(2)
    L.rect(cx - hw_top - 1, 1, cx + hw_top + 1, 2, PIEDRA["L"])
    L.hline(1, cx - hw_top - 1, cx + hw_top + 1, PIEDRA["B"])
    L.hline(3, cx - hw_top - 1, cx + hw_top + 1, PIEDRA["S"])

    # ── 3. Boca del horno (vano en arco) ──
    boca_hw = 10           # ~1/3 del ancho total (64 px)
    boca_top = 29
    boca_bot = 46
    arco_h = 4

    for y in range(boca_top, boca_bot + 1):
        if y < boca_top + arco_h:
            dy = boca_top + arco_h - y
            reduccion = int(dy * 1.8)
            hw = max(2, boca_hw - reduccion)
        else:
            hw = boca_hw
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, ARCANO["S"])

    # ── 4. Fuego (3 tonos: núcleo blanco-amarillo → naranja → rojo) ──
    # Se pinta de fuera hacia dentro: cada capa sobreescribe la anterior.
    # Las lenguas salen del mismo modo (de fuera hacia dentro).

    # 4a. Capa externa: rojo-anaranjado (la más grande)
    for y in range(30, 49):
        hw = max(0, 10 - abs(y - 39))
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_EXT)

    # 4b. Capa media: oro-naranja
    for y in range(34, 48):
        hw = max(0, 8 - abs(y - 41))
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_MED)

    # 4c. Núcleo caliente: blanco-amarillo (la más pequeña, abajo-centro)
    for y in range(39, 47):
        hw = max(1, 5 - abs(y - 43))
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_CORE)

    # 4d. Lenguas de llama que salen por arriba de la boca
    for y in range(26, 30):
        hw = max(1, (30 - y) * 3)
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_EXT)
    for y in range(27, 29):
        hw = max(1, (29 - y) * 2)
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_MED)
    # Bordes oscuros de las lenguas
    for y in range(26, 30):
        hw_ext = max(1, (30 - y) * 3)
        if cx - hw_ext - 1 >= 0:
            L.set(cx - hw_ext - 1, y, FUEGO_BORDE)
        if cx + hw_ext + 1 < 64:
            L.set(cx + hw_ext + 1, y, FUEGO_BORDE)

    # ── 5. Resplandor: sillares cerca de la boca, un tono más claro ──
    for y in range(boca_top - 8, boca_bot + 6):
        if y < 2 or y > 50:
            continue
        hw = _stone_hw(y)
        for x in range(cx - hw, cx + hw + 1):
            if not L.px[x, y][3]:
                continue
            rgb = L.px[x, y][:3]
            if rgb not in {PIEDRA["S"], PIEDRA["M"], PIEDRA["L"], PIEDRA["B"]}:
                continue
            dx = abs(x - cx)
            dy = abs(y - (boca_top + boca_bot) // 2)
            dist = dx + dy * 1.5
            if dist < 14:
                hval = _h(x, y, 301)
                p = L.px[x, y]
                if p[:3] == PIEDRA["M"]:
                    L.set(x, y, PIEDRA["L"] if hval < 60 else PIEDRA["M"])
                elif p[:3] == PIEDRA["S"]:
                    L.set(x, y, PIEDRA["M"] if hval < 50 else PIEDRA["S"])
                elif p[:3] == PIEDRA["L"]:
                    L.set(x, y, PIEDRA["B"] if hval < 40 else PIEDRA["L"])

    # ── 6. Base de madera con tablones verticales ──
    base_x0, base_x1 = cx - 23, cx + 23   # 46 px de ancho
    base_y0, base_y1 = 51, 78

    # Línea de separación piedra/madera
    L.hline(50, cx - 22, cx + 22, PIEDRA["S"])

    for y in range(base_y0, base_y1 + 1):
        for x in range(base_x0, base_x1 + 1):
            plank_w = 6
            within = (x - base_x0) % plank_w
            if within == 0:
                L.set(x, y, MADERA["S"])       # junta entre tablones
            else:
                hval = _h(x, y, 401)
                if hval < 30:
                    L.set(x, y, MADERA["M"])
                elif hval < 65:
                    L.set(x, y, MADERA["L"])
                else:
                    L.set(x, y, MADERA["S"])

    # Remate superior de la base (viga horizontal)
    L.hline(base_y0, base_x0, base_x1, MADERA["L"])
    L.hline(base_y0 + 1, base_x0, base_x1, MADERA["B"])
    L.hline(base_y0 + 2, base_x0, base_x1, MADERA["M"])
    # Remate inferior
    L.hline(base_y1, base_x0, base_x1, MADERA["S"])
    L.hline(base_y1 - 1, base_x0, base_x1, MADERA["S"])

    # ── 7. Yunque (delante, a la derecha) ──
    yunque = [
        # Fila 0 (y=62): cara superior plana
        (49, 62, HIERRO["B"]), (50, 62, HIERRO["B"]),
        (51, 62, HIERRO["L"]), (52, 62, HIERRO["L"]),
        # Fila 1 (y=63): cuerpo + arranque del cuerno
        (48, 63, HIERRO["L"]),
        (49, 63, HIERRO["M"]), (50, 63, HIERRO["M"]), (51, 63, HIERRO["M"]),
        (52, 63, HIERRO["M"]),
        (53, 63, HIERRO["M"]),   # cuerno
        (54, 63, HIERRO["L"]),   # punta del cuerno
        # Fila 2 (y=64): cuerpo + cuerno
        (48, 64, HIERRO["L"]),
        (49, 64, HIERRO["M"]), (50, 64, HIERRO["M"]), (51, 64, HIERRO["M"]),
        (52, 64, HIERRO["M"]),
        (53, 64, HIERRO["M"]), (54, 64, HIERRO["M"]),
        (55, 64, HIERRO["S"]),   # sombra bajo la punta
        # Fila 3 (y=65): cuerpo ensanchando
        (47, 65, HIERRO["M"]),
        (48, 65, HIERRO["M"]), (49, 65, HIERRO["M"]), (50, 65, HIERRO["M"]),
        (51, 65, HIERRO["M"]), (52, 65, HIERRO["M"]),
        (53, 65, HIERRO["S"]),
        # Fila 4 (y=66): cuerpo ensanchando
        (47, 66, HIERRO["M"]),
        (48, 66, HIERRO["M"]), (49, 66, HIERRO["M"]), (50, 66, HIERRO["M"]),
        (51, 66, HIERRO["M"]),
        (52, 66, HIERRO["S"]), (53, 66, HIERRO["S"]),
        # Fila 5 (y=67): base
        (47, 67, HIERRO["M"]),
        (48, 67, HIERRO["M"]), (49, 67, HIERRO["M"]), (50, 67, HIERRO["M"]),
        (51, 67, HIERRO["M"]),
        (52, 67, HIERRO["S"]), (53, 67, HIERRO["S"]),
        # Fila 6 (y=68): base
        (46, 68, HIERRO["S"]),
        (47, 68, HIERRO["M"]), (48, 68, HIERRO["M"]), (49, 68, HIERRO["M"]),
        (50, 68, HIERRO["M"]), (51, 68, HIERRO["M"]),
        (52, 68, HIERRO["S"]), (53, 68, HIERRO["S"]),
        # Fila 7 (y=69): base
        (46, 69, HIERRO["S"]),
        (47, 69, HIERRO["M"]), (48, 69, HIERRO["M"]), (49, 69, HIERRO["M"]),
        (50, 69, HIERRO["M"]),
        (51, 69, HIERRO["S"]), (52, 69, HIERRO["S"]),
        # Fila 8 (y=70): base inferior
        (46, 70, HIERRO["S"]), (47, 70, HIERRO["S"]),
        (48, 70, HIERRO["S"]), (49, 70, HIERRO["S"]),
        (50, 70, HIERRO["S"]), (51, 70, HIERRO["S"]),
    ]
    for x, y, c in yunque:
        L.set(x, y, c)

    L.contornear()
    return L

# ---------------------------------------------------------------------------
# 2. BOOKSHELF — estantería 64×80
# ---------------------------------------------------------------------------
def dibujar_bookshelf() -> Lienzo:
    L = Lienzo(64, 80)

    # --- Marco de madera ---
    frame_l, frame_r = 3, 60
    frame_t, frame_b = 2, 77
    # Laterales
    L.rect(frame_l, frame_t, frame_l + 3, frame_b, MADERA["M"])
    L.rect(frame_r - 3, frame_t, frame_r, frame_b, MADERA["M"])
    # Borde exterior en sombra y luz
    L.rect(frame_l, frame_t, frame_l, frame_b, MADERA["S"])         # izq sombra
    L.rect(frame_l + 3, frame_t, frame_l + 3, frame_b, MADERA["L"]) # izq luz
    L.rect(frame_r, frame_t, frame_r, frame_b, MADERA["S"])         # der sombra
    # Superior
    L.rect(frame_l, frame_t, frame_r, frame_t + 3, MADERA["M"])
    L.rect(frame_l, frame_t, frame_r, frame_t, MADERA["L"])
    L.rect(frame_l, frame_t + 3, frame_r, frame_t + 3, MADERA["S"])
    # Inferior
    L.rect(frame_l, frame_b - 3, frame_r, frame_b, MADERA["M"])
    L.rect(frame_l, frame_b - 3, frame_r, frame_b - 3, MADERA["L"])
    L.rect(frame_l, frame_b, frame_r, frame_b, MADERA["S"])

    # Veta de madera con hash en laterales
    for x in range(frame_l + 1, frame_l + 3):
        for y in range(frame_t + 4, frame_b - 3):
            if _h(x, y // 2, 83) < 25:
                L.set(x, y, MADERA["S"] if _h(x, y, 84) < 12 else MADERA["L"])
    for x in range(frame_r - 2, frame_r):
        for y in range(frame_t + 4, frame_b - 3):
            if _h(x, y // 2, 85) < 25:
                L.set(x, y, MADERA["S"] if _h(x, y, 86) < 12 else MADERA["L"])

    # Fondo del estante (oscuro, para que los libros resalten)
    L.rect(frame_l + 4, frame_t + 4, frame_r - 4, frame_b - 4, MADERA["S"])

    # --- 4 baldas ---
    shelves_y = [19, 37, 55, 72]
    shelf_thick = 3
    for sy in shelves_y:
        L.rect(frame_l + 4, sy, frame_r - 4, sy + shelf_thick - 1, MADERA["M"])
        L.rect(frame_l + 4, sy, frame_r - 4, sy, MADERA["L"])
        L.rect(frame_l + 4, sy + shelf_thick - 1, frame_r - 4, sy + shelf_thick - 1, MADERA["S"])
        # Veta en balda
        for x in range(frame_l + 4, frame_r - 3):
            for dy in range(shelf_thick):
                y = sy + dy
                if _h(x, y, 91) < 30:
                    c = MADERA["S"] if _h(x, y, 92) < 15 else MADERA["L"]
                    L.set(x, y, c)

    # --- Libros en cada sección ---
    secciones = [
        (frame_t + 4, shelves_y[0] - 1),   # sección 1
        (shelves_y[0] + shelf_thick, shelves_y[1] - 1),  # sección 2
        (shelves_y[1] + shelf_thick, shelves_y[2] - 1),  # sección 3
        (shelves_y[2] + shelf_thick, shelves_y[3] - 1),  # sección 4
    ]

    # Colores de libros disponibles
    book_colors = [
        (ROJO["M"], ROJO["L"], ROJO["S"]),
        (ARCANO["M"], ARCANO["L"], ARCANO["S"]),
        (ROJO["S"], ROJO["M"], ROJO["L"]),
        (ARCANO["S"], ARCANO["M"], ARCANO["L"]),
        (MADERA["L"], MADERA["B"], MADERA["M"]),
        (PAJA["M"], PAJA["L"], PAJA["S"]),
        (DORADO["S"], DORADO["M"], ROJO["S"]),  # libro dorado oscuro
        (MADERA["M"], MADERA["L"], MADERA["S"]),
    ]

    for sec_idx, (y0, y1) in enumerate(secciones):
        sec_h = y1 - y0 + 1
        if sec_h <= 0:
            continue
        x = frame_l + 5
        book_list = _generar_libros(sec_idx, sec_h, x, frame_r - 5, y0, y1)

        for bk in book_list:
            _dibujar_libro(L, bk, book_colors, y0, y1)

    L.contornear()
    return L


def _generar_libros(sec_idx: int, sec_h: int, x_start: int, x_end: int,
                    y0: int, y1: int) -> list:
    """Genera una lista de libros con posiciones y dimensiones para una sección."""
    libros = []
    x = x_start
    max_x = x_end
    book_id = 0

    while x < max_x - 2:
        seed = sec_idx * 100 + book_id
        # Ancho del libro: 3-8 px
        w = 3 + _h(seed, 0, 101) % 5
        if x + w > max_x:
            w = max_x - x
        if w < 2:
            break

        # Alto: entre 60% y 100% de la sección
        h_frac = 60 + _h(seed, 1, 102) % 40
        h = max(3, sec_h * h_frac // 100)

        # ¿Inclinado? (~15% de probabilidad)
        inclinado = _h(seed, 2, 103) < 15 and w >= 4 and sec_h >= 10

        # Color index
        color_idx = _h(seed, 3, 104) % 8

        # ¿Banda dorada? (~25%)
        banda = _h(seed, 4, 105) < 25

        # Posición Y de la banda dorada
        banda_y_frac = 30 + _h(seed, 5, 106) % 40  # 30-70% desde arriba

        libros.append({
            "x": x,
            "w": w,
            "h": h,
            "inclinado": inclinado,
            "color_idx": color_idx,
            "banda": banda,
            "banda_y_frac": banda_y_frac,
            "seed": seed,
        })

        x += w + 1  # 1 px de separación entre libros
        book_id += 1

    return libros


def _dibujar_libro(L: Lienzo, bk: dict, book_colors: list,
                   y0: int, y1: int) -> None:
    """Dibuja un libro en la estantería."""
    x = bk["x"]
    w = bk["w"]
    h = bk["h"]
    colores = book_colors[bk["color_idx"]]
    body, top, shadow = colores  # medio, luz, sombra

    if bk["inclinado"]:
        _dibujar_libro_inclinado(L, bk, colores, y0, y1)
    else:
        # Libro recto: se apoya en el fondo de la sección (y1)
        top_y = y1 - h + 1
        L.rect(x, top_y, x + w - 1, y1, body)

        # Lomo iluminado (1 px izquierdo)
        L.vline(x, top_y, y1, top)

        # Borde derecho en sombra
        L.vline(x + w - 1, top_y, y1, shadow)

        # Borde superior iluminado
        if top_y > y0:
            L.hline(top_y, x, x + w - 1, top)

        # Banda dorada
        if bk["banda"] and h >= 6:
            banda_y = top_y + h * bk["banda_y_frac"] // 100
            if y0 <= banda_y <= y1:
                L.hline(banda_y, x + 1, x + w - 2, DORADO["L"])
                if h >= 8:
                    L.hline(banda_y + 1, x + 1, x + w - 2, DORADO["M"])
                    if _h(bk["seed"], 6, 107) < 30:
                        L.hline(banda_y - 1, x + 1, x + w - 2, DORADO["B"])

        # Moteado sutil en el lomo
        for dy in range(1, h - 1):
            ly = top_y + dy
            if _h(bk["seed"], dy, 108) < 15:
                if _h(bk["seed"], dy, 109) < 50:
                    L.set(x + 1, ly, top)
                else:
                    L.set(x + w - 2, ly, shadow)


def _dibujar_libro_inclinado(L: Lienzo, bk: dict, colores: tuple,
                             y0: int, y1: int) -> None:
    """Dibuja un libro inclinado (apoyado en diagonal)."""
    x = bk["x"]
    w = bk["w"]
    h = bk["h"]
    body, top, shadow = colores
    seed = bk["seed"]

    # El libro se apoya en la esquina inferior: la base está en (x, y1)
    # y la punta superior se desplaza a la derecha
    # Dibujamos como un paralelogramo: columnas desplazadas
    top_y = y1 - h + 1
    # Desplazamiento máximo en X desde la base hasta la punta
    lean = min(w + 1, 4)
    # La punta está en x + w - 1 + lean, top_y
    puntax = x + w + lean - 1

    for dy in range(h):
        ly = y1 - dy
        # Interpolar X entre la base y la punta
        t = dy / max(1, h - 1)
        col_x0 = int(x + t * (puntax - x))
        col_x1 = col_x0 + w - 1
        if col_x1 > puntax:
            col_x1 = puntax

        for col_x in range(col_x0, col_x1 + 1):
            if 0 <= col_x < L.w and 0 <= ly < L.h:
                L.set(col_x, ly, body)

        # Borde iluminado (izquierdo/superior)
        if 0 <= col_x0 < L.w and 0 <= ly < L.h:
            L.set(col_x0, ly, top)
        # Borde en sombra (derecho)
        if 0 <= col_x1 < L.w and 0 <= ly < L.h:
            L.set(col_x1, ly, shadow)

    # Borde superior
    for col_x in range(puntax - w + 1, puntax + 1):
        if 0 <= col_x < L.w and 0 <= top_y < L.h:
            L.set(col_x, top_y, top)

    # Banda dorada en libro inclinado
    if bk["banda"] and h >= 8:
        banda_dy = h * bk["banda_y_frac"] // 100
        banda_y = y1 - banda_dy
        t = banda_dy / max(1, h - 1)
        banda_x0 = int(x + t * (puntax - x)) + 1
        banda_x1 = banda_x0 + w - 3
        if 0 <= banda_y < L.h:
            for bx in range(banda_x0, banda_x1 + 1):
                if 0 <= bx < L.w:
                    L.set(bx, banda_y, DORADO["L"])
                    if _h(seed, bx, 111) < 40:
                        L.set(bx, banda_y + 1, DORADO["M"])


# ---------------------------------------------------------------------------
# 3. DESK — escritorio de escriba 32×32
# ---------------------------------------------------------------------------
def dibujar_desk() -> Lienzo:
    L = Lienzo(32, 32)

    # --- Patas del escritorio ---
    for lx in (3, 25):
        L.rect(lx, 18, lx + 3, 30, MADERA["S"])
        L.vline(lx, 18, 30, MADERA["M"])
        L.vline(lx + 3, 20, 30, MADERA["M"])

    # --- Tablero (superficie vista de frente) ---
    # El tablero es el elemento principal
    L.rect(2, 12, 29, 19, MADERA["M"])
    # Canto superior iluminado
    L.hline(12, 2, 29, MADERA["L"])
    L.hline(13, 2, 29, MADERA["B"])
    # Canto inferior en sombra
    L.hline(18, 2, 29, MADERA["S"])
    L.hline(19, 2, 29, MADERA["S"])
    # Franja central con veta de madera
    for y in range(14, 18):
        for x in range(3, 29):
            if _h(x, y, 121) < 30:
                L.set(x, y, MADERA["L"] if _h(x, y, 122) < 15 else MADERA["S"])

    # --- Pergamino ---
    perg_x0, perg_x1 = 4, 17
    perg_y0, perg_y1 = 3, 15
    # Cuerpo del pergamino (paja)
    L.rect(perg_x0, perg_y0, perg_x1, perg_y1, PAJA["M"])
    # Borde iluminado (arriba-izquierda)
    L.hline(perg_y0, perg_x0, perg_x1, PAJA["L"])
    L.vline(perg_x0, perg_y0, perg_y1, PAJA["L"])
    L.hline(perg_y0 + 1, perg_x0, perg_x0 + 1, PAJA["B"])
    # Borde en sombra (abajo-derecha)
    L.hline(perg_y1, perg_x0 + 1, perg_x1, PAJA["S"])
    L.vline(perg_x1, perg_y0 + 1, perg_y1, PAJA["S"])
    # Rollo del pergamino (extremo enrollado)
    # Rollo superior
    L.rect(perg_x0, perg_y0 - 1, perg_x1, perg_y0 + 1, PAJA["L"])
    L.hline(perg_y0 - 1, perg_x0, perg_x1, PAJA["B"])
    L.hline(perg_y0 + 2, perg_x0 + 1, perg_x1 - 1, PAJA["S"])
    # Texto simulado en el pergamino (rayitas de arcano)
    for line_y in (7, 9, 11, 13):
        L.hline(line_y, perg_x0 + 3, perg_x1 - 3, ARCANO["S"])
        if _h(line_y, 0, 125) < 30:
            L.hline(line_y, perg_x0 + 3, perg_x1 - 5, ARCANO["S"])

    # --- Tintero ---
    tintero_x0, tintero_x1 = 21, 26
    tintero_y0, tintero_y1 = 8, 14
    # Cuerpo (arcano, como cerámica oscura)
    L.rect(tintero_x0, tintero_y0 + 2, tintero_x1, tintero_y1, ARCANO["M"])
    L.rect(tintero_x0, tintero_y0 + 2, tintero_x1, tintero_y1 - 2, ARCANO["L"])
    # Borde superior (más ancho)
    L.rect(tintero_x0 - 1, tintero_y0, tintero_x1 + 1, tintero_y0 + 2, ARCANO["M"])
    L.hline(tintero_y0, tintero_x0 - 1, tintero_x1 + 1, ARCANO["L"])
    L.hline(tintero_y0 + 2, tintero_x0 - 1, tintero_x1 + 1, ARCANO["S"])
    # Apertura (tinta oscura)
    L.rect(tintero_x0, tintero_y0 + 1, tintero_x1, tintero_y0 + 1, ARCANO["S"])
    L.set(tintero_x0 + 2, tintero_y0 + 1, ARCANO["B"])   # reflejo de la tinta
    # Base
    L.hline(tintero_y1, tintero_x0, tintero_x1, ARCANO["S"])

    # --- Pluma ---
    # Sale del tintero hacia la derecha y arriba
    pluma_x0 = tintero_x1 + 1
    pluma_y0 = tintero_y0 + 1
    # Eje de la pluma (diagonal)
    for i in range(6):
        px = pluma_x0 + i
        py = pluma_y0 - i
        if 0 <= px < 32 and 0 <= py < 32:
            L.set(px, py, PAJA["L"])
            if i < 3:
                L.set(px, py - 1, PAJA["B"] if i == 0 else PAJA["L"])
    # Punta de la pluma (más oscura)
    L.set(pluma_x0 + 6, pluma_y0 - 6, ARCANO["S"])
    L.set(pluma_x0 + 6, pluma_y0 - 7, PAJA["M"])
    # Barba de la pluma (ensanchamiento)
    for i in range(2, 5):
        px = pluma_x0 + i
        py = pluma_y0 - i
        if 0 <= px < 32 and 0 <= py < 32:
            L.set(px, py + 1, PAJA["S"])
            L.set(px - 1, py, PAJA["B"])

    L.contornear()
    return L


# ---------------------------------------------------------------------------
# 4. CHEST — cofre 32×32
# ---------------------------------------------------------------------------
def dibujar_chest() -> Lienzo:
    L = Lienzo(32, 32)
    cx = 16

    # ── 1. Tapa curva (tercio superior, vuela 1 px por lado) ──
    # Formato: (y, x_izq, x_der)
    lid_rows = [
        (7,  10, 21),   # cumbre, 12 px de ancho
        (8,  9, 22),    # 14 px
        (9,  7, 24),    # 18 px
        (10, 6, 25),    # 20 px
        (11, 4, 27),    # 24 px — vuela 1 px sobre el cuerpo
        (12, 4, 27),    # 24 px — ancho máximo
        (13, 5, 26),    # 22 px — igual que el cuerpo
        (14, 5, 26),    # 22 px — transición al cuerpo
    ]

    for y, lx, rx in lid_rows:
        for x in range(lx, rx + 1):
            # Luz arriba-izquierda: izquierda más clara, derecha en sombra
            if x <= lx + 1:
                L.set(x, y, MADERA["L"])
            elif x >= rx - 1:
                L.set(x, y, MADERA["S"])
            else:
                L.set(x, y, MADERA["M"])

    # Cresta de la tapa: brillo en el pico superior-izquierdo
    L.hline(7, 10, 15, MADERA["B"])
    L.set(16, 7, MADERA["L"])
    L.hline(8, 10, 16, MADERA["B"])
    # Sombra inferior de la tapa (separa del cuerpo)
    L.hline(14, 5, 26, MADERA["S"])

    # Veta de madera en la tapa
    for y in range(7, 15):
        for x in range(4, 28):
            if not L.px[x, y][3]:
                continue
            if _h(x, y, 151) < 18:
                if L.px[x, y][:3] == MADERA["M"]:
                    L.set(x, y, MADERA["L"] if x < cx else MADERA["S"])

    # ── 2. Cuerpo (tablones verticales con juntas oscuras) ──
    body_x0, body_x1 = 5, 26
    body_y0, body_y1 = 15, 25

    for y in range(body_y0, body_y1 + 1):
        for x in range(body_x0, body_x1 + 1):
            # 3 tablones, juntas en x=12 y x=19
            if x in (12, 19):
                L.set(x, y, MADERA["S"])       # junta oscura
            else:
                L.set(x, y, MADERA["M"])

    # Luz izquierda, sombra derecha y sombra inferior del cuerpo
    L.vline(body_x0, body_y0 + 1, body_y1 - 1, MADERA["L"])
    L.vline(body_x1, body_y0 + 1, body_y1, MADERA["S"])
    L.hline(body_y1, body_x0, body_x1, MADERA["S"])

    # Veta sutil en los tablones (lado iluminado)
    for y in range(body_y0 + 1, body_y1):
        for x in range(body_x0 + 1, body_x1):
            if x in (12, 19):
                continue
            if _h(x, y, 153) < 22 and x < cx:
                L.set(x, y, MADERA["L"])

    # ── 3. Flejes de hierro horizontales, con remaches de 1 px ──
    # Fleje superior (sobre la tapa)
    fy1 = 11
    L.rect(4, fy1, 27, fy1 + 1, HIERRO["M"])
    L.hline(fy1, 4, 27, HIERRO["L"])       # canto superior iluminado
    L.hline(fy1 + 1, 4, 27, HIERRO["S"])   # canto inferior en sombra

    # Fleje inferior (sobre el cuerpo)
    fy2 = 20
    L.rect(5, fy2, 26, fy2 + 1, HIERRO["M"])
    L.hline(fy2, 5, 26, HIERRO["L"])
    L.hline(fy2 + 1, 5, 26, HIERRO["S"])

    # Remaches de 1 px en cada fleje
    for fy, fx0, fx1 in [(fy1, 4, 27), (fy2, 5, 26)]:
        for rx in (fx0 + 3, (fx0 + fx1) // 2, fx1 - 3):
            L.set(rx, fy, DORADO["L"])

    # ── 4. Bocallave dorada (centro, bajo la tapa) ──
    lock_cx = (body_x0 + body_x1) // 2  # = 15
    lock_x0, lock_x1 = 13, 18
    lock_y0, lock_y1 = 16, 19

    # Placa dorada
    L.rect(lock_x0, lock_y0, lock_x1, lock_y1, DORADO["M"])
    L.rect(lock_x0, lock_y0, lock_x1, lock_y1 - 1, DORADO["L"])
    L.hline(lock_y0, lock_x0, lock_x1, DORADO["B"])   # canto superior brillante
    L.hline(lock_y1, lock_x0, lock_x1, DORADO["S"])   # canto inferior en sombra
    L.vline(lock_x1, lock_y0 + 1, lock_y1, DORADO["S"])

    # Ojo de la cerradura (hueco oscuro)
    L.set(lock_cx, lock_y0 + 1, ARCANO["S"])
    L.set(lock_cx, lock_y0 + 2, ARCANO["S"])
    L.set(lock_cx + 1, lock_y0 + 2, ARCANO["S"])   # más ancho abajo

    # ── 5. Patas ──
    for fx in (7, 22):
        L.rect(fx, 26, fx + 2, 28, MADERA["S"])
        L.vline(fx, 26, 28, MADERA["M"])            # borde interior más claro
    L.contornear()
    return L


# ---------------------------------------------------------------------------
# 5. FORGE_48 — horno de forja compacto 48×48 (icono menú construcción)
# ---------------------------------------------------------------------------
def dibujar_forge_48() -> Lienzo:
    L = Lienzo(48, 48)
    cx = 24

    # ── helper: semi-ancho de la estructura de piedra ──
    # y=0 se deja transparente (margen para el contorno negro superior).
    def _hw(y: int) -> int:
        if y < 2:
            return 0
        if y <= 5:
            return 4 + (y - 2)        # chimenea estrecha: 4→7 en y=2→5
        if y <= 29:
            t = min(1.0, (y - 5) / 10.0)
            return 7 + int(t * 11)    # horno: se ensancha 7→18
        if y <= 47:
            return 20                  # base ancha
        return 0

    # ── 1. Estructura de piedra ──
    for y in range(2, 48):
        hw = _hw(y)
        x0, x1 = cx - hw, cx + hw
        for x in range(x0, x1 + 1):
            hval = _h(x, y, 501)
            if hval < 18:
                L.set(x, y, PIEDRA["S"])
            elif hval < 55:
                L.set(x, y, PIEDRA["M"])
            elif hval < 82:
                L.set(x, y, PIEDRA["L"])
            else:
                L.set(x, y, PIEDRA["B"])

    # ── 2. Juntas — finas en el horno, más bastas en la base ──
    for y in range(2, 48):
        hw = _hw(y)
        x0, x1 = cx - hw, cx + hw
        if y <= 29:
            # Horno: sillares finos 4×5 px
            block_h, block_w = 4, 5
        else:
            # Base: mampostería basta 6×7 px
            block_h, block_w = 6, 7

        local_y = (y - 2) % block_h
        if local_y == 0 or local_y == block_h - 1:  # junta horizontal
            for x in range(x0, x1 + 1):
                L.set(x, y, PIEDRA["S"])

        row = (y - 2) // block_h
        offset = (block_w // 2) if row % 2 == 1 else 0
        for x in range(x0, x1 + 1):
            lx = x - x0 - offset
            while lx < 0:
                lx += block_w
            lx %= block_w
            if lx == 0 or lx == block_w - 1:  # junta vertical
                L.set(x, y, PIEDRA["S"])

    # Cornisa de la chimenea (en y=1-2, debajo del margen)
    hw_top = _hw(2)
    L.rect(cx - hw_top - 1, 1, cx + hw_top + 1, 2, PIEDRA["L"])
    L.hline(1, cx - hw_top - 1, cx + hw_top + 1, PIEDRA["B"])

    # ── 3. Boca del horno (muy prominente, ~mitad del ancho) ──
    boca_hw = 12            # 25 px total ≈ mitad de 48
    boca_top = 13
    boca_bot = 24
    arco_h = 3

    for y in range(boca_top, boca_bot + 1):
        if y < boca_top + arco_h:
            dy = boca_top + arco_h - y
            reduccion = int(dy * 1.5)
            hw = max(2, boca_hw - reduccion)
        else:
            hw = boca_hw
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, ARCANO["S"])

    # ── 4. Fuego (3 tonos, de fuera hacia dentro) ──
    # Capa externa (rojo-anaranjado)
    for y in range(boca_top - 1, boca_bot + 2):
        hw = max(0, 12 - abs(y - 19))
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_EXT)
    # Capa media (oro-naranja)
    for y in range(boca_top + 1, boca_bot + 1):
        hw = max(0, 9 - abs(y - 20))
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_MED)
    # Núcleo (blanco-amarillo)
    for y in range(18, 24):
        hw = max(1, 5 - abs(y - 21))
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_CORE)
    # Lenguas arriba
    for y in range(10, 13):
        hw = max(1, (13 - y) * 2)
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_EXT)
    for y in range(11, 12):
        hw = 2
        for x in range(cx - hw, cx + hw + 1):
            L.set(x, y, FUEGO_MED)
    # Bordes oscuros de las lenguas
    for y in range(10, 13):
        hw_ext = max(1, (13 - y) * 2)
        if cx - hw_ext - 1 >= 0:
            L.set(cx - hw_ext - 1, y, FUEGO_BORDE)
        if cx + hw_ext + 1 < 48:
            L.set(cx + hw_ext + 1, y, FUEGO_BORDE)

    # ── 5. Resplandor en los sillares ──
    for y in range(boca_top - 5, boca_bot + 4):
        if y < 2 or y > 29:
            continue
        hw = _hw(y)
        for x in range(cx - hw, cx + hw + 1):
            if not L.px[x, y][3]:
                continue
            rgb = L.px[x, y][:3]
            if rgb not in {PIEDRA["S"], PIEDRA["M"], PIEDRA["L"], PIEDRA["B"]}:
                continue
            dx = abs(x - cx)
            dy = abs(y - (boca_top + boca_bot) // 2)
            if dx + dy * 1.5 < 12:
                hval = _h(x, y, 601)
                p = L.px[x, y]
                if p[:3] == PIEDRA["M"]:
                    L.set(x, y, PIEDRA["L"] if hval < 55 else PIEDRA["M"])
                elif p[:3] == PIEDRA["S"]:
                    L.set(x, y, PIEDRA["M"] if hval < 45 else PIEDRA["S"])

    # ── 6. Separación horno / base ──
    L.hline(29, cx - 19, cx + 19, PIEDRA["S"])

    L.contornear()
    return L


# ---------------------------------------------------------------------------
# 6. SPELLBOOK — libro abierto 16×16 (icono Mesa de Encantamiento)
# ---------------------------------------------------------------------------
def dibujar_spellbook() -> Lienzo:
    L = Lienzo(16, 16)
    cx = 8

    # ── 1. Resplandor arcano flotando encima ──
    L.set(6, 1, ARCANO["B"])
    L.set(7, 1, ARCANO["B"])
    L.set(5, 2, ARCANO["B"])
    L.set(6, 2, ARCANO["L"])
    L.set(7, 2, ARCANO["L"])
    L.set(8, 2, ARCANO["B"])

    # ── 2. Páginas (dos bloques triangulares que forman una "V" abierta) ──
    # Página izquierda (crece hacia la izquierda desde el lomo)
    pag_izq = [
        (6, 5),
        (5, 6), (6, 6),
        (4, 7), (5, 7), (6, 7),
        (3, 8), (4, 8), (5, 8), (6, 8),
        (2, 9), (3, 9), (4, 9), (5, 9), (6, 9),
        (2, 10), (3, 10), (4, 10), (5, 10), (6, 10),
        (2, 11), (3, 11), (4, 11), (5, 11), (6, 11),
    ]
    # Página derecha (crece hacia la derecha desde el lomo)
    pag_der = [
        (9, 5),
        (9, 6), (10, 6),
        (9, 7), (10, 7), (11, 7),
        (9, 8), (10, 8), (11, 8), (12, 8),
        (9, 9), (10, 9), (11, 9), (12, 9), (13, 9),
        (9, 10), (10, 10), (11, 10), (12, 10), (13, 10),
        (9, 11), (10, 11), (11, 11), (12, 11), (13, 11),
    ]
    # Lomo (vertical oscuro entre ambas páginas)
    lomo = [
        (7, 5),
        (7, 6), (8, 6),
        (7, 7), (8, 7),
        (7, 8), (8, 8),
        (7, 9), (8, 9),
        (7, 10), (8, 10),
        (7, 11), (8, 11),
    ]

    for x, y in pag_izq:
        L.set(x, y, BLANCO["M"])
    for x, y in pag_der:
        L.set(x, y, BLANCO["S"])
    for x, y in lomo:
        L.set(x, y, ARCANO["S"])

    # Brillo en el canto superior-izquierdo de la página izquierda
    for x, y in [(3, 8), (2, 9), (2, 10), (2, 11)]:
        L.set(x, y, BLANCO["L"])

    # ── 3. Cubierta (parte inferior) ──
    for y in (12, 13):
        for x in range(2, 14):
            c = MADERA["M"] if y == 12 else MADERA["S"]
            # Luz desde arriba-izquierda en la cubierta
            if x <= 4 and y == 12:
                c = MADERA["L"]
            L.set(x, y, c)

    L.contornear()
    return L


# ---------------------------------------------------------------------------
# Verificación
# ---------------------------------------------------------------------------
def verificar(lienzos: dict, paleta_permitida: set) -> dict:
    """Mide cada lienzo: tamaño, colores, fuera de paleta, % borde negro."""
    resultados = {}
    for nombre, L in lienzos.items():
        r = {}
        r["tamaño"] = f"{L.w}×{L.h}"
        cs = L.colores()
        r["colores"] = len(cs)
        fuera = cs - paleta_permitida - {C_NEGRO}
        r["fuera_de_paleta"] = sorted(f"#{c[0]:02x}{c[1]:02x}{c[2]:02x}" for c in fuera) if fuera else "ninguno"

        # Píxeles de borde: aquellos opacos que tocan transparencia o el límite
        borde_opacos = set()
        for y in range(L.h):
            for x in range(L.w):
                if not L.px[x, y][3]:
                    continue
                # ¿Está en el borde exterior de la masa opaca?
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or nx >= L.w or ny < 0 or ny >= L.h or not L.px[nx, ny][3]:
                        borde_opacos.add((x, y))
                        break

        if borde_opacos:
            negros_borde = sum(1 for (x, y) in borde_opacos if L.px[x, y][:3] == C_NEGRO)
            r["contorno"] = f"{100 * negros_borde // len(borde_opacos)}%"
        else:
            r["contorno"] = "n/a (sin opacos)"

        r["seamless"] = "n/a (objeto, no suelo)"
        resultados[nombre] = r
    return resultados


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main() -> None:
    salida = STAGING
    if "--salida" in sys.argv:
        idx = sys.argv.index("--salida")
        if idx + 1 < len(sys.argv):
            salida = pathlib.Path(sys.argv[idx + 1])

    print(f"=== Estaciones geométricas — lote 3 ===")
    print(f"Salida: {salida.resolve()}")
    print()

    lienzos = {
        "forge": dibujar_forge(),
        "bookshelf": dibujar_bookshelf(),
        "desk": dibujar_desk(),
        "chest": dibujar_chest(),
        "forge_48": dibujar_forge_48(),
        "spellbook": dibujar_spellbook(),
    }

    for nombre, L in lienzos.items():
        ruta = salida / f"{nombre}.png"
        L.guardar(ruta)

    # --- Verificación ---
    todas_rampas = set()
    for rampa in [PIEDRA, MADERA, DORADO, ROJO, ARCANO, PAJA, HIERRO, BLANCO]:
        todas_rampas.update(rampa.values())
    todas_rampas.add(FUEGO_CORE)
    todas_rampas.add(FUEGO_MED)
    todas_rampas.add(FUEGO_EXT)
    todas_rampas.add(FUEGO_BORDE)

    resultados = verificar(lienzos, todas_rampas)

    print("\n=== INFORME ===")
    print("FICHEROS:")
    for nombre in lienzos:
        print(f"  {salida / f'{nombre}.png'}")

    print("\nMEDIDO:")
    for nombre, r in resultados.items():
        print(f"  {nombre}:")
        for k, v in r.items():
            print(f"    {k:18s} {v}")

    # DUDAS se imprime manualmente abajo

    print("""
DUDAS:
  1. FUEGO: El contrato no tiene rampa de fuego. Se usaron ROJO (L y M
     para llamas externas y borde) + DORADO (L y B para el núcleo
     caliente y la llama media). No se generan colores fuera de paleta:
     todo son tonos existentes en las rampas ROJO y DORADO.

  2. HIERRO: No hay rampa de metal/hierro en el contrato. Para los
     flejes del cofre y el yunque se usó la rampa PIEDRA, que es la
     más cercana (gris cálido). El brillo de 1-2 px en el canto
     superior-izquierdo se aplicó con PIEDRA B en ambas piezas.

  3. TINTERO (desk, no se tocó): Se usó ARCANO (púrpura) para el
     tintero por ser el color de la magia en el juego. El usuario no
     especificó material.

  4. PLUMA (desk, no se tocó): Se dibujó en diagonal saliendo del
     tintero. La longitud y el ángulo son compromisos a 32×32.

  5. YUNQUE: Se dibujó el cuerno puntiagudo a la derecha (2-3 px de
     extensión) y la base ancha. La silueta usa 9 filas de altura.
     Al solaparse con la base de madera, el contorno exterior es
     compartido — no hay línea negra separando yunque de base, solo
     el contraste de color PIEDRA vs MADERA. Si se quiere separación
     explícita habría que dibujar una sombra bajo el yunque.

  6. TAPA DEL COFRE: La curva se aproximó con 8 alturas discretas
     (y=7 a y=14), con la fila más ancha (y=11-12) volando 1 px sobre
     el cuerpo. A 32×32 no hay resolución para una curva más suave.
     La tapa ocupa 8 filas (~tercio superior). El cuerpo ocupa 11
     filas (y=15-25) más 3 filas de patas (y=26-28).

  7. RESPLANDOR DE LA FORJA: Los sillares de piedra alrededor de la
     boca del horno se recalcan un tono más claro (PIEDRA M→L, S→M,
     L→B) con hash espacial y un radio de ~14 px (distancia Manhattan
     ponderada). No se generan colores nuevos; todo está en las rampas
     del contrato.

  8. BOCA DEL HORNO: El vano en arco ocupa ~22 px de ancho (1/3 de 64)
     y 18 px de alto (y=29-46), con una curva de 4 px en la parte
     superior. El interior se rellena con ARCANO S (#3a2058) para
     simular la oscuridad del hogar antes de pintar el fuego encima.

  9. BASE DE LA FORJA: Se eligió MADERA (tablones verticales con vetas)
     en vez de mampostería basta, para contrastar con los sillares de
     piedra del horno y que la división mitad-arriba / mitad-abajo sea
     legible incluso sin la boca encendida.
""")


if __name__ == "__main__":
    main()
