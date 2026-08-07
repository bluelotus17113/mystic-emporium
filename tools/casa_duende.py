#!/usr/bin/env python3
"""Dibuja la Casa de Duendes: cabaña ancha 128×96, estilo Minish.

Sustituye a la seta 96×96. El formato ancho es deliberado: a 96×96 el sprite tenía
la misma silueta vertical que un árbol o un prop cualquiera y no se leía como
EDIFICIO. Una fachada más ancha que alta sí.

Contrato (art_reference/paleta_minish.png, 28 colores):
  - vista FRONTAL (fachada + sombra de contacto), nunca 3/4 ni isométrica
  - contorno 1 px #21181b por debajo de los rellenos
  - shading plano de 2-3 tonos, cartoon, sin degradados

Anclajes que NO son libres — vienen de la escena y del script de la casa:
  - CELL_SIZE 32 → 128×96 = huella de 4×3 celdas
  - el Sprite2D está centrado con offset (0,-8): y_imagen = y_nodo + 56
  - worker_house.gd pone el brillo nocturno en y_nodo=+18 → y_imagen 74: ahí van
    puerta y ventanas, o el resplandor cae sobre pared ciega
  - el humo sale en y_nodo=-74 → y_imagen -18, por encima del sprite: la chimenea
    tiene que estar arriba del todo para que el humo parezca salir de ella
  - la puerta se pisa en y_nodo=+46 → y_imagen 102, justo bajo el borde inferior

    python3 tools/casa_duende.py [--salida <ruta.png>]
"""
import pathlib
import sys

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "godot/art/sprites/environment/decoration_worker_house.png"
W, H = 128, 96

# Sacados de art_reference/paleta_minish.png. Si un color no está ahí, no se usa.
NEGRO = (0x21, 0x18, 0x1B)
PAJA_L = (0xFF, 0xD1, 0x96)
PAJA_M = (0xFE, 0xAE, 0x70)
PAJA_D = (0xEE, 0x9E, 0x57)
PAJA_S = (0xAB, 0x51, 0x30)
MADERA_L = (0xBD, 0x6A, 0x62)
MADERA_M = (0xB1, 0x5D, 0x52)
MADERA_D = (0x75, 0x30, 0x27)
PIEDRA_L = (0xA3, 0xA7, 0xC2)
PIEDRA_D = (0x65, 0x6E, 0x97)
VENTANA = (0xFF, 0xD1, 0x96)
VENTANA_L = (0xF5, 0xFF, 0xE8)
PUERTA = (0x52, 0x33, 0x3F)
PUERTA_L = (0x75, 0x30, 0x27)
HIERBA_M = (0x63, 0xAB, 0x3E)
HIERBA_D = (0x3B, 0x7D, 0x4F)
HIERBA_L = (0xC8, 0xD4, 0x5D)


def _lienzo() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _h(x: int, y: int, s: int = 0) -> int:
    """Hash espacial 0..99. La piedra se motea con esto y no con `(x+y) % 2`:
    el damero se lee como tablero de ajedrez, no como mampostería."""
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100


def rect(px, x0, y0, x1, y1, c) -> None:
    """Relleno inclusivo, recortado al lienzo."""
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            px[x, y] = c + (255,)


def _tejado_ancho(y: int) -> int:
    """Medio ancho del tejado a cada altura: trapecio con alero que vuela."""
    if y < 10:
        return 0
    t = (y - 10) / 34.0  # 0 en la cumbrera, 1 en el alero
    return int(30 + t * 32)


