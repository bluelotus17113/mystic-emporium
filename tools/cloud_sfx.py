#!/usr/bin/env python3
"""Sonido del viaje entre zonas: una ráfaga de viento que sube y se va.

Acompaña al telón de nubes. Es ruido filtrado paso bajo con la frecuencia de
corte subiendo y bajando, más un soplo grave por debajo; nada de tono musical,
porque tiene que sonar a aire y no a efecto de menú.

    python3 tools/cloud_sfx.py
"""
import pathlib
import struct
import wave

import numpy as np

DEST = pathlib.Path(__file__).resolve().parent.parent / "godot/audio/sfx/cloud_travel.wav"
SR = 44100
DUR = 1.6


def paso_bajo(x, corte):
    """Un polo, con el corte variando muestra a muestra. En bucle de Python
    tardaría segundos; con el filtro recursivo vectorizado por tramos basta."""
    a = np.exp(-2.0 * np.pi * corte / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1.0 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def main():
    n = int(SR * DUR)
    t = np.linspace(0.0, DUR, n, endpoint=False)
    rng = np.random.default_rng(11)

    # Envolvente: sube rápido, se mantiene mientras las nubes tapan y se va.
    env = np.minimum(t / 0.35, 1.0) * np.clip((DUR - t) / 0.55, 0.0, 1.0)
    env = env ** 1.3

    # El corte del filtro sigue a la envolvente: cuando más fuerte sopla, más
    # agudo. Es lo que hace que se lea como movimiento y no como un siseo.
    corte = 300.0 + 2600.0 * env

    ruido = rng.normal(0.0, 1.0, n)
    aire = paso_bajo(ruido, corte)
    aire /= np.max(np.abs(aire)) + 1e-9

    # Soplo grave: da cuerpo y peso, para que el viaje se sienta largo.
    grave = paso_bajo(rng.normal(0.0, 1.0, n), np.full(n, 110.0))
    grave /= np.max(np.abs(grave)) + 1e-9

    mezcla = (aire * 0.78 + grave * 0.42) * env * 0.55
    # Estéreo con las dos mitades desfasadas: las nubes vienen de los dos lados.
    izq = mezcla * (0.75 + 0.25 * np.sin(t * 2.1))
    der = mezcla * (0.75 + 0.25 * np.sin(t * 2.1 + np.pi))

    inter = np.empty(n * 2)
    inter[0::2] = izq
    inter[1::2] = der
    datos = np.clip(inter, -1.0, 1.0)
    pcm = (datos * 32767).astype("<i2")

    DEST.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(DEST), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{DEST.name}  {DUR:.1f}s  {DEST.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
