# Mystic Emporium Automata — Game Design Document

**Versión:** 1.1 (Pre-Beta · Mecánicamente Completo en Godot 4.6.2)
**Motor:** Godot 4.6.2
**Estado:** Bucle de juego completo, automatización funcionando, contenido implementado. Pendiente: pulido visual y QoL menor.
**Fecha:** 2026-06-28
**Autor:** vaknadesu
**Repo:** https://github.com/bluelotus17113/mystic-emporium

---

## Índice

0. Changelog v1.1 — Estado Actual
1. Visión General del Juego
2. Mecánicas de Juego Principales
3. Arquitectura Técnica (Godot 4)
4. Interfaz de Usuario y Experiencia (UI/UX)
5. Característica Única: Modo Compañero de Escritorio
6. Contenido del Juego (Versión de Lanzamiento 8–10h)
7. Hoja de Ruta de Desarrollo Futuro
8. Plan de Port Unity → Godot (mapeo de equivalencias)
9. Plan de Acción Inmediato

---

## 0. Changelog v1.1 — Estado Actual

**Resumen:** el juego pasó de un esqueleto de port (v1.0) a un loop mecánicamente completo y jugable. Lo que cambió respecto a v1.0:

### Sistemas terminados
- **Bucle de juego completo** (recolectar → craftear → vender) con automatización funcional en los 5 ejes (Craft / Entregas / Research / Upgrade / Workers) controlable desde la HUD.
- **Save/Load atómico** (`.tmp` → rename + `.bak` recovery). Persiste workstations, generadores, órdenes activas, evento en curso, precios del shop, workers comprados, expansión del patio.
- **5 eventos dinámicos** con feedback rico (icono + descripción + countdown + glow). Festival Lunar, Eclipse Arcano, Inspección del Gremio, Asalto de Bandidos, Tormenta Arcana — todos con mecánica real.
- **Sistema de zonas (Natural / Taller / Recepción)** con cámara que conmuta entre ellas. Buildables filtrados por zona activa en el panel de construcción.
- **Cap dinámico de clientes** según sillas de espera (base 1 + 1 por silla).
- **Paciencia de clientes 3–5 min** (180–312s según personalidad).
- **Notificaciones anti-cascada**: sólo ALERT como toast; el resto va al "Diario" del panel de pedidos.

### Contenido expandido respecto a v1.0
| Aspecto | v1.0 estimado | v1.1 real |
|---|---|---|
| Ítems | ~25–30 | **86** |
| Recetas | ~20 | **55** |
| Investigaciones | 15–20 | **22** |
| Edificios | 10–12 | **147** (incluye decoración) |
| Ayudantes | 3 tipos | **5 tipos** |
| Eventos | — | **5** |

### Generadores nuevos (Patio Natural)
| Generador | Item | Desbloqueo | Cooldown | Costo |
|---|---|---|---|---|
| Pozo Arcano | agua_arcana | Patio Nv 2 | 10s | 220⚜ |
| Altar Lunar | polvo_lunar | Patio Nv 3 | 16s | 320⚜ |
| Geoda Amatista | fragmento_amatista | Patio Nv 3 | 18s | 380⚜ |
| Veta de Hierro Fundido | lingote_hierro | Patio Nv 4 | 22s | 480⚜ |
| Santuario Espiritual | esencia_espiritual | Patio Nv 4 | 20s | 560⚜ |

### Workers nuevos
| Worker | Recolecta | Precio base | Velocidad |
|---|---|---|---|
| 🪓 Leñador | madera_arcana + mena_hierro | 180⚜ | 80 |
| ✨ Espíritu | agua + polvo lunar + amatista + esencia + lingote | 450⚜ | 95 |

Los workers ahora soportan `preferred_resource_types: Array[int]` (lista de tipos preferidos en orden) en vez de un único tipo. Sistema de reservas: dos workers nunca caminan al mismo nodo; si está reservado por otro, el segundo wander en lugar de competir.

### Research con materiales
Cada investigación ahora pide coins + materiales (auto-derivados por tema y tier):
- T1 (≤200⚜): solo hierba + cristal (raws iniciales).
- T2 (≤500): + madera + hierro.
- T3 (≤1000): + agua_arcana + polvo_lunar (Patio Nv 2-3).
- T4-5: + amatista + esencia + lingote (Patio Nv 3-4).

### QoL agregado
- **Tooltips ricos** en generadores y workstations (hover: cooldown restante, yield, nivel, próximo upgrade, receta activa).
- **Hotkeys en build panel**: B abre/cierra, Tab cambia tab, click-der/Esc cancela, R rota.
- **Toggle auto-craft por estación** (botón 🤖/⏸ en el panel del Caldero/Forja).
- **Panel lateral de clientes** (derecha): sorted por tier (VIPs arriba), botón ✓ por cliente.
- **Pedidos solo de items obtainable** (filtra catálogo por recetas unlocked + items PRIMARY).
- **EventIndicator** grande arriba-derecha con icono/color/countdown.
- **Filtrado de buildables por zona activa** en build panel.

### Bugs notorios resueltos
- Workers se salían del mapa al construir parcela (resource_node registrado antes de tener pos).
- Cascadas de notificaciones congelaban el juego.
- Auto-research disparaba toasts en bucle por items faltantes.
- Items huérfanos (agua, polvo, amatista, lingote, esencia) ahora tienen generador propio.
- Aprendiz no llegaba a biblioteca por guard mal puesto.

