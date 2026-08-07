#!/usr/bin/env python3
"""Primitivas para siluetas orgánicas, y las dos medidas que las juzgan.

Existe por un fallo concreto y medido. Los generadores dibujaban con fórmulas
—`disc()`, elipses, triángulos— y el resultado pasaba las siete comprobaciones del
contrato pero parecía fabricado. Al medirlo salió por qué:

    tree_birch    20 px de canto recto seguido,  97,4 % de simetría especular
    hay_bale      10 px,                        100,0 % (exacta)
    tree_oak       8 px,                         97,4 %

Nada en la naturaleza tiene 20 px de borde recto ni es simétrico al 97 %. La
asimetría es lo que hace que una forma parezca viva.

El truco es no dibujar una elipse: dibujar un **radio distinto para cada ángulo**,
con ruido suave encima. Cada dirección tiene su bulto y el contorno deja de ser una
curva perfecta.

Todo aquí es determinista: el mismo `semilla` da el mismo resultado siempre. Sin eso
no se puede revisar en git ni reproducir un fallo.
"""
import math

import numpy as np


# ── Ruido ────────────────────────────────────────────────────────────────────

def _h(x: int, y: int, s: int = 0) -> int:
    """Hash espacial determinista, 0..99. El mismo de todo el proyecto."""
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100


def ruido_angular(angulo: float, semilla: int, armonicos: int = 3) -> float:
    """Ruido suave y periódico en el ángulo, en [-1, 1].

    Periódico de verdad: en `angulo` y en `angulo + 2π` vale lo mismo, así que el
    contorno cierra sin escalón. Con ruido no periódico aparece una muesca en el
    punto de cierre, que es un artefacto muy visible en un sprite pequeño.

    Suma unos pocos armónicos con fase y peso sacados del hash. Pocos a propósito:
    con muchos el contorno se vuelve nervioso y a 32×32 se lee como ruido, no como
    forma.
    """
    v = 0.0
    peso = 0.0
    for k in range(1, armonicos + 1):
        fase = _h(k, semilla, 17) / 100.0 * 2.0 * math.pi
        amp = 1.0 / k  # los armónicos altos pesan menos: bultos grandes, no rizos
        v += amp * math.sin(k * angulo + fase)
        peso += amp
    return v / peso if peso else 0.0


def radio_organico(angulo: float, base: float, semilla: int,
                   amplitud: float = 0.18, armonicos: int = 3) -> float:
    """Radio que se desvía de `base` según el ángulo. La pieza central.

    `amplitud` 0,18 significa que el radio oscila un ±18 % alrededor del base.
    Por debajo de 0,10 sigue pareciendo una elipse; por encima de 0,30 la forma
    se descompone y deja de reconocerse.
    """
    return base * (1.0 + amplitud * ruido_angular(angulo, semilla, armonicos))


# ── Máscaras ─────────────────────────────────────────────────────────────────

def blob(w: int, h: int, semilla: int, amplitud: float = 0.18,
         armonicos: int = 3, cx: float = None, cy: float = None) -> np.ndarray:
    """Máscara booleana de una mancha orgánica que llena el lienzo w×h.

    El centro se puede descentrar (`cx`, `cy`) para romper la simetría todavía más:
    una copa cuyo centro está un par de píxeles a la izquierda ya no puede salir
    especular por mucho ruido que lleve.
    """
    cx = (w - 1) / 2.0 if cx is None else cx
    cy = (h - 1) / 2.0 if cy is None else cy
    m = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            dx = x - cx
            dy = (y - cy) * (w / float(h))  # normaliza para lienzos no cuadrados
            d = math.hypot(dx, dy)
            if d == 0.0:
                m[y, x] = True
                continue
            r = radio_organico(math.atan2(dy, dx), min(w, h) / 2.0 - 0.5,
                               semilla, amplitud, armonicos)
            m[y, x] = d <= r
    return m


def romper_simetria(mascara: np.ndarray, semilla: int, fuerza: int = 2) -> np.ndarray:
    """Muerde el contorno de forma desigual entre izquierda y derecha.

    Para cuando ya tienes una silueta que te gusta y solo hay que quitarle el aire
    de plantilla. Usa semillas distintas por lado, que es justo lo que impide que
    el resultado vuelva a salir especular.
    """
    m = mascara.copy()
    H, W = m.shape
    for y in range(H):
        xs = np.where(m[y])[0]
        if len(xs) == 0:
            continue
        # cada lado con su semilla: si compartieran, el mordisco sería simétrico
        mi = _h(y, 0, semilla) % (fuerza + 1)
        md = _h(y, 1, semilla + 991) % (fuerza + 1)
        if mi:
            m[y, xs[0]:xs[0] + mi] = False
        if md:
            m[y, max(0, xs[-1] - md + 1):xs[-1] + 1] = False
    return m


