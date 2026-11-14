shader_type spatial;
// Intonaco dipinto a mano: pennellate larghe, macchie d'umido verso terra, qualche crepa sottile.
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.80, 0.74, 0.62);
varying vec3 pm;
varying vec3 nm;
varying vec3 pl;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	pl = VERTEX;
}

void fragment() {
	vec2 uv = piano(pm, nm);
	float larga = fbm(uv * vec2(0.9, 2.3));
	float fine = rum(uv * vec2(7.0, 26.0)) * 0.6 + rum(uv * 41.0) * 0.4;
	float umido = smoothstep(1.3, 0.0, pl.y + fbm(uv * 1.7) * 0.9);              // più scuro e verdastro in basso
	vec2 c = celle(uv * 1.3 + 9.0);
	// crepe rade e morbide: solo dove una macchia larga lo consente, così non diventano una rete tratteggiata
	float crepa = (1.0 - smoothstep(0.0, 0.035, c.x)) * smoothstep(0.55, 0.75, fbm(uv * 0.35 + 4.0)) * 0.6;
	vec3 col = colore * (0.86 + 0.22 * larga) * (0.94 + 0.12 * fine);
	col = mix(col, colore * vec3(0.62, 0.66, 0.55), umido * 0.45);
	col = mix(col, colore * 0.45, crepa * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	NORMAL = rilievo(NORMAL, VERTEX, fine * 0.6 + larga * 0.4 - crepa * 1.5, 0.012);
}