### Pendiente
- Pulido visual: los 12 sprites nuevos son procedurales (PIL); reemplazar por pixel-art autoral.
- Más decoración temática para Recepción.
- Modo Compañero (sección 5) sigue como roadmap.
- Sistema de mercado tipo Stardew/Recettear para v1.2.

---

## 1. Visión General del Juego

### 1.1. High Concept

**Mystic Emporium Automata** es un simulador 2D que fusiona la gestión de una tienda mágica con automatización profunda y la libertad de un constructor de bases. El jugador transforma un humilde taller en un vasto emporio, dividiéndolo en zonas especializadas para optimizar cadenas de producción. Su característica definitoria es un **Modo Compañero** que convierte el juego en un widget de escritorio interactivo, ofreciendo herramientas de productividad y ambiente para acompañar al usuario en sus tareas diarias.

### 1.2. Pilares del Diseño

- **Automatización Satisfactoria:** el placer está en observar un sistema complejo creado por el jugador funcionando solo.
- **Diseño Estratégico del Layout:** la colocación de edificios y zonas es clave para la eficiencia.
- **Progresión Constante y Gratificante:** siempre hay algo nuevo que construir, mejorar o investigar.
- **Mundo Vivo y Encantador:** el emporio se siente vivo con el ir y venir de ayudantes y clientes NPC.
- **Compañía No Intrusiva:** el Modo Compañero mejora el flujo de trabajo del usuario, no lo interrumpe.

### 1.3. Género y Plataforma

- **Género primario:** Simulación, Gestión, Automatización, Construcción de Bases, Incremental.
- **Género secundario:** Aplicación de Escritorio, Desktop Pet, Idle.
- **Plataforma de lanzamiento:** PC (Windows). Portabilidad sencilla a Linux y macOS gracias a Godot.

### 1.4. Modelo de Negocio y Monetización

- **Free-to-Play (F2P):** el juego base es gratuito para maximizar alcance.
- **Monetización ética (No Pay-to-Win):**
  - Skins cosméticos para ayudantes, estaciones y la interfaz del Modo Compañero.
  - Paquetes de decoración para personalizar la tienda.
  - Paquetes de música y ambient sounds para el reproductor integrado.

### 1.5. Público Objetivo