def dibujar() -> Image.Image:
    im = _lienzo()
    px = im.load()
    cx = W // 2

    # --- cuerpo: pared de madera ------------------------------------------
    # Va primero para que el tejado la tape por arriba, no al revés.
    rect(px, 16, 46, W - 17, 87, MADERA_M)
    for y in range(46, 88):  # junta de tablón cada 9 px, no raya cada 5
        for x in range(16, W - 16):
            if (x - 16) % 9 == 0:
                px[x, y] = MADERA_D + (255,)
    # El alero vuela por encima, así que proyecta una banda de sombra sobre la
    # pared. Es lo que separa tejado y cuerpo sin tener que meter una línea negra.
    rect(px, 16, 46, W - 17, 51, MADERA_D)
    rect(px, 16, 52, W - 17, 53, MADERA_L)          # canto iluminado bajo la sombra
    rect(px, 16, 84, W - 17, 87, MADERA_D)          # zócalo en sombra

    # --- zócalo de piedra --------------------------------------------------
    rect(px, 14, 80, W - 15, 87, PIEDRA_D)
    for y in range(80, 88):
        for x in range(14, W - 14):
            if _h(x // 3, y // 2, 7) < 45:
                px[x, y] = PIEDRA_L + (255,)

    # --- tejado de paja ----------------------------------------------------
    for y in range(10, 45):
        a = _tejado_ancho(y)
        rect(px, cx - a, y, cx + a - 1, y, PAJA_M)
    for y in range(10, 45):  # mechones: bandas verticales alternas
        a = _tejado_ancho(y)
        for x in range(cx - a, cx + a):
            m = (x * 7 + (y // 6) * 3) % 11
            if m < 3:
                px[x, y] = PAJA_D + (255,)
            elif m > 8:
                px[x, y] = PAJA_L + (255,)
    # La paja se coloca en hiladas superpuestas; sin ellas el tejado se lee como
    # tablones verticales y no como techo de paja.
    for y in (20, 30, 39):
        a = _tejado_ancho(y)
        rect(px, cx - a, y, cx + a - 1, y, PAJA_S)
        a2 = _tejado_ancho(y + 1)
        rect(px, cx - a2, y + 1, cx + a2 - 1, y + 1, PAJA_L)
    for y in range(10, 16):  # la cumbrera recibe la luz de arriba-izquierda
        a = _tejado_ancho(y)
        rect(px, cx - a, y, cx - a + 12, y, PAJA_L)
    a = _tejado_ancho(44)
    rect(px, cx - a, 41, cx + a - 1, 44, PAJA_S)    # alero en sombra
    for x in range(cx - a, cx + a, 4):              # borde dentado de la paja
        rect(px, x, 45, x + 1, 46, PAJA_S)

    # --- chimenea ----------------------------------------------------------
    rect(px, 88, 2, 102, 22, PIEDRA_D)
    for y in range(2, 23):
        for x in range(88, 103):
            if _h(x // 3, y // 2, 13) < 42:
                px[x, y] = PIEDRA_L + (255,)
    rect(px, 86, 0, 104, 4, PIEDRA_L)               # remate

    # --- puerta ------------------------------------------------------------
    rect(px, cx - 11, 60, cx + 10, 87, PUERTA)
    rect(px, cx - 11, 60, cx + 10, 62, PUERTA_L)    # dintel
    for y in range(58, 61):                         # arco
        d = 60 - y
        rect(px, cx - 11 + d * 2, y, cx + 10 - d * 2, y, PUERTA)
    for y in range(63, 88):                         # tablas
        for x in range(cx - 11, cx + 11):
            if (x - cx) % 7 == 0:
                px[x, y] = PUERTA_L + (255,)
    rect(px, cx + 5, 72, cx + 6, 74, PAJA_L)        # pomo

    # --- ventanas ----------------------------------------------------------
    for x0 in (26, W - 45):
        rect(px, x0, 56, x0 + 18, 72, VENTANA)
        rect(px, x0, 56, x0 + 18, 58, VENTANA_L)    # reflejo arriba
        rect(px, x0 + 8, 56, x0 + 10, 72, MADERA_D)  # parteluz vertical
        rect(px, x0, 63, x0 + 18, 65, MADERA_D)      # parteluz horizontal
        rect(px, x0 - 2, 53, x0 + 20, 55, MADERA_D)  # alfeizar superior
        rect(px, x0 - 2, 73, x0 + 20, 75, MADERA_D)  # alfeizar inferior

    # --- matas a los pies --------------------------------------------------
    # Rompen la línea recta del zócalo y asientan la casa en el suelo. Van a los
    # lados y NO delante de la puerta: ahí pisan los duendes al entrar.
    for x0, alto in ((2, 15), (14, 10), (W - 14, 15), (W - 26, 11), (cx + 30, 8),
                     (cx - 40, 9)):
        for i in range(6):
            h = alto - abs(i - 2) * 3
            if h <= 0:
                continue
            rect(px, x0 + i * 2, 92 - h, x0 + i * 2 + 1, 93, HIERBA_M)
            rect(px, x0 + i * 2, 92 - h, x0 + i * 2 + 1, 93 - h + 1, HIERBA_L)
            px[x0 + i * 2 + 1, 93] = HIERBA_D + (255,)
    rect(px, 8, 91, W - 9, 94, HIERBA_D)            # sombra de contacto

    _contornear(px)
    return im


def _contornear(px) -> None:
    """Contorno sticker de 1 px POR DEBAJO: solo pinta píxeles transparentes que
    tocan relleno, así no se come un píxel del dibujo."""
    borde = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3]:
                    borde.append((x, y))
                    break
    for x, y in borde:
        px[x, y] = NEGRO + (255,)


def main() -> None:
    destino = DESTINO
    if "--salida" in sys.argv:
        destino = pathlib.Path(sys.argv[sys.argv.index("--salida") + 1])
    im = dibujar()
    destino.parent.mkdir(parents=True, exist_ok=True)
    im.save(destino)
    colores = {p[:3] for p in im.get_flattened_data() if p[3]}
    print(f"{destino}  {im.size[0]}×{im.size[1]}  {len(colores)} colores")


if __name__ == "__main__":
    main()
