```
═══════════════════════════════════════════════════════════════
MAPA DE LA VIDA EN LA ISLA — Mystic Emporium
═══════════════════════════════════════════════════════════════

LO QUE CREÍAS SABER — verificado

✅ nombre propio por tipo   → Correcto. `worker_base.gd:15-21`, pool por `WorkerType`,
   respaldo en `NAMES_FALLBACK` (línea 22). Y además `NameGenerator.random_for_type()`
   en `shop_manager.gd:75` duplica la misma lógica al comprar — dos fuentes de verdad.
   
✅ rasgo de carácter          → Correcto. `enum Trait { DILIGENTE, DORMILON, ENERGICO,
   CURIOSO }` en línea 30. Se sortea al azar (línea 241), no hay elección del jugador.

✅ burbujas de emoji          → Correcto. `_maybe_mood()` línea 325, tres pools según
   estado (FETCHING/WORKING/otros). Además `_puff_mood()` línea 408 con tween flotante.

✅ saludo al cruzarse         → Correcto. `_maybe_greet()` línea 354, GREET_RADIUS=28.0
   (línea 69), cooldown 12s. El que inicia saluda, el otro responde con `_receive_chat`
   (línea 382). Ambos se paran (`_chat_pause`, línea 68) y sacan burbujas con delay.

✅ energía, descanso, sueño   → Correcto. Sistema completo: `_update_energy()` línea 735,
   `_maybe_sleep()` línea 769, noche = darkness > 0.55 (línea 774).

✅ casa con aforo de 5        → Correcto pero MATIZADO. `worker_house.gd:9`: `CAP=5`.
   `enter()` suma occupancy (línea 99), `leave()` resta (línea 104). El badge muestra
   "💤 N/5" (línea 114).

⚠️ ¿sin residentes asignados? → CORRECTO. Y esto es más grave de lo que pensabas. Ver
   pregunta 2 abajo.


═══════════════════════════════════════════════════════════════
PREGUNTA 1: ¿Qué hace el rasgo, exactamente?
═══════════════════════════════════════════════════════════════

El rasgo (`wtrait`) toca SOLO TRES COSAS. Las cuatro personalidades son indistinguibles
en todo lo demás.

1) VELOCIDAD BASE — `_apply_trait()` línea 240-244:
   - ENERGICO: ×1.12  (un 12% más rápido)
   - DORMILON: ×0.95  (un 5% más lento)
   - DILIGENTE / CURIOSO: ×1.0 (sin cambio)
   
2) CONSUMO DE ENERGÍA — `_apply_trait_behavior()` línea 250-261:
   - ENERGICO: `_drain_mult = 0.65` — se cansa un 35% menos
   - DORMILON: `_drain_mult = 1.35` — se cansa un 35% más
   - CURIOSO / DILIGENTE: sin cambio (pero ver punto 3)
   
3) RADIO DE DEAMBULACIÓN — `_apply_trait_behavior()` línea 259:
   - CURIOSO: `_wander_mult = 1.6` — explora un 60% más lejos de su home
   - Los demás: sin cambio
   
4) GANANCIA DE XP — `gain_xp()` línea 312:
   - DILIGENTE: `amount *= 2` — aprende el doble de rápido
   - Los demás: normal

EFECTO NETO: ENERGICO es objetivamente el mejor (más rápido, menos cansancio). DORMILON
es el peor (más lento, más cansancio). CURIOSO solo se nota en que deambula más lejos
— funcionalmente idéntico a DILIGENTE en recolección salvo que DILIGENTE sube de nivel
antes. En interacciones sociales: CERO diferencias. Los cuatro usan exactamente los
mismos emojis de saludo (`GREET_EMOTES` línea 71), los mismos de charla (`CHAT_EMOTES` 
línea 72), y el mismo comportamiento de `_maybe_greet()`.

Conclusión: tienes razón. Cuatro rasgos con tres parámetros numéricos no son cuatro
personalidades. Para Tomodachi Life haría falta que el rasgo condicione qué emoji saca
al saludar, a quién prefiere, o cómo reacciona a construibles sociales.


═══════════════════════════════════════════════════════════════
PREGUNTA 2: ¿Hay residencia asignada?
═══════════════════════════════════════════════════════════════

NO. Y NO SE GUARDA. Aquí está la evidencia:

- `_find_worker_house()` (línea 796): busca la casa con hueco MÁS CERCANA en cada
  llamada (radio 520 px). No hay preferencia, no hay asignación previa.
- `_rest_house` (línea 55): variable de instancia que se pisa CADA VEZ que el worker
  se cansa (línea 759) o anochece (línea 779). Se borra al salir (línea 753, 792).
- `get_save_dict()` (línea 265-274): los campos que persisten son SOLO:
  `name, level, xp, trait, energy, favorite, favorite_manual`. No hay `house_id`,
  `assigned_home`, ni nada parecido.
- `worker_house.gd:99-106`: `enter(_w)` y `leave(_w)` reciben el nodo pero NO lo
  almacenan. Solo incrementan/decrementan `occupants`. La casa no sabe quién está dentro.

Lo que eso implica: ahora mismo las casas son albergues. Un worker cansado entra en
la primera con hueco, duerme, sale, y mañana duerme en otra distinta. No hay arraigo,
no hay "mi casa", no hay vecinos. Para Tomodachi Life esto es el agujero más grande.


═══════════════════════════════════════════════════════════════
PREGUNTA 3: ¿Qué se puede construir en el patio?
═══════════════════════════════════════════════════════════════

El patio es `ZoneType.NATURE` (`global_enums.gd:3`) que corresponde a `allowed_zone=1`.

56 construibles con `allowed_zone=1`, divididos así:

DECORATIVOS (31):
  Categorías: nature (26), floor (3), table (2)
  Rango de coste: 15 – 200 monedas
  Mediana: ~55
  Todos unlocked_by_default salvo los que tienen min_natural_level > 0 (ninguno
  de los decorativos lo tiene).

FUNCIONALES (25):
  Generadores de recurso: desde Parcela de Hierbas (30) hasta Pararrayos Arcano (27200)
  Defensas de asedio: Trampa de Púas (55) a Mortero Arcano (140)
  Total de funcionales tempranos (unlocked, cost < 300): 30 – 220

¿Cuáles son "sitios" (algo que un worker pueda usar)?
  Solo UNO: la Casa de Duendes (`decoration_worker_house`, cost 200, 4×3).
  Es el ÚNICO construible del patio al que un worker va a propósito (a descansar/dormir).
  
  Hay puntos cálidos pasivos: los faroles (`lantern.gd`, grupo `warm_spot`) y las
  fuentes de luz (`warm_light.gd`) sirven como `_find_warm_spot()` (línea 864). Pero
  el worker solo se planta al lado — no "usa" el objeto, no hay animación de sentarse,
  no hay buffo.

  El Banco de Jardín (cost 60), la Fuente (120), el Brasero (75) son SOLO decoración.
  Tienen `is_decorative = true` y categoría `nature`. No tienen script, no emiten
  señales, no son parte de ningún grupo que los workers consulten.

Total de sitios funcionales para workers en el patio: 1 (la casa). Todo lo demás
es escenografía.


═══════════════════════════════════════════════════════════════
PREGUNTA 4: ¿Cómo se guarda un worker?
═══════════════════════════════════════════════════════════════

La cadena de persistencia es:

1. `shop_manager.gd:92-108` → `get_save_state()`:
   Guarda `type`, `x`, `y`, y el dict de `state` del worker. Los workers son propiedad
   del ShopManager (él los instancia y los serializa).

2. `worker_base.gd:265-274` → `get_save_dict()`:
   ```
   { "name", "level", "xp", "trait", "energy", "favorite", "favorite_manual" }
   ```
   Solo 7 campos. Nada de casa, amistades, inventario personal, humor, preferencias
   sociales.

3. `shop_manager.gd:111-132` → `load_save_state()`:
   Destruye todos los workers existentes, reinstancia desde las escenas registradas, y
   aplica `apply_save_dict()` después del `_ready()`.

4. `save_manager.gd:135` guarda todo bajo la clave `"shop"`.

Coste de añadir campos nuevos: BARATO. Solo hay que tocar TRES sitios:
- Añadir el campo a `get_save_dict()` (1 línea)
- Leerlo en `apply_save_dict()` (1 línea)
- Inicializarlo en la declaración de variables (1 línea)

Ejemplo: añadir `"assigned_house_id": String` al save dict son 3 líneas en
`worker_base.gd` y 0 en `shop_manager.gd` (el `"state"` se serializa opacamente).

Añadir una relación worker↔worker (amistad) es más caro porque el save dict de un
worker tendría que referenciar a otro. Haría falta un id único por worker (no existe,
solo `worker_name` que puede repetirse) o guardar las amistades a nivel `ShopManager`.


═══════════════════════════════════════════════════════════════
PREGUNTA 5: Economía — coste de 4-6 nuevos construibles
═══════════════════════════════════════════════════════════════

COSTES DE REFERENCIA EN EL PATIO (todos unlocked por defecto):

  Decoración barata (≤60):      15 – 60   (mediana 35)
  Decoración media (61–120):    70 – 120  (mediana 100)
  Decoración cara (121–200):   140 – 200  (Casa de Duendes = 200)
  Funcional temprano (≤220):    30 – 220  (mediana 90)

COSTES FUERA DEL PATIO (para calibrar):
  Expansión L0→L1: 130
  Expansión L1→L2: 400
  Expansión L2→L3: 900
  Primer duende:    60
  Primer gólem:    120
  Mejora "Buen Ojo": 150 (nivel 1)

SI AÑADIMOS 4-6 CONSTRUIBLES NUEVOS:
  - Una "plaza" o punto de reunión debería costar 100-150 (rango de Fuente y Arco)
  - Una "cafetería" o taller pequeño: 80-120 (rango de Brasero y Banco)
  - Un "banco de parque" extra o similar: 50-70
  - Un elemento focal grande (escenario, fogata): 150-200

  Total añadido: ~400-700 monedas extra sobre el total de 98630 de las puertas.
  Impacto en el ritmo de 18,9 h: < 0,7%, es decir, NINGUNO. No se notaría.

  La restricción real no es el coste en monedas sino el ESPACIO: el patio nivel 0
  mide 900×520 px. A 16px/tile, son 56×32 tiles ≈ ~56 construibles de 1×1 caben.
  Con 31 decorativos ya disponibles, añadir 4-6 más es viable mientras no se solapen
  con los generadores de recurso que el jugador necesita colocar.


═══════════════════════════════════════════════════════════════
LO QUE YA EXISTE (y no está en tu lista)
═══════════════════════════════════════════════════════════════

- `_find_warm_spot()` en `worker_base.gd:864`: los workers usan nodos del grupo
  `warm_spot` como puntos de descanso alternativos. Faroles (`lantern.gd:18`), luces
  cálidas (`warm_light.gd:26`), y casas (`worker_house.gd:23`) pertenecen a este grupo.
  Si creas una "plaza" o "cafetería", basta con que use `add_to_group("warm_spot")`
  y los workers la buscarán cuando estén cansados y no haya casa con hueco.

- `VillageLife` (`godot/scripts/world/village_life.gd`): genera transeúntes en la
  RECEPCIÓN, no en el patio. Son NPCs que cruzan y desaparecen, sin interacción con
  workers. No es reutilizable para el patio.

- `min_natural_level` en `buildable_data.gd:21`: sistema de gating por nivel de
  expansión YA EXISTE. Nuevos construibles pueden requerir nivel 2 o 3 de patio para
  desbloquearse. 15 generadores lo usan (Pozo Arcano requiere nivel 2, Altar Lunar
  nivel 3, etc.). Ningún decorativo lo usa hoy.

- `ShopManager` tiene `worker_scenes` y `spawn_position_provider` — si algún día los
  workers se instancian por otra vía que no sea comprarlos, ya hay infraestructura.


═══════════════════════════════════════════════════════════════
LO QUE FALTA DE VERDAD
═══════════════════════════════════════════════════════════════

1) RESIDENCIA ASIGNADA — no existe. `grep "assigned_house\|resident\|_home_house\|home_id" 
   godot/scripts/` devuelve 0 resultados. Sin esto, no hay "mi casa", no hay vecindario,
   no hay arraigo.

2) AMISTADES / RELACIONES — no existe. `grep "friend\|amistad\|afinidad\|relacion" 
   godot/scripts/` solo encuentra falsos positivos. El sistema de saludo (`_maybe_greet`)
   es un intercambio de emojis sin memoria: dos workers se cruzan, se saludan, y no
   pasa nada más. No hay registro de a quién conocen, no hay nivel de amistad, no hay
   eventos sociales.

3) SITIOS SOCIALES — el Banco de Jardín, la Fuente, el Brasero son pura escenografía.
   Ningún construible del patio (salvo la casa) responde a `has_method("interact")` ni
   pertenece a un grupo que los workers busquen para otra cosa que no sea descansar.

4) COMPORTAMIENTO DIFERENCIADO POR RASGO — los cuatro rasgos solo cambian velocidad,
   consumo de energía, radio de wander, y ganancia de XP. En el plano social, los
   cuatro son idénticos. No hay un rasgo "Sociable" que salude más, ni "Huraño" que
   evite el contacto.

5) ID ÚNICO DE WORKER — no existe. `worker_name` puede repetirse (el pool tiene 6-8
   nombres por tipo, y se compran múltiples workers del mismo tipo). Para guardar
   relaciones worker↔worker o worker↔casa, hace falta un UUID o un índice único.


═══════════════════════════════════════════════════════════════
PROPUESTAS (5 máximo)
═══════════════════════════════════════════════════════════════

PROPUESTA 1: Asignar casa a cada worker
  Ficheros: `worker_base.gd` (+3 líneas en save_dict/apply/variables),
            `worker_house.gd` (+residentes con nombre, +1 método)
  Reutiliza: `_find_worker_house()` (línea 796), `get_save_dict()` (línea 265),
             `has_room()` (worker_house.gd:95), grupo `worker_house`
  Coste: MUY BARATO. Solo hay que guardar un `String` (el id del buildable) en el
         save_dict del worker y asignarlo al comprar/spawnear en vez de buscar cada noche.
         El worker_house ya tiene `enter()`/`leave()` y contador.
  Riesgo: si se demuele la casa asignada, el worker se queda sin hogar. Solución: caer
          de vuelta al sistema actual de búsqueda por proximidad.

PROPUESTA 2: Darle propósito social a un construible existente
  Ficheros: script nuevo (~40 líneas) para el Banco de Jardín (o Fuente, o Brasero)
            o añadir el grupo `warm_spot` a un decorativo existente, +40 líneas en
            `worker_base.gd` para un estado nuevo `SOCIALIZING`
  Reutiliza: `decoration_garden_bench` (cost 60, ya tiene sprite y escena),
             `_find_warm_spot()` (línea 864), `_chat_pause` (línea 68),
             `CHAT_EMOTES` (línea 72)
  Coste: BARATO. Añadir `add_to_group("social_spot")` a un decorativo existente + una
         búsqueda en el worker tipo `_find_warm_spot()` pero para socializar. Ya hay
         pausa para charlar (`_chat_pause`), solo falta que la inicien en un sitio en
         vez de al cruzarse al azar.
  Riesgo: los workers se acumularían en el banco sin lógica de turnos. Hace falta un
          aforo tipo `CAP` como en la casa.

PROPUESTA 3: Memoria de saludos (proto-amistad)
  Ficheros: `worker_base.gd` (+dict `_acquaintances: Dictionary` en variables,
            +2 líneas en save_dict)
  Reutiliza: `_maybe_greet()` (línea 354), `GREET_COOLDOWN` (línea 70)
  Coste: BARATO. Un `Dictionary[String, int]` que mapee `worker_name → greet_count`.
         Cada `_start_chat()` incrementa el contador. A X saludos, emoji especial
         ("💛"). Sin balancear, sin eventos complejos — solo memoria.
  Riesgo: colisión de nombres si dos workers comparten `worker_name`. Solución: añadir
          un `uuid` al worker (4 líneas extra en `_ready()` y `save_dict`).

PROPUESTA 4: Comportamiento social por rasgo
  Ficheros: `worker_base.gd` (~15 líneas en `_apply_trait_behavior()`)
  Reutiliza: `Trait` enum existente (línea 30), `_maybe_greet()` (línea 354),
             `_wander_mult` (línea 59), `_drain_mult` (línea 60)
  Coste: BARATO. Solo añadir al `match wtrait` en `_apply_trait_behavior()`:
         - DILIGENTE → prefiere trabajar a socializar (ignora 50% de greet)
         - CURIOSO → saluda con más frecuencia (GREET_COOLDOWN reducido ×0.5)
         - ENERGICO → emoji diferente al saludar
         - DORMILON → no socializa si energy < 0.3
         Son ~3 líneas por rasgo.
  Riesgo: ninguno. Los multiplicadores ya existen, es añadir flags.

PROPUESTA 5: Construible "plaza" o "fogata" para el patio
  Ficheros: 1 `.tres` nuevo en `data/buildables/`, 1 `.tscn` + script (~50 líneas)
            en `scenes/environment/decorations/`
  Reutiliza: `buildable_data.gd` (campos `cost`, `allowed_zone`, `decoration_category`),
             `worker_house.gd` (patrón CAP + enter/leave + badge),
             `warm_spot` group para que también sirva de descanso,
             sprite de `decoration_brazier` (cost 75) como base artística
  Coste: MEDIO. El .tres son 15 líneas copiadas de otro decorativo. El script es un
         `worker_house.gd` simplificado: aforo, badge, workers entran/salen y emiten
         burbujas sociales. El sprite se reutiliza/tunea.
  Coste en monedas: 100-140 (rango Brasero-Fuente). No afecta al ritmo de 18,9 h.
  Riesgo: si el aforo es muy bajo (1-2), los workers hacen cola sin hacer nada.


═══════════════════════════════════════════════════════════════
RIESGOS
═══════════════════════════════════════════════════════════════

- **worker_base.gd ya pesa 1016 líneas.** Cualquier cambio social suma líneas a un
  fichero que maneja movimiento, energía, combate, recolección, guardado, animaciones,
  y menú contextual. Si se añade un sistema de amistades complejo, conviene extraerlo
  a un `worker_social.gd` como nodo hijo (patrón componente) en vez de engordar la
  FSM. Pero las propuestas 1-4 de arriba son <15 líneas cada una — no justifican
  nuevo fichero.

- **El saludo actual corta el movimiento** (`_chat_pause` línea 627-631 para ambos
  workers). Si se añaden sitios sociales donde los workers pasen más tiempo parados,
  la productividad de recolección baja. Con 3 workers no se nota; con 8, puede
  ralentizar el ritmo de crafting. Medir tras implementar.

- **Colisión de nombres**: si dos Duendes se llaman "Pip", cualquier sistema que
  referencie workers por nombre (amistades, casa asignada) necesita un UUID o índice.

- **El patio y el taller comparten workers.** Si los workers socializan en el patio,
  dejan de recolectar en el taller y viceversa. El wander ya está acotado por zona
  (`_pick_wander_target()` línea 964-975 usa `GridManager.get_zone_rect_at(_home_position)`),
  así que un worker spawneado en el taller no deambulará hasta el patio a saludar.
  Pero un sitio social en el taller requeriría otra lógica.


═══════════════════════════════════════════════════════════════
NO MEDIDO
═══════════════════════════════════════════════════════════════

- No medí cuántos workers caben simultáneamente en el patio nivel 0 sin colisiones.
- No medí el impacto de performance de 8+ workers buscando `warm_spot` o `social_spot`
  cada frame (actualmente la búsqueda es O(n) sobre grupos de nodos, pero se hace
  solo al necesitar descansar, no cada frame).
- No verifiqué si el `game_bootstrap.gd` instancia workers iniciales sin pasar por
  `shop_manager`, lo que dejaría workers "sin dueño" que no se serializan.
- No medí el coste real de añadir un `uuid` a cada worker — sé que es barato en
  código, pero no verifiqué si algún sistema externo (menú contextual, VFX) asume
  que el nombre es único.
```
