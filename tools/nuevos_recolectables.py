#!/usr/bin/env python3
"""Los cuatro recolectables de endgame: escenas, nodos y buildables.

Los tres últimos niveles del Patio Natural (Fronda 4000⚜, Selva 9000⚜, Bosque
Ancestral 20000⚜) no desbloqueaban ningún recurso: el jugador pagaba la expansión
y no recibía nada. Estos cuatro generadores cuelgan justo de esos niveles.

Se genera por script y no a mano porque son 12 ficheros con referencias cruzadas.
Y **sin un solo `uid=`**: un uid equivocado resuelve al recurso equivocado en
silencio, que es como se rompieron las investigaciones en su día. Godot resuelve
por `path=` y asigna los uid al importar.

Las texturas son PRESTADAS de recursos parecidos, porque los sprites propios se
dibujan después. Cambiar cada una es una línea en la tabla de aquí abajo.

    python3 tools/nuevos_recolectables.py
"""
import pathlib
import struct

RAIZ = pathlib.Path(__file__).resolve().parent.parent / "godot"
LADO = 40  # cada fotograma de una parcela mide 40×40

# id, nombre, tipo (ResourceType), edificio, coste, nivel de patio, cooldown,
# textura de parcela prestada, textura de nodo prestada
RECURSOS = [
    ("sal_abisal", "Sal Abisal", 10, "Salina Abisal", 850, 5, 14.0,
     "plot_geoda_amatista_anim.png", "geoda_amatista_node.png"),
    ("raiz_umbria", "Raíz Umbría", 11, "Arboleda Umbría", 950, 5, 15.0,
     "plot_wood_anim.png", "wood_node.png"),
    ("ceniza_estelar", "Ceniza Estelar", 12, "Brasero Estelar", 1800, 6, 20.0,
     "plot_altar_lunar_anim.png", "altar_lunar_node.png"),
    ("nucleo_obsidiana", "Núcleo de Obsidiana", 13, "Vena de Obsidiana", 3200, 7, 26.0,
     "plot_forja_fundida_anim.png", "forja_fundida_node.png"),
    # Segunda tanda. Nacieron como items sueltos de la tabla de contenido; sin
    # generador habrían sido inalcanzables, que es el fallo que ya arrastra el
    # juego 25 veces. Aquí se les da de dónde salir.
    ("polvo_espectro", "Polvo de Espectro", 14, "Cripta Espectral", 900, 5, 15.0,
     "plot_santuario_espiritu_anim.png", "santuario_espiritu_node.png"),
    ("savia_ancestral", "Savia Ancestral", 15, "Tocón Ancestral", 1000, 5, 16.0,
     "plot_herbs_anim.png", "herb_node.png"),
    ("fragmento_celestial", "Fragmento Celestial", 16, "Cráter Celeste", 1900, 6, 21.0,
     "plot_altar_lunar_anim.png", "altar_lunar_node.png"),
    ("corazon_magmatico", "Corazón Magmático", 17, "Caldera Magmática", 2000, 6, 22.0,
     "plot_forja_fundida_anim.png", "forja_fundida_node.png"),
    ("escarcha_eterna", "Escarcha Eterna", 18, "Manantial Helado", 3000, 7, 25.0,
     "plot_pozo_arcano_anim.png", "pozo_arcano_node.png"),
    ("rayo_cristalizado", "Rayo Cristalizado", 19, "Pararrayos Arcano", 3400, 7, 27.0,
     "plot_crystal_anim.png", "crystal_node.png"),
]

NIVEL_NOMBRE = {5: "Fronda", 6: "Selva", 7: "Bosque Ancestral"}


def ancho_png(ruta: pathlib.Path) -> int:
    """Ancho en píxeles leyendo la cabecera IHDR. Evita depender de PIL."""
    with ruta.open("rb") as f:
        cab = f.read(24)
    if cab[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{ruta} no es un PNG")
    return struct.unpack(">I", cab[16:20])[0]


def camello(sid: str) -> str:
    return "".join(p.capitalize() for p in sid.split("_"))


def escena_nodo(sid, nombre, tipo, tex_nodo) -> str:
    return f"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/gameplay/resource_node.gd" id="1_rn"]
[ext_resource type="Texture2D" path="res://art/sprites/environment/{tex_nodo}" id="2_tex"]

[node name="ResourceNode{camello(sid)}" type="Node2D"]
script = ExtResource("1_rn")
resource_type = {tipo}

