# Mystic Emporium — Mapa de arquitectura

Reemplazo manual del knowledge-graph que graphify no puede generar al no soportar GDScript.

## 1. Autoloads (25 managers)

| Manager | Job |
|---------|-----|
| GameEnums | Enums globales (WorkerType, ZoneType, StationType...) |
| NameGenerator | Nombres procedurales |
| AudioManager | BGM/SFX + pool de beeps |
| InventoryManager | Coins, reputación, items, max_capacity |
| ShopManager | Compra de ayudantes (Duende/Golem/Apprentice) |
| ResourceManager | Legacy placeholder |
| WorkstationManager | Registry de estaciones |
| GridManager | Validación de placement en grilla |
| BuildManager | Buildables unlock/demolish/refund |
| ResearchManager | Tech tree, gating de recipes/buildables |
| RecipeManager | Recetas unlocked + filtrado por station_type |
| OrderManager | Spawn clientes, queue, delivery |
| UIManager | Lifecycle de paneles |
| VFXManager | Partículas (COINS, UPGRADE, etc.) |
| NotificationManager | Toast queue throttled 4/sec |
| EventManager | Eventos random + multiplicadores |
| StatsManager | Achievements + guard anti-recursión |
| CalendarManager | Día/estación syncado a PC |
| IdleAutomationManager | Auto-craft/research/upgrade tick 1.5s |
| PrestigeManager | Stars + bonus coins permanente |
| DailyQuestManager | Misión diaria por cambio de fecha |
| ZoneExpansionManager | Patio levels 0-5 |
| SaveManager | 3 slots JSON + migración legacy |
| TutorialManager | Onboarding |
| WindowController | Modo companion/normal |

## 2. Signal flow de entrega de orden

Entrada: `OrderManager.try_complete_at(index)`

1. Check índice válido + `entry.completed == false`
2. **`entry.completed = true`** (guard contra doble entrega)
3. `InventoryManager.consume_items()` → si falla, rollback `completed=false`
4. **`_active.erase(entry)` inmediato** — el cliente sigue animando hacia el exit pero ya no cuenta en la cola activa
5. Recompensa: `EventManager.coin_mult × personality.coin_mult × order.coin_reward`
6. `entry.customer.leave()` → estado LEAVING
7. VFX coins + beep 720Hz
8. Emit en ESTE orden:
   - `queue_changed` → `HUD._refresh_all` pinta próxima orden o "—"
   - `order_completed` → `_on_order_completed` muestra "✓ entregada" si count==0
9. Eventualmente `_on_customer_left` libera la silla (idempotente)

Fix crítico: el flag `completed` + erase inmediato evita el bug original de doble entrega durante el walk-out.

## 3. Sistema de zonas (3 mutuamente exclusivas)

`ZoneCameraController._apply_zone_visibility(zone_name)` itera 3 grupos:
- `natural_visual` → solo si zone == "natural"
- `taller_visual` → solo si zone == "taller"
- `recepcion_visual` → solo si zone == "recepcion"

Gameplay (ticks, crafting) sigue corriendo off-screen; solo se gatea el render.

**Patio Natural expansión** (`ZoneExpansionManager`):
- Anchor izquierdo en x=1000, crece hacia derecha
- Niveles 0→5: width 800px → 4500px
- Altura fija 400 (compatible con companion mode strip)
- Cámara solo pannea horizontal (edge-scroll / wheel / right-click drag)
- Zoom auto-ajustado para que entre la altura completa

Ubicación física:
- **Generadores + Duendes + Golem** → Patio Natural (x ≈ 1000-3500)
- **Workstations + Apprentice + Protagonista** → Taller (x ≈ -1950 a -1050)
- **Counter + Customer markers** → Recepción (x ≈ -650 a 80)

## 4. Estado guardado

SaveManager → 11 managers persisten a JSON (slot 0-2):

| Clave | Manager | Contenido |
|---|---|---|
| `inventory` | InventoryManager | coins, items, max_capacity, reputation |
| `stats` | StatsManager | dict de stats + achievements desbloqueados |
| `calendar` | CalendarManager | current_day, current_season |
| `recipes` | RecipeManager | IDs de recetas unlocked |
| `research` | ResearchManager | activa, completadas, progreso |
| `build` | BuildManager | buildings colocados + buildables unlocked |
| `idle` | IdleAutomationManager | toggles auto-craft/research/upgrade/buy |
| `prestige` | PrestigeManager | stars, lifetime_stars, prestige_count |
| `daily_quest` | DailyQuestManager | quest activa + baseline |
| `zones` | ZoneExpansionManager | natural_level |

Transientes (no guardados): OrderManager._active, WorkstationManager state, clientes en escena.

## 5. Catálogos en `data/`

```
data/
├── items/         ~85 .tres (tier 1-5)
├── recipes/       ~36 .tres (gated por research)
├── orders/        ~22 .tres (40% de spawns son procedurales)
├── research/      ~22 .tres (tech tree)
├── buildables/    11 .tres
└── theme/         global_theme.tres (pixel art chunky)
```

`game_bootstrap.gd` al arrancar:
1. Auto-carga cada folder via `_load_resources_from_dir()`
2. Llama a `OrderManager.set_catalog()`, `RecipeManager.set_catalog()`, etc.
3. Wirea `OrderManager.{customer_scene, spawn_point, counter_point, exit_point}` desde markers del grupo
4. `ShopManager.register_worker_scene(type, scene)` para cada worker
5. `BuildManager.unlock_default_buildables(catalog)`

## 6. Gotchas

**a) Achievement cascade guard (`_checking`).** En `stats_manager.gd:123-152`: `_check_achievements()` daba recompensa síncrona → `add_coins` → `coins_changed` → `_on_coins_changed` → `bump` → `_check_achievements` de nuevo en la misma pila, congelando el juego. Fix: flag `_checking: bool` + `InventoryManager.call_deferred("add_coins")`.

**b) Generador locked = `modulate.a=0`, no `visible=false`.** En `resource_generator.gd:50-58`: el `ZoneCameraController` ya posee `visible` (lo togglea por zona). Si gating usara `visible`, pelearían. Alpha mantiene el nodo en el tree, sigue tickeando, pero invisible; al expandirse el patio el fade vuelve a 1.

**c) NotificationManager throttled (4/sec).** En `notification_manager.gd:10-44`: `post()` encola, `_process` emite máximo 1 cada 250ms. Antes una cascada de 5 logros + entrega de orden + investigación completaba en un frame creaba 8+ toasts con tween cada uno = freeze.

## Referencias clave de archivos

- `scripts/managers/order_manager.gd:153-184` — try_complete_at con guard
- `scripts/gameplay/zone_camera_controller.gd:_apply_zone_visibility` — toggle por grupo
- `scripts/managers/zone_expansion_manager.gd` — sizing + center_x
- `scripts/gameplay/resource_generator.gd:_apply_gating` — alpha gating
- `scripts/managers/stats_manager.gd:_check_achievements` — guard recursión
- `scripts/managers/notification_manager.gd:post + _process` — queue throttle
- `scripts/core/game_bootstrap.gd` — wiring de catálogos
- `scripts/managers/save_manager.gd:save_game/load_game` — estructura del save dict
