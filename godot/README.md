# Mystic Emporium Automata — Godot Port

Port a Godot 4.6 del proyecto original de Unity. Ver `../GDD/GDD.md` o `GDD.docx` para el diseño completo.

## Estado actual

**El bucle interactivo completo funciona end-to-end:**

### Sistemas
- ✅ Bootstrap carga catálogos de items, recetas, órdenes, research y buildables.
- ✅ Generadores (Hierba, Cristal) crean nodos de recurso con cooldown.
- ✅ `ResourceManager` indexa los nodos para búsqueda eficiente.
- ✅ Duendes recolectan hierbas; Gólems recolectan cristales (FSM IDLE → FETCHING → COLLECTED).
- ✅ Inventario central con señales (`coins_changed`, `item_changed`).
- ✅ Estaciones (Caldero, Forja) con crafteo asíncrono filtrado por StationType.
- ✅ `OrderManager` genera pedidos + spawnea NPCs visibles (CustomerAI con FSM ARRIVING/WAITING/LEAVING).
- ✅ Save/Load JSON en `user://savegame.json`.
- ✅ `WindowController` con DisplayServer para el modo compañero.

### UI interactiva
- ✅ HUD top bar: coins, items, pedido actual, botón **Entregar**.
- ✅ HUD action bar inferior: botones Inventario / Construir / Modo Compañero.
- ✅ Panel Inventario (tecla **I** o botón).
- ✅ Panel Workstation: clic en cualquier estación → muestra recetas filtradas con ingredientes en tiempo real y botón Mejorar (con su coste/nivel).
- ✅ Panel Construir (tecla **B** o botón): lista de edificios desbloqueados, validación de zona/coste, fantasma verde/rojo siguiendo al mouse, clic izq confirma, clic der/Esc cancela.
- ✅ Modo Compañero (tecla **F12**): ventana borderless + always-on-top + transparency (DisplayServer nativo).
- ✅ Main menu con Continuar / Nueva partida / Salir.

### Contenido del lanzamiento (parcial)
- **6 items** (Hierba Lunar, Cristal Cuarzo, Polvo Lunar, Poción Curación, Lingote Hierro, Daga Encantada)
- **4 recetas** (Caldero ×2, Forja ×2)
- **5 pedidos** distintos
- **4 buildables** desbloqueados de inicio (Parcela Hierbas, Filón Cristal, Caldero, Forja)
- **3 ayudantes** (Duende, Gólem, Aprendiz)

## Cómo correr

```bash
cd ~/Proyectos/MysticEmporium/godot
godot .                                       # abre el editor
# o en headless para verificación rápida:
godot --headless res://scenes/world/main_game.tscn --quit-after 1500
```

## Estructura

```
godot/
├── project.godot
├── art/                       # sprites finales (pendientes)
├── audio/                     # música y SFX (pendientes)
├── data/                      # Resources .tres (items, recipes, orders, research, buildables)
│   ├── items/                 # 4 items de prueba
│   ├── recipes/               # 2 recetas del caldero
│   └── orders/                # 3 pedidos
├── scenes/
│   ├── characters/            # worker_duende, worker_golem, worker_apprentice
│   ├── environment/           # resource_node, resource_generator_herbs, workstation_cauldron
│   ├── ui/                    # hud, inventory_panel, main_menu
│   └── world/                 # main_game.tscn (escena principal)
└── scripts/
    ├── ai/                    # worker_base + 3 especializaciones
    ├── core/                  # global_enums, game_bootstrap
    ├── data/                  # ItemData, RecipeData, BuildableData, ResearchData, OrderData
    ├── gameplay/              # resource_node, resource_generator, workstation
    ├── managers/              # 10 AutoLoads (ver project.godot)
    ├── ui/                    # hud, inventory_panel, main_menu
    └── window/                # window_controller (modo compañero)
```

## AutoLoads activos

