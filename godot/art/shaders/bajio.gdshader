shader_type canvas_item;
// Anima el bajío de la isla sin duplicar la textura del patio.
//
// La alternativa obvia —componer cuatro versiones del mapa entero y alternarlas—
// costaba ~57 MB para un efecto de ambiente. Aquí el mapa se compone una sola vez
// y el shader sustituye SOLO las celdas marcadas en la máscara, sacando el píxel
// de un atlas con los cuatro fotogramas. Máscara + atlas suman ~18 KB.

// 1 texel por celda del mapa. R > 0.5 = esa celda es bajío.
uniform sampler2D mascara : filter_nearest, repeat_disable;
// Los cuatro fotogramas en fila: 64×16.
uniform sampler2D fotogramas : filter_nearest, repeat_disable;
// Tamaño del mapa en celdas, para pasar de UV a coordenada de celda.
uniform vec2 celdas;
uniform float velocidad = 3.0;   // fotogramas por segundo
// Desfase por celda: sin esto todo el bajío parpadea a la vez y parece un fallo,
// no agua. Con él la onda recorre la costa.
uniform float desfase = 0.35;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (texture(mascara, UV).r > 0.5) {
		vec2 c = UV * celdas;
		vec2 dentro = fract(c);
		// La diagonal de la celda decide su desfase, así la onda avanza en sesgo.
		float t = TIME * velocidad + (floor(c.x) + floor(c.y)) * desfase;
		float f = floor(mod(t, 4.0));
		// El 0.999 evita que el filtrado se cuele en el fotograma vecino del atlas.
		vec2 uva = vec2((f + clamp(dentro.x, 0.0, 0.999)) * 0.25, dentro.y);
		base = texture(fotogramas, uva);
	}
	COLOR = base * COLOR;
}
