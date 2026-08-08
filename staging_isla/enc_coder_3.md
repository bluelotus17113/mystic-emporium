# Encargo 3 — contratar ayudantes en vez de comprarlos

Fichero nuevo: `godot/scripts/managers/contratos.gd` (autoload)
**No toques `shop_manager.gd`.** Yo hago el enganche; tú describes dónde.

## El problema

`shop_manager.gd:34` tiene `try_buy(worker_type)`: pagas y sale un ayudante con nombre,
rasgo y recurso favorito **al azar**. El precio sube un 40 % por compra
(`prices[worker_type] = int(cost * 1.4)`, línea 76) y no eliges nada.

El juego ya calcula rasgo y favorito, pero el jugador los descubre **después** de pagar.
Son datos que deberían ser la decisión y hoy son una sorpresa.

## Lo que hay que conseguir

Una **bolsa de tres candidatos** que se renueva **cada día real**. Cada candidato trae su
ficha por delante: nombre, tipo, rasgo y recurso favorito. El jugador elige uno, o no
elige ninguno y espera a mañana a ver si sale algo mejor.

### Qué sabe el registro

- los tres candidatos de hoy, con sus datos ya decididos
- cuándo toca renovar
- contratar a uno (lo saca de la bolsa; los otros dos siguen hasta la renovación)

### El día real, y sus casos raros

Esto es lo que hay que hacer bien. Guarda un **timestamp Unix** (`Time.get_unix_time_from_system()`)
y compara al arrancar y al cargar partida.

Tres casos que hay que resolver **explícitamente**, y quiero leer en el informe qué
decidiste en cada uno:

1. **Vuelve tras una semana.** No acumules siete tandas. Una tanda nueva y ya.
2. **El reloj del sistema va hacia atrás** (cambio de hora, zona horaria, trampa). Si el
   timestamp guardado es *mayor* que el actual, no te quedes bloqueado para siempre:
   renueva y reescribe el guardado.
3. **Partida antigua sin el campo.** Genera tanda y guarda el timestamp de ahora.

### El precio, que es lo que crea la tensión

Si los tres cuestan igual, el jugador coge el del mejor rasgo y no hay decisión.

Haz que el precio **varíe con el candidato**: un ±30 % sobre el precio base de su tipo
(`get_price`). Así hay elección real entre uno mediocre y barato y uno bueno y caro. Un
solo número, no una tabla de valoración.

### Tope de plantilla

**Máximo 10 ayudantes de cada tipo.** Si ya tienes 10 duendes, los candidatos duende
salen marcados como no contratables y con el motivo. No los escondas: que se vea por qué.

## Lo que NO quiero

- Stats numéricos inventados ("fuerza 7/10"). Con rasgo y favorito ya hay decisión.
  Añadir números es exactamente el sistema de más que hay que rechazar.
- Rareza, estrellas, niveles de contrato ni cartas.
- Interfaz. Tú das los datos; la pantalla la hago yo después.
- Tocar la escalada del 40 % ni el sistema de precios existente.

Si pasas de 130 líneas, te has pasado.

## Comprobar

    godot --headless --import
    godot --headless --quit-after 400

Línea base: `Items: 131 | Recipes: 111 | Orders: 84 | Research: 40 | Buildables: 224`.

Y comprueba tú los tres casos raros del día real: escribe un script de usar y tirar en
`tools/` que simule los timestamps y verifique que renueva cuando debe. **No me digas que
funciona sin haberlo ejecutado.**

## Informe

El de tu definición. Con:
- **el enganche exacto** en `shop_manager.gd`
- qué decidiste en cada uno de los tres casos raros
- el apartado **DESCARTADO** relleno