| AutoLoad | Ruta | Función |
|---|---|---|
| `GameEnums` | `scripts/core/global_enums.gd` | Enums compartidos (ZoneType, StationType, etc.) |
| `AudioManager` | `scripts/managers/audio_manager.gd` | Música + pool de 8 SFX players |
| `InventoryManager` | `scripts/managers/inventory_manager.gd` | Coins + items + señales |
| `ResourceManager` | `scripts/managers/resource_manager.gd` | Registro de nodos de recurso |
| `WorkstationManager` | `scripts/managers/workstation_manager.gd` | Registro de estaciones |
| `GridManager` | `scripts/managers/grid_manager.gd` | Grid lógico + zonas |
| `BuildManager` | `scripts/managers/build_manager.gd` | Modo construcción con fantasma |
| `ResearchManager` | `scripts/managers/research_manager.gd` | Árbol de investigación |
| `OrderManager` | `scripts/managers/order_manager.gd` | Generación de pedidos |
| `UIManager` | `scripts/managers/ui_manager.gd` | Orquestador (panel único) |
| `SaveManager` | `scripts/managers/save_manager.gd` | JSON save en `user://` |
| `WindowController` | `scripts/window/window_controller.gd` | Modo compañero (DisplayServer) |

## Controles (InputMap configurado)

| Acción | Tecla |
|---|---|
| `build_confirm` | Clic izquierdo |
| `build_cancel` | Clic derecho · Esc |
| `ui_toggle_inventory` | `I` |
| `ui_toggle_build` | `B` |
| `ui_toggle_companion` | `F12` |

## Próximos pasos (del § 9 del GDD)

### Inmediatos (sin hacer aún)
- [ ] `ProtagonistAI` para entrega automática de pedidos a los CustomerAI esperando.
- [ ] Encanting Table + Scribe Desk + sus recetas.
- [ ] Iron Ore + Arcane Wood + Spirit Essence como recursos faltantes (~25 items totales del GDD).
- [ ] Mostrar y persistir reputación.

### Sistemas faltantes
- [ ] `TileMapLayer` por cada zona (Natural, Workshop, Reception) y wire-up con `GridManager.register_zone_layer()`.
- [ ] `RecipeManager` para gestionar recetas desbloqueadas dinámicamente.
- [ ] Panel de research con barra de progreso global.
- [ ] Tutorial step-by-step (`TutorialManager`).
- [ ] Sistema de mejoras (`upgrade_cost` ya está en `Workstation`, falta UI).

### Pulido
- [ ] Reemplazar `Polygon2D` placeholders por pixel art (DB16). Hay un MCP de pixel art configurado.
- [ ] AnimationPlayer/AnimatedSprite2D para idle/walk de workers.
- [ ] Particles2D para crafteo y mejora.
- [ ] AudioStreams reales en `audio/sfx/` y `audio/music/`.

### Modo compañero
- [ ] Sprite del compañero + animaciones idle.
- [ ] Widgets de productividad (notas, pomodoro, lista de tareas).
- [ ] Reproductor de música + mezclador de ambiente.

## Validación rápida

Si quieres confirmar que todo sigue parseando después de un cambio:

```bash
godot --headless --import
# Debe terminar sin "Parse error" ni "SCRIPT ERROR"
```

Y para validar el runtime:

```bash
godot --headless res://scenes/world/main_game.tscn --quit-after 1500 2>&1 | grep -E "Bootstrap|Collect"
# Debe ver el bootstrap y al menos un par de "[Collect] +1 Hierba Lunar"
```

## Notas técnicas

- **No usar `Array.erase()` esperando bool** — retorna `void` en Godot. Usar `find()` + `remove_at()`.
- **No usar `add_child()` en `_ready`** del propio script si el padre aún está montando hijos. Usar `call_deferred("add_child", n)` o `parent.add_child.call_deferred(n)`.
- **Cast `as Array[T]` no convierte arrays sin tipo** — usar `typed_array.assign(untyped_array)`.
- **`@tool` en data scripts** es para que el editor pueda crear `.tres` con `Create > New Resource > <Type>`.
- **Stretch mode `canvas_items` + `keep`** mantiene pixel-perfect en distintas resoluciones.
- **`per_pixel_transparency/allowed=true`** ya está configurado en `project.godot` para el modo compañero.

## Referencias

- GDD completo: `~/Proyectos/MysticEmporium/GDD/GDD.docx`
- Conversación original (Gemini): `~/Descargas/Mystic Emporium Automata_ Desktop Game`
- Repo Unity original: <https://github.com/bluelotus17113/MysticEmporium> (estaba vacío)
