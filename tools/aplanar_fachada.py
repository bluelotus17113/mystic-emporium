#!/usr/bin/env python3
"""Quita la fuga a un edificio de PixelLab dejándolo de frente.

PixelLab dibuja edificios con mucho detalle —tejas, tablones, piedra individual—
pero **siempre en 3/4**, enseñando la pared lateral en fuga. Probado también con
`view: side`, que sale todavía más isométrico. El juego es top-down plano y ya se
rehicieron 59 sprites en su día para quitar justamente eso.

La solución que funciona: quedarse con la cara frontal y **espejarla** sobre el eje
del elemento central (la puerta, el hueco del horno, el vano). Se pierde lo que
viviese en la pared lateral —típicamente la chimenea— y el resultado sale más
estrecho, pero conserva la textura, que es lo que se venía a buscar.

El eje es el parámetro que importa y **no se adivina bien solo**: si cae 4 px a un
lado de la puerta, salen dos puertas. Por eso `--sugerir` dibuja una tira con varios
ejes candidatos para elegir mirándola, que es algo que un script no puede hacer.

    python3 tools/aplanar_fachada.py <fichero.png> --sugerir
    python3 tools/aplanar_fachada.py <fichero.png> --eje 52 [--lado der] [--suelo 6]
"""
import pathlib
import sys

from PIL import Image

NEGRO = (0, 0, 0)


def _contornear(im: Image.Image) -> Image.Image:
    """Rehace el contorno negro de 1 px por debajo. Hace falta porque el espejo y el
    recorte dejan cantos nuevos sin contorno."""
    W, H = im.size
    px = im.load()
    nuevos = [(x, y) for y in range(H) for x in range(W)
              if px[x, y][3] == 0 and any(
                  0 <= x + dx < W and 0 <= y + dy < H and px[x + dx, y + dy][3]
                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in nuevos:
        px[x, y] = NEGRO + (255,)
    return im


def aplanar(im: Image.Image, eje: int, ancho_final: int = None,
            alto_final: int = None, lado: str = "izq") -> Image.Image:
    """Espeja media fachada sobre `eje` y recentra en el lienzo original.

    `lado` decide con cuál te quedas, y no es un detalle: en un 3/4 la puerta suele
    caer en una de las dos caras. Con la mitad equivocada sale una casa sin puerta,
    que es lo que pasó al primer intento con la cabaña.
    """
    W, H = im.size
    if lado == "der":
        media = im.crop((eje, 0, W, H))
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        out.alpha_composite(media.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
        out.alpha_composite(media, (media.width, 0))
    else:
        media = im.crop((0, 0, eje, H))
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        out.alpha_composite(media, (0, 0))
        out.alpha_composite(media.transpose(Image.FLIP_LEFT_RIGHT), (eje, 0))
    bb = out.getbbox()
    if bb:
        out = out.crop(bb)
    fin = Image.new("RGBA", (ancho_final or W, alto_final or H), (0, 0, 0, 0))
    # anclado abajo y centrado: es como se colocan estos sprites en la escena
    fin.alpha_composite(out, ((fin.width - out.width) // 2, fin.height - out.height))
    return _contornear(fin)


def quitar_suelo(im: Image.Image, filas: int) -> Image.Image:
    """Borra las `filas` de abajo: la elipse de tierra que PixelLab hornea.

    La pide uno que no la ponga y la pone igual. Y hay que quitarla sí o sí, porque
    `sun_shadows.gd` ya dibuja una sombra de contacto al 30 % bajo cada prop: con las
    dos, la base sale doble.
    """
    W, H = im.size
    px = im.load()
    for y in range(H - filas, H):
        for x in range(W):
            px[x, y] = (0, 0, 0, 0)
    return im


def sugerir(ruta: pathlib.Path, ejes: list, z: int = 4, lado: str = "izq") -> pathlib.Path:
    """Tira con varios ejes candidatos, para elegir el bueno mirándola."""
    im = Image.open(ruta).convert("RGBA")
    W, H = im.size
    tira = Image.new("RGB", (len(ejes) * (W * z + 8) + 8, H * z + 8), (0x7C, 0xF2, 0xB6))
    for i, e in enumerate(ejes):
        a = aplanar(im.copy(), e, lado=lado)
        tira.paste(a.resize((W * z, H * z), Image.NEAREST),
                   (8 + i * (W * z + 8), 4), a.resize((W * z, H * z), Image.NEAREST))
    dst = ruta.with_name(ruta.stem + f"_ejes_{lado}.png")
    tira.save(dst)
    return dst


def main() -> None:
    argv = sys.argv[1:]
    args = [a for a in argv if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    ruta = pathlib.Path(args[0])
    im = Image.open(ruta).convert("RGBA")

    if "--sugerir" in argv:
        W = im.size[0]
        ejes = [int(W * f) for f in (0.34, 0.40, 0.44, 0.48, 0.52, 0.58)]
        lado = argv[argv.index("--lado") + 1] if "--lado" in argv else "izq"
        dst = sugerir(ruta, ejes, lado=lado)
        print(f"ejes probados: {ejes}")
        print(f"tira -> {dst}")
        return

    if "--eje" not in argv:
        raise SystemExit("falta --eje N (usa --sugerir para verlos)")
    eje = int(argv[argv.index("--eje") + 1])
    salida = pathlib.Path(argv[argv.index("--salida") + 1]) if "--salida" in argv else ruta
    lado = argv[argv.index("--lado") + 1] if "--lado" in argv else "izq"
    out = aplanar(im, eje, lado=lado)
    if "--suelo" in argv:
        out = _contornear(quitar_suelo(out, int(argv[argv.index("--suelo") + 1])))
    out.save(salida)
    cols = len({p[:3] for p in out.get_flattened_data() if p[3]})
    print(f"{salida.name}  {out.size[0]}×{out.size[1]}  {cols} colores  (eje {eje}, lado {lado})")


if __name__ == "__main__":
    main()
