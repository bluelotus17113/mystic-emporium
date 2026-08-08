# Encargo 6 — personalidad MBTI: cuatro ejes, no dieciséis etiquetas

Fichero a editar: `godot/scripts/ai/vida_social.gd` (188 líneas, es TUYO)
**No toques `worker_base.gd`.** El enganche del guardado lo hago yo; tú lo describes.

## La decisión de diseño que ya está tomada

El usuario quiere personalidades tipo MBTI (las 16: INTJ, ENFP…) y que eso genere
afinidades y conflictos entre ayudantes.

Se implementa como **cuatro ejes binarios**, no como dieciséis etiquetas:

    E/I  extrovertido / introvertido
    S/N  sensorial / intuitivo
    T/F  racional / emocional
    J/P  planificador / espontáneo

Con etiquetas harían falta 16×16 = **256 combinaciones de pareja** definidas a mano,
que nadie puede mantener ni verificar. Con ejes, la afinidad sale sola: **cuántos ejes
comparten dos ayudantes**, de 0 a 4. Sin tabla. Y las siglas se componen de los ejes,
así que el jugador sigue viendo "INTJ".

Si te ves escribiendo una tabla de 256 entradas, o incluso de 16, has cogido el camino
caro. Vuelve a los ejes.

## Lo que hay que añadir

1. **Los cuatro ejes por ayudante.** Se sortean al nacer y se guardan. Cuatro bits.
2. **Las siglas**, para poder enseñarlas en el menú del ayudante.
3. **Afinidad entre dos**: ejes compartidos, 0 a 4.
4. **Que la afinidad module lo que YA existe**: la memoria de encuentros
   (`_registrar_encuentro`) y el emoji del saludo (`_pick_greet_emote`).
   - afinidad alta → llegan antes al umbral de amistad
   - afinidad baja (0 o 1 eje) → en vez de acercarse, **chocan**

## Los conflictos

Decisión del usuario: **los conflictos penalizan y se pueden reconciliar.** No son solo
visuales.

Tú escribes la parte de estado y decisión:
- llevar la cuenta de roces igual que se lleva la de encuentros
- a partir de un umbral, ese par está enemistado
- exponer si dos están enemistados, y un emoji de conflicto (💢 y similares)
- **una vía de reconciliación**: si estando enemistados coinciden en un banco (o sea,
  eligen socializar pese a todo), los roces bajan

La penalización en producción NO la escribes tú: eso toca `worker_base.gd`. Describe en
el informe **qué debería consultar** y dónde, y lo engancho yo.

## Lo que NO quiero

- Tabla de 16 personalidades ni de 256 parejas.
- Interfaz. Solo los datos y el estado.
- Que la afinidad alta dé bonificación de producción. Las amistades a propósito no dan
  ventaja; los conflictos sí penalizan, y esa asimetría es deliberada: un mal ambiente
  se nota, un buen ambiente es lo normal.
- Tocar `worker_base.gd`.

Esto son unas 60-70 líneas sobre un fichero que ya existe. Si escribes 200, te has
pasado.

## Los números

Elígelos y **razónalos**, pero deja los umbrales en constantes con nombre y juntos al
principio: los vamos a tener que ajustar cuando sepamos cuánto se cruzan de verdad los
ayudantes. Ahora mismo lo estoy midiendo y todavía no lo sé.

## Comprobar

    godot --headless --import
    godot --headless --quit-after 400

Línea base: `Items: 131 | Recipes: 111 | Orders: 84 | Research: 40 | Buildables: 224`.

Y **prueba el guardado con un script**, como hiciste con `tools/test_amistad.py`, que
esa vez salió bien: ejes que sobreviven a ida y vuelta por JSON, afinidad simétrica
(A con B igual que B con A), y los bordes de los umbrales.

## Informe

El de tu definición, con **qué debe consultar worker_base y dónde** para la penalización,
los números razonados, y el **DESCARTADO** relleno.
