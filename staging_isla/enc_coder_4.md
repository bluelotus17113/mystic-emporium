# Encargo 4 — que se reúnan a charlar

Fichero nuevo: `godot/scripts/environment/punto_social.gd`
**No toques `worker_base.gd`.** Yo hago el enganche; tú lo describes.

## La idea, y su restricción clave

Los ayudantes ya se saludan al cruzarse (`_maybe_greet`, con `GREET_EMOTES`) y se paran
a charlar (`_chat_pause`, `CHAT_EMOTES`). Pero eso pasa **al azar**, cuando se topan. No
hay ningún sitio al que ir a juntarse.

La restricción, que viene del análisis y es lo que hace que esto no rompa nada:

**Solo socializan cuando NO hay nada que recolectar.** El worker ya deambula
(`_wander_target`) cuando `_find_best_target()` devuelve null. Ese tiempo ya está
perdido: usarlo para socializar no cuesta producción. Un estado social que compita con
el trabajo sí la costaría, y el jugador lo notaría como que sus ayudantes vaguean.

## Lo que hay que escribir

Un script para colgar de un decorativo que lo convierta en punto de reunión:

- se apunta al grupo `social_spot` en `_ready()`
- tiene aforo (`CAP`), como `worker_house.gd`
- sabe si le queda sitio, y admite/suelta ocupantes
- da una posición donde plantarse (varias, para que no se solapen en el mismo píxel)

Y una función para que el worker encuentre el más cercano con hueco, del mismo estilo que
`_find_warm_spot()` (`worker_base.gd:864`), que puedes leer como referencia.

## Dónde se cuelga

**El Banco de Jardín** (`decoration_garden_bench`), que ya existe con sprite, escena y
coste 60. De los 56 construibles del patio, 55 son un `Node2D` con un `Sprite2D` y nada
más — así que añadirle un script es el cambio más barato posible.

No hagas un construible nuevo. Si esto funciona, luego se cuelga el mismo script de otros.

## El aforo

**CAP = 2** en el banco. Es un banco, se sientan dos.

Si un tercero quiere y no cabe: **que siga su camino**, sin bloquearse y sin cola. Un
worker esperando de pie a que se libere un banco se lee como un fallo, no como vida.

## Lo que NO quiero

- Un estado `SOCIALIZING` nuevo en la máquina de estados. Reutiliza el wander.
- Amistades, afinidades ni memoria. Eso va en otro encargo.
- Buffos por socializar. Que se junten y charlen es el objetivo; premiarlo con
  estadísticas lo convierte en una tarea más que optimizar.
- Un construible nuevo.

Si pasas de 80 líneas, te has pasado.

## Comprobar

    godot --headless --import
    godot --headless --quit-after 400

Línea base: `Items: 131 | Recipes: 111 | Orders: 84 | Research: 40 | Buildables: 224`.
Si el recuento cambia, has tocado el catálogo y no debías.

## Informe

El de tu definición, con el **enganche exacto** en `worker_base.gd` —qué función, qué
línea, y en qué punto de la prioridad del `_physics_process`— y el **DESCARTADO** relleno.
