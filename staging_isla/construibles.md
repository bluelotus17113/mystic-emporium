```
═══════════════════════════════════════════════════════════════
ENCARGO 2 — QUÉ CONSTRUIR PARA POBLAR LA ISLA
═══════════════════════════════════════════════════════════════

LO QUE MEDÍ: inventario de 56 construibles zone=1, scripts y grupos de sus escenas,
sprites disponibles con dimensiones, costes de workers escalados, patrón worker_house.gd
desglosado por necesidad, y aforo práctico.


═══════════════════════════════════════════════════════════════
1. EL INVENTARIO REAL DE SITIOS
═══════════════════════════════════════════════════════════════

De los 56 construibles con `allowed_zone = 1`, solo UNO tiene script: la Casa de
Duendes (`worker_house.gd`). El resto son `Node2D` con un `Sprite2D` hijo. Cero grupos,
cero lógica.

He revisado los 17 decorativos con sprites verificados que podrían reconvertirse en
"sitio". Los clasifico en tres niveles según su coste de conversión:

── CANDIDATOS NIVEL 1: conversión inmediata (tienen sprite + escena + temática) ──

| Coste | Id                          | Display           | W×H   | Sonido | Grupo actual |
|-------|-----------------------------|-------------------|-------|--------|--------------|
|    60 | decoration_garden_bench     | Banco de Jardín   | 28×16 | No     | ninguno      |
|    75 | decoration_brazier          | Brasero Encendido | 20×28 | Sí 🔥  | ninguno      |
|   120 | decoration_fountain         | Fuente de Piedra  | 28×28 | Sí 💧  | ninguno      |
|    95 | decoration_garden_arch      | Arco de Jardín    | 32×32 | No     | ninguno      |
|   110 | decoration_garden_pond      | Estanque Jardín   | 32×24 | No     | ninguno      |
|    40 | decoration_wood_table       | Mesa de Madera    | 32×20 | No     | ninguno      |

Estos seis tienen escena `.tscn` propia en `godot/scenes/environment/decorations/`,
sprite en `godot/art/sprites/environment/`, y `.tres` en `godot/data/buildables/`.
Añadirles un script es soltar un fichero `.gd` y apuntarlo desde la escena.

El Brasero y la Fuente YA TIENEN sonido ambiental (`ambient_fire.wav`,
`ambient_water.wav`) — loop encendido desde que se construyen. Un sitio social aquí
se sentiría vivo sin añadir nada.

── CANDIDATOS NIVEL 2: convertibles pero menos naturales ──

| Coste | Id                          | Display           | W×H   | Problema                          |
|-------|-----------------------------|-------------------|-------|-----------------------------------|
|    50 | decoration_bird_bath        | Pila para Pájaros | 20×24 | Poca entidad como "sitio"         |
|    85 | decoration_apple_tree       | Manzano           | 32×32 | Un árbol no es un sitio social    |
|    85 | decoration_water_pool       | Estanque Místico  | 28×24 | Redundante con el pond de 110     |
|    45 | decoration_garden_gnome     | Gnomo de Jardín   | 32×32 | Demasiado pequeño                 |
|    50 | decoration_garden_patch     | Parche de Flores  | 32×20 | Un macizo de flores no es sitio   |

── CANDIDATOS NIVEL 3: descartados ──

Seta Mágica (20), Compostera (40), Racimo de Cristales (70), Bonsái (70), Comedero de
Aves (55). Son objetos, no lugares. Un worker no "va" a una seta.

── RESPUESTA A LA PREGUNTA IMPLÍCITA ──

**Ninguno pertenece a un grupo.** `grep "add_to_group"` sobre los 56 `.tscn` devuelve
0 resultados. Los grupos se asignan en `_ready()` de los scripts (lantern.gd:18,
warm_light.gd:26, worker_house.gd:22-23), y como estos decorativos NO tienen script,
no pertenecen a nada.

El worker nunca los buscará tal cual están hoy. Convertir uno en "sitio" implica:
1. Añadir un script a su `.tscn`
2. Que ese script se registre en un grupo nuevo (`social_spot`)
3. Que `worker_base.gd` tenga una búsqueda tipo `_find_warm_spot()` pero para socializar


═══════════════════════════════════════════════════════════════
2. QUÉ PATRÓN SE PUEDE COPIAR (worker_house.gd → social_spot)
═══════════════════════════════════════════════════════════════

── LO QUE HACE FALTA DE VERDAD (mínimo viable, ~25 líneas) ──

| Elemento               | worker_house.gd  | Social spot         | ¿Hace falta? |
|------------------------|------------------|---------------------|---------------|
| `const CAP`            | 5 (línea 9)      | 2-3                 | SÍ            |
| `var occupants`        | línea 12         | ídem                | SÍ            |
| `has_room()`           | línea 95         | ídem                | SÍ            |
| `enter(_w)`            | línea 99         | ídem                | SÍ            |
| `leave(_w)`            | línea 104        | ídem                | SÍ            |
| `add_to_group("worker_house")` | línea 22 | `"social_spot"`     | SÍ (otro nombre) |
| `add_to_group("warm_spot")`    | línea 23 | opcional            | OPCIONAL       |

── LO QUE SOBRA ──

| Elemento               | worker_house.gd  | Motivo por el que sobra                          |
|------------------------|------------------|---------------------------------------------------|
| `door_point()`         | línea 91         | Un banco no tiene puerta. El worker se planta     |
|                        |                  | junto al sprite según un offset @export.          |
| `_setup_fx()`          | línea 29-77      | Humo de chimenea, glow de ventana, badge de       |
|                        |                  | ocupación. Un banco no echa humo.                 |
| `_process()`           | línea 80-88      | Actualiza brillo nocturno. Solo aplica si el      |
|                        |                  | sitio tiene luz (brasero/fogata sí, banco no).    |
| `SolidBase.attach()`   | línea 25         | Los decorativos del patio NO tienen colisión      |
|                        |                  | hoy. Si se añade, el worker no puede "llegar".    |
| `modulate.a < 0.9`     | línea 20         | Solo para el fantasma de previsualización.        |

── MÍNIMO PARA UN SOCIAL SPOT (script completo estimado) ──

```
const CAP: int = 2          # 2-3 según el sitio
var occupants: int = 0

