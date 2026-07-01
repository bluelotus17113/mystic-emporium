# Graph Report - .  (2026-07-01)

## Corpus Check
- Corpus is ~7,208 words - fits in a single context window. You may not need a graph.

## Summary
- 84 nodes · 115 edges · 10 communities (8 shown, 2 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.76)
- Token cost: 60,000 input · 12,557 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Companion Mode + Living World|Companion Mode + Living World]]
- [[_COMMUNITY_Core Loop + Data Foundations|Core Loop + Data Foundations]]
- [[_COMMUNITY_Progression Meta + Bootstrap|Progression Meta + Bootstrap]]
- [[_COMMUNITY_Autoloads + Build Pipeline|Autoloads + Build Pipeline]]
- [[_COMMUNITY_Order + Delivery Flow|Order + Delivery Flow]]
- [[_COMMUNITY_Workers + Research|Workers + Research]]
- [[_COMMUNITY_AI + Idle Automation|AI + Idle Automation]]
- [[_COMMUNITY_Resource Generation + Zones|Resource Generation + Zones]]
- [[_COMMUNITY_Map Overview|Map Overview]]
- [[_COMMUNITY_UI Manager|UI Manager]]

## God Nodes (most connected - your core abstractions)
1. `SaveManager (3 slots JSON + migración)` - 12 edges
2. `Mystic Emporium Automata` - 8 edges
3. `Modo Compañero de Escritorio` - 8 edges
4. `WorkerAI (base FSM IDLE/FETCHING/WORKING/DELIVERING)` - 8 edges
5. `Core Loop (observar-construir-automatizar-producir-recompensa-reinvertir)` - 6 edges
6. `Sistema de Construcción Basado en Rejilla` - 6 edges
7. `Sistema de Ayudantes / IA con FSM` - 6 edges
8. `Catálogos en data/ (items/recipes/orders/research/buildables)` - 6 edges
9. `Sistema de Zonas Especializadas` - 5 edges
10. `Sistema de Investigación (progresión horizontal)` - 5 edges

## Surprising Connections (you probably didn't know these)
- `IdleAutomationManager (tick 1.5s)` --semantically_similar_to--> `Sistema de Ayudantes / IA con FSM`  [INFERRED] [semantically similar]
  ARCHITECTURE.md → GDD.md
- `InputMap (B/I/F12 + click)` --shares_data_with--> `Sistema de Construcción Basado en Rejilla`  [INFERRED]
  README.md → GDD.md
- `Rutas de saves (user:// por plataforma)` --shares_data_with--> `SaveManager (3 slots JSON + migración)`  [EXTRACTED]
  BUILD.md → ARCHITECTURE.md
- `Modo Compañero de Escritorio` --references--> `WindowController (modo companion/normal)`  [EXTRACTED]
  GDD.md → ARCHITECTURE.md
- `Sistema de Construcción Basado en Rejilla` --references--> `BuildManager`  [EXTRACTED]
  GDD.md → ARCHITECTURE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Core loop end-to-end (generar -> craftear -> vender)** — graphify_docs_gdd_resource_generator, graphify_docs_gdd_worker_ai, graphify_docs_gdd_workstation, graphify_docs_architecture_order_manager, graphify_docs_architecture_inventory_manager [EXTRACTED 1.00]
- **Modo Compañero (widget desktop pet)** — graphify_docs_gdd_companion_mode, graphify_docs_architecture_window_controller, graphify_docs_gdd_display_server_advantage, graphify_docs_gdd_productivity_tools, graphify_docs_gdd_ambient_tools [EXTRACTED 1.00]
- **Sistema de 3 zonas mutuamente exclusivas** — graphify_docs_gdd_zone_natural, graphify_docs_gdd_zone_workshop, graphify_docs_gdd_zone_reception, graphify_docs_architecture_zone_camera_controller, graphify_docs_architecture_zone_expansion_manager [EXTRACTED 1.00]

## Communities (10 total, 2 thin omitted)

### Community 0 - "Companion Mode + Living World"
Cohesion: 0.14
Nodes (16): WindowController (modo companion/normal), Herramientas de ambiente (música/mezclador), Modo Compañero de Escritorio, Pilar: Diseño Estratégico del Layout, Pilar: Mundo Vivo y Encantador, Pilar: Compañía No Intrusiva, Pilar: Progresión Constante y Gratificante, DisplayServer nativo (ventaja vs Unity P/Invoke) (+8 more)

