# Encargo 1 — que el rasgo tenga consecuencias

Fichero nuevo: `godot/scripts/ai/rasgos.gd`
**No toques `worker_base.gd`.** Son 1016 líneas con recolección, descanso, sueño y
combate entrelazados. Tú entregas el fichero; el enganche lo hago yo.

## El problema, medido

`worker_base.gd` define cuatro rasgos (línea 30) y solo tres hacen algo:

| rasgo | efecto actual | dónde |
|---|---|---|
| `ENERGICO` | ×1,12 velocidad, ×0,65 desgaste | 242, 255 |
| `DORMILON` | ×0,95 velocidad, ×1,35 desgaste | 242, 257 |
| `DILIGENTE` | XP ×2 | 312 |
| **`CURIOSO`** | **nada** | — |

Una de las cuatro personalidades es decorativa: sale en el menú y en el tooltip y no
cambia el comportamiento. El jugador no puede distinguir un curioso de un diligente
mirándolos.

## Lo que hay que conseguir

Que los cuatro se **noten mirándolos**, sin inventar sistemas. Todo lo que necesitas ya
existe como variable; se trata de modularla, no de crearla.

### `CURIOSO` — el que más rinde por línea

`worker_base.gd:51` tiene `FAVORITE_BIAS = 0.45`: cada ayudante tira hacia su recurso
favorito porque ese sesgo multiplica la distancia al cuadrado. Un **curioso ignora su
favorito** y va cambiando de recurso.

Es literalmente lo que significa ser curioso, y en pantalla se ve solo: mientras los
demás repiten ruta, el curioso deambula entre recursos distintos.

### `DORMILON` — siestas visibles

Ahora se cansa antes (×1,35) y ya está. Que además **se eche siestas cortas a media
jornada**, no solo de noche: parar, un emoji `💤`, unos segundos, seguir. Lo que hace que
se lea es que ocurra **de día y a la vista**, no dentro de la casa.

### `ENERGICO` — que no pare

Ya se cansa menos. Añádele que **deambule más lejos** cuando está ocioso: el radio de
merodeo mayor. Existe `_wander_mult` (línea 59) sin usar para esto.

### `DILIGENTE` — que se note el oficio

Ya gana XP doble. Que además **descanse menos rato**: recupera hasta un umbral más bajo y
vuelve al trabajo antes. `REST_RECOVER_TO = 0.55` es la constante.

## Cómo lo entregas

Un script con funciones **puras** que `worker_base` pueda llamar sin saber nada de ti.
Por ejemplo, y esto es una sugerencia, no un molde:

```gdscript
class_name Rasgos
static func sesgo_favorito(wtrait: int, base: float) -> float
static func recuperar_hasta(wtrait: int, base: float) -> float
static func radio_merodeo(wtrait: int, base: float) -> float
static func quiere_siesta(wtrait: int, energia: float, es_de_dia: bool) -> bool
```

Cada una recibe el valor base y devuelve el modulado. Así el enganche que yo haga es
cambiar `FAVORITE_BIAS` por `Rasgos.sesgo_favorito(wtrait, FAVORITE_BIAS)` y poco más.

**Documenta en el informe el enganche exacto**: qué línea de `worker_base.gd` cambia y
por qué llamada.

## Los números

Elígelos tú, pero **razónalos en el informe**. Piensa en qué se ve, no en qué es
elegante: un cambio del 5 % no lo distingue nadie, y uno del 300 % rompe el equilibrio
de 18,9 h de partida que está medido.

## Lo que descartas

Este encargo tiene una trampa fácil: montar un sistema de personalidad con pesos,
tablas de configuración y curvas. **No.** Cuatro rasgos, cuatro modulaciones, funciones
estáticas. Si acabas con más de 120 líneas, te has pasado.

En el apartado DESCARTADO del informe quiero leer qué te planteaste y no escribiste.