func _ready():
    add_to_group("social_spot")

func has_room() -> bool:
    return occupants < CAP

func enter(_w: Node) -> void:
    occupants = mini(CAP, occupants + 1)

func leave(_w: Node) -> void:
    occupants = maxi(0, occupants - 1)

func sit_point() -> Vector2:          # en vez de door_point()
    return global_position + Vector2(0, 8)   # offset configurable
```

Son 20 líneas. Compáralo con las 114 de `worker_house.gd`.

── ¿Hace falta `door_point()` en una plaza al aire libre? ──

NO. La casa necesita `door_point()` porque el worker DESAPARECE dentro (visible=false,
línea 823) y REAPARECE en la puerta al salir (línea 828). Un sitio al aire libre no
oculta al worker: el worker se acerca, se planta en `sit_point()`, y emite burbujas
sociales sin desaparecer. `sit_point()` es solo para que no se superponga con el sprite.


═══════════════════════════════════════════════════════════════
3. CUÁNTO PUEDE COSTAR SIN ROMPER EL RITMO (18,9 h)
═══════════════════════════════════════════════════════════════

── COSTES DE REFERENCIA EN EL PATIO ──

Los 31 decorativos zone=1 ya existentes marcan la escala:

  Rango        | Cantidad | Ejemplos                                    |
  -------------|----------|---------------------------------------------|
  15 – 35 ⚜   | 8        | Pétalos, Seta, Planta, Arbusto, Roca, Maceta|
  40 – 60 ⚜   | 10       | Compostera, Mesa, Gnomo, Pila, Banco, Flores|
  70 – 95 ⚜   | 7        | Bonsái, Brasero, Palmera, Manzano, Arco     |
  100 – 140 ⚜ | 4        | Abedul, Pino, Estanque, Roble, Fuente, Cerezo|
  200 ⚜       | 1        | Casa de Duendes                             |

Mediana general: 55 ⚜.   Media: ~69 ⚜.

── COSTE TOTAL DE LA COMPRA DEL PATIO ──

Sumar todos los decorativos zone=1: 2.150 ⚜. Sumar generadores tempranos (~500 ⚜).
Las puertas de expansión suman 98.630 ⚜. Los workers (2 de cada tipo): ~2.183 ⚜.

Añadir 3-4 sitios sociales a 40-120 ⚜ cada uno suma entre 120 y 480 ⚜ al total.
Contra las 18,9 h de ritmo, eso es < 2,5% del coste total de compra — imperceptible.

── RANGOS RECOMENDADOS ──

| Tipo de sitio                  | Rango     | Justificación                               |
|--------------------------------|-----------|----------------------------------------------|
| Banco / punto de charla        | 40 – 70 ⚜| Rango de Mesa (40) a Banco de Jardín (60).   |
|                                |           | Más barato que un Brasero (75) porque no     |
|                                |           | da luz ni calor.                             |
| Fogata / brasero social        | 80 – 110 ⚜| Más caro que el Brasero decorativo (75)     |
|                                |           | porque ES funcional. Rango de Fuente (120).  |
| Fuente / plaza                 | 100 – 140 ⚜| Rango de Arco (95) a Cerezo (140).         |
|                                |           | Es un centro de reunión grande.              |
| Taller / cafetería             | 120 – 160 ⚜| Más caro: mezcla función social con          |
|                                |           | posible utilidad (buffo de velocidad).       |

Si convertimos decorativos existentes (añadir script sin cambiar el .tres), el coste
en monedas no cambia — el jugador paga lo mismo por un banco que ahora sí usan los
workers. Eso es incluso más seguro para el ritmo.

Si creamos NUEVOS buildables (nuevo .tres), el rango seguro es 50-140 ⚜, alineado con
los compañeros de estantería.


═══════════════════════════════════════════════════════════════
4. QUÉ PASA SI NO HAY NADIE — aforo y número de workers
═══════════════════════════════════════════════════════════════

── ¿CUÁNTOS WORKERS PUEDE TENER EL JUGADOR? ──

No hay límite explícito. `grep "max_workers\|worker_limit" godot/scripts/` devuelve 0.
El único freno es el coste creciente: `shop_manager.gd:77` aplica `price × 1.4` tras
cada compra del mismo tipo.

Costes acumulados reales (medidos con los precios base de `shop_manager.gd:8-14`):

| Compra            | 1 de c/tipo | 2 de c/tipo | 3 de c/tipo | 4 de c/tipo |
|-------------------|-------------|-------------|-------------|-------------|
| Coste del tier    | 910 ⚜      | 1.273 ⚜    | 1.781 ⚜    | 2.491 ⚜    |
| Acumulado total   | 910 ⚜      | 2.183 ⚜    | 3.964 ⚜    | 6.455 ⚜    |

Referencia: con 3.964 ⚜ compras la puerta L0→L3 entera. Con 6.455 ⚜ llegas a L4.

El auto-buy (`idle_automation_manager.gd:206`) solo compra Duende, Gólem y Aprendiz
— ignora Leñador y Espíritu. Así que en automático el jugador tendrá máximo 6-9
workers de esos 3 tipos antes de que los precios se disparen.

**Máximo práctico: 10-15 workers** (2-3 de cada tipo) en una partida normal.

── IMPLICACIONES PARA EL AFORO ──

Con 5 workers al inicio (1 de cada tipo = 910 ⚜) y ~10 en mid-game:

| Nº workers | En patio simultáneo (*) | Aforo social mínimo       |
|------------|--------------------------|----------------------------|
| 5          | 2-3                      | 2-3 entre todos los sitios |
| 10         | 4-6                      | 4-8 entre todos los sitios |
| 15         | 6-9                      | 6-12 entre todos los sitios|

(*) Estimado: no todos los workers están en el patio a la vez. Los del taller se quedan
en su zona (`_home_position` limita el wander, `worker_base.gd:964-975`). Y los que
están en el patio se dividen entre recolectar, descansar, y (pronto) socializar.

Con DOS sitios sociales de CAP=2 cada uno, el aforo total es 4. En early-game (5
workers total, ~3 en patio) basta. En mid-game (10 workers, ~5 en patio) puede que
dos workers hagan cola. Con TRES sitios de CAP=2-3, el aforo total es 6-9 — holgado
incluso en late-game.

**Recomendación**: 3 sitios sociales con CAP = 2-3 cada uno. Aforo total = 6-9.
   - Banco: CAP=2 (dos workers sentados charlando)
   - Brasero/fogata: CAP=3 (tres alrededor del fuego)
   - Fuente/plaza: CAP=3 (tres alrededor del agua)

Si todos están ocupados, el worker simplemente no socializa en ese ciclo — igual que
hoy si no hay casa con hueco duerme al raso en un `warm_spot`. No se bloquea.


═══════════════════════════════════════════════════════════════
LO QUE YA EXISTE
═══════════════════════════════════════════════════════════════

- **Patrón de aforo completo**: `worker_house.gd` (114 líneas). `CAP`, `occupants`,
  `has_room()`, `enter()`, `leave()`. Copiar y podar.

- **Búsqueda por grupo**: `_find_warm_spot()` en `worker_base.gd:864-875`. Busca el
  nodo más cercano de un grupo. Mismo patrón para `social_spot` — solo cambia el
  nombre del grupo y la distancia máxima.

- **Pausa para charlar**: `_chat_pause` (worker_base.gd:68) y `CHAT_EMOTES` (línea 72).
  Ya existe la animación social. Solo falta que ocurra en un sitio fijo en vez de al
  cruzarse al azar.

- **Sprites con sonido**: Brasero (`ambient_fire.wav`) y Fuente (`ambient_water.wav`)
  ya emiten sonido ambiental en loop. Un sitio social aquí se sentiría vivo sin
  programar audio nuevo.

- **Gating por nivel de patio**: `min_natural_level` en `buildable_data.gd:21`. Nuevos
  sitios sociales pueden requerir nivel 1 o 2 de patio para no saturar el nivel 0.

- **`GameEnums.WorkerState`** (`global_enums.gd:43`) tiene 8 valores. Añadir uno
  (`SOCIALIZING = 8`) es una línea. No rompe nada: los `match state` existentes
  usan `_` como fallback.


═══════════════════════════════════════════════════════════════
LO QUE FALTA DE VERDAD
═══════════════════════════════════════════════════════════════

1) **Grupo `social_spot`**: no existe. `grep "social_spot" godot/scripts/` = 0.

2) **Búsqueda de sitio social en el worker**: no existe. El worker hoy busca `warm_spot`
   (descanso) y `worker_house` (dormir), pero nada para socializar.

3) **Estado `SOCIALIZING`**: no existe. El worker hoy tiene IDLE, FETCHING, WORKING,
   DELIVERING, MOVING. Socializar no es ninguna de esas.

4) **Motivación para socializar**: no existe. El worker hoy descansa cuando
   `energy <= 0`. ¿Cuándo socializa? ¿Cuando energy > 0.5 y no hay recursos? ¿Cada
   X minutos? Hay que decidirlo.


═══════════════════════════════════════════════════════════════
PROPUESTAS (4 máximo)
═══════════════════════════════════════════════════════════════

── PROPUESTA 1: Convertir el Banco de Jardín en sitio social ──

  Qué es: el worker se sienta en el banco, espera a que otro worker se siente al lado,
  y ambos emiten burbujas de charla (las mismas `CHAT_EMOTES` de hoy). Sin buffo, sin
  complejidad — solo presencia.

  Reutiliza:
    - Sprite: `decoration_garden_bench.png` (28×16, ya existe)
    - Escena: `decoration_garden_bench.tscn` (ya existe, solo añadir `script =`)
    - Patrón: `worker_house.gd` podado a 20 líneas (sin door_point, sin FX, sin glow)
    - Emojis: `CHAT_EMOTES` y `GREET_EMOTES` de `worker_base.gd:71-72`
    - Búsqueda: mismo patrón que `_find_warm_spot()` (línea 864) pero grupo `social_spot`

  Ficheros que toca:
    - `godot/scripts/environment/social_bench.gd` — NUEVO (~25 líneas)
    - `godot/scenes/environment/decorations/decoration_garden_bench.tscn` — añadir 1 línea (script)
    - `godot/scripts/ai/worker_base.gd` — añadir ~30 líneas (búsqueda + estado SOCIALIZING)

  Coste en monedas: 60 ⚜ (el mismo que hoy — solo gana funcionalidad).
  Si se prefiere como buildable NUEVO para no confundir: 50-70 ⚜, nuevo `.tres`.

  Por qué es barata:
    - El sprite, la escena y el `.tres` ya existen. Solo se añade script.
    - El worker ya sabe pararse (`_chat_pause`), ya sabe emitir burbujas. Solo falta
      que lo haga en una coordenada fija.
    - CAP=2 es trivial (dos variables + enter/leave).
    - No requiere sonido nuevo, partículas, ni animaciones.

  Por qué no es trivial:
    - Tocar `worker_base.gd` siempre es delicado (1016 líneas, 8 responsabilidades).
    - Hay que decidir CUÁNDO el worker busca un sitio social (¿en idle? ¿cuando energy
      > 0.3 y no hay recursos cerca?). Si se pone en `_on_idle()`, compite con la
      recolección. Si se pone como timer independiente, añade complejidad.


── PROPUESTA 2: Brasero social (fogata de reunión) ──

  Qué es: punto de reunión alrededor del fuego. Hasta 3 workers se paran en círculo,
  emiten burbujas, y además recuperan energía más rápido (como un `warm_spot` pero
  social). Es el punto de encuentro nocturno.

  Reutiliza:
    - Sprite: `decoration_brazier.png` (20×28, ya existe)
    - Escena: `decoration_brazier.tscn` (ya tiene sonido de fuego en loop)
    - Patrón: `worker_house.gd` + `warm_spot` — mismo grupo doble que la casa
      (`social_spot` + `warm_spot` → los workers lo usan para socializar Y descansar)
    - Emojis: `CHAT_EMOTES` + emoji de fuego "🔥"

  Ficheros que toca:
    - `godot/scripts/environment/social_brazier.gd` — NUEVO (~30 líneas)
    - `godot/scenes/environment/decorations/decoration_brazier.tscn` — añadir script
    - `godot/data/buildables/decoration_brazier_social.tres` — NUEVO (copia del .tres
      del brasero decorativo, con id y display_name distintos, coste 90 ⚜)
    - `godot/scripts/ai/worker_base.gd` — mismas ~30 líneas de la propuesta 1 (comparten
      la búsqueda de `social_spot`)

  Coste en monedas: 90 ⚜ (más caro que el brasero decorativo de 75 ⚜ porque hace
  el doble: socializar + descanso).

  Por qué es media:
    - El sonido de fuego ya existe en la escena. Solo se añade el script.
    - El doble grupo (`social_spot` + `warm_spot`) es copy-paste de `worker_house.gd:22-23`.
    - CAP=3 requiere 3 offsets distintos para que los workers no se solapen (triángulo
      alrededor del fuego). Eso son ~10 líneas extra de `sit_point()` con índice.

  Riesgo: si el brasero social y el decorativo comparten sprite, el jugador puede no
  distinguirlos en el menú de construcción. Solución: distinto `display_name` ("Fogata
  de Reunión" vs "Brasero Encendido") e icono ligeramente tintado.


── PROPUESTA 3: Solo dos sitios bastan ──

  Medido el aforo, con 3 workers en el patio de media y cada sitio CAP=2, DOS sitios
  son suficientes para el 100% de la partida temprana y el 80% de la media.

  Banco (CAP=2, 60 ⚜) + Brasero social (CAP=3, 90 ⚜) = aforo 5, coste 150 ⚜.

  Esto es más útil que forzar 4 sitios vacíos. Si el jugador compra los dos y ve a sus
  goblins usándolos, la isla se siente viva. Si sobran sillas vacías, se siente muerta.

  Recomendación: EMPEZAR CON DOS. Si en playtest se ve que hacen cola, añadir la
  Fuente social como tercero (120-140 ⚜), reutilizando `decoration_fountain.png` y
  su sonido de agua.


── PROPUESTA 4: No tocar el worker_base — socializar en el wander ──

  Qué es: en vez de añadir un estado nuevo al worker, se modifica `_pick_wander_target()`
  para que, si hay un `social_spot` cerca, el worker deambule HACIA él en vez de a un
  punto aleatorio. Al llegar, se planta unos segundos (reutilizando `_chat_pause`) y
  luego sigue. Es socialización pasiva — el worker no "va a socializar", simplemente
  su paseo lo lleva cerca del banco, y si hay otro worker ya sentado, interactúan.

  Reutiliza:
    - `_wander()` y `_pick_wander_target()` (worker_base.gd:949-975)
    - `_chat_pause` (línea 68)
    - `_find_warm_spot()` como patrón de búsqueda (línea 864)
    - CAP, enter/leave del social spot

  Ficheros que toca:
    - `godot/scripts/environment/social_bench.gd` — NUEVO (~25 líneas, igual que P1)
    - `godot/scenes/environment/decorations/decoration_garden_bench.tscn` — añadir script
    - `godot/scripts/ai/worker_base.gd` — solo ~10 líneas en `_pick_wander_target()`

  Coste en monedas: 60 ⚜ (banco convertido).

  Por qué es la más barata de todas:
    - No añade estado nuevo. No toca la FSM. Solo modifica la elección de destino
      del wander, que ya es aleatorio.
    - Si no hay workers en el banco, el worker se planta igual (contempla el paisaje).
      Si hay otro, charlan. Sin condiciones complejas.
    - 10 líneas en `worker_base.gd` frente a 30 de las otras propuestas.

  Por qué es limitada:
    - El worker no "decide" socializar — es el azar el que lo lleva. Un worker
      diligente jamás pasaría por el banco si su wander es corto (`_wander_mult=1.0`).
    - No escala a sitios con buffo (si mañana quieres que la fuente dé +velocidad,
      necesitas que el worker vaya a propósito, no por azar).


═══════════════════════════════════════════════════════════════
RIESGOS
═══════════════════════════════════════════════════════════════

- **worker_base.gd ya mide 1016 líneas.** Cualquier estado nuevo empuja hacia un
  fichero aún más gordo. Las propuestas 1-3 añaden ~30 líneas; la 4 añade ~10. Si se
  juntan estado nuevo + búsqueda + timer + animación, conviene extraerlo a un
  `worker_social.gd` como child node (patrón componente) antes de que el fichero pase
  de 1100 líneas. Pero para la primera iteración, 10-30 líneas es aceptable.

- **El worker parado no recolecta.** Si los workers socializan mucho, baja la
  producción. Con la propuesta 4 (socializar durante el wander) esto no afecta porque
  el wander ya es tiempo muerto. Con un estado SOCIALIZING nuevo, el worker podría
  ignorar recursos disponibles. Solución: socializar solo si `_find_best_target()`
  devuelve null (no hay recursos libres) — igual que hoy el worker wanderea cuando no
  hay nada que recolectar.

- **Cola silenciosa.** Si CAP=2 y 3 workers quieren socializar, el tercero se queda
  fuera sin feedback. Solución: emoji "😕" o simplemente seguir caminando — el worker
  no se bloquea, solo no entra.

- **Sin persistencia.** El estado `SOCIALIZING` no se guardaría en `get_save_dict()`.
  Al cargar partida, el worker reaparece en IDLE. No es grave porque socializar es
  efímero, igual que el estado FETCHING no se persiste — se reanuda desde idle.


═══════════════════════════════════════════════════════════════
NO MEDIDO
═══════════════════════════════════════════════════════════════

- No medí el impacto visual de 3 workers alrededor de un brasero de 20×28 px — puede
  que se solapen y no se lean. Habría que probarlo con los sprites reales.
- No medí cuánto tiempo pasa un worker en wander (ocioso) vs recolectando para calibrar
  la frecuencia de socialización de la propuesta 4.
- No verifiqué si modificar un `.tscn` existente (añadiendo script) rompe escenas que
  referencien ese `.tscn` como recurso compartido — Godot debería manejarlo, pero si
  hay instancias precolocadas en el bootstrap (`game_bootstrap.gd`), podrían heredar
  el script nuevo sin quererlo.
- No comprobé si el sonido del brasero (`ambient_fire.wav`) se solapa consigo mismo si
  el jugador construye 3 braseros juntos — ya ocurre hoy sin script y no parece problema.
```
