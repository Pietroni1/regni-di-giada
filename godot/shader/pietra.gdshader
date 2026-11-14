shader_type spatial;
// Muratura di pietra a corsi sfalsati, con conci di tono diverso, fughe incassate e muschio in basso.
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.42, 0.40, 0.37);
uniform float concio = 0.75;         // lato dei conci in metri
varying vec3 pm;
varying vec3 nm;
varying vec3 pl;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	pl = VERTEX;
}

void fragment() {
	vec2 uv = piano(pm, nm) / concio;
	uv.y *= 1.7;
	float riga = floor(uv.y);
	uv.x += h21(vec2(riga, 3.0));
	vec2 f = fract(uv);
	float id = h21(vec2(floor(uv.x), riga));
	float bx = min(f.x, 1.0 - f.x), by = min(f.y, 1.0 - f.y) / 1.7;
	float fuga = smoothstep(0.0, 0.06, min(bx, by * 1.7));
	float grana = rum(pm.xz * 9.0 + pm.y * 7.0) * 0.5 + rum(piano(pm, nm) * 31.0) * 0.5;
	vec3 col = colore * (0.72 + 0.5 * id) * (0.85 + 0.3 * grana);
	col = mix(colore * 0.3, col, fuga);
	float muschio = smoothstep(0.9, 0.0, pl.y) * smoothstep(0.4, 0.7, fbm(piano(pm, nm) * 2.3)) * (0.4 + 0.6 * (1.0 - fuga));
	col = mix(col, vec3(0.16, 0.26, 0.09), muschio * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	NORMAL = rilievo(NORMAL, VERTEX, fuga * 1.0 + grana * 0.25 + id * 0.3, 0.03);
}
