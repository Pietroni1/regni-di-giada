shader_type spatial;
// Piastre e bordi di armature ed elmi: metallo o lacca con graffi, usura chiara sugli spigoli e patina negli incavi.
// lamelle > 0: larghezza (m) delle lamelle attorno all'asse verticale del modello: giunture scure, ribattini e tinta che varia
// da una piastra all'altra (le file sovrapposte le fa la geometria).
render_mode diffuse_burley, cull_disabled;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.5, 0.5, 0.55);
uniform float metallico = 0.6;
uniform float ruvido = 0.4;
uniform float lamelle = 0.0;
varying vec3 pl;

void vertex() { pl = VERTEX; }

void fragment() {
	float graffi = rum3(pl * vec3(160.0, 14.0, 160.0)) * 0.5 + rum3(pl * vec3(20.0, 190.0, 20.0)) * 0.5;
	float patina = fbm3(pl * 6.0);
	float spigolo = clamp(length(fwidth(NORMAL)) * 4.0, 0.0, 1.0);        // dove la normale cambia in fretta
	vec3 base = colore;
	float giuntura = 0.0;
	float ribattino = 0.0;
	if (lamelle > 0.0) {
		float k = atan(pl.x, pl.z) * 0.2 / lamelle;          // lungo il giro del corpo (circa 20 cm di raggio)
		float x = fract(k);
		base *= 0.88 + 0.24 * h21(vec2(floor(k), floor(pl.y * 14.0)));
		giuntura = 1.0 - smoothstep(0.0, 0.035, min(x, 1.0 - x));
		ribattino = 1.0 - smoothstep(0.08, 0.13, length(vec2((x - 0.5) * lamelle, (fract(pl.y * 14.0) - 0.3) / 14.0)) / lamelle * 3.0);
	}
	vec3 col = base * (0.75 + 0.35 * patina) * (0.92 + 0.14 * graffi);
	col = mix(col, base * 1.7 + 0.08, spigolo * 0.55);
	col = mix(col, base * 0.45, smoothstep(0.62, 0.9, patina) * 0.45);
	col = mix(col, base * 0.3, giuntura * 0.6);
	col = mix(col, vec3(0.75, 0.55, 0.25), ribattino * 0.7);
	ALBEDO = col;
	METALLIC = mix(metallico, 0.9, ribattino);
	ROUGHNESS = clamp(ruvido + (graffi - 0.5) * 0.25 + smoothstep(0.6, 0.9, patina) * 0.3, 0.08, 1.0);
	SPECULAR = 0.5;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
