# Encargo 2 — que cada goblin tenga SU casa

Fichero nuevo: `godot/scripts/environment/residencia.gd`
**No toques `worker_base.gd` ni `worker_house.gd`.** El enganche lo hago yo; tú
describes dónde va.

## El problema, medido

`worker_base.gd:796` tiene `_find_worker_house()`: coge **la casa más cercana con
hueco** dentro de 520 px. Y `worker_house.gd` es un aforo compartido de 5 (`CAP`) con
un contador de ocupantes.

Resultado: un ayudante duerme cada noche en una casa distinta. No hay vecindario, hay
albergue. Y en un juego que quiere sentirse como Tomodachi Life, "Fizwick vive aquí" es
la mitad del encanto.

## Lo que hay que conseguir

Que cada ayudante tenga **una casa asignada** y vuelva siempre a la suya.

### El registro

Un autoload pequeño que sepa quién vive dónde. Lo mínimo:

- asignar un ayudante a una casa (la más cercana con sitio, al crearlo)
- preguntar qué casa le toca a un ayudante
- preguntar quiénes viven en una casa (para enseñar los nombres)
- liberar la plaza si el ayudante desaparece

### El caso que lo rompe todo

**Si el jugador demuele la casa asignada, el ayudante se queda sin hogar.** Lo detectó
el analista y es real: las casas son construibles y se pueden vender.

Tiene que caer con elegancia: si su casa ya no existe, se le busca otra con el sistema
actual de proximidad y se le reasigna. Sin errores en consola y sin que se quede parado.

### El guardado

`worker_base.gd:265` tiene `get_save_dict()` y devuelve un diccionario plano con
`level`, `trait` y demás. Añadir la casa asignada es **una clave más**.

Ojo: hay que guardar algo que sobreviva a recargar la partida. Un `NodePath` no vale
porque los nodos se recrean. Piensa qué identificador es estable y **dilo en el
informe** — si no lo tienes claro, dilo también, que es mejor que inventarlo.

## Lo que NO quiero

- Un sistema de "hogares" con niveles, mejoras, mobiliario ni felicidad. **No.**
- Una interfaz nueva. Los nombres de los residentes se enseñan luego; ahora solo el
  registro.
- Tocar el aforo de 5 ni la lógica de `enter()`/`leave()` de `worker_house.gd`.

Si acabas con más de 90 líneas, te has pasado. Es un diccionario con cuatro operaciones.

## Comprobar

    godot --headless --import
    godot --headless --quit-after 400

Línea base: `Items: 131 | Recipes: 111 | Orders: 84 | Research: 40 | Buildables: 224`
más un `resources still in use at exit`, que es artefacto de salir con `--quit-after`.

## Informe

El de tu definición. Con el **enganche exacto** que necesito hacer yo (qué línea de
`worker_base.gd` y qué llamada), y el apartado **DESCARTADO** relleno.
