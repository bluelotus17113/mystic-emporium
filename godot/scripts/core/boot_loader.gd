extends Control
## Splash screen que precarga main_game.tscn en un thread para eliminar el
## freeze de 500ms-2s al arrancar. Muestra progress bar mientras Godot resuelve
## las 47 ext_resources (workers, workstations, UI panels, etc). Cuando el
## threaded load termina, hace change_scene_to_packed — instantáneo porque el
## PackedScene ya está en memoria.

const MAIN_GAME_PATH: String = "res://scenes/world/main_game.tscn"
const POMODORO_PATH: String = "res://scenes/standalone/pomodoro_app.tscn"
const TODO_PATH: String = "res://scenes/standalone/todo_app.tscn"

## Sprites críticos: aparecen en los primeros minutos y causan hitch al primer draw
## si Godot los sube al VRAM en runtime. Los renderizamos invisibles por 1 frame antes
## de cambiar de escena para forzar el upload.
const PREWARM_TEXTURES: Array[String] = [
	# Workers (visibles casi de inmediato)
	"res://art/sprites/characters/duende_anim.png",
	"res://art/sprites/characters/golem.png",
	"res://art/sprites/characters/apprentice.png",
	"res://art/sprites/characters/lenador_anim.png",
	"res://art/sprites/characters/espiritu_anim.png",
	"res://art/sprites/characters/protagonist_anim.png",
	# Workstations en pantalla desde el arranque
	"res://art/sprites/environment/cauldron_anim.png",
	"res://art/sprites/environment/forge_anim.png",
	"res://art/sprites/environment/bookshelf.png",
	# Icons de HUD que se muestran cada frame
	"res://art/sprites/environment/ws_caldero.png",
	"res://art/sprites/environment/ws_forja.png",
	"res://art/sprites/environment/rs_biblioteca.png",
	# Generator nodes / plots (aparecen al minuto ~2)
	"res://art/sprites/environment/pozo_arcano_node.png",
	"res://art/sprites/environment/altar_lunar_node.png",
	"res://art/sprites/environment/geoda_amatista_node.png",
	"res://art/sprites/environment/forja_fundida_node.png",
	"res://art/sprites/environment/santuario_espiritu_node.png",
]

@onready var progress_bar: ProgressBar = $Center/VBox/ProgressBar
@onready var status_label: Label = $Center/VBox/StatusLabel

var _target_path: String = MAIN_GAME_PATH
var _load_progress: Array = [0.0]  # ByRef container que Godot rellena


func _ready() -> void:
	# Enrutado por args igual que app_launcher (mantener paridad).
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		if a == "--pomodoro":
			_target_path = POMODORO_PATH
			DisplayServer.window_set_title("Pomodoro")
			DisplayServer.window_set_size(Vector2i(360, 340))
			DisplayServer.window_set_min_size(Vector2i(280, 240))
		elif a == "--todo":
			_target_path = TODO_PATH
			DisplayServer.window_set_title("Tareas")
			DisplayServer.window_set_size(Vector2i(440, 460))
			DisplayServer.window_set_min_size(Vector2i(280, 240))

	# Standalone apps (pomodoro/todo) son livianas — cambiar directo sin splash.
	if _target_path != MAIN_GAME_PATH:
		get_tree().change_scene_to_file.call_deferred(_target_path)
		return

	status_label.text = "Cargando Mystic Emporium..."
	progress_bar.value = 0.0
	# ResourceLoader threaded: Godot resuelve deps en un worker thread interno.
	# CACHE_MODE_REUSE evita duplicar assets si ya están en el ResourceLoader cache.
	var err: int = ResourceLoader.load_threaded_request(MAIN_GAME_PATH, "PackedScene", true, ResourceLoader.CACHE_MODE_REUSE)
	if err != OK:
		push_error("[BootLoader] load_threaded_request failed: %s" % err)
		# Fallback: change_scene sincrónico. Peor UX pero garantiza que el juego abre.
		get_tree().change_scene_to_file.call_deferred(MAIN_GAME_PATH)
		return
	set_process(true)


func _process(_delta: float) -> void:
	var status: int = ResourceLoader.load_threaded_get_status(MAIN_GAME_PATH, _load_progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = _load_progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			status_label.text = "Precacheando texturas..."
			set_process(false)
			var scene: PackedScene = ResourceLoader.load_threaded_get(MAIN_GAME_PATH)
			# Force VRAM upload de sprites críticos: los pintamos invisibles por 1 frame
			# antes de cambiar de escena. Sin esto Godot hace lazy upload al primer draw
			# in-game y hitchea 20-80ms al ver un sprite nuevo.
			_prewarm_textures()
			# call_deferred + await para dar tiempo al frame de terminar el upload.
			await get_tree().process_frame
			get_tree().change_scene_to_packed.call_deferred(scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[BootLoader] threaded load failed with status %d" % status)
			set_process(false)
			# Fallback sincrónico.
			get_tree().change_scene_to_file.call_deferred(MAIN_GAME_PATH)


## Renderiza los sprites críticos invisibles por 1 frame para forzar el upload al
## VRAM. Sin esto, el primer draw de cada textura in-game causa hitch de 20-80ms.
func _prewarm_textures() -> void:
	var warmup_layer := CanvasLayer.new()
	warmup_layer.visible = false  # nunca aparece, pero Godot igual dispatch el draw
	add_child(warmup_layer)
	for path in PREWARM_TEXTURES:
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(-9999, -9999)  # fuera de la pantalla por si acaso
		warmup_layer.add_child(s)
	# El warmup_layer se destruye con this Node al change_scene, no hace falta cleanup.
