extends Node2D
## Escena demo Minish: pinta un TileMapLayer y coloca objetos + jugador.
## Sirve para ver el estilo corriendo y como base editable en el editor.

const OBJ = "res://art/sprites/minish_objects/"

# atlas coords (x,y) de tiles clave en tileset_minish.tres
const TILE = {
	"grass": Vector2i(0, 0), "grass2": Vector2i(1, 0), "flowers": Vector2i(2, 0),
	"dirt": Vector2i(3, 0), "path": Vector2i(5, 0), "water": Vector2i(0, 1),
	"grass_dark": Vector2i(6, 2),
	"d_N": Vector2i(4, 3), "d_S": Vector2i(5, 3), "d_E": Vector2i(6, 3), "d_W": Vector2i(7, 3),
	"d_NW": Vector2i(0, 4), "d_NE": Vector2i(1, 4), "d_SW": Vector2i(2, 4), "d_SE": Vector2i(3, 4),
}
const W := 40
const H := 26


func _ready() -> void:
	var layer: TileMapLayer = $TileMapLayer
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# base de hierba
	for y in H:
		for x in W:
			var t := TILE.grass
			var r := rng.randi() % 12
			if r == 0:
				t = TILE.grass2
			elif r == 1:
				t = TILE.flowers
			layer.set_cell(Vector2i(x, y), 0, t)
	# estanque de agua (arriba-izquierda)
	for y in range(2, 7):
		for x in range(2, 9):
			layer.set_cell(Vector2i(x, y), 0, TILE.water)
	# camino horizontal
	for x in W:
		layer.set_cell(Vector2i(x, 15), 0, TILE.path)
		layer.set_cell(Vector2i(x, 16), 0, TILE.path)
	# parcela de tierra con borde (granja)
	var px0 := 24
	var py0 := 4
	var pw := 8
	var ph := 6
	for y in range(py0, py0 + ph):
		for x in range(px0, px0 + pw):
			layer.set_cell(Vector2i(x, y), 0, TILE.dirt)
	# bordes de la parcela
	for x in range(px0, px0 + pw):
		layer.set_cell(Vector2i(x, py0 - 1), 0, TILE.d_S)
		layer.set_cell(Vector2i(x, py0 + ph), 0, TILE.d_N)
	for y in range(py0, py0 + ph):
		layer.set_cell(Vector2i(px0 - 1, y), 0, TILE.d_E)
		layer.set_cell(Vector2i(px0 + pw, y), 0, TILE.d_W)
	layer.set_cell(Vector2i(px0 - 1, py0 - 1), 0, TILE.d_SE)
	layer.set_cell(Vector2i(px0 + pw, py0 - 1), 0, TILE.d_SW)
	layer.set_cell(Vector2i(px0 - 1, py0 + ph), 0, TILE.d_NE)
	layer.set_cell(Vector2i(px0 + pw, py0 + ph), 0, TILE.d_NW)

	# objetos decorativos (Sprite2D con y-sort)
	_place("tree", 6, 11)
	_place("tree", 12, 9)
	_place("tree_pine", 34, 10)
	_place("tree_apple", 4, 20)
	_place("tree", 36, 20)
	_place("bush", 18, 13)
	_place("bush", 9, 19)
	_place("rock", 14, 18)
	_place("pebbles", 20, 21)
	_place("stump", 28, 19)
	_place("flowers_white", 16, 22)
	_place("flowers_pink", 22, 12)
	_place("well", 8, 22)
	_place("sign", 20, 17)
	# valla alrededor de la parcela
	for x in range(px0, px0 + pw):
		_place("fence_h", x, py0 - 1)
	for y in range(py0, py0 + ph, 2):
		_place("fence_post", px0 - 1, y)
		_place("fence_post", px0 + pw, y)

	# jugador
	var player := preload("res://scenes/minish/player_minish.tscn").instantiate()
	player.position = Vector2(20 * 16, 18 * 16)
	add_child(player)
	var cam := Camera2D.new()
	cam.zoom = Vector2(3, 3)
	player.add_child(cam)


func _place(name: String, tx: int, ty: int) -> void:
	var s := Sprite2D.new()
	s.texture = load(OBJ + name + ".png")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = Vector2(tx * 16 + 8, ty * 16 + 16)
	s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	s.y_sort_enabled = true
	$Objects.add_child(s)
