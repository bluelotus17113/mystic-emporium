# Skill: pixel art top-down para Mystic Emporium

Esto no es teoría de pixel art en general. Es **el contrato de ESTE juego**, medido
sobre la referencia que dio el usuario, y todo número que aparece aquí salió de contar
píxeles, no de la memoria de nadie.

La fuente de verdad legible por máquina es `art_reference/contrato_rediseno.json`.
Si este texto y ese JSON se contradicen, **gana el JSON**: se genera midiendo.

---

## Lo primero, porque te va a morder

**No puedes ver imágenes.** Corres sobre un modelo de texto. No mires el PNG que
acabas de escribir esperando juzgarlo: no vas a poder. Tu trabajo es escribir el
**generador en Python** y comprobarlo **midiendo con PIL**.

Todo lo que afirmes tiene que salir de un `print()` de un script que ejecutaste.
"Creo que se ve bien" no es un resultado. "El tile repite sin costura, medido con
`np.abs(a-b).mean() == 0` en los cuatro bordes" sí lo es.

---

## El contrato, en números

| Qué | Valor | Cómo se midió |
|---|---|---|
| Tile | **16×16** px nativos | periodo de autocorrelación en la referencia = 16 en X e Y |
| Pitch | **1** (nativo) | la referencia se ve a ×4, pero el arte es 1:1 |
| Contorno | **`#000000`** negro puro, **1 px** | 83 % de las rachas negras son de 1 px |
| Contorno en suelos | **NO** | la hierba de la referencia solo tiene 3,5 % de negro, y es sombra de matas |
| Tonos por material | **3 mínimo, 4 recomendado** | las rampas medidas tienen 4 |
| Dithering | **prohibido** | la referencia no tiene ni un píxel de tramado |

El color que define el look es la hierba: **`#7cf2b6`**, una menta brillante. El juego
usaba `#63ab3e`, un verde amarillento. Ese cambio solo ya mueve la imagen entera.

Las rampas completas están en el JSON. No inventes colores: si necesitas un tono que
no está, **dilo en el informe** en vez de improvisarlo.

---

## Las cuatro reglas de composición

**1. Contorno sí en objetos, no en suelos.**
Un árbol, una valla, una casa o una roca llevan contorno negro de 1 px. Un tile de
hierba o de tierra **no**: contornear los suelos dibuja la rejilla, y 120×72 celdas con
línea negra se leen como cuadrícula, no como pradera.

**2. La luz viene de arriba-izquierda.**
Brillo en esa esquina, sombra propia abajo-derecha. Consistente en TODO. Un solo
objeto iluminado al revés canta muchísimo.

**3. Los suelos van sin costura.**
Un tile de suelo se repite cientos de veces. Si el borde derecho no encaja con el
izquierdo, se ve una rejilla. Usa aritmética modular: cualquier posición se calcula
con `x % ANCHO`, nunca con un valor absoluto que se corte en el borde.

**4. Sombra de contacto, no pedestal.**
Los objetos altos llevan una elipse oscura debajo. Una base sólida rectangular o un
rombo de suelo son el antipatrón isométrico: el juego es top-down plano.

---

## El ruido: hash espacial, nunca `(x+y) % 2`

Esto ha salido mal ya en este proyecto. Un damero se lee como **tablero de ajedrez**,
no como piedra ni como hierba. Para variación natural:

```python
def h(x: int, y: int, s: int = 0) -> int:
    """Hash espacial determinista, 0..99. Mismo (x,y,s) -> mismo valor siempre."""
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return (n ^ (n >> 16)) % 100
```

Determinista importa: el generador tiene que dar el mismo PNG en cada ejecución, o no
se puede verificar ni revisar en git.

Para que el ruido **no rompa el tileado**, hashea la coordenada ya envuelta:

```python
c = h(x % ANCHO, y % ALTO, semilla)   # bien: repite
c = h(x, y, semilla)                  # mal: costura en el borde
```

---

## Cómo se comprueba un tile de suelo

```python
import numpy as np
from PIL import Image

a = np.asarray(Image.open(ruta).convert("RGB"), dtype=int)
# el borde derecho tiene que continuar en el izquierdo
assert np.abs(a[:, -1] - a[:, 0]).mean() < 40, "costura vertical"
assert np.abs(a[-1, :] - a[0, :]).mean() < 40, "costura horizontal"
```

Y la prueba de verdad: componer un mosaico 3×3 del tile y comprobar que no aparece
ninguna línea recta que no dibujaste tú.

---

## Silueta antes que textura

El error típico es meter detalle en una forma que no se lee. A 16×16 el jugador
distingue **la silueta** y poco más. Orden de trabajo:

1. Silueta legible en negro sobre blanco. Si no se reconoce en dos tonos, no se va a
   reconocer con veinte.
2. Color base plano.
3. Sombra (1 tono) y luz (1 tono).
4. Solo entonces, detalle.

Dos objetos distintos **no pueden tener la misma silueta con otro color**. Ya pasó:
siete minerales salieron como el mismo rombo en siete colores, pasaron todas las
comprobaciones automáticas y en el inventario eran indistinguibles.

---

## Formato del informe

Termina siempre con esto, y con números de verdad:

```
FICHEROS: [rutas escritas]
MEDIDO:
  tamaño        [WxH de cada uno]
  colores       [nº únicos por fichero]
  fuera de paleta [lista de hex que no están en el contrato, o "ninguno"]
  contorno      [% de píxeles de borde en #000000, o "n/a: es suelo"]
  seamless      [PASA/FALLA por fichero, con el valor medido]
DUDAS: [lo que tuviste que decidir sin que el contrato lo dijera]
```

Ese apartado de DUDAS es obligatorio y es el más útil. Si inventaste un color, si
elegiste una silueta entre dos posibles, si el contrato no cubría un caso: dilo. Quien
orquesta sí puede mirar los PNG y decidir, pero solo si sabe dónde mirar.