[node name="Sprite2D" type="Sprite2D" parent="."]
texture_filter = 1
scale = Vector2(2, 2)
offset = Vector2(0, -12)
texture = ExtResource("2_tex")
"""


def escena_generador(sid, nombre, tipo, nivel, cooldown, tex_plot, n_frames) -> str:
    corto = sid[:3]
    atlas = "\n".join(
        f'[sub_resource type="AtlasTexture" id="ATX_{corto}{i + 1}"]\n'
        f'atlas = ExtResource("3_tex")\n'
        f"region = Rect2({i * LADO}, 0, {LADO}, {LADO})"
        for i in range(n_frames)
    )
    lista = ", ".join(
        f'{{"duration": 1.0, "texture": SubResource("ATX_{corto}{i + 1}")}}'
        for i in range(n_frames)
    )
    # load_steps = 1 + ext_resources(3) + sub_resources(1 forma + n atlas + 1 frames)
    pasos = 1 + 3 + 1 + n_frames + 1
    return f"""[gd_scene load_steps={pasos} format=3]

[ext_resource type="Script" path="res://scripts/gameplay/resource_generator.gd" id="1_rg"]
[ext_resource type="PackedScene" path="res://scenes/environment/resource_node_{sid}.tscn" id="2_node"]
[ext_resource type="Texture2D" path="res://art/sprites/environment/{tex_plot}" id="3_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(44, 44)

{atlas}

[sub_resource type="SpriteFrames" id="SF_{corto}"]
animations = [{{
"frames": [{lista}],
"loop": true,
"name": &"idle",
"speed": 5.56
}}]

[node name="ResourceGenerator{camello(sid)}" type="Node2D"]
script = ExtResource("1_rg")
resource_type = {tipo}
resource_node_scene = ExtResource("2_node")
min_natural_level = {nivel}
generation_cooldown = {cooldown}

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
scale = Vector2(2, 2)
sprite_frames = SubResource("SF_{corto}")
animation = &"idle"
autoplay = "idle"

[node name="SpawnPoint" type="Marker2D" parent="."]

[node name="Area2D" type="Area2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Area2D"]
shape = SubResource("RectangleShape2D_1")
"""


def buildable(sid, edificio, coste, nivel) -> str:
    return f"""[gd_resource type="Resource" script_class="BuildableData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/buildable_data.gd" id="1_bd"]
[ext_resource type="PackedScene" path="res://scenes/environment/resource_generator_{sid}.tscn" id="2_scene"]

[resource]
script = ExtResource("1_bd")
id = &"build_generador_{sid}"
display_name = "{edificio}"
description = "Genera materiales de endgame. Requiere Patio Natural Nv {nivel} ({NIVEL_NOMBRE[nivel]})."
scene = ExtResource("2_scene")
cost = {coste}
allowed_zone = 1
size = Vector2i(1, 1)
unlocked_by_default = false
min_natural_level = {nivel}
"""


def main() -> None:
    escenas = RAIZ / "scenes/environment"
    datos = RAIZ / "data/buildables"
    arte = RAIZ / "art/sprites/environment"
    hechos = 0
    for sid, nombre, tipo, edificio, coste, nivel, cd, tex_plot, tex_nodo in RECURSOS:
        for t in (tex_plot, tex_nodo):
            if not (arte / t).exists():
                raise SystemExit(f"falta la textura prestada {t}")
        n = ancho_png(arte / tex_plot) // LADO
        salidas = [
            (escenas / f"resource_node_{sid}.tscn", escena_nodo(sid, nombre, tipo, tex_nodo)),
            (escenas / f"resource_generator_{sid}.tscn",
             escena_generador(sid, nombre, tipo, nivel, cd, tex_plot, n)),
            # El fichero va SIN el prefijo `build_`, aunque el id lo lleve: es la
            # convención de los 8 generadores que ya existían (generador_altar_lunar.tres
            # contiene id = build_generador_altar_lunar). Saltársela no rompe el juego
            # —los buildables se cargan escaneando la carpeta— pero sí rompe cualquier
            # herramienta que busque por patrón de nombre.
            (datos / f"generador_{sid}.tres", buildable(sid, edificio, coste, nivel)),
        ]
        for ruta, texto in salidas:
            ruta.write_text(texto, encoding="utf-8")
            hechos += 1
        print(f"  {sid:18} tipo={tipo}  Nv{nivel} {NIVEL_NOMBRE[nivel]:16} {coste:5}⚜  {n} frames")
    print(f"{hechos} ficheros escritos")


if __name__ == "__main__":
    main()