Aficionados a juegos de optimización (Factorio, Satisfactory), construcción de bases (RimWorld) y simuladores "cozy" (Stardew Valley, Rusty's Retirement), que además aprecian herramientas de productividad y personalización de su entorno de escritorio.

---

## 2. Mecánicas de Juego Principales

### 2.1. Core Loop

1. **Observación y Planificación:** el jugador evalúa el estado del emporio: ¿qué recursos faltan?, ¿qué pedido es más rentable?, ¿qué investigación desbloquea la siguiente estación clave?
2. **Construir:** se gastan `Arcane Coins` para colocar un edificio (generador, estación, almacén).
3. **Automatización:** el edificio se registra y los ayudantes comienzan a interactuar con él.
4. **Producción:** las cadenas se activan, transformando recursos básicos en productos de valor.
5. **Recompensa:** los clientes NPC son atendidos por el protagonista; al completar un pedido se obtienen `Arcane Coins` y Reputación.
6. **Reinversión:** las nuevas monedas financian mejoras y nuevas investigaciones → vuelve al paso 1 con más herramientas y desafíos.

### 2.2. Sistema de Construcción Basado en Rejilla

- **Grid lógico:** `GridManager` (AutoLoad) mantiene un `Dictionary[Vector2i, Node2D]` que mapea coordenadas a objetos construidos. Permite comprobaciones de ocupación instantáneas.
- **Modo construcción:**
  - **Activación:** desde la UI (`BuildMenuPopup`) llamando a `BuildManager.enter_build_mode(buildable_data)`.
  - **Feedback visual ("fantasma"):** se instancia una vista previa del prefab del edificio con `modulate.a = 0.5`. En `_process(delta)` se sigue al ratón snapped al grid (`local_to_map`/`map_to_local` de `TileMapLayer`).
  - **Validación:** `is_valid_placement()` comprueba:
    1. `!GridManager.is_cell_occupied(grid_pos)`
    2. `buildable_data.allowed_zone == GridManager.get_zone_type(grid_pos)`
  - **Colocación:** clic izquierdo en celda válida → se descuenta el coste, se instancia la escena real, se registra en el grid.
  - **Cancelación:** clic derecho o `ui_cancel` → `queue_free()` del fantasma y salida del modo.

### 2.3. Sistema de Zonas Especializadas

Tres zonas funcionales definidas por `TileMapLayer` separados dentro del mismo `TileMap`:

- **Santuario Natural** (`nature_zone_layer`): suelo de tierra/roca. Solo edificios con `allowed_zone == ZoneType.NATURE` (Generadores).
- **Taller del Artesano** (`workshop_zone_layer`): suelo de piedra/madera. Solo `ZoneType.WORKSHOP` (Estaciones de Trabajo, Almacenamiento).
- **Atrio del Emporio** (`reception_zone_layer`): suelo ornamental. Solo `ZoneType.RECEPTION` (Mostrador, Sillas, decoraciones).

**Detección:** `GridManager.get_zone_type(cell)` consulta `get_cell_source_id(cell)` o `has_cell(cell)` en cada capa en orden de prioridad.

### 2.4. Sistema de Generación de Recursos

- **El Generador (`ResourceGenerator.gd`):** cada escena de generador (`ParcelaHierbas.tscn`) contiene un sprite base, un `Marker2D` llamado `SpawnPoint`, y el script `ResourceGenerator.gd`. En `_process(delta)` un `timer` cuenta; al alcanzar `generation_cooldown` se llama a `generate_resource()`:
  1. Instancia un `ResourceNode` escena en la posición del `SpawnPoint`.
  2. Llama a `ResourceManager.register_resource_node(node)` para que sea visible a la IA.
- **El Nodo (`ResourceNode.gd`):** al recolectarse se desactiva (`hide()` + `set_process(false)`) en lugar de destruirse, permitiendo reactivación posterior por el generador. Más eficiente que `instantiate`/`queue_free` constante.

### 2.5. Sistema de Crafteo y Estaciones de Trabajo

- **Reutilización por datos:** `Workstation.gd` es genérico. Cada escena define su `StationType` enum en el Inspector (export).
- **Filtrado de recetas:** el `UIManager` filtra y muestra solo `RecipeData` cuyo `required_station_type` coincide con la estación abierta.
- **Proceso de crafteo (`craft_async`):**
  1. Entra en estado `CRAFTING`.
  2. `InventoryManager.remove_item()` consume ingredientes.
  3. `await get_tree().create_timer(crafting_time * crafting_time_multiplier).timeout`.
  4. `InventoryManager.add_item()` añade el producto.
  5. `AudioManager.play_sfx("success_ding")`.
  6. Vuelve a `IDLE`.

### 2.6. Sistema de Ayudantes y Automatización (IA)

- **Arquitectura:** cada tipo de ayudante tiene su script de IA (`WorkerAI.gd` para Duendes, `GolemAI.gd`, `ApprenticeAI.gd`) heredando de una base común. Máquina de estados finita (FSM) con `enum State { IDLE, FETCHING, WORKING, DELIVERING }`.
- **Búsqueda eficiente (Patrón de Registro):** un ayudante en `IDLE` no escanea la escena. Llama al manager apropiado:
  ```gdscript
  var target = ResourceManager.get_closest_available_node(global_position, ResourceType.HERB)
  ```
  El manager recorre su lista interna (mucho menor que toda la escena) y devuelve el objetivo más cercano. Si hay objetivo cambia de estado; si no, sigue `IDLE`.
- **Protagonista (`ProtagonistAI.gd`):** misma arquitectura, pero sus objetivos son `CustomerAI` en estado `WAITING`.

### 2.7. Sistema de Pedidos y Clientes NPC

- **`OrderManager` como director:**
  - Tiene una lista pública de todos los `OrderData` posibles. Selecciona uno al azar y emite la señal `order_generated`.
  - Simultáneamente instancia un `Customer.tscn` en `spawn_point` y llama a `customer.setup(order_data, counter_point, exit_point)`.
- **Ciclo de vida (`CustomerAI.gd`):**
  - **`ARRIVING`:** se mueve desde `spawn_point` hasta `counter_point`.
  - **`WAITING`:** se queda en el mostrador. Muestra bocadillo con icono del ítem. `ProtagonistAI` puede identificarlo como objetivo.
  - **`LEAVING`:** activado por `on_order_completed()`. Se mueve al `exit_point` y `queue_free()` al llegar.
- **Completar un pedido:**
  - **Vía UI:** botón "Entregar" en `OrdersPopupPanel`.
  - **Vía Protagonista:** el `ProtagonistAI` detecta los ítems disponibles, va al cliente y completa automáticamente.
  - **Lógica final (en `OrderManager`):** descuenta items, suma coins, llama a `customer.on_order_completed()`, y genera el siguiente pedido.

### 2.8. Sistema de Progresión: Investigación y Mejoras

#### Investigación (Progresión Horizontal — Desbloqueo de Contenido)

- **`ResearchData` con prerrequisitos:** cada research tiene `prerequisites: Array[ResearchData]`. Esto forma un árbol tecnológico.
- **`ResearchManager`** mantiene `completed_research: Array[ResearchData]`.
- **Disponibilidad:** una investigación se muestra solo si:
  1. Su `required_station_type` coincide con la estación abierta.
  2. No está ya en `completed_research`.
  3. Todos sus `prerequisites` SÍ están completados.
- **Recompensas flexibles:** al completarse, desbloquea un `RecipeData` (`RecipeManager.unlock_recipe()`) o un `BuildableData` (`BuildManager.unlock_buildable()`).

#### Mejoras / Upgrades (Progresión Vertical — Optimización)

- Cada script de edificio (`Workstation`, `ResearchStation`, `ResourceGenerator`) contiene `current_level`, `upgrade_cost` y un `multiplier` de eficiencia.
- **El `UIManager` como mediador:** al abrir el panel de un edificio mejorable, conecta dinámicamente la señal `pressed` del botón "Mejorar" a `building.try_upgrade()`:
  ```gdscript
  upgrade_button.pressed.connect(active_workstation.try_upgrade)
  ```
- **Bucle de mejora:**
  1. Clic en "Mejorar".
  2. `try_upgrade()` verifica monedas en `InventoryManager`.
  3. Si OK, resta coins, `current_level += 1`, `multiplier *= 0.85`, `upgrade_cost *= 1.75`.
  4. Llama a `update_upgrade_button_ui()` y emite señal `upgraded` para refresco de UI.

---

## 3. Arquitectura Técnica (Godot 4)

### 3.1. Estructura de Carpetas

```
res://
├── art/
│   ├── sprites/        # Personajes, entorno, UI
│   ├── tiles/          # Tilesets de zonas
│   └── fonts/
├── audio/
│   ├── music/
│   └── sfx/
├── data/               # Recursos (.tres) — datos del juego
│   ├── buildables/
│   ├── items/
│   ├── orders/
│   ├── recipes/
│   └── research/
├── scenes/
│   ├── characters/     # workers, customer, protagonist
│   ├── environment/    # generators, workstations, storage
│   ├── ui/             # paneles, popups, tooltips
│   └── world/          # main_game.tscn, menu.tscn
├── scripts/
│   ├── ai/             # WorkerAI, GolemAI, ApprenticeAI, CustomerAI, ProtagonistAI
│   ├── core/           # CameraController, global_enums.gd
│   ├── data/           # ItemData, RecipeData, BuildableData, ResearchData (extends Resource)
│   ├── gameplay/       # Workstation, ResourceGenerator, ResourceNode
│   ├── managers/       # AutoLoads: UIManager, InventoryManager, BuildManager, etc.
│   └── window/         # WindowController (modo compañero)
└── project.godot
```

### 3.2. Arquitectura de Managers (AutoLoad / Singleton)

En lugar del patrón Singleton C# de Unity, Godot usa **AutoLoad** (registrados en `Project Settings → AutoLoad`). Cada manager es un Node global accesible por nombre desde cualquier script:

```gdscript
# scripts/managers/inventory_manager.gd
extends Node

var arcane_coins: int = 0
var items: Dictionary = {}  # ItemData -> int

signal coins_changed(new_amount: int)
signal item_added(item: ItemData, qty: int)

func add_item(item: ItemData, qty: int) -> void:
    items[item] = items.get(item, 0) + qty
    item_added.emit(item, qty)
```

**Managers principales (todos AutoLoad):**

| Manager | Responsabilidad |
|---|---|
| `UIManager` | Director de toda la UI, modelo de "panel único" |
| `InventoryManager` | Inventario central, coins, capacidad |
| `BuildManager` | Modo construcción, fantasma, colocación |
| `ResearchManager` | Árbol de investigación, completed_research |
| `ResourceManager` | Registro de nodos de recursos, búsqueda más cercana |
| `WorkstationManager` | Registro de estaciones por tipo |
| `OrderManager` | Generación de pedidos, spawn de clientes |
| `SaveManager` | Serialización/deserialización del estado |
| `AudioManager` | Music + SFX, con buses dedicados |
| `GridManager` | Grid lógico, ocupación, zonas |

**Comunicación desacoplada vía señales:** los sistemas no se llaman directamente entre sí. Emiten señales (`item_added`, `order_completed`, `research_completed`) a las que otros managers o nodos de UI se suscriben.

### 3.3. Arquitectura de Datos (Resources)

Todo el contenido del juego se modela como `Resource` (.tres) — equivalente directo de los `ScriptableObject` de Unity, pero más limpio y nativo del editor:

```gdscript
# scripts/data/item_data.gd
@tool
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var max_stack: int = 99
```

**Para crear contenido:** clic derecho en el FileSystem → `New Resource…` → seleccionar `ItemData` → editar en el Inspector. No requiere código.

**Tipos de Resource principales:**
- `ItemData.tres` — definición de un ítem (recursos, intermedios, productos finales).
- `RecipeData.tres` — receta de crafteo (ingredientes, output, tiempo, estación requerida).
- `BuildableData.tres` — edificio construible (escena, coste, zona permitida).
- `ResearchData.tres` — investigación (prerrequisitos, coste, recompensa).
- `OrderData.tres` — pedido posible (ítem requerido, cantidad, recompensa).

### 3.4. Lógica de la IA (Patrón de Registro)

Para evitar el ineficiente `get_tree().get_nodes_in_group()` o búsquedas de escena, los objetos se registran proactivamente:

- **Registro:** en `_ready()`, cada objeto funcional llama a su manager: `WorkstationManager.register(self)`, `ResourceManager.register_node(self)`.
- **Petición:** la IA pide tareas: `ResourceManager.get_closest_available_node(pos, ResourceType.HERB)`.
- **Respuesta:** el manager recorre su lista interna (pequeña) y devuelve el mejor objetivo casi instantáneamente.
- **Baja:** en `_exit_tree()`: `WorkstationManager.unregister(self)`, previniendo objetivos fantasma.

### 3.5. Sistema de Guardado y Carga

- **Estructura de datos:** un script `SaveData` con `@export` properties para todo lo persistente (coins, inventario serializado, ayudantes, progreso, edificios colocados).
- **Serialización:** Godot ofrece dos caminos limpios:
  1. **JSON** (legible, debuggable): `JSON.stringify(data_dict)` + `FileAccess.open("user://save.json", FileAccess.WRITE)`.
  2. **Resource nativo** (más eficiente, soporta references): `ResourceSaver.save(save_resource, "user://save.tres")`.
- **Almacenamiento:** `user://` (equivalente directo de `Application.persistentDataPath` de Unity).
- **Auto-save:** se conecta a `get_tree().auto_accept_quit = false` y se sobrescribe `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` en el `SaveManager` para guardar antes de cerrar.
- **Auto-load:** en `_ready()` del `SaveManager`, si existe `user://save.tres` lo carga y reconstruye estado inyectándolo en los demás managers vía sus métodos públicos.

---

## 4. Interfaz de Usuario y Experiencia (UI/UX)

### 4.1. Filosofía

- **Centralización:** el `UIManager` (AutoLoad) es el "director de orquesta". Los objetos del mundo no gestionan su UI; envían peticiones al manager.
- **Contextualidad:** los menús aparecen solo cuando son relevantes.
- **Panel único:** solo un panel pop-up principal puede estar abierto a la vez; abrir uno cierra el anterior.
- **Feedback constante:** señales (`coins_changed`, `inventory_updated`) refrescan la UI en tiempo real.

### 4.2. Estructura del Canvas y Paneles

Godot maneja la UI con `CanvasLayer` + nodos `Control`. La jerarquía:

```
MainGameCanvas (CanvasLayer)
├── HUDPanel (Control, ancla esquina, mouse_filter = IGNORE)
│   └── CoinLabel
├── ActionBar (HBoxContainer, anclado abajo)
│   ├── ButtonShop
│   ├── ButtonOrders
│   ├── ButtonInventory
│   └── ButtonBuild
├── InventoryPopup (PanelContainer, hidden)
├── OrdersPopup (PanelContainer, hidden)
├── ShopPopup (PanelContainer, hidden)
├── BuildMenuPopup (PanelContainer, hidden)
├── WorkstationPanel (PanelContainer, hidden)  # contextual
├── ResearchPanel (PanelContainer, hidden)     # contextual
├── GeneratorPanel (PanelContainer, hidden)    # contextual
├── ResearchProgressBar (ProgressBar, siempre visible)
└── TooltipPanel (PanelContainer, hidden, sigue al ratón)
```

**Escalado:** `Project Settings → Display → Window → Stretch` modo `canvas_items` para escalado pixel-perfect.

### 4.3. Flujo de Interacción

- **Clic en `ButtonShop`:** señal `pressed` conectada a `UIManager.toggle_shop_panel()` → cierra cualquier abierto, activa `ShopPopup`, reproduce SFX click.
- **Clic en una estación del mundo:** el `Area2D` de la estación emite `input_event`. El script `Workstation.gd` filtra clic izquierdo y llama a `UIManager.toggle_workstation_panel(self)`. El manager guarda `active_workstation`, abre el panel, conecta el botón "Mejorar" a `active_workstation.try_upgrade`, y puebla las recetas filtradas por `active_workstation.station_type`.

---

## 5. Característica Única: Modo Compañero de Escritorio

### 5.1. Concepto y Funcionalidad

Estado del juego donde la ventana se transforma en un widget minimalista sin bordes, "siempre visible" anclado a un borde de la pantalla. Permite supervisión pasiva del emporio y acceso a herramientas útiles sin interrumpir el trabajo del usuario.

### 5.2. Implementación Técnica en Godot (ventaja vs Unity)

En Unity esto requería **P/Invoke** a `SetWindowLong`, `SetWindowPos`, `SetLayeredWindowAttributes` — frágil, plataforma-específico, dolor de cabeza.

En **Godot 4** el `DisplayServer` ofrece todo nativamente y multiplataforma:

```gdscript
# scripts/window/window_controller.gd
extends Node

func switch_to_compact_mode() -> void:
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
    DisplayServer.window_set_size(Vector2i(1920, 120))
    var screen_size = DisplayServer.screen_get_size()
    DisplayServer.window_set_position(Vector2i(0, screen_size.y - 120))

func switch_to_expanded_mode() -> void:
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
    DisplayServer.window_set_size(Vector2i(1280, 720))
```

Para **transparencia real** (clic atraviesa zonas transparentes): habilitar en `project.godot` la opción `display/window/per_pixel_transparency/allowed = true` y `display/window/per_pixel_transparency/enabled = true`.

Para **input pass-through** en zonas transparentes (Godot 4.2+): `DisplayServer.window_set_mouse_passthrough(polygon)`.

### 5.3. El Compañero

`DesktopCompanionAI` instanciado en el modo compacto:
- Sprite grande y animado del protagonista o un ayudante.
- `AnimationPlayer` para "idle" (respirar, mirar alrededor) y reactivas (seguir cursor, reaccionar a clics).
- Patrulla lentamente en su barra.
- Drag & drop con `_input` o `Draggable` component custom.

### 5.4. Herramientas de Productividad y Ambiente

Doble clic / clic derecho en el compañero abre menú contextual:

- **Productividad:**
  - **Bloc de Notas** (`TextEdit` persistido en `user://notes.txt`).
  - **Lista de Tareas** (Tree o ItemList).
  - **Temporizador Pomodoro** (Timer + UI).
- **Ambiente:**
  - **Reproductor de Música** (`AudioStreamPlayer` con playlist).
  - **Mezclador de Sonidos** (varios `AudioStreamPlayer` en loop con sliders de volumen).

### 5.5. Sinergia con el Juego Principal

- Investigaciones y logros desbloquean skins, temas para widgets, paquetes de música.
- El compañero muestra bocadillos con notificaciones (`¡Pedido Urgente!`, `¡Investigación Completada!`), manteniendo al jugador conectado sin tener el juego en primer plano.

---

## 6. Contenido del Juego (Versión de Lanzamiento 8–10h)

### 6.1. Ítems (86 totales — v1.1)

**Recursos Primarios — del mapa, vía generadores (9):**
- Hierba Lunar (Parcela de Hierbas — default)
- Cristal de Cuarzo (Filón de Cristal — default)
- Madera Arcana (Arboleda Arcana — 90⚜, inicial)
- Mena de Hierro (Depósito de Hierro — 110⚜, inicial)
- Agua Arcana (Pozo Arcano — Patio Nv 2)
- Polvo Lunar (Altar Lunar — Patio Nv 3)
- Fragmento de Amatista (Geoda Amatista — Patio Nv 3)
- Lingote de Hierro (Veta Fundida — Patio Nv 4)
- Esencia Espiritual (Santuario — Patio Nv 4)

**Ingredientes Procesados (~30):** Cuarzo Purificado, Esencia Estabilizada, Tabla Encantada, Pergamino en Blanco, Pigmento Rúnico, Hilo de Tela Mágica, Resina Encantada, etc. — todos via recetas en las 5 estaciones.

**Productos Finales (~45):** pociones (curación, fuerza, mana, velocidad, resistencia, invisibilidad, antídoto, elixir de vida...), armas mágicas (daga, espada, lanza, arco, bastón), amuletos, anillos, pergaminos elementales, golems, capas, escudos, etc.

Ver `Catalogo_Maestro.xlsx → Items` para la lista completa con categoría, tier, valor base y obtainable.

### 6.2. Edificios Construibles (147 totales — v1.1)

**Generadores funcionales (9):**
- 4 iniciales (`unlocked_by_default = true`): Parcela de Hierbas, Filón de Cristal, Arboleda Arcana, Depósito de Hierro.
- 5 gated por nivel del Patio: Pozo Arcano (Nv 2), Altar Lunar (Nv 3), Geoda Amatista (Nv 3), Veta Fundida (Nv 4), Santuario Espiritual (Nv 4).

**Estaciones de Trabajo (7):** Caldero Alquímico, Forja Mística, Mesa de Encantamiento, Escritorio de Escriba, Círculo de Invocación, Biblioteca Arcana, Observatorio Astrológico.

**Soporte (4):** Cofre de Almacenamiento, Mostrador, Silla de Espera (solo Recepción — suma +1 cap de clientes), Almacén.

**Decoración (~125):** distribuidas en 5 categorías (wall, floor, table, nature, sin categoría). Filtradas por tab "✨ Decoración" en el panel de construcción.

Todos los buildables tienen `allowed_zone` (NATURE / WORKSHOP / RECEPTION / NONE). Panel de construcción muestra solo los compatibles con la zona activa.

### 6.3. Ayudantes (5 tipos — v1.1)

| Ayudante | Especialidad | Precio base | Velocidad | Notas |
|---|---|---|---|---|
| 🧚 Duende | hierba_lunar | 60⚜ | 90 | Rápido y barato |
| 🗿 Gólem | cristal_cuarzo | 120⚜ | 60 | Lento, resistente |
| 📚 Aprendiz | (investigación en estaciones) | 100⚜ | 75 | No recolecta — investiga |
| 🪓 Leñador | madera_arcana + mena_hierro | 180⚜ | 80 | Mid-game, cubre 2 raws |
| ✨ Espíritu | agua + polvo + amatista + esencia + lingote | 450⚜ | 95 | End-game, cubre 5 items raros |

Cada uno se compra desde el panel "Mercado" con `Arcane Coins` y recibe nombre aleatorio al crearse. El precio sube ×1.4 por cada compra adicional del mismo tipo.

`WorkerBase.preferred_resource_types: Array[int]` permite que un worker recoja múltiples tipos: itera la lista y elige el nodo más cercano de cualquiera. Sistema de reservas (`ResourceNode.reserve(worker)`) evita que dos workers vayan al mismo target.

### 6.4. Árbol de Investigación (22 nodos — v1.1)

Cada research pide **coins + materiales** (no solo coins). Auto-derivado por tema (alquimia → hierba+agua, metalurgia → hierro+cristal, etc.) y por tier (más caro = más materiales y más raros).

| Tier | Coste coins | Items requeridos | Investigaciones |
|---|---|---|---|
| T1 | ≤200⚜ | 6 + 3 (solo hierba/cristal) | Alquimia Básica, Cultivo Arcano, Minería Arcana, Metalurgia Básica |
| T2 | 201–500⚜ | 12 + 8 (+madera/hierro) | Destilación, Encantamiento Básico/Avanzado, Escritura Arcana, Telar, Curtido, Forja Mística, Extracción Hierro, Alquimia Avanzada |
| T3 | 501–1000⚜ | 20 + 12 + 4 raro (+agua/polvo) | Astrología, Observatorio, Invocación Básica, Zoología, Minería Avanzada |
| T4 | 1001–1500⚜ | 30 + 18 + 6 raro (+amatista/esencia) | Invocación Avanzada, Minería Legendaria |
| T5 | >1500⚜ | 35 + 20 + 8 raro (+lingote) | Metalurgia Legendaria, Familiares |

Cada research desbloquea recetas y/o buildables. Ver `Catalogo_Maestro.xlsx → Investigaciones` para detalles completos.
- Meta final: receta legendaria que sirve como objetivo de end-game para la versión de lanzamiento.

---

## 7. Hoja de Ruta de Desarrollo Futuro

### 7.1. Fase de Pulido ("Juiciness")

- Reemplazo de placeholders por pixel art final (DB16 o paleta personalizada).
- Animaciones de caminar, trabajar, idle para todos los ayudantes y el protagonista.
- VFX para crafteo, construcción, mejoras (`GPUParticles2D`).
- Diseño completo de sonido (música variada + banco de SFX).

### 7.2. Implementación Completa del Modo Compañero

- Resolver desafíos de manipulación de ventana (ventaja Godot: ya casi resuelto vs Unity).
- Desarrollar widgets de productividad.
- Implementar reproductor de música y mezclador de ambiente.
- Crear tienda de cosméticos in-game para monetización.

### 7.3. Expansiones de Contenido

- **"La Actualización del Gremio":** sistema de reputación, clientes VIP, tablón de misiones complejas.
- **"La Actualización de la Logística":** transporte físico, los ayudantes mueven ítems de cofres a estaciones, optimización de rutas.
- **"La Actualización de los Elementales":** nuevos recursos high-tier, ayudantes especializados (Hada de Luz, Elemental de Transporte).
- **"La Actualización de la Magia de Combate":** sistema de "defensa de la tienda" contra criaturas mágicas, nuevas armas/armaduras.

---

## 8. Plan de Port Unity → Godot (Mapeo de Equivalencias)

Esta sección documenta cómo traducir cada componente del proyecto Unity existente al equivalente en Godot 4.6. Sirve de blueprint para la migración.

### 8.1. Equivalencias Generales

| Unity | Godot 4 | Notas |
|---|---|---|
| `MonoBehaviour` | `Node` / `Node2D` | Heredar de la clase Node correcta según contexto |
| `Awake()` | `_ready()` | Godot no separa Awake/Start |
| `Start()` | `_ready()` | Mismo |
| `Update()` | `_process(delta)` | |
| `FixedUpdate()` | `_physics_process(delta)` | |
| `OnDestroy()` | `_exit_tree()` | |
| `OnMouseDown()` | `Area2D.input_event` o `Control.gui_input` | Requiere `Area2D` con `CollisionShape2D` |
| `Instantiate(prefab)` | `scene.instantiate()` + `add_child()` | `prefab` es `PackedScene` precargada |
| `Destroy(go)` | `node.queue_free()` | |
| `GetComponent<X>()` | `get_node()` / `$NodePath` / `find_child()` | Más explícito en Godot |
| `Transform` | `transform` (built-in en Node2D/Node3D) | |
| `Vector2/3` | `Vector2/3` | Idénticos en API |
| `Coroutines` (IEnumerator) | `await get_tree().create_timer(t).timeout` | O señales |
| `[SerializeField]` | `@export` | Mismo propósito |
| `Singleton (static Instance)` | **AutoLoad** | Configurado en Project Settings |
| `ScriptableObject` | **Resource** + `@tool class_name X extends Resource` | Más limpio |
| `[CreateAssetMenu]` | (automático con `class_name`) — clic derecho FileSystem → New Resource | |
| `Tilemap` | `TileMapLayer` (Godot 4.3+) | Una capa por layer, más performante |
| `Sprite Atlas` | `AtlasTexture` | |
| `Animator` | `AnimationPlayer` + `AnimationTree` | `AnimatedSprite2D` para sprite sheets |
| `Unity UI Canvas` | `CanvasLayer` + nodos `Control` | |
| `Button` | `Button` | Misma API básica |
| `Text` / `TMP_Text` | `Label` / `RichTextLabel` | |
| `Image` | `TextureRect` | |
| `JsonUtility.ToJson` | `JSON.stringify(dict)` | O `ResourceSaver.save()` |
| `Application.persistentDataPath` | `user://` | Identico propósito |
| `Resources.LoadAll()` | `load("res://...")` + `DirAccess.get_files_at()` | |
| `Time.deltaTime` | `delta` (parámetro de `_process`) | |
| `Input.GetKeyDown()` | `Input.is_action_just_pressed("name")` | Usar el InputMap |
| `Debug.Log()` | `print()` / `push_warning()` / `push_error()` | |
| `P/Invoke` para ventana | `DisplayServer.*` | **HUGE win** — multiplataforma nativo |

### 8.2. Mapeo de Scripts del Proyecto Actual

| Script Unity (C#) | Equivalente Godot (GDScript) | Cambios principales |
|---|---|---|
| `GameManager.cs` | AutoLoad `game_manager.gd` | Singleton → AutoLoad |
| `UIManager.cs` | AutoLoad `ui_manager.gd` | Mismo patrón; usar señales para refresh |
| `InventoryManager.cs` | AutoLoad `inventory_manager.gd` | Emitir señales `coins_changed`, `item_added` |
| `BuildManager.cs` | AutoLoad `build_manager.gd` | `Input` events ↔ InputMap |
| `GridManager.cs` | AutoLoad `grid_manager.gd` | `TileMapLayer.local_to_map()` |
| `ResearchManager.cs` | AutoLoad `research_manager.gd` | |
| `ResourceManager.cs` | AutoLoad `resource_manager.gd` | |
| `WorkstationManager.cs` | AutoLoad `workstation_manager.gd` | |
| `OrderManager.cs` | AutoLoad `order_manager.gd` | |
| `SaveManager.cs` | AutoLoad `save_manager.gd` | `ResourceSaver` o JSON |
| `AudioManager.cs` | AutoLoad `audio_manager.gd` | `AudioStreamPlayer` + buses |
| `Workstation.cs` | Escena `workstation.tscn` + `workstation.gd` | Node2D con Area2D para clic |
| `ResourceGenerator.cs` | `resource_generator.tscn` + script | Marker2D para SpawnPoint |
| `ResourceNode.cs` | `resource_node.tscn` + script | |
| `WorkerAI.cs` | `worker_ai.gd` (CharacterBody2D) | FSM con `enum State` |
| `GolemAI.cs` | `golem_ai.gd` | |
| `ApprenticeAI.cs` | `apprentice_ai.gd` | |
| `CustomerAI.cs` | `customer_ai.gd` | |
| `ProtagonistAI.cs` | `protagonist_ai.gd` | |
| `WindowController.cs` | `window_controller.gd` | **DisplayServer** en lugar de P/Invoke |
| `ItemData.cs` (SO) | `item_data.gd` extends Resource | |
| `RecipeData.cs` (SO) | `recipe_data.gd` extends Resource | |
| `BuildableData.cs` (SO) | `buildable_data.gd` extends Resource | |
| `ResearchData.cs` (SO) | `research_data.gd` extends Resource | |
| `TutorialManager.cs` | AutoLoad `tutorial_manager.gd` | |
| `ShopManager.cs` | AutoLoad `shop_manager.gd` | |
| `CameraController.cs` | `camera_controller.gd` (Camera2D) | |

### 8.3. Estrategia de Port Recomendada

**Opción A — Re-implementación incremental (RECOMENDADA):**
1. Crear proyecto Godot 4.6 limpio con la estructura de carpetas del § 3.1.
2. Portar primero las clases de datos (`Resource`): items, recipes, buildables, research. Es mecánico.
3. Portar los managers como AutoLoads, uno por uno, validando con prints.
4. Portar las escenas básicas: `MainGame.tscn` con TileMapLayer y un generador.
5. Portar la IA del Duende (`WorkerAI`), validar el loop completo: generador → recolección → estación → inventario.
6. Iterar añadiendo Gólem, Aprendiz, estaciones, pedidos, investigación, upgrades.
7. UI al final, una vez la lógica funciona.

**Opción B — Reescritura desde GDD:**
- Usar este GDD como spec y reescribir todo desde cero sin mirar el código Unity. Más limpio pero pierde aprendizajes/balanceo del proyecto actual.

**Opción C — Híbrido:**
- Re-implementación incremental (A), pero consultando el código Unity solo cuando un sistema tenga lógica no obvia (filtrado de recetas, validación de prerrequisitos de research, balanceo de upgrades).

### 8.4. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|---|---|
| Diferencias sutiles en `_process` vs `Update` | Validar con prints las primeras semanas |
| Save format incompatible | Aceptar: empezar de cero al portar; el balanceo cambiará |
| Tilemap zoning con `TileMapLayer` | Probar prototipo de 3 capas antes de comprometerse |
| Modo compañero con transparencia | Prototipar primero en una escena de prueba, no al final |
| Plugins Unity sin equivalente | Inventariar; la mayoría tienen alternativas en Godot |

---

## 9. Plan de Acción Inmediato

Habiendo decidido el port a Godot, el próximo paso no es continuar el desarrollo en Unity sino **iniciar el port siguiendo la Opción A del § 8.3**.

### 9.1. Setup del proyecto Godot

1. Crear `~/Proyectos/MysticEmporium/godot/` con Godot 4.6.x.
2. Configurar `project.godot`:
   - Resolución base 1920×1080, stretch `canvas_items`.
   - Habilitar `per_pixel_transparency` para el modo compañero.
   - Configurar InputMap (acciones: `build_confirm`, `build_cancel`, `ui_toggle_inventory`, etc.).
3. Crear la estructura de carpetas del § 3.1.
4. Configurar Git con `.gitignore` para Godot.

### 9.2. Portar las clases de datos (Resources)

5. `item_data.gd`, `recipe_data.gd`, `buildable_data.gd`, `research_data.gd`, `order_data.gd`.
6. Crear 2–3 `.tres` de prueba (HierbaLunar, CristalCuarzo, PocionCuracionMenor) para validar el flujo.

### 9.3. Portar los managers base como AutoLoads

7. `inventory_manager.gd` con señales.
8. `audio_manager.gd` con buses Music/SFX.
9. `save_manager.gd` con guardar/cargar JSON básico.

### 9.4. Implementar el Core Loop mínimo

10. `MainGame.tscn` con cámara 2D, una `TileMapLayer` de zona Natural.
11. `resource_generator.tscn` + `resource_node.tscn` (Hierba Lunar).
12. `worker_ai.gd` (Duende) — FSM mínima: IDLE → FETCHING → DELIVERING.
13. Inventario incrementa coins. Validar: un Duende recolecta de un generador y deposita.

### 9.5. UI mínima

14. `MainGameCanvas` con `HUDPanel` mostrando coins.
15. `InventoryPopup` mostrando el dict de items.

### 9.6. Iterar

16. Añadir crafteo (`Workstation`), pedidos (`OrderManager`), investigación (`ResearchManager`), upgrades, tutorial, modo compañero.
17. Pulir al final (sprites finales, animaciones, sonidos, VFX).

---

## Apéndice A — Recomendaciones Adicionales

- **Control de versiones desde el día uno:** usar GitHub privado o GitLab. Commits frecuentes con mensajes descriptivos.
- **Resolución pixel art recomendada:** sprites de personajes 32×32, tiles 16×16, UI elements 16×16 o 32×32. Camera2D con zoom entero (2x, 3x, 4x) para nitidez.
- **Paleta:** considerar [DB16](https://lospec.com/palette-list/dawnbringer-16) o una personalizada de 16–24 colores para coherencia. (Hay un MCP de pixel art configurado en este equipo que respeta DB16.)
- **Performance:** con miles de nodos (recursos, ayudantes), evitar `_process` cuando se pueda; usar `Timer` con señales para tareas periódicas.
- **Testing temprano del modo compañero:** prototipar la transparencia y `always_on_top` la primera semana. Es la feature de mayor riesgo técnico.

---

**Fin del documento.**