# ── Medidas ──────────────────────────────────────────────────────────────────

def simetria(mascara: np.ndarray) -> float:
    """% de píxeles que coinciden con el reflejo horizontal. Objetivo natural ≤ 80."""
    return 100.0 * (mascara == mascara[:, ::-1]).sum() / mascara.size


def _traza_contorno(mascara: np.ndarray) -> list:
    """Píxeles del borde EN ORDEN, recorriendo el perímetro (Moore)."""
    H, W = mascara.shape
    inicio = None
    for y in range(H):
        xs = np.where(mascara[y])[0]
        if len(xs):
            inicio = (int(xs[0]), y)
            break
    if inicio is None:
        return []
    vec = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]

    def dentro(p):
        x, y = p
        return 0 <= x < W and 0 <= y < H and mascara[y, x]

    camino = [inicio]
    actual, back = inicio, 4
    for _ in range(4 * H * W):
        for k in range(8):
            d = (back + 1 + k) % 8
            sig = (actual[0] + vec[d][0], actual[1] + vec[d][1])
            if dentro(sig):
                back = (d + 4 + 1) % 8
                actual = sig
                break
        else:
            break
        if actual == inicio and len(camino) > 2:
            break
        camino.append(actual)
    return camino


def mayor_tramo_recto(mascara: np.ndarray) -> int:
    """Tramo más largo del contorno con dirección CONSTANTE. Objetivo ≤ 4.

    Ojo con la trampa que tenía la primera versión de esto: medía cuántas filas
    seguidas compartían la misma columna extrema. Pero en el punto más ancho de
    CUALQUIER forma redonda varias filas comparten columna, así que aquello
    penalizaba la redondez, no la rectitud — un círculo perfecto sacaba 20 px y
    "suspendía". Se cazó porque las propias primitivas orgánicas de este fichero
    suspendían su propia medida.

    Lo que sí delata una fórmula es un tramo de perímetro avanzando siempre en la
    misma dirección: los lados de un triángulo o de un rectángulo. Un contorno
    orgánico cambia de dirección constantemente.
    """
    c = _traza_contorno(mascara)
    if len(c) < 3:
        return 0
    mx = run = 1
    for i in range(2, len(c)):
        d1 = (c[i][0] - c[i - 1][0], c[i][1] - c[i - 1][1])
        d0 = (c[i - 1][0] - c[i - 2][0], c[i - 1][1] - c[i - 2][1])
        if d1 == d0:
            run += 1
            mx = max(mx, run)
        else:
            run = 1
    return mx


def variacion_curvatura(mascara: np.ndarray) -> float:
    """σ del radio dividida por el radio medio, desde el centroide.

    Una elipse perfecta da casi 0. Una forma orgánica, 0,08 o más. No es un
    aprobado/suspenso: es el número que distingue "tiene bultos" de "es lisa".
    """
    ys, xs = np.nonzero(mascara)
    if len(xs) == 0:
        return 0.0
    cx, cy = xs.mean(), ys.mean()
    H, W = mascara.shape
    radios = []
    for k in range(72):  # cada 5 grados
        a = k * math.pi / 36.0
        dx, dy = math.cos(a), math.sin(a)
        r = 0.0
        while True:
            x, y = int(round(cx + dx * (r + 1))), int(round(cy + dy * (r + 1)))
            if not (0 <= x < W and 0 <= y < H) or not mascara[y, x]:
                break
            r += 1
        radios.append(r)
    radios = np.array(radios, dtype=float)
    m = radios.mean()
    return float(radios.std() / m) if m > 0 else 0.0


def informe(mascara: np.ndarray) -> dict:
    """Las tres medidas de golpe, para meterlas en un print."""
    return {
        "simetria": round(simetria(mascara), 1),
        "tramo_recto": mayor_tramo_recto(mascara),
        "curvatura": round(variacion_curvatura(mascara), 3),
    }


if __name__ == "__main__":
    import sys

    from PIL import Image
    if len(sys.argv) < 2:
        raise SystemExit("uso: python3 tools/formas_organicas.py <fichero.png>…")
    for ruta in sys.argv[1:]:
        a = np.asarray(Image.open(ruta).convert("RGBA"))
        i = informe(a[:, :, 3] > 127)
        print(f"{ruta.split('/')[-1]:28} simetría {i['simetria']:5.1f}%  "
              f"recto {i['tramo_recto']:2} px  curvatura {i['curvatura']:.3f}")