### Community 1 - "Core Loop + Data Foundations"
Cohesion: 0.20
Nodes (15): Catálogos en data/ (items/recipes/orders/research/buildables), GridManager, ZoneCameraController (visibility toggle por grupo), BuildableData, Core Loop (observar-construir-automatizar-producir-recompensa-reinvertir), Sistema de Crafteo y Estaciones, Sistema de Construcción Basado en Rejilla, ItemData (+7 more)

### Community 2 - "Progression Meta + Bootstrap"
Cohesion: 0.23
Nodes (12): Achievement cascade guard (_checking flag), BuildManager, CalendarManager, DailyQuestManager, game_bootstrap.gd (auto-carga catálogos), NotificationManager (throttled 4/sec), PrestigeManager, RecipeManager (+4 more)

### Community 3 - "Autoloads + Build Pipeline"
Cohesion: 0.22
Nodes (9): 25 Managers AutoLoad, Distribución AppImage, Preset Linux x86_64, Build & Export pipeline, Rutas de saves (user:// por plataforma), Preset Windows Desktop (cross-compile), AutoLoad / Singleton (Godot), Godot 4.6.2 (motor) (+1 more)

### Community 4 - "Order + Delivery Flow"
Cohesion: 0.22
Nodes (9): Guard doble-entrega (flag completed + erase inmediato), EventManager (coin_mult, eventos random), InventoryManager, Signal flow entrega de orden (try_complete_at), OrderManager, VFXManager, 5 Eventos Dinámicos (Festival Lunar, Eclipse, Inspección, Bandidos, Tormenta), Sistema de Pedidos y Clientes NPC (+1 more)

### Community 5 - "Workers + Research"
Cohesion: 0.25
Nodes (8): ShopManager (compra de ayudantes), Sistema de Investigación (progresión horizontal), WorkerAI (base FSM IDLE/FETCHING/WORKING/DELIVERING), Aprendiz (investiga en estaciones), Duende (worker rápido), Gólem (worker resistente), Leñador (madera + hierro), Espíritu (end-game, 5 recursos raros)

### Community 6 - "AI + Idle Automation"
Cohesion: 0.33
Nodes (7): IdleAutomationManager (tick 1.5s), Sistema de Ayudantes / IA con FSM, CustomerAI (FSM ARRIVING/WAITING/LEAVING), Pilar: Automatización Satisfactoria, ProtagonistAI (atiende clientes), Patrón de Registro (managers indexan objetos), Zona: Atrio del Emporio (Recepción)

### Community 7 - "Resource Generation + Zones"
Cohesion: 0.40
Nodes (6): Alpha gating (modulate.a=0 vs visible=false), ZoneExpansionManager (patio niveles 0-5), Sistema de Generación de Recursos, ResourceGenerator, ResourceNode, Zona: Santuario Natural (Patio Natural)

## Knowledge Gaps
- **20 isolated node(s):** `Duende (worker rápido)`, `Gólem (worker resistente)`, `Leñador (madera + hierro)`, `Espíritu (end-game, 5 recursos raros)`, `Sistema Save/Load (JSON atómico)` (+15 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SaveManager (3 slots JSON + migración)` connect `Progression Meta + Bootstrap` to `Autoloads + Build Pipeline`, `Order + Delivery Flow`, `AI + Idle Automation`, `Resource Generation + Zones`?**
  _High betweenness centrality (0.361) - this node is a cross-community bridge._
- **Why does `Mystic Emporium Automata` connect `Companion Mode + Living World` to `Core Loop + Data Foundations`, `AI + Idle Automation`?**
  _High betweenness centrality (0.207) - this node is a cross-community bridge._
- **Why does `Core Loop (observar-construir-automatizar-producir-recompensa-reinvertir)` connect `Core Loop + Data Foundations` to `Companion Mode + Living World`, `Order + Delivery Flow`, `Workers + Research`, `Resource Generation + Zones`?**
  _High betweenness centrality (0.197) - this node is a cross-community bridge._
- **What connects `Pilar: Diseño Estratégico del Layout`, `Pilar: Progresión Constante y Gratificante`, `Pilar: Mundo Vivo y Encantador` to the rest of the system?**
  _30 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Companion Mode + Living World` be split into smaller, more focused modules?**
  _Cohesion score 0.14166666666666666 - nodes in this community are weakly interconnected._